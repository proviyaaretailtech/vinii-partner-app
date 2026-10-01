import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/guest_theme.dart';
import 'look/look.dart';
import 'look/motion.dart';

/// A one-shot confetti burst for "Order placed!" and "Served": a cannon from
/// [origin] that fans upward, slows against the air and then flutters down,
/// tumbling as it falls. It plays once (about 3.4 s) and stops, so screens
/// and tests never spin forever; under reduced motion it does not play.
class Confetti extends StatefulWidget {
  const Confetti({
    super.key,
    this.count = 96,
    this.origin = const Alignment(0, -0.5),
  });
  final int count;

  /// Where the burst leaves from, in the page's own alignment space.
  final Alignment origin;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  List<_Bit>? _bits;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bits != null) return;
    final r = Random(7);
    _bits = [
      for (var i = 0; i < widget.count; i++)
        _Bit(
          angle: -pi * (0.08 + 0.84 * r.nextDouble()),
          speed: 260 + r.nextDouble() * 560,
          spin: (r.nextDouble() - 0.5) * 16,
          flip: 3 + r.nextDouble() * 6,
          sway: 6 + r.nextDouble() * 14,
          swayRate: 2 + r.nextDouble() * 3,
          size: 6 + r.nextDouble() * 7,
          delay: r.nextDouble() * 0.08,
          shape: i % 7 == 0 ? 1 : (i % 5 == 0 ? 2 : 0),
          tone: i % 6,
        ),
    ];
    if (!reducedMotion(context)) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bits = _bits;
    if (bits == null || reducedMotion(context)) {
      return const SizedBox.shrink();
    }
    final p = GuestPalette.of(context);
    final colors = [
      p.accent,
      p.keyLight,
      p.success,
      Colors.white.withValues(alpha: 0.92),
      Color.lerp(p.keyLight, Colors.white, 0.45)!,
      Color.lerp(p.accent, p.danger, 0.5)!,
    ];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(bits, _c.value, colors, widget.origin),
        ),
      ),
    );
  }
}

class _Bit {
  const _Bit({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.flip,
    required this.sway,
    required this.swayRate,
    required this.size,
    required this.delay,
    required this.shape,
    required this.tone,
  });
  final double angle, speed, spin, flip, sway, swayRate, size, delay;
  final int shape, tone;
}

const _gravity = 900.0;
const _drag = 2.3;

/// Where a piece of confetti fired from [origin] at [angle] (radians, up is
/// negative) and [speed] (px/s) is after [sec] seconds. Drag slows it
/// exponentially; gravity pulls it down until the two balance in a steady
/// fall of gravity / drag. So it rises, slows, and flutters down past where
/// it started.
@visibleForTesting
Offset confettiAt(Offset origin, double angle, double speed, double sec) {
  final decay = 1 - exp(-_drag * sec);
  final vx = cos(angle) * speed;
  final vy = sin(angle) * speed;
  return Offset(
    origin.dx + vx * decay / _drag,
    origin.dy +
        _gravity / _drag * sec +
        (vy - _gravity / _drag) * decay / _drag,
  );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t, this.colors, this.origin);
  final List<_Bit> bits;
  final double t;
  final List<Color> colors;
  final Alignment origin;

  static const _life = 3.4;

  @override
  void paint(Canvas canvas, Size size) {
    final o = origin.alongSize(size);
    final paint = Paint();
    for (final b in bits) {
      final local = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final sec = local * _life;
      final at = confettiAt(o, b.angle, b.speed, sec);
      final x = at.dx + sin(sec * b.swayRate) * b.sway * min(1, sec);
      final y = at.dy;
      final fade = local > 0.78 ? (1 - local) / 0.22 : 1.0;
      paint.color = colors[b.tone % colors.length].withValues(alpha: fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(b.spin * sec);
      final flip = cos(sec * b.flip).abs().clamp(0.15, 1.0);
      switch (b.shape) {
        case 1:
          canvas.drawCircle(Offset.zero, b.size * 0.42, paint);
        case 2:
          final tri = Path()
            ..moveTo(0, -b.size * 0.6)
            ..lineTo(b.size * 0.55 * flip, b.size * 0.45)
            ..lineTo(-b.size * 0.55 * flip, b.size * 0.45)
            ..close();
          canvas.drawPath(tri, paint);
        default:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: b.size * flip,
                height: b.size * 0.55,
              ),
              const Radius.circular(1.5),
            ),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// The big check that opens on success screens: the disc springs in, two
/// rings ripple out from it and the tick draws itself.
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({super.key, this.size = 96});
  final double size;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reducedMotion(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final box = widget.size * 2.4;
    return SizedBox.square(
      dimension: box,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _CheckPainter(_c.value, p.success, widget.size),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.color, this.disc);
  final double t;
  final Color color;
  final double disc;

  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = disc / 2;

    // Two ripples leave the disc, one after the other.
    for (final (start, end) in const [(0.14, 0.62), (0.3, 0.78)]) {
      final k = _seg(t, start, end);
      if (k <= 0 || k >= 1) continue;
      final e = Curves.easeOutCubic.transform(k);
      canvas.drawCircle(
        c,
        r * (1 + 0.9 * e),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - e) + 0.5
          ..color = color.withValues(alpha: 0.5 * (1 - e)),
      );
    }

    // The disc springs open.
    final pop = Curves.easeOutBack.transform(_seg(t, 0, 0.32));
    if (pop > 0) {
      canvas.drawCircle(
        c,
        r * pop,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
      );
      canvas.drawCircle(c, r * pop, Paint()..color = color);
    }

    // The tick draws itself.
    final draw = Curves.easeOutCubic.transform(_seg(t, 0.28, 0.62));
    if (draw > 0) {
      final path = Path()
        ..moveTo(c.dx - r * 0.42, c.dy + r * 0.04)
        ..lineTo(c.dx - r * 0.1, c.dy + r * 0.34)
        ..lineTo(c.dx + r * 0.46, c.dy - r * 0.3);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * draw),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = r * 0.17
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t || old.color != color;
}

/// A bottom-up dark scrim over a picture so white text stays readable. Black
/// in a night room; the template's own espresso on a light one, so cream
/// cards fade to warm brown and not to a muddy grey.
class PhotoScrim extends StatelessWidget {
  const PhotoScrim({
    super.key,
    this.strength = 0.85,
    this.top = false,
    this.topStrength = 0.45,
  });

  /// How dark the bottom edge gets (where words sit over the picture).
  final double strength;

  /// Also darken the top edge, so buttons over a bright picture stay legible.
  final bool top;

  /// How dark that top edge gets. A light page wants far less than a dark one.
  final double topStrength;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<GuestPalette>();
    final base = palette == null || palette.isDark
        ? Colors.black
        : Color.lerp(palette.ink, Colors.black, 0.25)!;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              base.withValues(alpha: top ? topStrength : 0),
              base.withValues(alpha: 0),
              base.withValues(alpha: strength),
            ],
            stops: const [0, 0.42, 1],
          ),
        ),
      ),
    );
  }
}
