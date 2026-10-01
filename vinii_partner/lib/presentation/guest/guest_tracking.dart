import 'package:flutter/material.dart';

import '../../core/time_format.dart';
import '../../domain/pos_order.dart';
import '../theme/guest_theme.dart';
import 'guest_categories.dart';
import 'guest_discover.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';

/// Board 1 #13 / Board 2 #10: live order tracking. Real orders follow the
/// POS status through the gateway's watch stream (the kitchen's taps move
/// this screen); in Studio's preview a "Next step (preview)" control walks
/// through every step locally so owners can see them all.
class GuestTrackingScreen extends StatefulWidget {
  const GuestTrackingScreen({super.key});

  @override
  State<GuestTrackingScreen> createState() => _GuestTrackingScreenState();
}

class _GuestTrackingScreenState extends State<GuestTrackingScreen> {
  bool _servedShown = false;

  /// The steps for how this order reaches the guest, with wording to match.
  /// Step names the restaurant can change come from the copy registry;
  /// "Packed", "Picked up" and "Delivered" mean something else and stay.
  static List<(GuestTrackingStep, String, String)> stepsFor(
    ServiceType t,
    GuestCopy c,
  ) {
    final confirmed = (
      GuestTrackingStep.confirmed,
      c('order.confirmed'),
      GuestTrackingStep.confirmed.subtitle,
    );
    final kitchen = (
      GuestTrackingStep.inKitchen,
      c('order.in_kitchen'),
      GuestTrackingStep.inKitchen.subtitle,
    );
    return switch (t) {
      ServiceType.dineIn => [
        confirmed,
        kitchen,
        (
          GuestTrackingStep.ready,
          c('order.ready'),
          GuestTrackingStep.ready.subtitle,
        ),
        (
          GuestTrackingStep.onTheWay,
          GuestTrackingStep.onTheWay.title,
          GuestTrackingStep.onTheWay.subtitle,
        ),
        (
          GuestTrackingStep.served,
          // Its default line repeats the subtitle; only the restaurant's own.
          c.own('order.served') ?? GuestTrackingStep.served.title,
          GuestTrackingStep.served.subtitle,
        ),
      ],
      ServiceType.takeaway => [
        confirmed,
        kitchen,
        (
          GuestTrackingStep.ready,
          c('order.ready'),
          'Collect it at the counter',
        ),
        (GuestTrackingStep.served, 'Picked up', 'Enjoy your meal!'),
      ],
      ServiceType.delivery => [
        confirmed,
        kitchen,
        (GuestTrackingStep.ready, 'Packed', 'Waiting for the rider'),
        (GuestTrackingStep.onTheWay, 'On the way', 'Heading to you'),
        (GuestTrackingStep.served, 'Delivered', 'Enjoy your meal!'),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final t = GuestCopy.of(context);
    final order = s.latest!;
    final current = s.step;
    final steps = stepsFor(order.serviceType, t);
    // The restaurant's own heading, if it wrote one; the number then moves
    // to the line underneath.
    final heading = t.own('order.tracking');
    final cancelled = order.status == PosStatus.cancelled;
    if (current == GuestTrackingStep.served && !_servedShown) {
      _servedShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GuestFlow.served(context);
      });
    }
    final minutes = s.estimatedMinutes(order);
    return GuestPage(
      bottom: s.lines.isNotEmpty ? const CartBar() : null,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GuestTopBar(title: heading ?? 'Order #${order.displayNo}'),
          Center(
            child: Text(
              [
                if (heading != null) '#${order.displayNo}',
                if (order.serviceType == ServiceType.dineIn &&
                    s.tableName != null)
                  s.tableName!,
                '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
              ].join(' · '),
              style: p.body(13.5, color: p.inkMuted),
            ),
          ),
          const Center(child: PreviewBanner()),
          const SizedBox(height: 12),
          if (cancelled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GuestCard(
                color: p.danger.withValues(alpha: 0.1),
                child: Text(
                  'This order was cancelled. Please speak to a staff member.',
                  style: p.body(15, weight: FontWeight.w700),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GuestCard(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
                child: Column(
                  children: [
                    for (final (i, st) in steps.indexed)
                      _StepRow(
                        title: st.$2,
                        subtitle: st.$3,
                        time: i == 0 ? clockTime(order.createdAt) : null,
                        state: st.$1.index < current.index
                            ? _State.done
                            : st.$1 == current
                            ? (current == GuestTrackingStep.served
                                  ? _State.done
                                  : _State.current)
                            : _State.future,
                        last: i == steps.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          if (!cancelled && current.index < GuestTrackingStep.ready.index)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: GuestCard(
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: p.inkMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Estimated time',
                        style: p.body(14, color: p.inkMuted),
                      ),
                    ),
                    Text(
                      '$minutes–${minutes + 5} minutes',
                      style: p.body(15, weight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          if (s.gateway.isPreview && current != GuestTrackingStep.served)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: GuestButton(
                key: const ValueKey('preview-next'),
                label: 'Next step (preview)',
                icon: Icons.skip_next_rounded,
                style: GuestButtonStyle.soft,
                dense: true,
                onTap: () => s.advancePreview([for (final st in steps) st.$1]),
              ),
            ),
          if (s.features.discoverWhileWaiting) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Discover more',
                      style: p.display(20, weight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => GuestFlow.discover(context, waiting: true),
                    child: Text('See all', style: p.body(14)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'Keep exploring while we prepare your order.',
                style: p.body(13.5, color: p.inkMuted),
              ),
            ),
            const DiscoverStrip(),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: GuestButton(
              label: 'View bill',
              style: GuestButtonStyle.outline,
              dense: true,
              onTap: () => GuestFlow.bill(context),
            ),
          ),
        ],
      ),
    );
  }
}

enum _State { done, current, future }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.last,
    this.time,
  });

  final String title;
  final String subtitle;
  final _State state;
  final bool last;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final active = p.isDark ? p.accent : const Color(0xFFD08A3C);
    final color = switch (state) {
      _State.done => p.success,
      _State.current => active,
      _State.future => p.border,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  width: state == _State.current ? 30 : 26,
                  height: state == _State.current ? 30 : 26,
                  decoration: BoxDecoration(
                    color: state == _State.future ? p.surfaceAlt : color,
                    shape: BoxShape.circle,
                    boxShadow: state == _State.current
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: state == _State.done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : state == _State.current
                      ? const Icon(
                          Icons.more_horiz_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: state == _State.done ? p.success : p.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: p.body(
                            15.5,
                            weight: FontWeight.w700,
                            color: state == _State.future ? p.inkMuted : p.ink,
                          ),
                        ),
                      ),
                      if (time != null)
                        Text(time!, style: p.body(12.5, color: p.inkMuted)),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: p.body(
                      13,
                      color: state == _State.current ? active : p.inkMuted,
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
