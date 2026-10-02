import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/guest_session.dart';
import '../../core/money.dart';
import '../../domain/billing.dart';
import '../../domain/guest_catalog.dart';
import '../../domain/storefront.dart';
import '../theme/guest_theme.dart';
import '../widgets/rings.dart';
import 'guest_nearby.dart';
import 'look/look.dart';
import 'look/motion.dart';

/// Gives every guest screen the party's [GuestSession], the staff exit and
/// where CMS pictures are served from. Lives above the runtime's own
/// Navigator, so pushed screens and sheets (shown with
/// `useRootNavigator: false`) all see it.
class GuestScope extends InheritedNotifier<GuestSession> {
  const GuestScope({
    super.key,
    required GuestSession session,
    required this.onExit,
    this.mediaBaseUrl = '',
    required super.child,
  }) : super(notifier: session);

  /// Staff-only way out; null inside Studio's preview.
  final VoidCallback? onExit;

  /// The Master's public origin for bucket pictures (see [mediaUrl]).
  final String mediaBaseUrl;

  /// A displayable address for a CMS picture reference, or null when there
  /// is none (or it cannot be shown on this phone).
  static String? mediaUrlOf(BuildContext context, String? ref) => mediaUrl(
    ref,
    context.getInheritedWidgetOfExactType<GuestScope>()?.mediaBaseUrl ?? '',
  );

  /// Rebuilds the caller whenever the session changes.
  static GuestSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GuestScope>()!.notifier!;

  /// For event handlers: no rebuild dependency.
  static GuestSession read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GuestScope>()!.notifier!;

  static VoidCallback? exitOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GuestScope>()?.onExit;
}

/// The restaurant's own guest-facing words (the copy registry, edited in the
/// VINII OS storefront CMS) in the party's language, falling back to its
/// English and then to the registry's English default:
///
/// ```dart
/// final t = GuestCopy.of(context);
/// Text(t('cart.place'));
/// ```
class GuestCopy {
  const GuestCopy(this.copy, this.language);

  /// Rebuilds the caller when the party switches language.
  factory GuestCopy.of(BuildContext context) {
    final s = GuestScope.of(context);
    return GuestCopy(s.definition.copy, s.language);
  }

  final StorefrontCopy copy;
  final CopyLanguage language;

  String call(String key, [Map<String, String> vars = const {}]) =>
      copyText(copy, key, language, vars);

  /// Only what the restaurant wrote; null keeps a screen's own wording.
  String? own(String key, [Map<String, String> vars = const {}]) =>
      ownCopyText(copy, key, language, vars);
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
    this.stage = 0.5,
    this.maxWidth = 480,
    this.alerts = false,
    this.alertsTop = 58,
    this.alertsEndInset = 0,
  });

  final Widget child;
  final Widget? bottom;

  /// Floats the "what the tables around you are ordering" alert over this
  /// page (menu-browsing pages only; never checkout or tracking).
  final bool alerts;

  /// How far down the alert floats, to clear this page's own header.
  final double alertsTop;

  /// Width of a side panel the alert must not centre across (the wide order panel).
  final double alertsEndInset;

  /// How wide the content may be. A phone-width column by default; a screen
  /// that lays out two panes asks for more.
  final double maxWidth;
  final Color? background;
  final bool safeTop;

  /// How strongly the lit room shows behind the page (0 to 1), or null for a
  /// flat page. It is a still picture, not an animation, so every page can
  /// have it at no cost.
  final double? stage;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final lit = stage != null && background == null;
    final scaffold = Scaffold(
      backgroundColor: lit ? Colors.transparent : (background ?? p.background),
      body: SafeArea(
        top: safeTop,
        bottom: bottom == null,
        child: GuestColumn(maxWidth: maxWidth, child: child),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              top: false,
              child: GuestColumn(
                fill: false,
                maxWidth: maxWidth > 480 ? 480 : maxWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: bottom,
                ),
              ),
            ),
    );
    final page = lit
        ? Stack(
            fit: StackFit.expand,
            children: [
              GuestStage(intensity: stage!, drift: false),
              scaffold,
            ],
          )
        : scaffold;
    return alerts
        ? NearbyAlertHost(
            topOffset: alertsTop,
            endInset: alertsEndInset,
            child: page,
          )
        : page;
  }
}

/// Centres content and caps it at [maxWidth] (480 px, a phone's width, unless
/// a screen asks for more).
class GuestColumn extends StatelessWidget {
  const GuestColumn({
    super.key,
    required this.child,
    this.fill = true,
    this.maxWidth = 480,
  });
  final Widget child;
  final double maxWidth;

