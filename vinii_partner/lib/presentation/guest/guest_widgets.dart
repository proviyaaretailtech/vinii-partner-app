import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/guest_session.dart';
import '../../core/money.dart';
import '../../domain/billing.dart';
import '../../domain/guest_catalog.dart';
import '../theme/guest_theme.dart';
import '../widgets/rings.dart';

/// Gives every guest screen the party's [GuestSession] and the staff exit.
/// Lives above the runtime's own Navigator, so pushed screens and sheets
/// (shown with `useRootNavigator: false`) all see it.
class GuestScope extends InheritedNotifier<GuestSession> {
  const GuestScope({
    super.key,
    required GuestSession session,
    required this.onExit,
    required super.child,
  }) : super(notifier: session);

  /// Staff-only way out; null inside Studio's preview.
  final VoidCallback? onExit;

  /// Rebuilds the caller whenever the session changes.
  static GuestSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GuestScope>()!.notifier!;

  /// For event handlers: no rebuild dependency.
  static GuestSession read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GuestScope>()!.notifier!;

  static VoidCallback? exitOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GuestScope>()?.onExit;
}

/// A soft slide-and-fade used for every guest screen, so the runtime feels
/// like one continuous surface rather than stacked Material pages.
Route<T> guestRoute<T>(Widget page, {bool up = false}) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 380),
  reverseTransitionDuration: const Duration(milliseconds: 280),
  pageBuilder: (context, a, b) => page,
  transitionsBuilder: (context, a, b, child) {
    final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: up ? const Offset(0, 0.12) : const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);

/// The page shell: template background, safe areas, and content held to a
/// phone-width column so the runtime still looks right in a wide box.
class GuestPage extends StatelessWidget {
  const GuestPage({
    super.key,
    required this.child,
    this.bottom,
    this.background,
    this.safeTop = true,
  });

  final Widget child;
  final Widget? bottom;
  final Color? background;
  final bool safeTop;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Scaffold(
      backgroundColor: background ?? p.background,
      body: SafeArea(
        top: safeTop,
        bottom: bottom == null,
        child: GuestColumn(child: child),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              top: false,
              child: GuestColumn(
                fill: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: bottom,
                ),
              ),
            ),
    );
  }
}

/// Centres content and caps it at 480 px wide.
class GuestColumn extends StatelessWidget {
  const GuestColumn({super.key, required this.child, this.fill = true});
  final Widget child;

  /// False for bars (the bottom button area): take the child's height, not
  /// all the height offered — otherwise the bar would swallow the page.
  final bool fill;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: fill ? null : 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: child,
    ),
  );
}

enum GuestButtonStyle { primary, outline, soft, success }

