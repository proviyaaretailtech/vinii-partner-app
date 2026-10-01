import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../theme/guest_theme.dart';
import 'motion.dart';

/// Colours and shadows the guest runtime derives from the storefront's own
/// palette. Nothing here is a brand colour: every value is computed from the
/// template and the accent (including any the CMS overrides), so a restaurant
/// that picks its own colours gets the same lighting in them.
extension GuestLook on GuestPalette {
  /// The colour of the light in the room: the accent, softened so it reads
  /// as light rather than paint. A very dark accent (espresso) falls back to
  /// warm daylight, so the scene is never lit in brown.
  Color get keyLight {
    final h = HSLColor.fromColor(accent);
    if (accent.computeLuminance() < 0.12 || h.saturation < 0.08) {
      return isDark ? const Color(0xFFE9B36B) : const Color(0xFFF2C58B);
    }
    return h
        .withSaturation((h.saturation * 0.9).clamp(0.35, 0.95))
        .withLightness(isDark ? 0.58 : 0.62)
        .toColor();
  }

  /// [c] made dark (on a light page) or light (on a dark one) until it can
  /// be read as text on this page: at least 4.5:1 against the background.
  /// An already readable colour is returned unchanged, so a restaurant's own
  /// accent is only ever adjusted as far as legibility needs.
  Color readable(Color c, {double minRatio = 4.5}) {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    var h = HSLColor.fromColor(c);
    final towardDark = background.computeLuminance() > 0.5;
    for (var i = 0; i < 40 && ratio(h.toColor(), background) < minRatio; i++) {
      final l = towardDark ? h.lightness - 0.02 : h.lightness + 0.02;
      if (l < 0 || l > 1) break;
      h = h.withLightness(l);
    }
    return h.toColor();
  }

  /// The "night" the hero is always set against: the dark template's own
  /// background, or the light template's ink, so a white headline reads.
  Color get night => isDark ? background : ink;

  /// The page surface with a breath of the accent, so cards read as lit and
  /// not as flat grey.
  Color get surfaceLit => Color.lerp(surface, keyLight, isDark ? 0.045 : 0.05)!;

  /// A hairline drawn from the accent instead of a neutral grey.
  Color get hairline => Color.lerp(border, keyLight, isDark ? 0.22 : 0.3)!;

  /// A soft sheen across a card, brighter at the lit corner (upper left).
  Gradient get sheen => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(surface, keyLight, isDark ? 0.09 : 0.08)!, surface],
  );

  /// Shadows with an offset and a soft blur, tinted so they sit in the room
  /// (warm brown on light pages, deep umber on dark ones).
  List<BoxShadow> lift([double level = 1]) {
    final base = isDark ? Colors.black : const Color(0xFF3A2410);
    return [
      BoxShadow(
        color: base.withValues(alpha: (isDark ? 0.55 : 0.14) * level),
        blurRadius: 30 * level,
        offset: Offset(0, 16 * level),
      ),
      BoxShadow(
        color: base.withValues(alpha: (isDark ? 0.35 : 0.10) * level),
        blurRadius: 6 * level,
        offset: Offset(0, 2 * level),
      ),
    ];
  }
}

/// The lit room behind a screen: a warm key light from the upper left, a
/// slow drift of soft out-of-focus light, a vignette, and a fine grain.
///
/// [night] forces the dark scene regardless of template (the welcome hero is
/// always night so its white headline reads). [intensity] scales it from a
/// full hero (1) to a barely-there page backdrop (0.25). The drift runs at
/// about 15 frames a second and stops entirely under reduced motion.
class GuestStage extends StatefulWidget {
  const GuestStage({
    super.key,
    this.intensity = 1,
    this.spot = const Alignment(-0.55, -0.7),
    this.night = false,
    this.drift = true,
    this.grain = true,
    this.motes = 0,
    this.child,
  });

  final double intensity;
  final Alignment spot;
  final bool night;
  final bool drift;
  final bool grain;

  /// How many specks of light rise through the scene (embers in a night
  /// room, flour dust in a bakery). Zero for none.
  final int motes;
  final Widget? child;

  @override
  State<GuestStage> createState() => _GuestStageState();
}