  /// False for bars (the bottom button area): take the child's height, not
  /// all the height offered — otherwise the bar would swallow the page.
  final bool fill;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: fill ? null : 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

enum GuestButtonStyle { primary, outline, soft, success }

/// The one button of the runtime: full width, accent-filled by default
/// ("Start exploring →", "Place order →"). Its corners (pill, rounded,
/// square) and whether the main button is filled or outlined come from the
/// storefront's theme.
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
    this.onImage = false,
  });

  final String label;
  final VoidCallback? onTap;
  final GuestButtonStyle style;
  final IconData? icon;
  final bool trailingArrow;
  final bool busy;
  final bool dense;

  /// Over a darkened photo: an outlined main button is drawn in white, so
  /// a dark accent never disappears into the picture.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final line = onImage ? Colors.white : p.accent;
    final (bg, fg, border) = switch (style) {
      GuestButtonStyle.primary when p.buttonOutline => (
        Colors.transparent,
        line,
        line,
      ),
      GuestButtonStyle.primary => (p.accent, p.onAccent, null),
      GuestButtonStyle.success => (p.success, Colors.white, null),
      GuestButtonStyle.soft => (p.surfaceAlt, p.ink, null),
      GuestButtonStyle.outline => (Colors.transparent, p.ink, p.border),
    };
    final enabled = onTap != null && !busy;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: onTap == null ? 0.6 : 1,
      child: Material(
        color: bg,
        shape: p.buttonShape(
          border == null
              ? BorderSide.none
              : BorderSide(
                  color: border,
                  width: style == GuestButtonStyle.primary ? 1.8 : 1.4,
                ),
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

/// The restaurant's mark: its logo (uploaded in the CMS), or its initials
/// on the accent.
class GuestLogo extends StatelessWidget {
  const GuestLogo({super.key, this.size = 36, this.initials = true});
  final double size;

  /// False: nothing at all when there is no logo picture to show.
  final bool initials;

  /// Whether the restaurant has a logo this phone can show.
  static bool hasPicture(BuildContext context) =>
      GuestScope.mediaUrlOf(
        context,
        GuestScope.read(context).definition.brand.logoUrl,
      ) !=
      null;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final brand = GuestScope.read(context).definition.brand;
    final url = GuestScope.mediaUrlOf(context, brand.logoUrl);
    final words = brand.displayName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.toLowerCase() != 'the')
        .toList();
    final letters = words.isEmpty
        ? '·'
        : words.take(2).map((w) => w[0].toUpperCase()).join();
    final fallback = !initials
        ? const SizedBox.shrink()
        : Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(size * 0.3),
            ),
            child: Text(
              letters,
              style: p.display(size * 0.38, color: p.onAccent),
            ),
          );
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.3),
      child: Image.network(
        url,
        key: const ValueKey('guest-logo-image'),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => fallback,
      ),
    );
  }
}

/// A pill chip for storefront tags: "Bestseller" orange with a flame,
/// "Spicy" with heat. Icons are drawn, never emoji, so they keep the chip's
/// weight and colour in every font.
class TagChip extends StatelessWidget {
  const TagChip(this.tag, {super.key, this.onImage = false});
  final String tag;

  /// Over a photo scrim: always light text on a dark glass.
  final bool onImage;

  static IconData? iconFor(String tag) => switch (tag.toLowerCase()) {
    'bestseller' => Icons.local_fire_department_rounded,
    'spicy' => Icons.thermostat_rounded,
    "chef's special" => Icons.workspace_premium_rounded,
    'seasonal' => Icons.eco_rounded,
    'new' => Icons.auto_awesome_rounded,
    'vegan' => Icons.eco_rounded,
    'jain' => Icons.spa_rounded,
    'gluten-free' => Icons.grass_rounded,
    'vegetarian' => Icons.spa_rounded,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final hot = tag.toLowerCase() == 'bestseller';
    final bg = hot
        ? const Color(0xFFC2410C)
        : onImage
        ? Colors.black.withValues(alpha: 0.45)
        : p.surfaceAlt;
    final fg = hot || onImage ? Colors.white : p.ink;
    final icon = iconFor(tag);
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 5, 10, 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: onImage && !hot
            ? Border.all(color: Colors.white.withValues(alpha: 0.18))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            tag,
            style: p.body(12, weight: FontWeight.w700, color: fg),
          ),
        ],
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

/// The same colour as [budgetColor], safe to use for text on this page.
Color budgetTextColor(GuestPalette p, BudgetStatus s) =>
    p.readable(budgetColor(p, s));

/// Green on track, amber when close, red when over.
Color budgetColor(GuestPalette p, BudgetStatus s) => s.over
    ? p.danger
    : s.close
    ? const Color(0xFFF59E0B)
    : p.success;

/// "₹1,300 / ₹7,000 · 19% used" around a ring.
class BudgetRing extends StatelessWidget {
  const BudgetRing({
    super.key,
    required this.status,
    this.size = 64,
    this.fromZero = false,
  });
  final BudgetStatus status;
  final double size;

  /// Fills from empty when first shown (the budget overview), instead of
  /// appearing already filled.
  final bool fromZero;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: fromZero ? 0 : null, end: status.fraction),
      duration: fromZero ? GuestMotion.hero : const Duration(milliseconds: 650),
      curve: fromZero ? GuestMotion.arrive : Curves.easeOutBack,
      builder: (context, v, _) => ProgressRing(
        value: v,
        size: size,
        stroke: size / 9,
        color: budgetColor(p, status),
        trackColor: p.surfaceAlt,
        child: CountUp(
          value: status.percentUsed,
          from: fromZero ? 0 : null,
          format: (v) => '${v.round()}%',
          duration: fromZero ? GuestMotion.hero : GuestMotion.slow,
          style: p.price(size * 0.24),
        ),
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
    final text = budgetTextColor(p, status);
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
                Text(line, style: p.body(13, color: text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded card on the template's surface, lit from the upper left and
/// edged with a hairline drawn from the accent (not a grey line).
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: borderColor ?? p.hairline),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: color,
        gradient: color == null ? p.sheen : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
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
