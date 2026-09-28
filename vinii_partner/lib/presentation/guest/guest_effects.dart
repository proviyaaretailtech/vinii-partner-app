import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/guest_theme.dart';

/// A one-shot confetti burst for "Order placed!" and "Served". It plays once
/// (about 2.6 s) and stops, so screens and tests never spin forever.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.count = 70});
  final int count;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  late final List<_Bit> _bits;

  @override
  void initState() {
    super.initState();
    final r = Random(7);
    _bits = [
      for (var i = 0; i < widget.count; i++)
        _Bit(
          x: r.nextDouble(),
          drift: (r.nextDouble() - 0.5) * 0.35,
          speed: 0.7 + r.nextDouble() * 0.6,
          spin: (r.nextDouble() - 0.5) * 14,
          size: 5 + r.nextDouble() * 6,
          delay: r.nextDouble() * 0.25,
          hue: i % 5,
        ),
    ];
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final colors = [
      p.accent,
      p.success,
      const Color(0xFFF97316),
      const Color(0xFF60A5FA),
      const Color(0xFFF472B6),
    ];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_bits, _c.value, colors),
        ),
      ),
    );
  }
}

class _Bit {
  const _Bit({
    required this.x,
    required this.drift,
    required this.speed,
    required this.spin,
    required this.size,
    required this.delay,
    required this.hue,
  });
  final double x, drift, speed, spin, size, delay;
  final int hue;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t, this.colors);
  final List<_Bit> bits;
  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bits) {
      final local = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * b.speed * size.height * 0.95;
      final x = (b.x + b.drift * local) * size.width;
      final fade = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      final paint = Paint()
        ..color = colors[b.hue % colors.length].withValues(alpha: fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(b.spin * local)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: b.size,
              height: b.size * 0.5,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// The big green check that springs in on success screens.
class SuccessCheck extends StatelessWidget {
  const SuccessCheck({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, v, child) =>
          Transform.scale(scale: v.clamp(0, 1.3), child: child),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.success,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: p.success.withValues(alpha: 0.45),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}

/// A bottom-up dark scrim over a photo so white text stays readable.
class PhotoScrim extends StatelessWidget {
  const PhotoScrim({super.key, this.strength = 0.85, this.top = false});
  final double strength;
  final bool top;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: top ? 0.45 : 0),
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: strength),
          ],
          stops: const [0, 0.42, 1],
        ),
      ),
    ),
  );
}