/// The one button shape of the runtime: a full-width pill, accent-filled by
/// default ("Start exploring →", "Place order →").
class GuestButton extends StatelessWidget {
  const GuestButton({
    super.key,
    required this.label,
    required this.onTap,
    this.style = GuestButtonStyle.primary,
    this.icon,
    this.trailingArrow = false,
    this.busy = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onTap;
  final GuestButtonStyle style;
  final IconData? icon;
  final bool trailingArrow;
  final bool busy;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final (bg, fg, border) = switch (style) {
      GuestButtonStyle.primary => (p.accent, p.onAccent, null),
      GuestButtonStyle.success => (p.success, Colors.white, null),
      GuestButtonStyle.soft => (p.surfaceAlt, p.ink, null),
      GuestButtonStyle.outline => (Colors.transparent, p.ink, p.border),
    };
    final enabled = onTap != null && !busy;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: border == null
              ? BorderSide.none
              : BorderSide(color: border, width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          child: SizedBox(
            height: dense ? 46 : 56,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: fg,
                    ),
                  )
                else ...[
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: p.body(
                        dense ? 14.5 : 16,
                        weight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                  if (trailingArrow) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20, color: fg),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon button, glassy over photos or tinted on the page.
class RoundIcon extends StatelessWidget {
  const RoundIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.color,
    this.background,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final Color? background;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final button = Material(
      color: background ?? p.surfaceAlt,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, size: size * 0.46, color: color ?? p.ink),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// Back arrow, centred title, optional trailing actions and the staff exit.
class GuestTopBar extends StatelessWidget {
  const GuestTopBar({
    super.key,
    this.title,
    this.onBack,
    this.trailing = const [],
  });

  final String? title;
  final VoidCallback? onBack;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          if (onBack != null || canPop)
            RoundIcon(
              icon: Icons.arrow_back_ios_new_rounded,
              size: 40,
              tooltip: 'Back',
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 40),
          Expanded(
            child: Text(
              title ?? '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: p.display(17, weight: FontWeight.w700),
            ),
          ),
          ...trailing,
          const GuestExitButton(),
          if (trailing.isEmpty && GuestScope.exitOf(context) == null)
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// The staff way out: a faint lock that needs a long-press and a confirm,
/// so a guest cannot leave the table app by accident.
class GuestExitButton extends StatelessWidget {
  const GuestExitButton({super.key});

  @override
  Widget build(BuildContext context) {
    final onExit = GuestScope.exitOf(context);
    if (onExit == null) return const SizedBox.shrink();
    final p = GuestPalette.of(context);
    return Tooltip(
      message: 'Staff: press and hold to leave',
      child: GestureDetector(
        key: const ValueKey('guest-exit'),
        onLongPress: () async {
          unawaited(HapticFeedback.mediumImpact());
          final ok = await showDialog<bool>(
            context: context,
            useRootNavigator: false,
            builder: (context) => AlertDialog(
              backgroundColor: p.surface,
              title: Text('Return to staff mode?', style: p.display(20)),
              content: Text(
                'The guest menu will close on this phone.',
                style: p.body(14, color: p.inkMuted),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Stay', style: p.body(15, color: p.ink)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Return',
                    style: p.body(15, weight: FontWeight.w700, color: p.ink),
                  ),
                ),
              ],
            ),
          );
          if (ok == true) onExit();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: p.inkMuted.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

/// The restaurant's mark: its logo, or its initials on the accent.
class GuestLogo extends StatelessWidget {
  const GuestLogo({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final brand = GuestScope.read(context).definition.brand;
    final words = brand.displayName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.toLowerCase() != 'the')
        .toList();
    final initials = words.isEmpty
        ? '·'
        : words.take(2).map((w) => w[0].toUpperCase()).join();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.accent,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(initials, style: p.display(size * 0.38, color: p.onAccent)),
    );
    if (brand.logoUrl == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.3),
      child: Image.network(
        brand.logoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => fallback,
      ),
    );
  }
}

/// A pill chip for storefront tags: "Bestseller" orange, "Spicy" with chili.
class TagChip extends StatelessWidget {
  const TagChip(this.tag, {super.key, this.onImage = false});
  final String tag;

  /// Over a photo scrim: always light text on a dark glass.
  final bool onImage;

  static String? emojiFor(String tag) => switch (tag.toLowerCase()) {
    'bestseller' => '🔥',
    'spicy' => '🌶️',
    "chef's special" => '👨‍🍳',
    'seasonal' => '🍂',
    'new' => '✨',
    'vegan' => '🌱',
    'gluten-free' => '🌾',
    'vegetarian' => '🥬',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final hot = tag.toLowerCase() == 'bestseller';
    final bg = hot
        ? const Color(0xFFF97316)
        : onImage
        ? Colors.black.withValues(alpha: 0.45)
        : p.surfaceAlt;
    final fg = hot || onImage ? Colors.white : p.ink;
    final emoji = emojiFor(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: onImage && !hot
            ? Border.all(color: Colors.white.withValues(alpha: 0.18))
            : null,
      ),
      child: Text(
        emoji == null ? tag : '$emoji $tag',
        style: p.body(12, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// – 1 + in a pill.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.qty,
    required this.onChanged,
    this.min = 0,
    this.compact = false,
  });

  final int qty;
  final ValueChanged<int> onChanged;
  final int min;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = compact ? 30.0 : 40.0;
    Widget btn(IconData icon, String tip, VoidCallback? onTap) => RoundIcon(
      icon: icon,
      size: s,
      tooltip: tip,
      background: p.surface,
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(
            Icons.remove_rounded,
            'Less',
            qty > min ? () => onChanged(qty - 1) : null,
          ),
          SizedBox(
            width: compact ? 26 : 34,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: p.price(compact ? 14 : 17),
            ),
          ),
          btn(Icons.add_rounded, 'More', () => onChanged(qty + 1)),
        ],
      ),
    );
  }
}

/// Green on track, amber when close, red when over.
Color budgetColor(GuestPalette p, BudgetStatus s) => s.over
    ? p.danger
    : s.close
    ? const Color(0xFFF59E0B)
    : p.success;

/// "₹1,300 / ₹7,000 · 19% used" around a ring.
class BudgetRing extends StatelessWidget {
  const BudgetRing({super.key, required this.status, this.size = 64});
  final BudgetStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: status.fraction),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      builder: (context, v, _) => ProgressRing(
        value: v,
        size: size,
        stroke: size / 9,
        color: budgetColor(p, status),
        trackColor: p.surfaceAlt,
        child: Text('${status.percentUsed}%', style: p.price(size * 0.24)),
      ),
    );
  }
}

/// A slim progress bar with "₹980 spent · 33% used".
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.status, this.caption});
  final BudgetStatus status;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                caption ?? '${rupees(status.spent)} / ${rupees(status.budget)}',
                style: p.body(13, weight: FontWeight.w600),
              ),
            ),
            Text(
              '${status.percentUsed}% used',
              style: p.body(13, color: p.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: status.fraction.clamp(0, 1).toDouble()),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: budgetColor(p, status),
              backgroundColor: p.surfaceAlt,
            ),
          ),
        ),
      ],
    );
  }
}

/// "You're well within your budget! ₹5,560 remaining" — or the warning.
class BudgetNote extends StatelessWidget {
  const BudgetNote({super.key, required this.status});
  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final c = budgetColor(p, status);
    final (icon, title) = status.over
        ? (Icons.error_outline_rounded, "You're over your budget")
        : status.close
        ? (Icons.info_outline_rounded, 'Getting close to your budget')
        : (Icons.check_circle_rounded, "You're well within your budget!");
    final line = status.over
        ? '${rupees(-status.remaining)} over'
        : '${rupees(status.remaining)} remaining';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: p.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: c),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: p.body(14, weight: FontWeight.w700)),
                Text(line, style: p.body(13, color: c)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded card on the template's surface.
class GuestCard extends StatelessWidget {
  const GuestCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Material(
      color: color ?? p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: borderColor ?? p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// "Preview — nothing was sent to the kitchen", on every post-order screen
/// inside Studio's preview.
class PreviewBanner extends StatelessWidget {
  const PreviewBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    if (!GuestScope.read(context).gateway.isPreview) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined, size: 16, color: p.inkMuted),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Preview — nothing was sent to the kitchen',
              style: p.body(12.5, weight: FontWeight.w600, color: p.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Light haptic plus the add itself — every "add" in the runtime uses it.
int addWithHaptic(BuildContext context, GuestItem item, {int qty = 1}) {
  HapticFeedback.lightImpact();
  return GuestScope.read(context).add(item, qty: qty);
}
