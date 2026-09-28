import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../domain/pos_order.dart';
import '../../domain/storefront.dart';
import '../theme/guest_theme.dart';
import 'guest_effects.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';

/// Board 1 #12, Board 2 #9 and #13: the celebration after "Place order" —
/// the server's order number and total, never a local guess. A pre-order
/// shows its pickup time instead of a serving estimate.
class GuestPlacedScreen extends StatelessWidget {
  const GuestPlacedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final order = s.latest!;
    final pre = order.scheduledFor != null;
    final minutes = s.estimatedMinutes(order);
    return CelebrationPage(
      title: pre ? 'Pre-order confirmed!' : 'Order placed!',
      lines: [
        '#${order.displayNo}',
        [
          if (order.serviceType == ServiceType.dineIn && s.tableName != null)
            s.tableName!,
          '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
          rupees(order.bill.payable),
        ].join(' · '),
        if (pre)
          'Pickup on ${DateFormat('EEE, d MMM').format(order.scheduledFor!)} • '
              '${DateFormat('h:mm a').format(order.scheduledFor!)}',
      ],
      card: pre
          ? null
          : _InfoCard(
              icon: Icons.timer_outlined,
              title: 'Estimated serving time',
              value: '$minutes–${minutes + 5} minutes',
            ),
      primary: s.features.liveTracking && !pre
          ? GuestButton(
              label: 'Track order',
              trailingArrow: true,
              onTap: () => GuestFlow.tracking(context),
            )
          : GuestButton(
              label: pre ? 'View pre-order' : 'View order details',
              onTap: () => GuestFlow.bill(context),
            ),
      secondary: GuestButton(
        label: pre ? 'Order something else' : 'Continue exploring',
        style: GuestButtonStyle.outline,
        onTap: () => GuestFlow.orderMore(context),
      ),
      dark: p.isDark,
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
    final dineIn = s.mode == GuestServiceMode.dineIn;
    return CelebrationPage(
      title: dineIn ? 'Your order is served!' : 'Your order is ready!',
      lines: const ['Hope you enjoy your meal.'],
      primary: GuestButton(
        label: 'View bill',
        trailingArrow: true,
        onTap: () => GuestFlow.bill(context),
      ),
      secondary: GuestButton(
        label: 'Order more',
        style: GuestButtonStyle.outline,
        onTap: () => GuestFlow.orderMore(context),
      ),
      dark: p.isDark,
    );
  }
}

/// The shared celebratory layout: confetti, the springy check, a big title
/// (handwritten on the artisan template) and two buttons. Light templates
/// switch to their ink colour as the background, like Board 2 #9.
class CelebrationPage extends StatelessWidget {
  const CelebrationPage({
    super.key,
    required this.title,
    required this.lines,
    required this.primary,
    required this.secondary,
    required this.dark,
    this.card,
  });

  final String title;
  final List<String> lines;
  final Widget primary;
  final Widget secondary;
  final Widget? card;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final bg = dark ? p.background : p.ink;
    final fg = dark ? p.ink : p.background;
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Confetti(),
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
                          const SizedBox(height: 40),
                          const SuccessCheck(size: 104),
                          const SizedBox(height: 28),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: p.scriptFamily != null
                                ? p.hero(40, color: fg)
                                : p.display(32, color: fg),
                          ),
                          const SizedBox(height: 12),
                          for (final (i, l) in lines.indexed)
                            Padding(
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
                          if (card != null) ...[
                            const SizedBox(height: 24),
                            card!,
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: _OnDark(
                      dark: dark,
                      child: Column(
                        children: [
                          primary,
                          const SizedBox(height: 12),
                          secondary,
                        ],
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
    final inverted = GuestPalette(
      template: p.template,
      background: p.ink,
      surface: p.ink,
      surfaceAlt: p.ink.withValues(alpha: 0.8),
      border: p.background.withValues(alpha: 0.4),
      ink: p.background,
      inkMuted: p.background.withValues(alpha: 0.7),
      accent: darkAccent ? p.background : p.accent,
      onAccent: darkAccent ? p.ink : p.onAccent,
      success: p.success,
      danger: p.danger,
      displayFamily: p.displayFamily,
      scriptFamily: p.scriptFamily,
      bodyFamily: p.bodyFamily,
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