class _GuestStageState extends State<GuestStage>
    with SingleTickerProviderStateMixin {
  final _t = ValueNotifier<double>(0.18);
  Ticker? _ticker;
  Duration _last = Duration.zero;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_asked) return;
    _asked = true;
    if (widget.drift && !reducedMotion(context)) {
      _ticker = createTicker(_tick)..start();
    }
  }

  void _tick(Duration elapsed) {
    // About 15 fps: the light moves a pixel at a time, so more is waste.
    if ((elapsed - _last).inMilliseconds < 66) return;
    _last = elapsed;
    _t.value = (elapsed.inMilliseconds / 34000) % 1;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final night = widget.night || p.isDark;
    final base = widget.night ? p.night : p.background;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _StagePainter(
              t: _t,
              base: base,
              light: p.keyLight,
              night: night,
              intensity: widget.intensity,
              spot: widget.spot,
              motes: widget.motes,
            ),
          ),
          if (widget.grain) GrainOverlay(strength: night ? 1 : 0.7),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.t,
    required this.base,
    required this.light,
    required this.night,
    required this.intensity,
    required this.spot,
    required this.motes,
  }) : super(repaint: t);

  final ValueNotifier<double> t;
  final Color base;
  final Color light;
  final bool night;
  final double intensity;
  final Alignment spot;
  final int motes;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);
    final k = intensity.clamp(0.0, 1.0);
    final long = size.longestSide;
    final phase = t.value * 2 * math.pi;

    // Key light, upper left, breathing very slightly.
    final c = spot.alongSize(size);
    final breathe = 1 + 0.04 * math.sin(phase);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          long * 0.85 * breathe,
          [
            light.withValues(alpha: (night ? 0.40 : 0.34) * k),
            light.withValues(alpha: (night ? 0.12 : 0.10) * k),
            light.withValues(alpha: 0),
          ],
          const [0, 0.45, 1],
        ),
    );

    // A cooler, weaker bounce from the opposite corner gives the room depth.
    final bounce = Offset(size.width * 0.95, size.height * 0.92);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(bounce, long * 0.55, [
          light.withValues(alpha: (night ? 0.14 : 0.12) * k),
          light.withValues(alpha: 0),
        ]),
    );

    // Soft out-of-focus light drifting on slow, unequal loops.
    for (var i = 0; i < 5; i++) {
      final seed = i * 1.7 + 0.6;
      final x =
          size.width *
          (0.12 +
              0.76 * ((i * 0.37 + 0.11) % 1) +
              0.04 * math.sin(phase + seed));
      final y =
          size.height *
          (0.08 +
              0.55 * ((i * 0.53 + 0.21) % 1) +
              0.035 * math.cos(phase * (1 + i * 0.13) + seed));
      final r = size.shortestSide * (0.10 + 0.07 * ((i * 0.29) % 1));
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(x, y), r, [
            Color.lerp(
              light,
              Colors.white,
              0.35,
            )!.withValues(alpha: (night ? 0.10 : 0.08) * k),
            Color.lerp(light, Colors.white, 0.35)!.withValues(alpha: 0),
          ]),
      );
    }

    // Specks of light rising slowly: each on its own loop and sway.
    if (motes > 0) {
      final speck = Paint();
      for (var i = 0; i < motes; i++) {
        final seed = (i * 0.6180339) % 1;
        final rise = (seed + t.value * (1.5 + (i % 4) * 0.5)) % 1;
        final x =
            size.width *
            (((i * 0.37) % 1) + 0.025 * math.sin(phase * 3 + i * 1.3));
        final y = size.height * (1.02 - rise * 1.04);
        final twinkle = 0.55 + 0.45 * math.sin(phase * 5 + i * 2.1);
        final edge = (rise < 0.12
            ? rise / 0.12
            : rise > 0.8
            ? (1 - rise) / 0.2
            : 1.0);
        speck.color = Color.lerp(light, Colors.white, night ? 0.5 : 0.7)!
            .withValues(
              alpha: (night ? 0.55 : 0.5) * twinkle * edge.clamp(0.0, 1.0) * k,
            );
        canvas.drawCircle(Offset(x, y), 0.9 + (i % 3) * 0.55, speck);
      }
    }

    // Vignette: the room falls away at the edges.
    final shade = night ? Colors.black : const Color(0xFF3A2410);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          long * 0.78,
          [
            shade.withValues(alpha: 0),
            shade.withValues(alpha: (night ? 0.55 : 0.10) * (0.4 + 0.6 * k)),
          ],
          const [0.55, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.base != base ||
      old.light != light ||
      old.night != night ||
      old.intensity != intensity ||
      old.spot != spot ||
      old.motes != motes;
}

/// A fine film grain over a scene, so flat colour reads as a lit surface.
/// One small tile is drawn once and repeated; if the platform cannot make
/// the tile, nothing is drawn and the scene is simply cleaner.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key, this.strength = 1});
  final double strength;

  static ui.Image? _tile;
  static bool _failed = false;

  static ui.Image? _make() {
    if (_tile != null || _failed) return _tile;
    try {
      const side = 96;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      final r = math.Random(11);
      final dot = Paint();
      for (var i = 0; i < 1900; i++) {
        final light = r.nextBool();
        dot.color = (light ? Colors.white : Colors.black).withValues(
          alpha: 0.015 + r.nextDouble() * 0.045,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            r.nextInt(side).toDouble(),
            r.nextInt(side).toDouble(),
            1,
            1,
          ),
          dot,
        );
      }
      _tile = rec.endRecording().toImageSync(side, side);
    } catch (_) {
      _failed = true;
    }
    return _tile;
  }

  @override
  Widget build(BuildContext context) {
    final tile = _make();
    if (tile == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Opacity(
        opacity: strength.clamp(0.0, 1.0),
        child: CustomPaint(size: Size.infinite, painter: _GrainPainter(tile)),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter(this.tile);
  final ui.Image tile;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ImageShader(
          tile,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.identity().storage,
        ),
    );
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.tile != tile;
}
