import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A circular progress ring with a centre label: the 60-second accept
/// countdown and the guest's budget meter ("₹1,300 / ₹7,000").
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.trackColor,
    this.size = 64,
    this.stroke = 7,
    this.child,
  });

  /// 0…1 (values above 1 draw a full ring).
  final double value;
  final Color color;
  final Color trackColor;
  final double size;
  final double stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _RingPainter(
        value.clamp(0, 1).toDouble(),
        color,
        trackColor,
        stroke,
      ),
      child: Center(child: child),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track, this.stroke);
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, 2 * pi, false, base);
    if (value <= 0) return;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, -pi / 2, 2 * pi * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

/// Counts down to [deadline] once a second and rebuilds [builder]. Used by
/// the new-order alert (60 s to accept) and "Limited today" offers.
class Countdown extends StatefulWidget {
  const Countdown({
    super.key,
    required this.deadline,
    required this.builder,
    this.onDone,
  });

  final DateTime deadline;
  final Widget Function(BuildContext context, Duration left) builder;
  final VoidCallback? onDone;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown>
    with SingleTickerProviderStateMixin {
  // Created in initState: a lazily-created ticker would first be touched in
  // dispose and never run.
  late final Ticker _ticker;
  Duration _left = Duration.zero;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _left = _compute();
    _ticker = createTicker((_) => _tick())..start();
  }

  Duration _compute() {
    final d = widget.deadline.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  void _tick() {
    final left = _compute();
    if (left.inMilliseconds ~/ 250 != _left.inMilliseconds ~/ 250) {
      setState(() => _left = left);
    }
    if (left == Duration.zero && !_done) {
      _done = true;
      // Nothing left to count: stop asking for frames.
      _ticker.stop();
      widget.onDone?.call();
    }
  }

  @override
  void didUpdateWidget(Countdown old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline) {
      _done = false;
      _left = _compute();
      if (!_ticker.isActive) _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _left);
}
