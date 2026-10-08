import 'package:flutter/material.dart';

import '../../core/time_format.dart';
import '../../domain/pos_order.dart';
import '../../l10n/l10n.dart';
import '../theme/guest_theme.dart';
import '../widgets/food_art.dart';
import '../widgets/rings.dart';
import 'guest_categories.dart';
import 'guest_discover.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';
import 'look/look.dart';
import 'look/motion.dart';

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
    AppLocalizations l,
  ) {
    final path = switch (t) {
      ServiceType.dineIn || ServiceType.delivery => [
        GuestTrackingStep.confirmed,
        GuestTrackingStep.inKitchen,
        GuestTrackingStep.ready,
        GuestTrackingStep.onTheWay,
        GuestTrackingStep.served,
      ],
      ServiceType.takeaway => [
        GuestTrackingStep.confirmed,
        GuestTrackingStep.inKitchen,
        GuestTrackingStep.ready,
        GuestTrackingStep.served,
      ],
    };
    return [
      for (final st in path) (st, _stepTitle(l, c, t, st), _stepHint(l, t, st)),
    ];
  }

  /// What a step is called for this way of ordering.
  static String _stepTitle(
    AppLocalizations l,
    GuestCopy c,
    ServiceType t,
    GuestTrackingStep st,
  ) => switch (st) {
    GuestTrackingStep.confirmed =>
      c.own('order.confirmed') ?? l.guestTrackConfirmed,
    GuestTrackingStep.inKitchen =>
      c.own('order.in_kitchen') ?? l.guestTrackInKitchen,
    GuestTrackingStep.ready =>
      t == ServiceType.delivery
          ? l.guestTrackPacked
          : c.own('order.ready') ?? l.guestTrackReady,
    GuestTrackingStep.onTheWay => l.guestTrackOnTheWay,
    GuestTrackingStep.served => switch (t) {
      // Its default line repeats the subtitle; only the restaurant's own.
      ServiceType.dineIn => c.own('order.served') ?? l.guestTrackServed,
      ServiceType.takeaway => l.guestTrackPickedUp,
      ServiceType.delivery => l.guestTrackDelivered,
    },
  };

  /// The line under a step's name.
  static String _stepHint(
    AppLocalizations l,
    ServiceType t,
    GuestTrackingStep st,
  ) => switch (st) {
    GuestTrackingStep.confirmed => l.guestTrackConfirmedHint,
    GuestTrackingStep.inKitchen => l.guestTrackInKitchenHint,
    GuestTrackingStep.ready => switch (t) {
      ServiceType.dineIn => l.guestTrackReadyHintTable,
      ServiceType.takeaway => l.guestTrackReadyHintCounter,
      ServiceType.delivery => l.guestTrackPackedHint,
    },
    GuestTrackingStep.onTheWay =>
      t == ServiceType.delivery
          ? l.guestTrackOnTheWayHintDelivery
          : l.guestTrackOnTheWayHintTable,
    GuestTrackingStep.served => l.guestTrackEnjoy,
  };

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final l = context.l10n;
    final t = GuestCopy.of(context);
    final order = s.latest!;
    final current = s.step;
    final steps = stepsFor(order.serviceType, t, l);
    final tableName = l.guestTableNameOf(s);
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
          GuestTopBar(
            title: heading ?? l.guestTrackTitle(number: order.displayNo),
          ),
          Center(
            child: Text(
              [
                if (heading != null) '#${order.displayNo}',
                if (order.serviceType == ServiceType.dineIn &&
                    tableName != null)
                  tableName,
                l.guestPlacedItemCount(count: order.itemCount),
              ].join(' · '),
              style: p.body(13.5, color: p.inkMuted),
            ),
          ),
          const Center(child: PreviewBanner()),
          if (s.gateway.isPreview && current != GuestTrackingStep.served)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: GuestButton(
                key: const ValueKey('preview-next'),
                label: l.guestTrackNextPreview,
                icon: Icons.skip_next_rounded,
                style: GuestButtonStyle.soft,
                dense: true,
                onTap: () => s.advancePreview([for (final st in steps) st.$1]),
              ),
            ),
          const SizedBox(height: 12),
          if (!cancelled)
            Reveal(
              child: _StatusHero(order: order, current: current, steps: steps),
            ),
          if (cancelled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GuestCard(
                color: p.danger.withValues(alpha: 0.1),
                child: Text(
                  l.guestTrackCancelled,
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
                        index: i,
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
          if (!cancelled &&
              minutes != null &&
              current.index < GuestTrackingStep.ready.index)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: GuestCard(
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: p.inkMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.guestTrackEstimatedTime,
                        style: p.body(14, color: p.inkMuted),
                      ),
                    ),
                    Text(
                      l.guestPlacedEstimateRange(
                        low: minutes,
                        high: minutes + 5,
                      ),
                      style: p.body(15, weight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          if (s.features.discoverWhileWaiting) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.guestDiscoverMore,
                      style: p.display(20, weight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => GuestFlow.discover(context, waiting: true),
                    child: Text(l.guestTrackSeeAll, style: p.body(14)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                l.guestDiscoverWaiting,
                style: p.body(13.5, color: p.inkMuted),
              ),
            ),
            const DiscoverStrip(),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: GuestButton(
              label: l.guestPlacedViewBill,
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

/// The one thing to look at while waiting: the order's first dish in a ring
/// that fills as the kitchen works through the steps, with what is happening
/// now and roughly how long is left.
class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.order,
    required this.current,
    required this.steps,
  });

  final PlacedOrder order;
  final GuestTrackingStep current;
  final List<(GuestTrackingStep, String, String)> steps;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final at = steps.indexWhere((st) => st.$1 == current);
    final now = steps[at < 0 ? 0 : at];
    final fraction = steps.length < 2
        ? 1.0
        : ((at < 0 ? 0 : at) / (steps.length - 1)).clamp(0.0, 1.0);
    final first = order.lines.isEmpty ? null : order.lines.first;
    final active = p.isDark ? p.accent : p.readable(p.keyLight);
    final served = current == GuestTrackingStep.served;
    return Column(
      children: [
        SizedBox.square(
          dimension: 156,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: fraction),
                duration: GuestMotion.hero,
                curve: GuestMotion.arrive,
                builder: (context, v, _) => ProgressRing(
                  value: v == 0 ? 0.04 : v,
                  size: 156,
                  stroke: 6,
                  color: served ? p.success : active,
                  trackColor: p.hairline,
                ),
              ),
              SizedBox.square(
                dimension: 128,
                child: FoodArt(
                  // i18n-ignore: name of the painted plate, not shown as text
                  name: first?.name ?? 'plate',
                  imageUrl: first == null
                      ? null
                      : s.catalog.item(first.itemId)?.item.imageUrl,
                  radius: 64,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: GuestMotion.base,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(a),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey(now.$1),
            children: [
              Text(now.$2, textAlign: TextAlign.center, style: p.display(22)),
              const SizedBox(height: 2),
              Text(
                context.l10n.guestTrackStepOf(
                  step: (at < 0 ? 0 : at) + 1,
                  total: steps.length,
                ),
                textAlign: TextAlign.center,
                style: p.body(14, color: served ? p.success : active),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.last,
    this.time,
  });

  final int index;
  final String title;
  final String subtitle;
  final _State state;
  final bool last;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final active = p.isDark ? p.accent : p.readable(p.keyLight);
    final color = switch (state) {
      _State.done => p.success,
      _State.current => active,
      _State.future => p.border,
    };
    return Reveal(
      index: index,
      dx: 12,
      dy: 0,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  // A step changing state swaps its marker with a pop.
                  AnimatedSwitcher(
                    duration: GuestMotion.slow,
                    switchInCurve: Curves.easeOutBack,
                    transitionBuilder: (child, a) =>
                        ScaleTransition(scale: a, child: child),
                    child: KeyedSubtree(
                      key: ValueKey(state),
                      child: _Marker(state: state, color: color),
                    ),
                  ),
                  if (!last)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        // The line fills downward once the step is done. A
                        // painter, so the row can still size itself.
                        child: SizedBox(
                          width: 2.5,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: state == _State.done ? 1 : 0),
                            duration: GuestMotion.hero,
                            curve: GuestMotion.arrive,
                            builder: (context, v, _) => CustomPaint(
                              painter: _LinePainter(v, p.border, p.success),
                            ),
                          ),
                        ),
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
                              color: state == _State.future
                                  ? p.inkMuted
                                  : p.ink,
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
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter(this.fill, this.track, this.done);
  final double fill;
  final Color track;
  final Color done;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.width / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = track,
    );
    if (fill > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height * fill),
          r,
        ),
        Paint()..color = done,
      );
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.fill != fill || old.track != track || old.done != done;
}

/// A step's round marker: a tick when done, a breathing halo with three
/// travelling dots while the kitchen is on it, an empty ring before that.
class _Marker extends StatefulWidget {
  const _Marker({required this.state, required this.color});
  final _State state;
  final Color color;

  @override
  State<_Marker> createState() => _MarkerState();
}

class _MarkerState extends State<_Marker> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.state == _State.current &&
        _c == null &&
        !reducedMotion(context)) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final c = widget.color;
    switch (widget.state) {
      case _State.done:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        );
      case _State.future:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(color: p.border),
          ),
        );
      case _State.current:
        final c0 = _c;
        return SizedBox.square(
          dimension: 30,
          child: c0 == null
              ? _dots(c, 0.5)
              : AnimatedBuilder(
                  animation: c0,
                  builder: (context, _) => _dots(c, c0.value),
                ),
        );
    }
  }

  Widget _dots(Color c, double t) {
    final breathe = (1 - (2 * t - 1).abs());
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.25 + 0.3 * breathe),
                blurRadius: 10 + 8 * breathe,
                spreadRadius: 1 + 3 * breathe,
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha:
                        0.45 + 0.55 * (1 - ((t * 3 - i) % 3) / 3).clamp(0, 1),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
