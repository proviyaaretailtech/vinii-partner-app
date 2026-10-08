import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../core/time_format.dart';
import '../../domain/pos_order.dart';
import '../../domain/storefront.dart';
import '../../l10n/l10n.dart';
import '../theme/guest_theme.dart';
import 'guest_effects.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';
import 'look/look.dart';
import 'look/motion.dart';
import 'look/tray.dart';

/// Board 1 #12, Board 2 #9 and #13: the celebration after "Place order" —
/// the server's order number and total, never a local guess. A pre-order
/// shows its pickup time instead of a serving estimate.
class GuestPlacedScreen extends StatelessWidget {
  const GuestPlacedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final l = context.l10n;
    final order = s.latest!;
    final pre = order.scheduledFor != null;
    final minutes = s.estimatedMinutes(order);
    final tableName = l.guestTableNameOf(s);
    return CelebrationPage(
      title: pre
          ? l.guestPlacedPreOrderTitle
          : GuestCopy.of(context).own('order.placed') ?? l.guestPlacedTitle,
      lines: [
        '#${order.displayNo}',
        [
          if (order.serviceType == ServiceType.dineIn && tableName != null)
            tableName,
          l.guestPlacedItemCount(count: order.itemCount),
          rupees(order.bill.payable),
        ].join(' · '),
        if (pre)
          l.guestPlacedPickupOn(
            day: dateFormat('EEE, d MMM').format(order.scheduledFor!),
            time: wallClock(order.scheduledFor!),
          ),
      ],
      card: pre || minutes == null
          ? null
          : _InfoCard(
              icon: Icons.timer_outlined,
              title: l.guestPlacedEstimateTitle,
              value: l.guestPlacedEstimateRange(
                low: minutes,
                high: minutes + 5,
              ),
            ),
      primary: s.features.liveTracking && !pre
          ? GuestButton(
              label: l.guestPlacedTrackOrder,
              trailingArrow: true,
              onTap: () => GuestFlow.tracking(context),
            )
          : GuestButton(
              label: pre ? l.guestPlacedViewPreOrder : l.guestPlacedViewDetails,
              onTap: () => GuestFlow.bill(context),
            ),
      secondary: GuestButton(
        label: pre ? l.guestPlacedOrderElse : l.guestPlacedContinue,
        style: GuestButtonStyle.outline,
        onTap: () => GuestFlow.orderMore(context),
      ),
      dark: p.isDark,
      tray: order.lines,
    );
  }
}

/// Board 1 #15: "Your order is served!".
class GuestServedScreen extends StatelessWidget {
  const GuestServedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final l = context.l10n;
    final dineIn = s.mode == GuestServiceMode.dineIn;
    return CelebrationPage(
      title: dineIn ? l.guestPlacedServedTitle : l.guestPlacedReadyTitle,
      lines: [l.guestPlacedEnjoy],
      primary: GuestButton(
        label: l.guestPlacedViewBill,
        trailingArrow: true,
        onTap: () => GuestFlow.bill(context),
      ),
      secondary: GuestButton(
        label: l.guestPlacedOrderMore,
        style: GuestButtonStyle.outline,
        onTap: () => GuestFlow.orderMore(context),
      ),
      dark: p.isDark,
      tray: s.latest?.lines ?? const [],
    );
  }
}

/// The shared celebratory layout: confetti, the drawing check, a big title
/// (handwritten on the artisan template) and two buttons. Light templates
/// switch to their ink colour as the background, like Board 2 #9. Everything
/// arrives in one sequence (check, title, order number, details, buttons),
/// and the phone gives one firm tap as the page arrives.
class CelebrationPage extends StatefulWidget {
  const CelebrationPage({
    super.key,
    required this.title,
    required this.lines,
    required this.primary,
    required this.secondary,
    required this.dark,
    this.card,
    this.tray = const [],
  });

  final String title;
  final List<String> lines;
  final Widget primary;
  final Widget secondary;
  final Widget? card;
  final bool dark;

  /// The dishes this is about, shown under the words.
  final List<CartLine> tray;

  @override
  State<CelebrationPage> createState() => _CelebrationPageState();
}

class _CelebrationPageState extends State<CelebrationPage> {
  @override
  void initState() {
    super.initState();
    // One firm tap as the page arrives (no timer: a frame callback).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) HapticFeedback.mediumImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final fg = widget.dark ? p.ink : p.background;
    return Scaffold(
      backgroundColor: widget.dark ? p.background : p.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const GuestStage(night: true, intensity: 0.85, motes: 14),
          const Confetti(origin: Alignment(0, -0.38)),
          SafeArea(
            child: GuestColumn(
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: GuestExitButton(),
                  ),
                  const PreviewBanner(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          const SuccessCheck(size: 96),
                          Reveal(
                            delay: const Duration(milliseconds: 420),
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: p.scriptFamily != null
                                  ? p.hero(40, color: fg)
                                  : p.display(32, color: fg),
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final (i, l) in widget.lines.indexed)
                            Reveal(
                              delay: Duration(milliseconds: 560 + i * 90),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  l,
                                  textAlign: TextAlign.center,
                                  style: i == 0
                                      ? p.body(
                                          17,
                                          weight: FontWeight.w800,
                                          color: fg,
                                        )
                                      : p.body(
                                          14.5,
                                          color: fg.withValues(alpha: 0.7),
                                        ),
                                ),
                              ),
                            ),
                          if (widget.tray.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            Reveal(
                              delay: const Duration(milliseconds: 760),
                              child: DishTray(lines: widget.tray),
                            ),
                          ],
                          if (widget.card != null) ...[
                            const SizedBox(height: 24),
                            Reveal(
                              delay: const Duration(milliseconds: 880),
                              child: widget.card!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Reveal(
                    delay: const Duration(milliseconds: 960),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: _OnDark(
                        dark: widget.dark,
                        child: Column(
                          children: [
                            widget.primary,
                            const SizedBox(height: 12),
                            widget.secondary,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Buttons on the inverted (ink) background need light ink, and a dark
/// accent (espresso) would vanish there, so it swaps to the page colour.
class _OnDark extends StatelessWidget {
  const _OnDark({required this.dark, required this.child});
  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (dark) return child;
    final p = GuestPalette.of(context);
    final darkAccent = p.accent.computeLuminance() < 0.25;
    final inverted = p.copyWith(
      background: p.ink,
      surface: p.ink,
      surfaceAlt: p.ink.withValues(alpha: 0.8),
      border: p.background.withValues(alpha: 0.4),
      ink: p.background,
      inkMuted: p.background.withValues(alpha: 0.7),
      accent: darkAccent ? p.background : p.accent,
      onAccent: darkAccent ? p.ink : p.onAccent,
    );
    return Theme(
      data: Theme.of(context).copyWith(extensions: [inverted]),
      child: child,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final fg = p.isDark ? p.ink : p.background;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: p.isDark ? p.accent : fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: p.body(13, color: fg.withValues(alpha: 0.7)),
                ),
                Text(
                  value,
                  style: p.body(17, weight: FontWeight.w800, color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
