import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The families of dish the illustrated fallback can draw. A dish with a real
/// photo never uses this; it is what a menu without photos shows instead of
/// an emoji, so the swipe deck still has a face on every card.
enum DishFamily {
  curry,
  rice,
  skewers,
  pizza,
  pasta,
  noodles,
  flatbread,
  handheld,
  cake,
  sweet,
  drink,
  cup,
  loaf,
  pastry,
  snack,
  plate;

  /// Whether the dish is served hot, so it earns steam.
  bool get steams => switch (this) {
    curry || rice || skewers || pasta || noodles || cup || snack => true,
    _ => false,
  };

  /// Picks the family from a dish name. Whole-word matches (with plurals and
  /// compounds such as "milkshake"); unknown dishes get the plain plate. The
  /// order of the table is the order of precedence.
  static DishFamily of(String name) {
    final words = RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(name.toLowerCase()).map((m) => m.group(0)!).toList();
    if (words.isEmpty) return DishFamily.plate;
    final padded = ' ${words.join(' ')} ';
    for (final entry in _keywords) {
      for (final k in entry.$2) {
        if (k.contains(' ')) {
          if (padded.contains(' $k ') || padded.contains(' ${k}s ')) {
            return entry.$1;
          }
          continue;
        }
        for (final w in words) {
          if (w == k || w == '${k}s' || w == '${k}es') return entry.$1;
          if (k.length >= 4 && (w.startsWith(k) || w.endsWith(k))) {
            return entry.$1;
          }
        }
      }
    }
    return DishFamily.plate;
  }

  static final _keywords = <(DishFamily, List<String>)>[
    // Names that a more general word further down would otherwise capture.
    (
      DishFamily.curry,
      _words(
        'pav bhaji,tikka masala,butter masala,paneer masala,'
        'chicken masala',
      ),
    ),
    (DishFamily.snack, _words('spring roll')),
    (DishFamily.pizza, _words('pizza,calzone')),
    (
      DishFamily.pasta,
      _words(
        'pasta,penne,spaghetti,macaroni,lasagna,lasagne,fusilli,linguine,'
        'fettuccine,ravioli,gnocchi,alfredo,arrabbiata,carbonara,'
        'tagliatelle,mac and cheese',
      ),
    ),
    (
      DishFamily.noodles,
      _words(
        'noodle,hakka,ramen,chowmein,chow mein,maggi,udon,soba,lo mein,'
        'pad thai,thukpa',
      ),
    ),
    (
      DishFamily.cake,
      _words(
        'cake,brownie,tiramisu,cheesecake,tart,pie,babka,muffin,cupcake,'
        'gateau,mousse,pudding,panna cotta',
      ),
    ),
    (
      DishFamily.cup,
      _words(
        'coffee,latte,cappuccino,espresso,tea,chai,mocha,americano,'
        'macchiato,cortado,flat white,hot chocolate,matcha,kaapi,kahwa',
      ),
    ),
    (
      DishFamily.drink,
      _words(
        'juice,soda,shake,lassi,lime,lemon,mojito,smoothie,cola,water,'
        'buttermilk,chaas,milk,beer,wine,mocktail,cooler,lemonade,'
        'sharbat,sherbet,falooda,thandai,cocktail,sprite,coke,pepsi,'
        'frappe',
      ),
    ),
    (
      DishFamily.sweet,
      _words(
        'jamun,kheer,halwa,ice cream,icecream,kulfi,rasmalai,rasgulla,'
        'jalebi,payasam,sundae,ladoo,laddu,barfi,burfi,peda,gelato,rabri,'
        'shrikhand,mithai,dessert,phirni,malpua',
      ),
    ),
    (
      DishFamily.pastry,
      _words(
        'croissant,danish,scroll,cinnamon roll,bun,bagel,puff,eclair,'
        'doughnut,donut,strudel,palmier,turnover',
      ),
    ),
    (
      DishFamily.loaf,
      _words('bread,loaf,sourdough,focaccia,baguette,toast,ciabatta,brioche'),
    ),
    (
      DishFamily.handheld,
      _words(
        'burger,sandwich,wrap,roll,frankie,kathi,shawarma,pav,taco,sub,'
        'hot dog,slider,panini,quesadilla,burrito',
      ),
    ),
    (
      DishFamily.flatbread,
      _words(
        'dosa,dose,uttapam,uthappam,roti,naan,paratha,parota,kulcha,'
        'chapati,thepla,idli,vada',
      ),
    ),
    (
      DishFamily.rice,
      _words('biryani,biriyani,pulao,pulav,rice,khichdi,thali,combo,meal'),
    ),
    (
      DishFamily.skewers,
      _words(
        'tikka,kebab,kabab,tandoori,seekh,skewer,grill,65,lollipop,satay,'
        'shashlik,tangdi,bbq,barbecue',
      ),
    ),
    (
      DishFamily.snack,
      _words(
        'corn,fries,pakora,pakoda,pakode,samosa,momo,dumpling,dim sum,'
        'chaat,bhel,puri,nuggets,popcorn,kachori,cutlet,tikki,wings,'
        'poppers,nachos,chips,crispy',
      ),
    ),
    (
      DishFamily.curry,
      _words(
        'curry,dal,daal,dhal,masala,gravy,kurma,korma,makhani,sabzi,'
        'sabji,soup,sambar,rasam,stew,chicken,mutton,lamb,fish,prawn,'
        'shrimp,paneer,egg,kadai,karahi,handi,bhuna,vindaloo,saag,palak,'
        'chole,chana,rajma,tadka,kofta,manchurian,bhaji,keema',
      ),
    ),
  ];

  static List<String> _words(String csv) => csv.split(',');
}

/// A dish drawn in code, lit from the upper left, on a transparent ground so
/// the card behind it supplies the atmosphere. Not a photo and never pretends
/// to be one.
///
/// [light] is the warm key-light tint (usually derived from the storefront's
/// accent). [onDark] tells the painter whether the card behind it is dark, so
/// shadows and rim light read correctly. [animate] allows the small ambient
/// motion (steam, a slow glint); it is ignored when the device asks for
/// reduced motion.
class DishArt extends StatefulWidget {
  const DishArt({
    super.key,
    required this.name,
    this.family,
    this.light = const Color(0xFFFFD08A),
    this.onDark = true,
    this.animate = true,
  });

  final String name;

  /// Forces a family; otherwise it is chosen from [name].
  final DishFamily? family;
  final Color light;
  final bool onDark;
  final bool animate;

  @override
  State<DishArt> createState() => _DishArtState();
}

class _DishArtState extends State<DishArt> with TickerProviderStateMixin {
  AnimationController? _steam;

  DishFamily get _family => widget.family ?? DishFamily.of(widget.name);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(DishArt old) {
    super.didUpdateWidget(old);
    _syncMotion();
  }

  /// The steam layer is the only thing that ever moves, and it only runs when
  /// the caller allows it, the dish is a hot one and the device has not asked
  /// for reduced motion.
  void _syncMotion() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final wanted = widget.animate && _family.steams && !reduce;
    if (wanted) {
      _steam ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 5600),
      );
      if (!_steam!.isAnimating) _steam!.repeat();
    } else if (_steam != null) {
      _steam!.dispose();
      _steam = null;
    }
  }

  @override
  void dispose() {
    _steam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = _family;
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.biggest.shortestSide.isFinite
            ? c.biggest.shortestSide
            : 160.0;
        return ExcludeSemantics(
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    isComplex: true,
                    willChange: false,
                    painter: _DishPainter(
                      family,
                      widget.name,
                      widget.light,
                      widget.onDark,
                    ),
                  ),
                ),
                if (family.steams)
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _SteamPainter(
                        anchors: _steamAt[family] ?? const [(50.0, 34.0)],
                        light: widget.light,
                        onDark: widget.onDark,
                        t: _steam,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Where the steam rises from, in the 0..100 picture space.
const _steamAt = <DishFamily, List<(double, double)>>{
  DishFamily.curry: [(37, 42), (50, 38), (63, 42)],
  DishFamily.rice: [(40, 32), (52, 28), (63, 33)],
  DishFamily.skewers: [(32, 54), (52, 48), (72, 44)],
  DishFamily.pasta: [(40, 36), (52, 31), (63, 36)],
  DishFamily.noodles: [(38, 34), (50, 29), (62, 34)],
  DishFamily.cup: [(42, 38), (52, 34), (60, 39)],
  DishFamily.snack: [(40, 30), (52, 26), (63, 31)],
};

/// The soft rising wisps. Drawn on its own layer so that only this layer
/// repaints while it animates; when [t] is null it paints one still frame.
class _SteamPainter extends CustomPainter {
  _SteamPainter({
    required this.anchors,
    required this.light,
    required this.onDark,
    this.t,
  }) : super(repaint: t);

  final List<(double, double)> anchors;
  final Color light;
  final bool onDark;
  final Animation<double>? t;

  static const _still = [0.34, 0.5, 0.42];

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side < 1) return;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 100);
    final tone = onDark
        ? Color.lerp(light, const Color(0xFFFFFFFF), .78)!
        : const Color(0xFF8A7560);
    final peak = onDark ? .34 : .20;
    for (var i = 0; i < anchors.length; i++) {
      final (x0, y0) = anchors[i];
      final ph = t == null ? _still[i % 3] : (t!.value + i * .37) % 1.0;
      final fade = math.sin(math.pi * ph);
      if (fade <= .01) continue;
      final base = y0 - math.min(22.0, y0 - 17) * ph;
      final path = Path();
      const steps = 9;
      for (var k = 0; k <= steps; k++) {
        final u = k / steps;
        final x =
            x0 +
            math.sin((u * .9 + ph * .8 + i * .31) * math.pi * 2) *
                (1.1 + 2.6 * u);
        final y = base - u * 15;
        k == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.4 + 2.4 * ph
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 + 1.3 * ph)
          ..shader = ui.Gradient.linear(
            Offset(x0, base),
            Offset(x0, base - 15),
            [tone.withValues(alpha: peak * fade), tone.withValues(alpha: 0)],
          ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SteamPainter old) =>
      old.light != light || old.onDark != onDark || old.t != t;
}

/// The static still life. Everything is authored in a 100 x 100 space and
/// scaled to the box, so one set of numbers serves every size.
class _DishPainter extends CustomPainter {
  const _DishPainter(this.family, this.name, this.light, this.onDark);
  final DishFamily family;
  final String name;
  final Color light;
  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side < 1) return;
    final s = _Scene(canvas, side, light, onDark, name, _seed(name, family));
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 100);
    switch (family) {
      case DishFamily.curry:
        _curry(s);
      case DishFamily.rice:
        _rice(s);
      case DishFamily.skewers:
        _skewers(s);
      case DishFamily.pizza:
        _pizza(s);
      case DishFamily.pasta:
        _pasta(s);
      case DishFamily.noodles:
        _noodles(s);
      case DishFamily.flatbread:
        _flatbread(s);
      case DishFamily.handheld:
        _handheld(s);
      case DishFamily.cake:
        _cake(s);
      case DishFamily.sweet:
        _sweet(s);
      case DishFamily.drink:
        _drink(s);
      case DishFamily.cup:
        _cup(s);
      case DishFamily.loaf:
        _loaf(s);
      case DishFamily.pastry:
        _pastry(s);
      case DishFamily.snack:
        _snack(s);
      case DishFamily.plate:
        _plateDish(s);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DishPainter old) =>
      old.family != family ||
      old.name != name ||
      old.light != light ||
      old.onDark != onDark;
}

/// A stable 32-bit seed from the dish name (FNV-1a, written so web and native
/// agree), so the same dish is always drawn the same way.
int _seed(String name, DishFamily f) {
  var h = 0x811C9DC5;
  for (final u in name.toLowerCase().trim().codeUnits) {
    h ^= u;
    h = (((h << 24) & 0xFFFFFFFF) + h * 0x193) & 0xFFFFFFFF;
  }
  return (h ^ (f.index * 7919)) & 0xFFFFFFFF;
}

// ───────────────────────────── one lit world ─────────────────────────────

/// Every circle in the set is seen from the same height: its ellipse is this
/// many times as tall as it is wide.
const double _kTilt = 0.46;

/// The direction of the key light, upper left.
const Offset _kLight = Offset(-0.62, -0.78);

const Color _black = Color(0xFF000000);

class _Scene {
  _Scene(
    this.canvas,
    this.px,
    this.light,
    this.onDark,
    String dishName,
    int seed,
  ) : name = dishName.toLowerCase(),
      rnd = math.Random(seed);

  final Canvas canvas;

  /// Device pixels across the whole picture.
  final double px;
  final Color light;
  final bool onDark;
  final String name;
  final math.Random rnd;

  /// 0 at 56 px and below, 1 at 320 px and above: how much fine detail has
  /// earned its place at this size.
  double get detail => ((px - 56) / 264).clamp(0.0, 1.0);

  /// A count that grows with the size on screen.
  int n(int base, [int extra = 0]) => base + (extra * detail).round();

  bool any(List<String> keys) => keys.any(name.contains);
  double r(double a, double b) => a + rnd.nextDouble() * (b - a);

  /// Shadows deepen on a dark card and soften on a light one.
  double get shadowA => onDark ? .72 : .32;
  double get rimA => onDark ? .9 : .4;

  /// The key-light tint pushed toward white: glints and specular spots.
  Color get spec => Color.lerp(light, const Color(0xFFFFFFFF), .62)!;
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
Color _hi(Color c, [double t = .35]) => _mix(c, const Color(0xFFFFF3DA), t);
Color _lo(Color c, [double t = .4]) => _mix(c, const Color(0xFF1F0E06), t);
Color _al(Color c, double a) => c.withValues(alpha: a.clamp(0.0, 1.0));

Paint _pf(Color c) => Paint()..color = c;
Paint _pg(Shader sh) => Paint()..shader = sh;
Paint _pb(Color c, double sigma) => Paint()
  ..color = c
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
Paint _ps(
  Color c,
  double w, {
  double blur = 0,
  StrokeCap cap = StrokeCap.round,
}) {
  final p = Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = cap
    ..strokeJoin = StrokeJoin.round;
  if (blur > 0) p.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
  return p;
}

/// Colour stops spread evenly when the caller gave none (the engine only
/// accepts a missing list for exactly two colours).
List<double>? _evenly(List<Color> cs, List<double>? st) {
  if (st != null || cs.length == 2) return st;
  return [for (var i = 0; i < cs.length; i++) i / (cs.length - 1)];
}

Shader _lin(Offset a, Offset b, List<Color> cs, [List<double>? st]) =>
    ui.Gradient.linear(a, b, cs, _evenly(cs, st));

/// A radial gradient; [tilt] below 1 squashes it into the same ellipse the
/// surface it lights is seen as.
Shader _rad(
  Offset c,
  double r,
  List<Color> cs, {
  List<double>? st,
  double tilt = 1,
  Offset? focal,
}) {
  final stops = _evenly(cs, st);
  if (tilt == 1) {
    return ui.Gradient.radial(c, r, cs, stops, TileMode.clamp, null, focal);
  }
  final m = Matrix4.identity()
    ..setEntry(1, 1, tilt)
    ..setEntry(1, 3, c.dy * (1 - tilt));
  return ui.Gradient.radial(c, r, cs, stops, TileMode.clamp, m.storage, focal);
}

/// A gradient along the key light for something drawn after a rotation by
/// [rot] (so the light still comes from the upper left on screen).
Shader _litLin(double rot, double half, Color hi, Color mid, Color lo) {
  final c = math.cos(-rot);
  final s = math.sin(-rot);
  final d =
      Offset(_kLight.dx * c - _kLight.dy * s, _kLight.dx * s + _kLight.dy * c) *
      half;
  return ui.Gradient.linear(d, -d, [hi, mid, lo], const [0, .5, 1]);
}

Rect _ell(Offset c, double rx, [double tilt = _kTilt]) =>
    Rect.fromCenter(center: c, width: rx * 2, height: rx * 2 * tilt);

/// A point on the ellipse of radius [rx] around [c] at angle [a].
Offset _on(Offset c, double rx, double a, [double tilt = _kTilt]) =>
    Offset(c.dx + rx * math.cos(a), c.dy + rx * tilt * math.sin(a));

/// Draws [draw] translated to [p] and rotated by [rot].
void _at(
  Canvas c,
  Offset p,
  double rot,
  VoidCallback draw, {
  double sx = 1,
  double sy = 1,
}) {
  c.save();
  c.translate(p.dx, p.dy);
  if (rot != 0) c.rotate(rot);
  if (sx != 1 || sy != 1) c.scale(sx, sy);
  draw();
  c.restore();
}

/// A closed smooth curve through [pts].
Path _smooth(List<Offset> pts) {
  final n = pts.length;
  final p = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = pts[(i - 1 + n) % n];
    final p1 = pts[i];
    final p2 = pts[(i + 1) % n];
    final p3 = pts[(i + 2) % n];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return p..close();
}

/// A soft irregular blob: a piece of chicken, a patch of cheese.
Path _blob(
  math.Random r,
  Offset c,
  double rx,
  double ry, {
  int n = 8,
  double wob = .16,
  double rot = 0,
}) {
  final pts = <Offset>[];
  for (var i = 0; i < n; i++) {
    final a = rot + i / n * math.pi * 2;
    final k = 1 + (r.nextDouble() * 2 - 1) * wob;
    pts.add(Offset(c.dx + math.cos(a) * rx * k, c.dy + math.sin(a) * ry * k));
  }
  return _smooth(pts);
}

/// A pointed leaf lying along +x from the origin.
Path _leaf(double len, double wid, [double bend = 0]) => Path()
  ..moveTo(0, 0)
  ..quadraticBezierTo(len * .42, -wid - bend, len, 0)
  ..quadraticBezierTo(len * .42, wid - bend, 0, 0)
  ..close();

/// A filled stroke of varying width along [pts].
Path _ribbon(List<Offset> pts, double Function(double t) w) {
  final left = <Offset>[];
  final right = <Offset>[];
  for (var i = 0; i < pts.length; i++) {
    final a = pts[math.max(0, i - 1)];
    final b = pts[math.min(pts.length - 1, i + 1)];
    var d = b - a;
    final len = d.distance;
    d = len == 0 ? const Offset(1, 0) : d / len;
    final nrm = Offset(-d.dy, d.dx);
    final hw = w(i / (pts.length - 1)) / 2;
    left.add(pts[i] + nrm * hw);
    right.add(pts[i] - nrm * hw);
  }
  final p = Path()..moveTo(left.first.dx, left.first.dy);
  for (final q in left.skip(1)) {
    p.lineTo(q.dx, q.dy);
  }
  for (final q in right.reversed) {
    p.lineTo(q.dx, q.dy);
  }
  return p..close();
}

/// Many short strokes batched by colour so a thousand grains stay cheap.
class _Strokes {
  _Strokes(this.width);
  final double width;
  final Map<int, List<Offset>> _pts = {};
  final Map<int, Color> _col = {};

  void add(Color c, Offset a, Offset b) {
    final k = c.toARGB32();
    (_pts[k] ??= <Offset>[]).addAll([a, b]);
    _col[k] = c;
  }

  void paint(Canvas cv) {
    _pts.forEach((k, pts) {
      cv.drawPoints(ui.PointMode.lines, pts, _ps(_col[k]!, width));
    });
  }
}

// ───────────────────────── light, shadow, glint ─────────────────────────

/// The soft contact shadow under a dish: a wide ambient pool and a tight dark
/// core, both pushed down and to the right, away from the key light.
void _ground(_Scene s, Offset c, double rx, {double tilt = _kTilt}) {
  s.canvas.drawOval(
    _ell(c + const Offset(3.2, 1.8), rx * 1.05, tilt),
    _pb(_al(_black, s.shadowA * .55), 3.6),
  );
  s.canvas.drawOval(
    _ell(c + const Offset(1.3, .9), rx * .95, tilt),
    _pb(_al(_black, s.shadowA * .95), 1.3),
  );
}

/// The key light catching the upper-left edge of a rim, in the restaurant's
/// light tint. Three overlapping arcs so it fades at both ends.
void _rim(
  _Scene s,
  Rect oval, {
  double mid = 1.22 * math.pi,
  double span = .85 * math.pi,
  double w = 1.0,
  double a = 1,
}) {
  for (var i = 0; i < 3; i++) {
    final sp = span * (1 - i * .3);
    s.canvas.drawArc(
      oval,
      mid - sp / 2,
      sp,
      false,
      _ps(_al(s.light, s.rimA * a * (.3 + .3 * i)), w),
    );
  }
}

/// A soft elongated highlight: the sheen on sauce, syrup, glaze or brass.
void _gloss(
  _Scene s,
  Offset c,
  double rx,
  double ry, {
  double rot = 0,
  double a = .6,
}) {
  _at(
    s.canvas,
    c,
    rot,
    () => s.canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      _pb(_al(s.spec, a), math.min(rx, ry) * .4 + .15),
    ),
  );
}

/// A tiny hard glint with a bright core.
void _spark(_Scene s, Offset c, double r, {double a = .9}) {
  s.canvas.drawCircle(c, r, _pb(_al(s.spec, a * .8), r * .5));
  s.canvas.drawCircle(c, r * .38, _pf(_al(const Color(0xFFFFFFFF), a)));
}

// ───────────────────────────── vessels ─────────────────────────────

/// The five tones that make a vessel read: lit side, mid, shade, and the
/// inside wall in light and in shadow.
class _Mat {
  const _Mat(this.lit, this.mid, this.dark, this.inLit, this.inDark);
  final Color lit, mid, dark, inLit, inDark;
}

const _slate = _Mat(
  Color(0xFF6F7885),
  Color(0xFF3C434E),
  Color(0xFF181B21),
  Color(0xFF515966),
  Color(0xFF15181D),
);
const _iron = _Mat(
  Color(0xFF8A7866),
  Color(0xFF4A3E35),
  Color(0xFF1B1511),
  Color(0xFF65564A),
  Color(0xFF17120F),
);
const _brass = _Mat(
  Color(0xFFF8DA82),
  Color(0xFFC9963C),
  Color(0xFF6A4413),
  Color(0xFFEBC067),
  Color(0xFF7A4F16),
);
const _cream = _Mat(
  Color(0xFFFFF9EC),
  Color(0xFFEDDFC4),
  Color(0xFFB59C76),
  Color(0xFFFBF3E0),
  Color(0xFFDCCBA6),
);
const _steel = _Mat(
  Color(0xFFF5F7F9),
  Color(0xFFB9C0C9),
  Color(0xFF626B76),
  Color(0xFFDDE2E8),
  Color(0xFF7B848F),
);
const _walnut = _Mat(
  Color(0xFFB98350),
  Color(0xFF7E4F2A),
  Color(0xFF3A2212),
  Color(0xFF9A6638),
  Color(0xFF4A2D17),
);
const _oak = _Mat(
  Color(0xFFE8C48C),
  Color(0xFFC9995D),
  Color(0xFF7B5530),
  Color(0xFFD6A96C),
  Color(0xFF8A6238),
);

/// Where a bowl or plate ended up, so food can be placed in it.
class _Bowl {
  const _Bowl(this.c, this.rx, this.depth, this.foot, this.wall);
  final Offset c;
  final double rx, depth, foot, wall;
  Rect get rim => _ell(c, rx);
  Rect get hole => _ell(c, rx - wall);
  Offset get base => Offset(c.dx, c.dy + depth);
  Path get holePath => Path()..addOval(hole);

  /// The mouth plus the air above it, for food that rises over the rim.
  Path roomAbove(double height) => Path()
    ..addOval(hole)
    ..addRect(
      Rect.fromLTRB(
        c.dx - (rx - wall),
        c.dy - height,
        c.dx + (rx - wall),
        c.dy,
      ),
    );
}

/// A deep vessel seen from slightly above: wall, lip, and the inside.
_Bowl _bowl(
  _Scene s,
  Offset c,
  double rx,
  double depth,
  _Mat m, {
  double foot = .5,
  double wall = 2.6,
  double belly = 1.0,
}) {
  final cv = s.canvas;
  final fr = rx * foot;
  final g = _Bowl(c, rx, depth, fr, wall);
  final body = Path()
    ..moveTo(c.dx - rx, c.dy)
    ..cubicTo(
      c.dx - rx * belly,
      c.dy + depth * .62,
      c.dx - fr * 1.35,
      c.dy + depth * .96,
      c.dx - fr,
      c.dy + depth,
    )
    ..arcTo(_ell(g.base, fr), math.pi, -math.pi, false)
    ..cubicTo(
      c.dx + fr * 1.35,
      c.dy + depth * .96,
      c.dx + rx * belly,
      c.dy + depth * .62,
      c.dx + rx,
      c.dy,
    )
    ..close();
  cv.drawPath(
    body,
    _pg(
      _lin(
        Offset(c.dx - rx, c.dy),
        Offset(c.dx + rx, c.dy + depth * .35),
        [m.lit, m.mid, m.dark],
        const [0, .46, 1],
      ),
    ),
  );
  cv.drawPath(
    body,
    _pg(
      _lin(Offset(0, c.dy), Offset(0, c.dy + depth), [
        _al(_black, 0),
        _al(_black, .28),
      ]),
    ),
  );
  // Sheen running down the lit shoulder of the wall.
  final streak = Path()
    ..moveTo(c.dx - rx * .74, c.dy + depth * .16)
    ..quadraticBezierTo(
      c.dx - rx * .8,
      c.dy + depth * .55,
      c.dx - fr * .98,
      c.dy + depth * .84,
    );
  cv.drawPath(
    streak,
    _ps(
      _al(_mix(m.lit, s.light, .45), m.lit.computeLuminance() > .5 ? .5 : .34),
      rx * .05 + .7,
      blur: .8,
    ),
  );
  if (s.onDark) {
    // A thin bounce of the room's light keeps a dark vessel's far edge alive.
    final edge = Path()
      ..moveTo(c.dx + fr, c.dy + depth)
      ..cubicTo(
        c.dx + fr * 1.35,
        c.dy + depth * .96,
        c.dx + rx * belly,
        c.dy + depth * .62,
        c.dx + rx,
        c.dy,
      );
    cv.drawPath(edge, _ps(_al(s.light, .26), .9, blur: .5));
  }
  cv.drawOval(
    g.rim,
    _pg(_lin(g.rim.topLeft, g.rim.bottomRight, [m.lit, m.mid])),
  );
  cv.drawOval(
    g.hole,
    _pg(_lin(g.hole.centerLeft, g.hole.centerRight, [m.inDark, m.inLit])),
  );
  cv.drawOval(g.hole, _ps(_al(m.dark, .55), .6));
  _rim(s, g.rim, w: .9 + rx * .006);
  return g;
}

/// A plate, board or tray seen from slightly above: edge, face and a shallow
/// well. [well] is the well's share of the radius.
_Bowl _plate(
  _Scene s,
  Offset c,
  double rx,
  double thick,
  _Mat m, {
  double well = .72,
  bool wellOn = true,
}) {
  final cv = s.canvas;
  final side = Path()
    ..moveTo(c.dx - rx, c.dy)
    ..lineTo(c.dx - rx, c.dy + thick)
    ..arcTo(_ell(Offset(c.dx, c.dy + thick), rx), math.pi, -math.pi, false)
    ..lineTo(c.dx + rx, c.dy)
    ..close();
  cv.drawPath(
    side,
    _pg(_lin(Offset(c.dx - rx, 0), Offset(c.dx + rx, 0), [m.mid, m.dark])),
  );
  final top = _ell(c, rx);
  cv.drawOval(
    top,
    _pg(
      _rad(Offset(c.dx - rx * .4, c.dy - rx * .12), rx * 1.7, [
        m.lit,
        m.mid,
      ], tilt: _kTilt),
    ),
  );
  final g = _Bowl(c, rx, thick, 0, rx * (1 - well));
  if (wellOn) {
    final w = _ell(c + Offset(0, rx * .02), rx * well);
    cv.drawOval(
      w,
      _pg(
        _rad(Offset(c.dx - rx * .2, c.dy - rx * .08), rx * 1.1, [
          m.inLit,
          m.inDark,
        ], tilt: _kTilt),
      ),
    );
    cv.drawArc(w, math.pi * 1.0, math.pi * .9, false, _ps(_al(m.dark, .4), .8));
    cv.drawArc(w, math.pi * .05, math.pi * .7, false, _ps(_al(m.lit, .7), .7));
  }
  _rim(s, top, w: .9 + rx * .005);
  return g;
}

/// A random point inside an ellipse; [reach] is the share of its radius.
Offset _inEll(
  math.Random r,
  Offset c,
  double rx,
  double ry, [
  double reach = 1,
]) {
  final a = r.nextDouble() * math.pi * 2;
  final d = math.sqrt(r.nextDouble()) * reach;
  return Offset(c.dx + math.cos(a) * d * rx, c.dy + math.sin(a) * d * ry);
}

/// A small sprig of coriander: three pointed leaflets.
void _coriander(_Scene s, Offset p, double rot, double sz) {
  final cv = s.canvas;
  _at(cv, p, rot, () {
    for (var k = 0; k < 3; k++) {
      _at(cv, Offset.zero, k * 2.094, () {
        final leaf = _leaf(3.6 * sz, 1.3 * sz);
        cv.drawPath(
          leaf.shift(Offset(.25 * sz, .35 * sz)),
          _pf(_al(_black, .25)),
        );
        cv.drawPath(leaf, _pf(const Color(0xFF2B8434)));
        cv.drawPath(_leaf(2.6 * sz, .55 * sz), _pf(const Color(0xFF86D25A)));
      });
    }
  });
}

// ───────────────────────────── curry ─────────────────────────────

void _curry(_Scene s) {
  final cv = s.canvas;
  final dal = s.any(['dal', 'daal', 'dhal', 'makhani']);
  final green = s.any(['palak', 'saag', 'spinach', 'methi']);
  final pale = s.any(['korma', 'kurma', 'malai', 'stew']);
  final meat = s.any([
    'chicken',
    'mutton',
    'lamb',
    'keema',
    'fish',
    'prawn',
    'shrimp',
  ]);
  final gravy = dal
      ? const [Color(0xFF9C4C24), Color(0xFF6A2B14), Color(0xFF3B1507)]
      : green
      ? const [Color(0xFF9CC247), Color(0xFF668F28), Color(0xFF38601A)]
      : pale
      ? const [Color(0xFFF6DD9C), Color(0xFFDFB668), Color(0xFFA77B34)]
      : const [Color(0xFFF2923F), Color(0xFFCD4E1C), Color(0xFF86270C)];
  const c = Offset(50, 47);
  const rx = 38.0;
  _ground(s, const Offset(50, 77), 31);
  // Handles first: the bowl hides their inner halves.
  for (final side in const [-1.0, 1.0]) {
    final hc = Offset(c.dx + side * (rx + 2.2), c.dy + 3.6);
    cv.drawOval(
      Rect.fromCenter(center: hc, width: 10, height: 8),
      _ps(_black, 2.3)
        ..shader = _lin(
          hc - const Offset(5, 4),
          hc + const Offset(5, 4),
          [_brass.lit, _brass.mid, _brass.dark],
          const [0, .5, 1],
        ),
    );
  }
  final g = _bowl(s, c, rx, 27, dal ? _brass : _iron, wall: 2.8);
  cv.save();
  cv.clipPath(g.holePath);

  const sc = Offset(50, 50.4);
  const sr = 33.6;
  final surf = _ell(sc, sr);
  cv.drawOval(
    surf,
    _pg(
      _rad(
        const Offset(40, 46),
        sr * 1.2,
        gravy,
        st: const [0, .55, 1],
        tilt: _kTilt,
      ),
    ),
  );
  cv.drawOval(surf, _ps(_al(gravy[2], .6), 1.4, blur: .6));

  // Beads of oil floating on the gravy.
  for (var i = 0; i < s.n(5, 10); i++) {
    final p = _inEll(s.rnd, sc, sr, sr * _kTilt, .86);
    final rr = s.r(.7, 1.5);
    cv.drawOval(
      Rect.fromCenter(center: p, width: rr * 2.2, height: rr * 1.5),
      _pf(_al(const Color(0xFFFFC04A), .5)),
    );
    if (s.detail > .3 && i.isEven) _spark(s, p - Offset(rr * .3, rr * .3), .55);
  }
  // Specks of spice.
  final fleck = <Offset>[
    for (var i = 0; i < s.n(16, 52); i++)
      _inEll(s.rnd, sc, sr, sr * _kTilt, .94),
  ];
  cv.drawPoints(
    ui.PointMode.points,
    fleck,
    _ps(_al(const Color(0xFF4A1706), dal ? .4 : .5), .55),
  );

  // The cream swirl, poured in flat space and laid down in perspective.
  const sw = Offset(48, 50);
  final swirlR = dal ? 21.0 : 19.0;
  final pts = <Offset>[];
  for (var i = 0; i <= 46; i++) {
    final t = i / 46;
    final a = -1.2 + t * 2.75 * math.pi;
    final rr = swirlR * math.pow(1 - t, .85) + 1.6;
    pts.add(Offset(rr * math.cos(a), rr * math.sin(a)));
  }
  final ribbon = _ribbon(pts, (t) => .7 + 2.7 * math.pow(1 - t, .6));
  _at(cv, sw, 0, () {
    cv.drawPath(
      ribbon.shift(const Offset(.7, 1.5)),
      _pb(_al(gravy[2], .6), .9),
    );
    cv.drawPath(
      ribbon,
      _pg(
        _lin(const Offset(-19, -19), const Offset(19, 19), const [
          Color(0xFFFFFBF2),
          Color(0xFFF6DDB4),
        ]),
      ),
    );
  }, sy: _kTilt);

  if (dal) {
    // A butter pat melting into the cream.
    final pat = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(49, 49), width: 6.8, height: 5.2),
      const Radius.circular(1.2),
    );
    cv.drawRRect(pat.shift(const Offset(.6, 1)), _pb(_al(gravy[2], .8), .8));
    cv.drawRRect(
      pat,
      _pg(
        _lin(pat.outerRect.topLeft, pat.outerRect.bottomRight, const [
          Color(0xFFFFF3B8),
          Color(0xFFF2CC5A),
        ]),
      ),
    );
    if (s.detail > .2) _spark(s, const Offset(47.4, 47.6), .8);
  } else {
    // Pieces of paneer or meat sitting in the sauce, back to front.
    final count = s.detail > .45 ? 6 : 5;
    final start = s.r(0, math.pi * 2);
    final spots = <Offset>[
      for (var k = 0; k < count; k++)
        () {
          final a = start + k * math.pi * 2 / count + s.r(-.25, .25);
          final f = s.r(.52, .7);
          return Offset(
            sc.dx + math.cos(a) * sr * f,
            sc.dy + math.sin(a) * sr * f * _kTilt,
          );
        }(),
    ]..sort((a, b) => a.dy.compareTo(b.dy));
    final tones = meat
        ? const [Color(0xFFEBA352), Color(0xFFC46B27), Color(0xFF8B4416)]
        : green
        ? const [Color(0xFFFFF4D6), Color(0xFFF0CD86), Color(0xFFC2893E)]
        : const [Color(0xFFFBE3A2), Color(0xFFE8B35A), Color(0xFFB9772E)];
    for (final p in spots) {
      final size = s.r(7.6, 9.4);
      final rot = s.r(-.5, .5);
      final path = meat
          ? _blob(s.rnd, Offset.zero, size * .62, size * .48, n: 7, wob: .2)
          : (Path()..addRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset.zero,
                  width: size,
                  height: size * .82,
                ),
                Radius.circular(size * .2),
              ),
            ));
      _at(cv, p, rot, () {
        cv.drawPath(
          path.shift(const Offset(.7, 1.3)),
          _pb(_al(gravy[2], .9), .9),
        );
        cv.drawPath(
          path,
          _pg(_litLin(rot, size * .6, tones[0], tones[1], tones[2])),
        );
        // The part below the sauce line takes on the sauce.
        cv.drawPath(
          path,
          _pg(
            _lin(Offset(0, -size * .1), Offset(0, size * .5), [
              _al(gravy[1], 0),
              _al(gravy[1], .75),
            ]),
          ),
        );
        for (var j = 0; j < s.n(0, 3); j++) {
          cv.drawOval(
            Rect.fromCenter(
              center: Offset(
                s.r(-size * .3, size * .3),
                s.r(-size * .26, size * .16),
              ),
              width: s.r(.9, 2),
              height: s.r(.6, 1.2),
            ),
            _pf(_al(const Color(0xFF3F1808), .55)),
          );
        }
        _gloss(
          s,
          Offset(-size * .16, -size * .22),
          size * .2,
          size * .08,
          a: .5,
        );
      });
    }
  }

  // Fresh coriander over the top.
  for (var i = 0; i < s.n(6, 7); i++) {
    final p = _inEll(s.rnd, sc, sr, sr * _kTilt, .8);
    _coriander(s, p, s.r(0, 6.28), s.r(.6, .9));
  }
  // The sheen of the gravy under the key light.
  cv.drawArc(
    _ell(sc, sr * .8),
    math.pi * 1.1,
    math.pi * .28,
    false,
    _ps(_al(s.spec, .5), 1.6, blur: .9),
  );
  cv.restore();
}

// ───────────────────────────── rice ─────────────────────────────

/// A pointed leaf with a midrib, lying at [p] turned by [rot].
void _herbLeaf(
  _Scene s,
  Offset p,
  double rot,
  double len, {
  Color dark = const Color(0xFF2F7F34),
  Color lite = const Color(0xFF74C24C),
}) {
  final cv = s.canvas;
  final w = len * .36;
  final leaf = _leaf(len, w, len * .04);
  _at(cv, p, rot, () {
    cv.drawPath(leaf.shift(const Offset(.3, .7)), _pb(_al(_black, .35), .6));
    cv.drawPath(
      leaf,
      _pg(_lin(Offset(0, -w), Offset(len * .5, w), [lite, dark])),
    );
    if (s.detail > .3) {
      cv.drawLine(
        Offset(len * .08, 0),
        Offset(len * .86, 0),
        _ps(_al(_hi(lite, .5), .6), .4),
      );
    }
  });
}

void _rice(_Scene s) {
  final cv = s.canvas;
  final fried = s.any(['fried', 'schezwan', 'manchurian']);
  final m = fried ? _slate : _brass;
  const c = Offset(50, 55);
  const rx = 31.0;
  _ground(s, const Offset(52, 82), 29);
  if (!fried) {
    // Small loop handles on the handi.
    for (final side in const [-1.0, 1.0]) {
      final hc = Offset(c.dx + side * (rx + .6), c.dy + 5.5);
      cv.drawOval(
        Rect.fromCenter(center: hc, width: 5.5, height: 7),
        _ps(_black, 1.6)
          ..shader = _lin(
            hc - const Offset(3, 3),
            hc + const Offset(3, 3),
            [_brass.lit, _brass.mid, _brass.dark],
            const [0, .5, 1],
          ),
      );
    }
  }
  _bowl(s, c, rx, 24, m, foot: .55, wall: 2.6, belly: fried ? 1.0 : 1.14);

  // The mound of rice rising over the rim.
  final mound = Path()
    ..moveTo(c.dx - 28, c.dy + .6)
    ..cubicTo(c.dx - 28.6, c.dy - 14, c.dx - 15, c.dy - 31, c.dx - 1, c.dy - 31)
    ..cubicTo(
      c.dx + 14,
      c.dy - 31,
      c.dx + 28.6,
      c.dy - 14,
      c.dx + 28,
      c.dy + .6,
    )
    ..arcTo(_ell(c, 28), 0, math.pi, false)
    ..close();
  final tones = fried
      ? const [Color(0xFFFCE7A2), Color(0xFFEBC265), Color(0xFFAC7B2D)]
      : const [Color(0xFFFFF9E8), Color(0xFFF5E3B8), Color(0xFFC89A58)];
  cv.save();
  cv.clipPath(mound);
  cv.drawPath(
    mound,
    _pg(_rad(const Offset(40, 38), 44, tones, st: const [0, .5, 1])),
  );
  if (!fried) {
    // Saffron bleeding through the white grains, in loose patches that run
    // the whole height of the mound rather than stopping part-way.
    for (var i = 0; i < 6; i++) {
      final y0 = c.dy - 28 + i * 5.6 + s.r(-1.5, 1.5);
      final streak = Path()
        ..moveTo(c.dx + 31, y0 - 6 + s.r(-2, 2))
        ..cubicTo(
          c.dx + 12,
          y0 + 2,
          c.dx - 8,
          y0 - 5,
          c.dx - 31,
          y0 + 7 + s.r(-2, 4),
        );
      cv.drawPath(
        streak,
        _ps(
          _al(const Color(0xFFF2A22E), s.r(.3, .55)),
          s.r(2.4, 4.6),
          blur: 1.5,
        ),
      );
    }
    cv.drawOval(
      Rect.fromCenter(center: const Offset(62, 49), width: 22, height: 9),
      _pb(_al(const Color(0xFFB0651E), .16), 2.2),
    );
  }

  // Individual grains, lit from the upper left and shaded below.
  final palette = fried
      ? const [
          Color(0xFFF7DC8C),
          Color(0xFFEFC862),
          Color(0xFFE5B24A),
          Color(0xFFC98A32),
        ]
      : const [
          Color(0xFFFFF8E6),
          Color(0xFFF8E9BC),
          Color(0xFFF6C264),
          Color(0xFFD9902E),
        ];
  final grains = _Strokes(1.05);
  final b = mound.getBounds();
  final want = s.n(150, 430);
  var got = 0;
  for (var tries = 0; got < want && tries < want * 4; tries++) {
    final p = Offset(
      b.left + s.rnd.nextDouble() * b.width,
      b.top + s.rnd.nextDouble() * b.height,
    );
    if (!mound.contains(p)) continue;
    got++;
    final nx = (p.dx - 50) / 28;
    final ny = (p.dy - 24) / 34;
    final lit =
        ((.55 - nx * .34 - (ny - .35) * .6).clamp(0.0, 1.0) * 4).round() / 4;
    final pick = s.rnd.nextDouble();
    final base =
        palette[pick < .70
            ? 0
            : pick < .85
            ? 1
            : pick < .96
            ? 2
            : 3];
    final a = s.r(-1.2, 1.2) + .5;
    final d = Offset(math.cos(a), math.sin(a)) * s.r(.8, 1.15);
    grains.add(_lo(_hi(base, lit * .2), (1 - lit) * .3), p - d, p + d);
  }
  grains.paint(cv);
  // Form shadow on the far side, a warm glow where the light lands.
  cv.drawPath(
    mound,
    _pg(
      _lin(
        Offset(c.dx - 20, c.dy - 30),
        Offset(c.dx + 30, c.dy + 6),
        [_al(const Color(0xFF3A1E06), 0), _al(const Color(0xFF3A1E06), .22)],
        const [.4, 1],
      ),
    ),
  );
  cv.drawOval(
    Rect.fromCenter(center: const Offset(40, 33), width: 20, height: 13),
    _pb(_al(s.light, s.onDark ? .26 : .16), 3.6),
  );
  cv.restore();

  if (fried) {
    // Egg, carrot and spring onion through the rice.
    for (var i = 0; i < s.n(7, 12); i++) {
      final p = _inEll(s.rnd, Offset(c.dx, c.dy - 12), 22, 16);
      if (!mound.contains(p)) continue;
      cv.drawPath(
        _blob(s.rnd, p, s.r(1.4, 2.4), s.r(1, 1.7), n: 6),
        _pf(const Color(0xFFFFD34E)),
      );
    }
    for (var i = 0; i < s.n(5, 8); i++) {
      final p = _inEll(s.rnd, Offset(c.dx, c.dy - 12), 22, 16);
      if (!mound.contains(p)) continue;
      cv.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 2, height: 2),
          const Radius.circular(.5),
        ),
        _pf(const Color(0xFFEE7A22)),
      );
    }
    for (var i = 0; i < s.n(6, 10); i++) {
      final p = _inEll(s.rnd, Offset(c.dx, c.dy - 14), 21, 15);
      if (!mound.contains(p)) continue;
      cv.drawOval(
        Rect.fromCenter(center: p, width: 3, height: 2.2),
        _ps(const Color(0xFF58A83A), .9, cap: StrokeCap.butt),
      );
    }
  } else {
    // Fried onions, browned at the edges.
    const onion = [Color(0xFFE6B85A), Color(0xFFCC9038), Color(0xFFA2611F)];
    for (var i = 0; i < s.n(6, 10); i++) {
      final p = _inEll(s.rnd, Offset(c.dx + 3, c.dy - 17), 17, 10);
      if (!mound.contains(p)) continue;
      final a = s.r(0, 6.28);
      final dir = Offset(math.cos(a), math.sin(a));
      final len = s.r(3.4, 5.6);
      final bend = p + Offset(-dir.dy, dir.dx) * s.r(-2, 2);
      final path = Path()
        ..moveTo(p.dx + dir.dx * len / 2, p.dy + dir.dy * len / 2)
        ..quadraticBezierTo(
          bend.dx,
          bend.dy,
          p.dx - dir.dx * len / 2,
          p.dy - dir.dy * len / 2,
        );
      cv.drawPath(path.shift(const Offset(.4, .7)), _ps(_al(_black, .28), 1.3));
      cv.drawPath(path, _ps(onion[i % 3], s.r(.9, 1.4)));
    }
    // Mint over the top.
    const mint = [
      (-9.0, -21.0, -.9, 1.0),
      (-2.0, -27.0, -.35, 1.1),
      (5.0, -23.0, .55, .95),
      (-15.0, -14.0, -1.5, .9),
    ];
    for (var i = 0; i < s.n(3, 1); i++) {
      final (dx, dy, rot, k) = mint[i];
      _herbLeaf(s, Offset(c.dx + dx, c.dy + dy), rot, 7.2 * k);
    }
    // A boiled egg, halved, nestled against the rim.
    const ec = Offset(66, 51.5);
    final egg = Rect.fromCenter(center: ec, width: 11.4, height: 8.2);
    _at(cv, ec, -.25, () {
      final r0 = Rect.fromCenter(center: Offset.zero, width: 11.4, height: 8.2);
      cv.drawOval(
        r0.shift(const Offset(.8, 1.5)),
        _pb(_al(const Color(0xFF3A1E06), .55), 1),
      );
      cv.drawOval(
        r0,
        _pg(
          _lin(r0.topLeft, r0.bottomRight, const [
            Color(0xFFFFFFFF),
            Color(0xFFF1E3C6),
          ]),
        ),
      );
      cv.drawOval(r0, _ps(_al(const Color(0xFFCDB68C), .8), .6));
      const yolk = Offset(-.5, -.3);
      cv.drawCircle(
        yolk,
        2.6,
        _pg(
          _rad(
            yolk + const Offset(-1, -1),
            4.2,
            const [Color(0xFFFFE27A), Color(0xFFF5A91C), Color(0xFFC77A0A)],
            st: const [0, .55, 1],
          ),
        ),
      );
    });
    _spark(s, egg.center + const Offset(-1.7, -1.5), .55, a: .7);
  }

  // The front of the lip comes back over the foot of the mound.
  cv.drawArc(
    _ell(c, rx - 1.3),
    0,
    math.pi,
    false,
    _ps(_black, 2.7, cap: StrokeCap.butt)
      ..shader = _lin(
        Offset(c.dx - rx, 0),
        Offset(c.dx + rx, 0),
        [m.lit, m.mid, m.dark],
        const [0, .5, 1],
      ),
  );
  cv.drawArc(
    _ell(c + const Offset(0, -.9), rx - 1.3),
    math.pi * .1,
    math.pi * .5,
    false,
    _ps(_al(m.lit, .75), .6),
  );
  if (!fried) {
    _spark(s, Offset(c.dx - rx * .66, c.dy + 11), 1.1);
    _spark(s, Offset(c.dx - rx * .3, c.dy + 17), .7, a: .7);
  }
}

// ──────────────────────────── skewers ────────────────────────────

void _skewers(_Scene s) {
  final cv = s.canvas;
  final fry = s.any(['65', 'lollipop']);
  const c = Offset(50, 58);
  _ground(s, Offset(c.dx, c.dy + 4), 42);
  _plate(s, c, 42, 4, _slate, well: .9);

  // Green chutney in a small cream ramekin, back left.
  const rc = Offset(21, 48);
  cv.drawOval(
    _ell(rc + const Offset(2.2, 4.8), 8.6),
    _pb(_al(_black, s.shadowA * .6), 1.2),
  );
  final rg = _bowl(s, rc, 7.6, 4.8, _cream, foot: .6, wall: 1.3);
  cv.save();
  cv.clipPath(rg.holePath);
  final cs = _ell(rc + const Offset(0, .8), 6.2);
  cv.drawOval(
    cs,
    _pg(
      _rad(
        rc + const Offset(-1.6, -.8),
        8.5,
        const [Color(0xFFA6DC55), Color(0xFF5BA02B), Color(0xFF2F6B1A)],
        st: const [0, .55, 1],
        tilt: _kTilt,
      ),
    ),
  );
  cv.restore();
  _spark(s, rc + const Offset(-1.8, -.3), .6, a: .8);

  if (fry) {
    _pile65(s);
  } else {
    _tikkaSkewer(s);
  }

  // Onion rings, flat on the board.
  void ring(Offset p, double r0) {
    final o = _ell(p, r0);
    cv.drawOval(
      o.shift(const Offset(.5, 1)),
      _ps(_al(_black, s.shadowA * .45), 2, blur: .7),
    );
    cv.drawOval(o, _ps(const Color(0xFFB5578B), 2.2));
    cv.drawOval(
      o.shift(const Offset(-.2, -.25)),
      _ps(const Color(0xFFEBC4DA), 1),
    );
  }

  ring(const Offset(27, 71.5), 6.4);
  ring(const Offset(33.5, 70), 5.4);
  if (s.detail > .25) ring(const Offset(24, 68), 4.2);

  // A lemon wedge, cut face toward us.
  _at(cv, const Offset(66, 71), -.22, () {
    final rind = Path()
      ..moveTo(-6.4, 0)
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: 6.4),
        math.pi,
        math.pi,
        false,
      )
      ..close();
    final flesh = Path()
      ..moveTo(-5.3, 0)
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: 5.3),
        math.pi,
        math.pi,
        false,
      )
      ..close();
    cv.drawOval(
      Rect.fromCenter(center: const Offset(.8, .8), width: 14, height: 2.6),
      _pb(_al(_black, s.shadowA * .6), 1),
    );
    cv.drawPath(
      rind,
      _pg(
        _lin(const Offset(-6, -6), const Offset(6, 1), const [
          Color(0xFFFBDD55),
          Color(0xFFE8B422),
        ]),
      ),
    );
    cv.drawPath(
      flesh,
      _pg(
        _lin(const Offset(-5, -5), const Offset(5, 0), const [
          Color(0xFFFFF6BE),
          Color(0xFFFBE27A),
        ]),
      ),
    );
    for (var k = 1; k <= 5; k++) {
      final a = math.pi + k * math.pi / 6;
      cv.drawLine(
        Offset.zero,
        Offset(math.cos(a), math.sin(a)) * 4.7,
        _ps(const Color(0xFFF3D152), .5),
      );
    }
    cv.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 5.4),
      math.pi,
      math.pi,
      false,
      _ps(const Color(0xFFFFFBE2), .55),
    );
  });
  _spark(s, const Offset(63.4, 67.4), .6, a: .7);
}

void _tikkaSkewer(_Scene s) {
  final cv = s.canvas;
  const a0 = Offset(10, 66);
  const b0 = Offset(92, 52);
  final ang = math.atan2(b0.dy - a0.dy, b0.dx - a0.dx);
  final body = s.any(['chicken', 'murgh'])
      ? const Color(0xFFE0652B)
      : s.any(['mutton', 'lamb', 'seekh'])
      ? const Color(0xFFB5502A)
      : s.any(['paneer'])
      ? const Color(0xFFF0A93E)
      : const Color(0xFFEA8A33);
  cv.drawLine(
    a0 + const Offset(1.5, 2.8),
    b0 + const Offset(1.5, 2.8),
    _ps(_al(_black, s.shadowA * .5), 1.8, blur: 1),
  );
  cv.drawLine(a0, b0, _ps(const Color(0xFFD5DAE0), 1.3));
  cv.drawLine(
    a0 + const Offset(0, -.4),
    b0 + const Offset(0, -.4),
    _ps(const Color(0xCCFFFFFF), .4),
  );
  cv.drawCircle(
    a0 + const Offset(-2.4, .3),
    2.5,
    _ps(const Color(0xFFC3C9D1), 1),
  );

  void cube(Offset p, double rot, Color base, int kind) {
    const w = 12.0;
    const h = 9.8;
    const dx = 2.8;
    const dy = -3.6;
    _at(s.canvas, p, rot, () {
      cv.drawOval(
        Rect.fromCenter(
          center: const Offset(2.4, h / 2 + 1.4),
          width: w * 1.15,
          height: 3.4,
        ),
        _pb(_al(_black, s.shadowA * .65), 1.2),
      );
      final front = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        const Radius.circular(1.7),
      );
      final top = Path()
        ..moveTo(-w / 2, -h / 2)
        ..lineTo(-w / 2 + dx, -h / 2 + dy)
        ..lineTo(w / 2 + dx, -h / 2 + dy)
        ..lineTo(w / 2, -h / 2)
        ..close();
      final right = Path()
        ..moveTo(w / 2, -h / 2)
        ..lineTo(w / 2 + dx, -h / 2 + dy)
        ..lineTo(w / 2 + dx, h / 2 + dy)
        ..lineTo(w / 2, h / 2)
        ..close();
      cv.drawPath(right, _pf(_lo(base, .42)));
      cv.drawRRect(
        front,
        _pg(
          _lin(const Offset(0, -h / 2), const Offset(0, h / 2), [
            _hi(base, .12),
            _lo(base, .22),
          ]),
        ),
      );
      cv.drawPath(top, _pf(_hi(base, .38)));
      if (kind == 0) {
        // Char on the edges and a couple of grill marks.
        cv.drawRRect(
          front.deflate(.4),
          _ps(_al(const Color(0xFF2A1208), .35), .9),
        );
        for (var i = 0; i < s.n(2, 3); i++) {
          cv.drawOval(
            Rect.fromCenter(
              center: Offset(s.r(-w * .38, w * .38), s.r(-h * .36, h * .3)),
              width: s.r(1.2, 2.6),
              height: s.r(.8, 1.6),
            ),
            _pf(_al(const Color(0xFF2A1208), .55)),
          );
        }
        if (s.detail > .3) {
          for (final k in const [-3.0, 1.0]) {
            cv.drawLine(
              Offset(k - 1.5, -h * .38),
              Offset(k + 2.2, h * .38),
              _ps(_al(const Color(0xFF2A1208), .4), .8),
            );
          }
        }
      } else if (kind == 2) {
        for (final r0 in const [3.2, 5.2]) {
          cv.drawArc(
            Rect.fromCircle(center: const Offset(-1.5, 3.4), radius: r0),
            math.pi * 1.1,
            math.pi * .8,
            false,
            _ps(const Color(0xFFEBC4DA), .55),
          );
        }
      }
      cv.drawOval(
        Rect.fromCenter(
          center: const Offset(-w * .16, -h / 2 + dy * .5 - .2),
          width: 3,
          height: 1,
        ),
        _pf(_al(s.spec, .6)),
      );
    });
  }

  const kinds = [0, 1, 0, 2, 0];
  const colors = [null, Color(0xFF4F9E2E), null, Color(0xFFB45A8E), null];
  for (var i = 0; i < 5; i++) {
    final t = .24 + i * .14;
    final p = Offset.lerp(a0, b0, t)!;
    cube(p, ang + s.r(-.1, .1), colors[i] ?? body, kinds[i]);
  }
  // Coriander flecks over the cubes.
  for (var i = 0; i < s.n(4, 8); i++) {
    final p =
        Offset.lerp(a0, b0, s.r(.2, .84))! + Offset(s.r(-3, 3), s.r(-6, 1));
    cv.drawCircle(p, s.r(.4, .7), _pf(const Color(0xFF58A83A)));
  }
}

void _pile65(_Scene s) {
  final cv = s.canvas;
  final spots = <Offset>[
    for (var i = 0; i < s.n(9, 5); i++)
      _inEll(s.rnd, const Offset(50, 55), 25, 9),
  ]..sort((a, b) => a.dy.compareTo(b.dy));
  for (final p in spots) {
    final sz = s.r(8, 10.5);
    final rot = s.r(-.8, .8);
    final path = _blob(s.rnd, Offset.zero, sz * .58, sz * .44, n: 8, wob: .22);
    _at(cv, p, rot, () {
      cv.drawPath(
        path.shift(const Offset(.9, 1.6)),
        _pb(_al(_black, s.shadowA * .6), 1),
      );
      cv.drawPath(
        path,
        _pg(
          _litLin(
            rot,
            sz * .6,
            const Color(0xFFF5924A),
            const Color(0xFFD3481E),
            const Color(0xFF8B2209),
          ),
        ),
      );
      for (var j = 0; j < s.n(3, 6); j++) {
        cv.drawCircle(
          Offset(s.r(-sz * .38, sz * .38), s.r(-sz * .28, sz * .28)),
          s.r(.3, .7),
          _pf(
            _al(
              j.isEven ? const Color(0xFF6E1706) : const Color(0xFFFFC27A),
              .6,
            ),
          ),
        );
      }
      _gloss(s, Offset(-sz * .16, -sz * .2), sz * .2, sz * .08, a: .5);
    });
  }
  for (final (p, rot) in const [
    (Offset(35, 64), .25),
    (Offset(63, 61), -.45),
  ]) {
    _at(cv, p, rot, () {
      final chili = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(5, -2.6, 11, 1);
      cv.drawPath(
        chili.shift(const Offset(.5, 1.2)),
        _ps(_al(_black, .4), 2.4, blur: .6),
      );
      cv.drawPath(chili, _ps(const Color(0xFF4E9A2C), 2.4));
      cv.drawPath(
        chili.shift(const Offset(-.2, -.5)),
        _ps(const Color(0xFF8CD05A), .8),
      );
      cv.drawCircle(Offset.zero, 1.1, _pf(const Color(0xFF2C5E18)));
    });
  }
  const leaves = [
    (40.0, 53.0, .3),
    (56.0, 50.0, -.7),
    (68.0, 57.0, 1.9),
    (47.0, 62.0, 3.4),
    (30.0, 56.0, 2.6),
  ];
  for (var i = 0; i < s.n(3, 2); i++) {
    final (x, y, r0) = leaves[i];
    _herbLeaf(
      s,
      Offset(x, y),
      r0,
      6,
      dark: const Color(0xFF1F5E22),
      lite: const Color(0xFF4E9A3C),
    );
  }
}

// ───────────────────────────── pizza ─────────────────────────────

void _pizza(_Scene s) {
  final cv = s.canvas;
  final meaty = s.any([
    'pepperoni',
    'sausage',
    'meat',
    'bbq',
    'chicken',
    'salami',
  ]);
  const bc = Offset(50, 57);
  const pc = Offset(44, 50.5);
  const rr = 34.0;
  const t1 = .10 * math.pi;
  const t2 = .40 * math.pi;
  const lift = Offset(8.5, -2.2);
  final tseed = s.rnd.nextInt(1 << 30);

  _ground(s, Offset(bc.dx, bc.dy + 3), 45);
  _plate(s, bc, 45, 3.2, _walnut, wellOn: false);
  if (s.detail > .3) {
    for (final k in const [.93, .84, .75]) {
      cv.drawOval(_ell(bc, 45 * k), _ps(_al(_walnut.dark, .16), .5));
    }
  }

  Path sector(Offset o, double r, double a1, double a2) => Path()
    ..moveTo(o.dx, o.dy)
    ..lineTo(o.dx + r * math.cos(a1), o.dy + r * _kTilt * math.sin(a1))
    ..arcTo(_ell(o, r), a1, a2 - a1, false)
    ..close();

  final pie = sector(pc, rr, t2, t1 + math.pi * 2);
  final slice = sector(pc + lift, rr, t1 + .025 * math.pi, t2 - .025 * math.pi);

  void sides(Path p, double thick) {
    for (var k = 4; k >= 0; k--) {
      cv.drawPath(
        p.shift(Offset(0, thick * k / 4)),
        _pf(_mix(const Color(0xFFD99440), const Color(0xFF8A5120), k / 4)),
      );
    }
  }

  // Everything that sits on top of the dough, drawn once around [o]. The
  // slice reuses it, so it is exactly the piece that was taken from the pie.
  void top(Offset o) {
    final r = math.Random(tseed);
    cv.drawOval(
      _ell(o, rr),
      _pg(
        _rad(
          o + const Offset(-10, -4),
          rr * 1.4,
          const [Color(0xFFF3BB66), Color(0xFFD99840), Color(0xFFA9692A)],
          st: const [0, .55, 1],
          tilt: _kTilt,
        ),
      ),
    );
    for (var i = 0; i < s.n(6, 16); i++) {
      final p = _on(
        o,
        rr - 1.2 - r.nextDouble() * 2.6,
        r.nextDouble() * math.pi * 2,
      );
      cv.drawOval(
        Rect.fromCenter(
          center: p,
          width: r.nextDouble() * 2.2 + 1,
          height: r.nextDouble() * 1.2 + .6,
        ),
        _pf(_al(const Color(0xFF6B3A12), .5 + r.nextDouble() * .3)),
      );
    }
    for (var i = 0; i < s.n(5, 20); i++) {
      final p = _on(
        o,
        rr - .8 - r.nextDouble() * 3.2,
        r.nextDouble() * math.pi * 2,
      );
      cv.drawCircle(p, .35, _pf(_al(const Color(0xFFFFF6E0), .7)));
    }
    const inner = rr - 4.4;
    final ie = _ell(o + const Offset(0, .5), inner);
    cv.drawOval(
      ie,
      _pg(
        _rad(
          o + const Offset(-8, -3),
          inner * 1.3,
          const [Color(0xFFE5502F), Color(0xFFC4321C), Color(0xFF8F2012)],
          st: const [0, .55, 1],
          tilt: _kTilt,
        ),
      ),
    );
    cv.drawOval(ie, _ps(_al(const Color(0xFF7A2A10), .5), .8));
    // Melted mozzarella with golden blisters.
    for (var i = 0; i < s.n(11, 12); i++) {
      final p = _inEll(r, o, inner * .78, inner * .78 * _kTilt);
      final rx0 = 4.5 + r.nextDouble() * 4.5;
      final blob = _blob(r, p, rx0, rx0 * _kTilt * 1.2, n: 8, wob: .28);
      cv.drawPath(
        blob.shift(const Offset(.3, .9)),
        _pf(_al(const Color(0xFFB4702A), .5)),
      );
      cv.drawPath(
        blob,
        _pg(
          _lin(p - Offset(rx0, rx0 * .5), p + Offset(rx0, rx0 * .5), const [
            Color(0xFFFFF7D8),
            Color(0xFFF6DA94),
          ]),
        ),
      );
      if (i.isEven) {
        cv.drawOval(
          Rect.fromCenter(
            center:
                p + Offset(r.nextDouble() * 2 - 1, r.nextDouble() * 1.2 - .6),
            width: 2.4 + r.nextDouble() * 1.6,
            height: 1.4 + r.nextDouble(),
          ),
          _pf(_al(const Color(0xFFD28A32), .85)),
        );
      }
    }
    if (meaty) {
      for (var i = 0; i < 8; i++) {
        final d = inner * .76 * math.sqrt((i + .5) / 8);
        final p = _on(o, d, i * 2.4);
        final disc = _ell(p, 4.5, _kTilt * 1.12);
        cv.drawOval(disc.shift(const Offset(.4, 1)), _pf(_al(_black, .35)));
        cv.drawOval(
          disc,
          _pg(
            _rad(
              p + const Offset(-1.4, -.8),
              5.5,
              const [Color(0xFFD9553A), Color(0xFFB5301C), Color(0xFF7E1C10)],
              st: const [0, .5, 1],
              tilt: _kTilt,
            ),
          ),
        );
        cv.drawOval(disc, _ps(_al(const Color(0xFF5E150B), .6), .5));
        cv.drawCircle(
          p + const Offset(1.4, .4),
          .45,
          _pf(_al(const Color(0xFFF0A07A), .8)),
        );
        cv.drawCircle(
          p + const Offset(-1.2, 1),
          .35,
          _pf(_al(const Color(0xFFF0A07A), .7)),
        );
        _gloss(s, p + const Offset(-1.2, -.9), 1.4, .5, a: .55);
      }
    }
    for (var i = 0; i < (meaty ? 2 : 4); i++) {
      final p = _inEll(r, o, inner * .6, inner * .6 * _kTilt);
      _herbLeaf(s, p, r.nextDouble() * math.pi * 2, meaty ? 6 : 8.5);
    }
    cv.drawPoints(ui.PointMode.points, [
      for (var i = 0; i < s.n(8, 36); i++)
        _inEll(r, o, inner * .9, inner * .9 * _kTilt),
    ], _ps(_al(const Color(0xFF3C7A2A), .6), .5));
  }

  // The pie with its wedge missing.
  sides(pie, 3.6);
  cv.save();
  cv.clipPath(pie);
  top(pc);
  cv.restore();
  _rim(s, _ell(pc, rr), w: 1);

  // The lifted slice: shadow on the board, edge, then its own top.
  cv.drawPath(
    slice.shift(lift * .2 + const Offset(2.2, 6.2)),
    _pb(_al(_black, s.shadowA * .55), 2.2),
  );
  // Strings of cheese still joining it to the pie.
  for (final f in const [.35, .58, .8]) {
    final p0 =
        pc + Offset(rr * f * math.cos(t2), rr * f * _kTilt * math.sin(t2));
    final p1 = p0 + lift + const Offset(-.5, -1);
    final mid = Offset.lerp(p0, p1, .5)! + const Offset(0, 3.4);
    final str = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, p1.dx, p1.dy);
    cv.drawPath(
      str.shift(const Offset(.3, 1)),
      _ps(_al(_black, .25), 1, blur: .5),
    );
    cv.drawPath(str, _ps(const Color(0xFFFFF0C0), 1));
  }
  sides(slice, 3.6);
  cv.save();
  cv.clipPath(slice);
  top(pc + lift);
  cv.restore();
  _spark(s, pc + lift + const Offset(20, 8), .7, a: .6);
}

// ───────────────────────────── pasta ─────────────────────────────

void _pasta(_Scene s) {
  final cv = s.canvas;
  const c = Offset(50, 52);
  const pasta = [Color(0xFFFDE6A8), Color(0xFFF4C968), Color(0xFFC78F30)];
  const sauce = [Color(0xFFFF7A44), Color(0xFFE5502A), Color(0xFFA32C14)];
  _ground(s, const Offset(51, 75), 34);
  final g = _bowl(s, c, 41, 16, _cream, foot: .62, wall: 4.4);

  // A few drops of sauce that landed on the rim.
  for (var i = 0; i < s.n(2, 6); i++) {
    final a = s.r(.1, 1.1) * math.pi;
    final p = _on(c, s.r(37.8, 40.2), a);
    final rr = s.r(.5, 1.3);
    cv.drawOval(
      Rect.fromCenter(center: p, width: rr * 2.2, height: rr * 1.7),
      _pf(_al(const Color(0xFFD63E1E), .9)),
    );
    cv.drawCircle(
      p + Offset(-rr * .3, -rr * .3),
      rr * .25,
      _pf(_al(s.spec, .7)),
    );
  }

  cv.save();
  cv.clipPath(g.roomAbove(32));
  final pool = _ell(const Offset(50, 54), 34.5);
  cv.drawOval(
    pool,
    _pg(
      _rad(
        const Offset(40, 51),
        42,
        const [Color(0xFFF0603A), Color(0xFFCF4022), Color(0xFF8E2210)],
        st: const [0, .55, 1],
        tilt: _kTilt,
      ),
    ),
  );
  cv.drawOval(pool, _ps(_al(const Color(0xFF6A160A), .45), 1.2, blur: .6));

  // A heap of penne: sample a dome, then draw back to front.
  const hc = Offset(50, 52);
  const hr = 29.0;
  const hh = 18.0;
  final heap = <(Offset, double, double, double)>[];
  for (var i = 0; i < s.n(34, 44); i++) {
    final a = s.r(0, math.pi * 2);
    final d = math.sqrt(s.rnd.nextDouble());
    final u = d * math.cos(a);
    final v = d * math.sin(a);
    final h = hh * math.pow(1 - d * d, .7);
    heap.add((Offset(hc.dx + u * hr, hc.dy + v * hr * _kTilt - h), v, h, u));
  }
  heap.sort((a, b) => (a.$2 + a.$3 * .03).compareTo(b.$2 + b.$3 * .03));
  for (final (p, v, h, u) in heap) {
    const len = 9.4;
    const wid = 4.5;
    final k = s.r(.88, 1.12);
    final rot = s.r(0, math.pi);
    final lit = (.55 - .35 * u - .3 * v + .25 * h / hh).clamp(0.0, 1.0);
    final coat = s.r(.66, .88);
    final body = Path()
      ..moveTo(-len / 2 + 1.6, -wid / 2)
      ..lineTo(len / 2 + 1.6, -wid / 2)
      ..lineTo(len / 2 - 1.6, wid / 2)
      ..lineTo(-len / 2 - 1.6, wid / 2)
      ..close();
    final sheath = Path()
      ..moveTo(-len / 2 + 3.2, -wid / 2 + .1)
      ..lineTo(len / 2 - .2, -wid / 2 + .1)
      ..lineTo(len / 2 - 3.0, wid / 2 - .1)
      ..lineTo(-len / 2 - .1, wid / 2 - .1)
      ..close();
    final open = s.rnd.nextDouble() < .6;
    _at(
      cv,
      p,
      rot,
      () {
        cv.drawPath(
          body.shift(const Offset(.6, 1.2)),
          _pf(_al(const Color(0xFF4A0E06), .62)),
        );
        cv.drawPath(
          body,
          _pg(_litLin(rot, wid * .6, pasta[0], pasta[1], pasta[2])),
        );
        cv.drawPath(body, _ps(pasta[1], .9));
        cv.drawPath(
          sheath,
          _pg(
            _litLin(
              rot,
              wid * .6,
              _al(_mix(sauce[1], sauce[0], lit), coat),
              _al(_mix(sauce[2], sauce[1], lit + .35), coat),
              _al(sauce[2], coat),
            ),
          ),
        );
        cv.drawPath(sheath, _ps(_al(sauce[1], coat), .8));
        if (open) {
          final hole = Rect.fromCenter(
            center: const Offset(len / 2 + .2, 0),
            width: 2.0,
            height: wid * .84,
          );
          cv.drawOval(hole, _pf(const Color(0xFF8A5A1E)));
          cv.drawOval(hole, _ps(_al(const Color(0xFFFFEBB0), .8), .4));
        }
        if (s.detail > .3) {
          // Round the tube: a shade along its underside, a glint along its top.
          cv.drawLine(
            const Offset(-len / 2 + 2.2, wid / 2 - .5),
            const Offset(len / 2 - 2.4, wid / 2 - .5),
            _ps(_al(sauce[2], .55), .8),
          );
          cv.drawLine(
            const Offset(-len / 2 + 3.4, -wid / 2 + .8),
            const Offset(len / 2 - 1.4, -wid / 2 + .8),
            _ps(_al(s.spec, .5), .5),
          );
        }
      },
      sx: k,
      sy: k,
    );
  }
  // Chilli flakes and cracked pepper.
  cv.drawPoints(ui.PointMode.points, [
    for (var i = 0; i < s.n(8, 30); i++)
      _inEll(s.rnd, hc + const Offset(0, -9), 22, 10),
  ], _ps(_al(const Color(0xFF5A1208), .75), .6));
  cv.restore();

  // Parmesan curls and basil on top.
  for (var i = 0; i < s.n(3, 4); i++) {
    final a = s.r(0, math.pi * 2);
    final d = math.sqrt(s.rnd.nextDouble()) * .7;
    final h = hh * math.pow(1 - d * d, .7);
    final p = Offset(
      hc.dx + d * math.cos(a) * hr,
      hc.dy + d * math.sin(a) * hr * _kTilt - h - 1,
    );
    _at(cv, p, s.r(-.6, .6), () {
      final curl = Path()
        ..moveTo(-2.6, 0)
        ..quadraticBezierTo(0, -2.6, 2.7, .2);
      cv.drawPath(
        curl.shift(const Offset(0, .8)),
        _ps(const Color(0xFFD9BE86), 1.3),
      );
      cv.drawPath(curl, _ps(const Color(0xFFFFF6DC), 1.2));
    });
  }
  const basil = [(46.5, 36.0, -.7), (53.5, 37.5, .5), (50.0, 33.0, -1.7)];
  for (final (x, y, r0) in basil) {
    _herbLeaf(s, Offset(x, y), r0, 9);
  }
  _spark(s, const Offset(43, 40), .8, a: .7);
}

// ──────────────────────────── noodles ────────────────────────────

void _noodles(_Scene s) {
  final cv = s.canvas;
  const c = Offset(50, 50);
  const rx = 37.0;
  _ground(s, const Offset(52, 79), 30);
  final g = _bowl(s, c, rx, 28, _slate, wall: 2.6);
  // A thin gold band round the wall.
  cv.drawArc(
    _ell(Offset(c.dx, c.dy + 5.8), rx - 1.5),
    .04,
    math.pi - .08,
    false,
    _ps(_black, 1.1, cap: StrokeCap.butt)
      ..shader = _lin(
        Offset(c.dx - rx, 0),
        Offset(c.dx + rx, 0),
        const [Color(0xFFF2D27A), Color(0xFFC99A3C), Color(0xFF6A4A16)],
        const [0, .5, 1],
      ),
  );

  // The nest of noodles piled over the rim.
  final nest = Path()
    ..moveTo(c.dx - 34, c.dy + 1)
    ..cubicTo(
      c.dx - 35,
      c.dy - 12,
      c.dx - 18,
      c.dy - 20.5,
      c.dx - 1,
      c.dy - 20.5,
    )
    ..cubicTo(c.dx + 16, c.dy - 20.5, c.dx + 35, c.dy - 12, c.dx + 34, c.dy + 1)
    ..arcTo(g.hole, 0, math.pi, false)
    ..close();
  cv.save();
  cv.clipPath(nest);
  cv.drawPath(
    nest,
    _pg(
      _rad(
        const Offset(40, 38),
        46,
        const [Color(0xFFF7CC6C), Color(0xFFDA9A3A), Color(0xFF8E5A1E)],
        st: const [0, .55, 1],
      ),
    ),
  );
  const tones = [
    Color(0xFFFCE48E),
    Color(0xFFF4C86A),
    Color(0xFFE2A844),
    Color(0xFFC08630),
  ];
  final arcs = <(Offset, double, double, double, double, double)>[];
  for (var i = 0; i < s.n(26, 46); i++) {
    final p = _inEll(s.rnd, Offset(c.dx, c.dy - 6), 28, 17);
    final r0 = s.r(7, 21);
    arcs.add((
      p,
      r0,
      r0 * s.r(.28, .6),
      s.r(-.5, .5) + (i.isEven ? 0 : math.pi),
      s.r(0, math.pi * 2),
      s.r(1.3, 1.9) * math.pi,
    ));
  }
  arcs.sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
  final wide = 1.5 + .5 * s.detail;
  for (final (p, ax, ay, rot, start, sweep) in arcs) {
    final lit = (.62 - (p.dx - 50) / 80 - (p.dy - 40) / 36).clamp(0.0, 1.0);
    final col = tones[(3 - (lit * 3.4).floor().clamp(0, 3))];
    _at(cv, p, rot, () {
      final oval = Rect.fromCenter(
        center: Offset.zero,
        width: ax * 2,
        height: ay * 2,
      );
      cv.drawArc(
        oval.shift(const Offset(.3, .7)),
        start,
        sweep,
        false,
        _ps(_al(const Color(0xFF3A1E06), .4), wide),
      );
      cv.drawArc(oval, start, sweep, false, _ps(col, wide));
      if (s.detail > .15) {
        cv.drawArc(
          oval.shift(const Offset(-.3, -.45)),
          start,
          sweep,
          false,
          _ps(_al(const Color(0xFFFFEBB0), .5), .5),
        );
      }
    });
  }
  // Vegetables worked through the noodles.
  for (var i = 0; i < s.n(6, 10); i++) {
    final p = _inEll(s.rnd, Offset(c.dx, c.dy - 8), 25, 14);
    cv.drawOval(
      Rect.fromCenter(center: p, width: 3, height: 2.2),
      _ps(const Color(0xFF58AE3C), 1),
    );
    cv.drawCircle(p, .5, _pf(const Color(0xFFC9EA9A)));
  }
  for (var i = 0; i < s.n(5, 9); i++) {
    final p = _inEll(s.rnd, Offset(c.dx, c.dy - 8), 25, 14);
    final a = s.r(0, math.pi);
    final d = Offset(math.cos(a), math.sin(a)) * s.r(1.4, 2.2);
    cv.drawLine(p - d, p + d, _ps(const Color(0xFFF0832A), 1.2));
  }
  for (var i = 0; i < s.n(3, 6); i++) {
    final p = _inEll(s.rnd, Offset(c.dx, c.dy - 8), 24, 13);
    final a = s.r(0, math.pi);
    final d = Offset(math.cos(a), math.sin(a)) * s.r(1.5, 2.4);
    cv.drawLine(
      p - d,
      p + d,
      _ps(i.isEven ? const Color(0xFFD93A2B) : const Color(0xFF9A3F86), 1.3),
    );
  }
  cv.drawPoints(ui.PointMode.points, [
    for (var i = 0; i < s.n(5, 20); i++)
      _inEll(s.rnd, Offset(c.dx, c.dy - 8), 26, 14),
  ], _ps(_al(const Color(0xFFFFF1D4), .9), .6));
  // Form shadow and the warm key light on the nest.
  cv.drawPath(
    nest,
    _pg(
      _lin(
        Offset(c.dx - 22, c.dy - 22),
        Offset(c.dx + 34, c.dy + 4),
        [_al(const Color(0xFF2A1204), 0), _al(const Color(0xFF2A1204), .2)],
        const [.45, 1],
      ),
    ),
  );
  cv.drawOval(
    Rect.fromCenter(center: const Offset(40, 34), width: 20, height: 10),
    _pb(_al(s.light, s.onDark ? .26 : .16), 3.4),
  );
  cv.restore();
  _gloss(s, const Offset(61, 38), 4.5, 1.1, rot: -.3, a: .4);

  // Chopsticks resting on the rim, tips in the noodles.
  for (final off in const [Offset.zero, Offset(2.7, -2.5)]) {
    final t = const Offset(47, 33.5) + off;
    final e = const Offset(90, 77) + off;
    final dir = (e - t) / (e - t).distance;
    final nrm = Offset(-dir.dy, dir.dx);
    final stick = Path()
      ..moveTo((t + nrm * .6).dx, (t + nrm * .6).dy)
      ..lineTo((e + nrm * 1.0).dx, (e + nrm * 1.0).dy)
      ..lineTo((e - nrm * 1.0).dx, (e - nrm * 1.0).dy)
      ..lineTo((t - nrm * .6).dx, (t - nrm * .6).dy)
      ..close();
    cv.drawPath(
      stick.shift(const Offset(1.3, 2.2)),
      _pb(_al(_black, s.shadowA * .55), 1.1),
    );
    cv.drawPath(
      stick,
      _pg(
        _lin(
          t - nrm * 1.2,
          t + nrm * 1.2,
          const [Color(0xFFF3CF86), Color(0xFFC89048), Color(0xFF8E5E2A)],
          const [0, .55, 1],
        ),
      ),
    );
    // Lacquered grip.
    final g0 = Offset.lerp(t, e, .7)!;
    final grip = Path()
      ..moveTo((g0 + nrm * .8).dx, (g0 + nrm * .8).dy)
      ..lineTo((e + nrm * 1.0).dx, (e + nrm * 1.0).dy)
      ..lineTo((e - nrm * 1.0).dx, (e - nrm * 1.0).dy)
      ..lineTo((g0 - nrm * .8).dx, (g0 - nrm * .8).dy)
      ..close();
    cv.drawPath(grip, _pf(const Color(0xFF9E2A1B)));
    cv.drawLine(
      g0 - nrm * 1.1,
      g0 + nrm * 1.1,
      _ps(const Color(0xFFE2B85A), .9, cap: StrokeCap.butt),
    );
    cv.drawLine(
      t - nrm * .4,
      e - nrm * .4,
      _ps(_al(const Color(0xFFFFF0CC), .35), .35),
    );
  }
}

// ──────────────────────────── flatbread ────────────────────────────

void _flatbread(_Scene s) {
  final cv = s.canvas;
  final roti = s.any([
    'roti',
    'naan',
    'paratha',
    'parota',
    'kulcha',
    'chapati',
    'thepla',
    'phulka',
  ]);
  const c = Offset(50, 58);
  _ground(s, Offset(c.dx, c.dy + 3.2), 44);
  _plate(s, c, 44, 3.2, _steel, well: .78);

  // Two small steel katoris at the back, one white, one red or golden.
  void katori(Offset kc, List<Color> tones, bool coconut) {
    cv.drawOval(
      _ell(kc + const Offset(2.6, 6.2), 9.4),
      _pb(_al(_black, s.shadowA * .6), 1.3),
    );
    final k = _bowl(s, kc, 9.2, 5.6, _steel, foot: .55, wall: 1.4);
    cv.save();
    cv.clipPath(k.holePath);
    final surf = _ell(kc + const Offset(0, .9), 7.8);
    cv.drawOval(
      surf,
      _pg(
        _rad(
          kc + const Offset(-2, -.8),
          10,
          tones,
          st: const [0, .6, 1],
          tilt: _kTilt,
        ),
      ),
    );
    for (var i = 0; i < s.n(2, 7); i++) {
      final p = _inEll(s.rnd, kc + const Offset(0, .9), 6.6, 6.6 * _kTilt);
      cv.drawCircle(
        p,
        s.r(.3, .6),
        _pf(
          coconut
              ? (i.isEven ? const Color(0xFF3F7A2A) : const Color(0xFF2A1A0C))
              : const Color(0xFFFFE07A),
        ),
      );
    }
    cv.restore();
    _gloss(s, kc + const Offset(-2.4, -.6), 2.2, .7, a: .6);
  }

  katori(const Offset(26, 47), const [
    Color(0xFFFFFDF4),
    Color(0xFFF3ECD8),
    Color(0xFFCFC3A4),
  ], true);
  katori(
    const Offset(71, 45),
    roti
        ? const [Color(0xFFF4C23F), Color(0xFFE09A22), Color(0xFFA8660E)]
        : const [Color(0xFFE5502C), Color(0xFFC03018), Color(0xFF86200F)],
    false,
  );

  if (roti) {
    _rotiStack(s);
  } else {
    _dosaRoll(s);
  }
}

void _dosaRoll(_Scene s) {
  final cv = s.canvas;
  const a = Offset(11, 68);
  const b = Offset(86, 58);
  final span = b - a;
  final d = span / span.distance;
  final up = Offset(d.dy, -d.dx);
  final heading = math.atan2(d.dy, d.dx);
  double rad(double t) => 5.6 + 3.0 * math.pow(t, .8);
  Offset at(double t) => a + span * t;

  final body = Path()
    ..moveTo((at(0) + up * rad(0)).dx, (at(0) + up * rad(0)).dy);
  for (var i = 1; i <= 20; i++) {
    final p = at(i / 20) + up * rad(i / 20);
    body.lineTo(p.dx, p.dy);
  }
  for (var i = 20; i >= 0; i--) {
    final p = at(i / 20) - up * rad(i / 20);
    body.lineTo(p.dx, p.dy);
  }
  final theta = math.atan2(up.dy, up.dx);
  for (var i = 1; i < 12; i++) {
    final phi = theta + math.pi + math.pi * i / 12;
    body.lineTo(a.dx + math.cos(phi) * rad(0), a.dy + math.sin(phi) * rad(0));
  }
  body.close();

  cv.drawPath(
    body.shift(const Offset(2, 3.4)),
    _pb(_al(_black, s.shadowA * .65), 1.7),
  );
  cv.save();
  cv.clipPath(body);
  cv.drawPath(
    body,
    _pg(
      _lin(
        at(.5) + up * 9,
        at(.5) - up * 9,
        const [Color(0xFFFFDC8C), Color(0xFFE8A64A), Color(0xFFB4682A)],
        const [0, .5, 1],
      ),
    ),
  );
  // Toasted patches and the lace between them.
  for (var i = 0; i < s.n(9, 20); i++) {
    final t = s.r(.05, .95);
    final p = at(t) + up * (s.r(-.85, .85) * rad(t));
    _at(cv, p, heading + s.r(-.4, .4), () {
      cv.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: s.r(6, 14),
          height: s.r(2, 5),
        ),
        _pf(_al(const Color(0xFF8E4B14), s.r(.2, .38))),
      );
    });
  }
  for (var i = 0; i < s.n(8, 28); i++) {
    final t = s.r(.03, .97);
    final p = at(t) + up * (s.r(-.9, .9) * rad(t));
    cv.drawCircle(p, s.r(.3, .7), _pf(_al(const Color(0xFFFFE6A0), .4)));
  }
  // The overlapping edge of the roll.
  final seamA = at(.12) + up * (rad(.12) * .1);
  final seamB = at(.95) - up * (rad(.95) * .45);
  final seam = Path()
    ..moveTo(seamA.dx, seamA.dy)
    ..quadraticBezierTo(at(.55).dx, at(.55).dy - 3.5, seamB.dx, seamB.dy);
  cv.drawPath(seam, _ps(_al(const Color(0xFF8A4A16), .5), .8));
  cv.drawPath(
    seam.shift(const Offset(0, .8)),
    _ps(_al(const Color(0xFFFFE9B0), .5), .6),
  );
  // Ghee sheen along the top.
  final sheenA = at(.1) + up * (rad(.1) * .55);
  final sheenB = at(.92) + up * (rad(.92) * .6);
  cv.drawLine(sheenA, sheenB, _ps(_al(s.spec, .5), 1.7, blur: 1));
  cv.restore();

  // The open end, with the potato filling showing.
  _at(cv, b, heading, () {
    final r1 = rad(1);
    final mouth = Rect.fromCenter(
      center: Offset.zero,
      width: 5.4,
      height: r1 * 2,
    );
    cv.drawOval(mouth, _pf(const Color(0xFFA5611F)));
    cv.drawOval(mouth, _ps(_al(const Color(0xFFFFE3A0), .6), .6));
    final fill = Rect.fromCenter(
      center: const Offset(.4, 0),
      width: 3.6,
      height: r1 * 2 - 3.4,
    );
    cv.drawOval(
      fill,
      _pg(
        _lin(fill.topLeft, fill.bottomRight, const [
          Color(0xFFFBD65A),
          Color(0xFFE9A92A),
        ]),
      ),
    );
    for (var i = 0; i < s.n(4, 8); i++) {
      cv.drawCircle(
        Offset(s.r(-1, 1.6), s.r(-r1 * .7, r1 * .7)),
        s.r(.25, .55),
        _pf(i % 3 == 0 ? const Color(0xFF4E9A3A) : const Color(0xFF6A3A0A)),
      );
    }
  });
  // A little filling that has tumbled onto the plate.
  final spill = _blob(
    s.rnd,
    b + d * 4.5 + const Offset(1, 5.4),
    3.2,
    2,
    n: 7,
    wob: .25,
  );
  cv.drawPath(
    spill.shift(const Offset(.6, 1)),
    _pb(_al(_black, s.shadowA * .5), .8),
  );
  cv.drawPath(
    spill,
    _pg(
      _lin(b + const Offset(0, 3), b + const Offset(5, 8), const [
        Color(0xFFFBD65A),
        Color(0xFFD99A22),
      ]),
    ),
  );
  _spark(s, at(.28) + up * (rad(.28) * .55), .7, a: .7);
}

void _rotiStack(_Scene s) {
  final cv = s.canvas;
  final seeds = s.any(['naan', 'kulcha']);
  const discs = [
    (Offset(47, 64.5), 29.0),
    (Offset(51, 60.5), 29.5),
    (Offset(48.5, 56.5), 29.0),
  ];
  // Where the top bread has blistered: x and y as shares of the radius,
  // then the size and the turn. Uneven on purpose.
  const blisters = [
    (-.52, -.12, 4.6, .4),
    (.05, -.42, 3.0, -.5),
    (.46, .08, 4.2, .2),
    (-.2, .4, 3.2, -.3),
    (-.68, .3, 2.2, .6),
    (.64, -.32, 2.6, -.7),
    (.24, .5, 2.0, .1),
  ];
  for (var i = 0; i < discs.length; i++) {
    final (dc, r0) = discs[i];
    const thick = 2.4;
    final side = Path()
      ..moveTo(dc.dx - r0, dc.dy)
      ..lineTo(dc.dx - r0, dc.dy + thick)
      ..arcTo(_ell(Offset(dc.dx, dc.dy + thick), r0), math.pi, -math.pi, false)
      ..lineTo(dc.dx + r0, dc.dy)
      ..close();
    cv.drawPath(
      side.shift(const Offset(1.6, 2.2)),
      _pb(_al(_black, s.shadowA * .55), 1.5),
    );
    cv.drawPath(
      side,
      _pg(
        _lin(Offset(dc.dx - r0, 0), Offset(dc.dx + r0, 0), const [
          Color(0xFFE6B766),
          Color(0xFFA9712C),
        ]),
      ),
    );
    final top = _ell(dc, r0);
    cv.drawOval(
      top,
      _pg(
        _rad(
          dc + const Offset(-9, -3),
          r0 * 1.5,
          const [Color(0xFFF7DA98), Color(0xFFE1AA55), Color(0xFFB57B34)],
          st: const [0, .6, 1],
          tilt: _kTilt,
        ),
      ),
    );
    if (i < 2) continue;
    for (final (fx, fy, w, turn) in blisters) {
      final p = dc + Offset(fx * r0, fy * r0 * _kTilt);
      _at(cv, p, turn, () {
        final spot = Rect.fromCenter(
          center: Offset.zero,
          width: w * (s.detail > .2 ? 1 : .8),
          height: w * .42,
        );
        cv.drawOval(spot.inflate(.7), _ps(_al(const Color(0xFFD2802E), .5), 1));
        cv.drawOval(spot, _pf(_al(const Color(0xFF4E2A0E), .78)));
      });
    }
    for (var j = 0; j < s.n(0, 9); j++) {
      final p = _inEll(s.rnd, dc, r0, r0 * _kTilt, .78);
      _at(cv, p, s.r(-1, 1), () {
        cv.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: s.r(1.2, 2.4),
            height: .8,
          ),
          _pf(_al(const Color(0xFF6B3A12), .6)),
        );
      });
    }
  }
  const dc = Offset(48.5, 56.5);
  if (seeds) {
    cv.drawPoints(ui.PointMode.points, [
      for (var i = 0; i < s.n(8, 36); i++)
        _inEll(s.rnd, dc, 26, 26 * _kTilt, .9),
    ], _ps(_al(const Color(0xFF2A1A0C), .8), .7));
  }
  _gloss(s, dc + const Offset(-10, -3), 9, 2.2, rot: -.15, a: .35);
  // A pat of butter melting a little off the centre.
  cv.drawOval(
    Rect.fromCenter(
      center: dc + const Offset(2.5, 1.6),
      width: 15,
      height: 6.4,
    ),
    _pb(_al(const Color(0xFFFFE29A), .6), 1),
  );
  final pat = Rect.fromCenter(
    center: dc + const Offset(2, 0),
    width: 6.8,
    height: 4.4,
  );
  cv.drawRRect(
    RRect.fromRectAndRadius(
      pat.shift(const Offset(.6, 1.1)),
      const Radius.circular(1),
    ),
    _pb(_al(const Color(0xFF7A4A0A), .5), .7),
  );
  cv.drawRRect(
    RRect.fromRectAndRadius(pat, const Radius.circular(1)),
    _pg(
      _lin(pat.topLeft, pat.bottomRight, const [
        Color(0xFFFFF6C4),
        Color(0xFFF1CB58),
      ]),
    ),
  );
  _spark(s, pat.topLeft + const Offset(1.4, 1), .6, a: .8);
}

// ──────────────────────────── handheld ────────────────────────────

class _Layer {
  const _Layer(this.kind, this.th, this.rx, this.lit, this.mid, this.dark);
  final String kind;
  final double th, rx;
  final Color lit, mid, dark;
}

/// The y of the front edge of a puck of radius [rx] centred at ([cx], [yc]) at x.
double _arcY(double x, double cx, double yc, double rx) {
  final k = ((x - cx) / rx).clamp(-1.0, 1.0);
  return yc + rx * _kTilt * math.sqrt(1 - k * k);
}

void _handheld(_Scene s) {
  if (s.any([
    'wrap',
    'roll',
    'frankie',
    'kathi',
    'shawarma',
    'burrito',
    'taco',
  ])) {
    _wrap(s);
    return;
  }
  final cv = s.canvas;
  final pav = s.any(['pav', 'vada']);
  const cx = 50.0;
  _ground(s, const Offset(50, 69.6), 41);
  _plate(s, const Offset(50, 67), 41, 2.6, _slate, well: .86);

  final bunTones = pav
      ? const [Color(0xFFF8DCA6), Color(0xFFE6B66E), Color(0xFFB98242)]
      : const [Color(0xFFF3C675), Color(0xFFD89B46), Color(0xFF9A6026)];
  final layers = pav
      ? <_Layer>[
          _Layer('bun', 7, 28.5, bunTones[0], bunTones[1], bunTones[2]),
          const _Layer(
            'chutney',
            1.4,
            27,
            Color(0xFF8CCB4A),
            Color(0xFF68AE38),
            Color(0xFF3F7A26),
          ),
          const _Layer(
            'vada',
            9,
            25,
            Color(0xFFF2B957),
            Color(0xFFD58C2E),
            Color(0xFF8E5018),
          ),
          const _Layer(
            'chutney',
            1.2,
            24,
            Color(0xFFE2503A),
            Color(0xFFC8321C),
            Color(0xFF86200F),
          ),
        ]
      : <_Layer>[
          _Layer('bun', 7, 28.5, bunTones[0], bunTones[1], bunTones[2]),
          const _Layer(
            'patty',
            6.5,
            29.5,
            Color(0xFF8A5434),
            Color(0xFF5E3018),
            Color(0xFF2A1208),
          ),
          const _Layer(
            'cheese',
            1.8,
            30.5,
            Color(0xFFFFDA5A),
            Color(0xFFF2B01E),
            Color(0xFFC07E0C),
          ),
          const _Layer(
            'tomato',
            3.2,
            28.5,
            Color(0xFFF0583E),
            Color(0xFFD6361F),
            Color(0xFF9A200F),
          ),
          const _Layer(
            'lettuce',
            3.2,
            31.5,
            Color(0xFFB4DE6A),
            Color(0xFF72B83C),
            Color(0xFF3F8A28),
          ),
        ];

  var yTop = 58.0;
  // Soft shadow of the stack on the plate.
  cv.drawOval(
    _ell(const Offset(52.5, 67.4), 29.5),
    _pb(_al(_black, s.shadowA * .75), 1.8),
  );
  for (var i = 0; i < layers.length; i++) {
    final l = layers[i];
    if (i > 0) yTop -= l.th;
    final front = Path()
      ..moveTo(cx - l.rx, yTop)
      ..lineTo(cx - l.rx, yTop + l.th)
      ..arcTo(_ell(Offset(cx, yTop + l.th), l.rx), math.pi, -math.pi, false)
      ..lineTo(cx + l.rx, yTop)
      ..arcTo(_ell(Offset(cx, yTop), l.rx), 0, math.pi, false)
      ..close();
    if (l.kind == 'lettuce') {
      // A ruffled green frill that overhangs the bun.
      final frill = Path()..moveTo(cx - l.rx, yTop);
      for (var x = cx - l.rx; x <= cx + l.rx; x += 1.5) {
        frill.lineTo(x, _arcY(x, cx, yTop, l.rx));
      }
      for (var x = cx + l.rx; x >= cx - l.rx; x -= 1.5) {
        frill.lineTo(
          x,
          _arcY(x, cx, yTop + l.th, l.rx) + 1.5 * math.sin(x * .8 + 1),
        );
      }
      frill.close();
      cv.drawPath(
        frill,
        _pg(
          _lin(
            Offset(cx - l.rx, 0),
            Offset(cx + l.rx, 0),
            [l.lit, l.mid, l.dark],
            const [0, .5, 1],
          ),
        ),
      );
      cv.drawPath(frill, _ps(_al(const Color(0xFFD9F0A0), .55), .5));
    } else {
      cv.drawPath(
        front,
        _pg(
          _lin(
            Offset(cx - l.rx, 0),
            Offset(cx + l.rx, 0),
            [l.lit, l.mid, l.dark],
            const [0, .46, 1],
          ),
        ),
      );
      cv.drawPath(
        front,
        _pg(
          _lin(Offset(0, yTop), Offset(0, yTop + l.th + 13), [
            _al(_black, 0),
            _al(_black, .18),
          ]),
        ),
      );
    }
    if (l.kind == 'patty' || l.kind == 'vada') {
      cv.save();
      cv.clipPath(front);
      for (var j = 0; j < s.n(10, 30); j++) {
        final x = s.r(cx - l.rx + 1, cx + l.rx - 1);
        final y = _arcY(x, cx, yTop, l.rx) + s.r(0, l.th);
        cv.drawCircle(
          Offset(x, y),
          s.r(.3, .8),
          _pf(
            _al(
              j.isEven ? l.lit : _lo(l.dark, .3),
              l.kind == 'vada' ? .7 : .55,
            ),
          ),
        );
      }
      cv.restore();
    }
    if (l.kind == 'cheese') {
      for (final (x, w, h) in const [
        (30.0, 5.0, 6.0),
        (60.0, 4.2, 4.6),
        (44.0, 3.4, 3.2),
      ]) {
        final y = _arcY(x, cx, yTop + l.th, l.rx) - .4;
        final drip = Path()
          ..moveTo(x - w / 2, y)
          ..quadraticBezierTo(x - w / 2, y + h * .8, x, y + h)
          ..quadraticBezierTo(x + w / 2, y + h * .8, x + w / 2, y)
          ..close();
        cv.drawPath(
          drip,
          _pg(_lin(Offset(x, y), Offset(x, y + h), [l.mid, l.dark])),
        );
      }
    }
    if (l.kind == 'bun' || l.kind == 'patty' || l.kind == 'tomato') {
      cv.drawArc(
        _ell(Offset(cx, yTop), l.rx),
        math.pi * .08,
        math.pi * .84,
        false,
        _ps(_al(l.lit, .6), .6),
      );
    }
  }

  // The top bun: a glossy dome with sesame.
  final topRx = pav ? 28.0 : 28.5;
  final rise = pav ? 18.0 : 22.0;
  final base = Offset(cx, yTop);
  final dome = Path()
    ..moveTo(cx - topRx, base.dy)
    ..cubicTo(
      cx - topRx - 1,
      base.dy - rise * .75,
      cx - topRx * .55,
      base.dy - rise,
      cx,
      base.dy - rise,
    )
    ..cubicTo(
      cx + topRx * .55,
      base.dy - rise,
      cx + topRx + 1,
      base.dy - rise * .75,
      cx + topRx,
      base.dy,
    )
    ..arcTo(_ell(base, topRx), 0, math.pi, false)
    ..close();
  cv.drawPath(
    dome.shift(const Offset(.6, 1.2)),
    _pb(_al(_black, s.shadowA * .4), 1),
  );
  cv.drawPath(
    dome,
    _pg(
      _rad(
        Offset(cx - 11, base.dy - rise * .6),
        topRx * 1.5,
        pav
            ? const [Color(0xFFFFE6B8), Color(0xFFE9BA72), Color(0xFFB07A3E)]
            : const [Color(0xFFF9CF84), Color(0xFFD9964A), Color(0xFF9B5A25)],
        st: const [0, .55, 1],
      ),
    ),
  );
  cv.save();
  cv.clipPath(dome);
  final b = dome.getBounds();
  var seeds = 0;
  final want = pav ? s.n(8, 30) : s.n(10, 30);
  for (var tries = 0; seeds < want && tries < want * 6; tries++) {
    final p = Offset(
      b.left + s.rnd.nextDouble() * b.width,
      b.top + s.rnd.nextDouble() * b.height,
    );
    if (!dome.contains(p)) continue;
    seeds++;
    _at(cv, p, s.r(-1, 1), () {
      if (pav) {
        cv.drawCircle(
          Offset.zero,
          s.r(.3, .6),
          _pf(_al(const Color(0xFFFFFAEE), .6)),
        );
      } else {
        cv.drawOval(
          Rect.fromCenter(
            center: const Offset(.3, .5),
            width: 2.2,
            height: 1.2,
          ),
          _pf(_al(const Color(0xFF8A5A22), .55)),
        );
        cv.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 2.2, height: 1.2),
          _pf(const Color(0xFFFFF1CC)),
        );
      }
    });
  }
  cv.drawPath(
    dome,
    _pg(
      _lin(
        Offset(cx - 20, base.dy - rise),
        Offset(cx + 30, base.dy + 4),
        [_al(const Color(0xFF3A1E06), 0), _al(const Color(0xFF3A1E06), .3)],
        const [.45, 1],
      ),
    ),
  );
  cv.restore();
  _gloss(s, Offset(cx - 11, base.dy - rise * .72), 10, 2.4, rot: -.45, a: .5);
  _rim(
    s,
    _ell(base, topRx),
    mid: 1.18 * math.pi,
    span: .5 * math.pi,
    w: .8,
    a: .7,
  );

  if (pav) {
    // A fried green chilli on the side.
    final chili = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(6, -3.2, 13, 1.2);
    _at(cv, const Offset(70, 74), -.1, () {
      cv.drawPath(
        chili.shift(const Offset(.6, 1.4)),
        _ps(_al(_black, s.shadowA * .5), 2.6, blur: .7),
      );
      cv.drawPath(chili, _ps(const Color(0xFF6B9A2C), 2.6));
      cv.drawPath(
        chili.shift(const Offset(-.2, -.6)),
        _ps(const Color(0xFFB4D870), .8),
      );
      cv.drawCircle(Offset.zero, 1.2, _pf(const Color(0xFF3E5C18)));
    });
  }
}

/// A roll or wrap: foil round one half, tortilla and filling at the open end.
void _wrap(_Scene s) {
  final cv = s.canvas;
  _ground(s, const Offset(50, 69.6), 41);
  _plate(s, const Offset(50, 67), 41, 2.6, _slate, well: .86);
  const a = Offset(19, 66);
  const b = Offset(81, 44);
  final span = b - a;
  final d = span / span.distance;
  final up = Offset(d.dy, -d.dx);
  final heading = math.atan2(d.dy, d.dx);
  const r0 = 10.0;
  Offset at(double t) => a + span * t;
  Path slab(double t0, double t1) {
    final p0 = at(t0);
    final p1 = at(t1);
    return Path()
      ..moveTo((p0 + up * r0).dx, (p0 + up * r0).dy)
      ..lineTo((p1 + up * r0).dx, (p1 + up * r0).dy)
      ..lineTo((p1 - up * r0).dx, (p1 - up * r0).dy)
      ..lineTo((p0 - up * r0).dx, (p0 - up * r0).dy)
      ..close();
  }

  final whole = slab(0, 1);
  cv.drawPath(
    whole.shift(const Offset(2.4, 3.6)),
    _pb(_al(_black, s.shadowA * .65), 1.8),
  );
  // The tortilla, charred in places.
  final roll = slab(.42, 1);
  cv.drawPath(
    roll,
    _pg(
      _lin(
        at(.7) + up * r0,
        at(.7) - up * r0,
        const [Color(0xFFF6DBA4), Color(0xFFE0B672), Color(0xFFA97A3A)],
        const [0, .5, 1],
      ),
    ),
  );
  cv.save();
  cv.clipPath(roll);
  for (var i = 0; i < s.n(5, 12); i++) {
    final t = s.r(.45, .98);
    final p = at(t) + up * (s.r(-.8, .8) * r0);
    _at(cv, p, heading + s.r(-.5, .5), () {
      cv.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: s.r(3, 7),
          height: s.r(1.4, 3),
        ),
        _pf(_al(const Color(0xFF8A5A22), s.r(.35, .6))),
      );
    });
  }
  cv.drawLine(
    at(.5) + up * (r0 * .62),
    at(.97) + up * (r0 * .66),
    _ps(_al(s.spec, .45), 1.6, blur: .9),
  );
  cv.restore();
  // Foil wrapped round the near half, with a torn edge and crinkles.
  final foil = slab(0, .52);
  cv.drawPath(
    foil,
    _pg(
      _lin(
        at(.25) + up * r0,
        at(.25) - up * r0,
        const [Color(0xFFFFFFFF), Color(0xFFC9CED6), Color(0xFF858D98)],
        const [0, .5, 1],
      ),
    ),
  );
  cv.save();
  cv.clipPath(foil);
  for (var i = 0; i < s.n(5, 14); i++) {
    final p = at(s.r(.02, .5)) + up * (s.r(-.9, .9) * r0);
    final q = p + Offset(s.r(-3, 3), s.r(-3, 3));
    cv.drawLine(
      p,
      q,
      _ps(_al(i.isEven ? _black : const Color(0xFFFFFFFF), .22), .45),
    );
  }
  cv.restore();
  final tear = Path();
  for (var k = 0; k <= 6; k++) {
    final p = at(.52 + (k.isEven ? .02 : -.015)) + up * (r0 - k * (2 * r0 / 6));
    k == 0 ? tear.moveTo(p.dx, p.dy) : tear.lineTo(p.dx, p.dy);
  }
  cv.drawPath(tear, _ps(_al(_black, .3), .6));
  // The open end, filling showing.
  _at(cv, b, heading, () {
    final mouth = Rect.fromCenter(
      center: Offset.zero,
      width: 6,
      height: r0 * 2,
    );
    cv.drawOval(mouth, _pf(const Color(0xFFC79A55)));
    final inner = mouth.deflate(.9);
    cv.save();
    cv.clipPath(Path()..addOval(inner));
    cv.drawRect(inner, _pf(const Color(0xFF8A5A2A)));
    for (var i = 0; i < 4; i++) {
      cv.drawArc(
        Rect.fromCenter(
          center: Offset(s.r(-1, 1), -r0 * .55 + i * 4.2),
          width: 4.4,
          height: 3.6,
        ),
        math.pi * .2,
        math.pi * 1.1,
        false,
        _ps(i.isEven ? const Color(0xFF7DC043) : const Color(0xFF5FA32E), 1.5),
      );
    }
    cv.drawCircle(const Offset(.4, -2), 1.4, _pf(const Color(0xFFB45A8E)));
    cv.drawCircle(const Offset(-.4, 3), 1.6, _pf(const Color(0xFF8E4B20)));
    cv.drawCircle(const Offset(.6, 6), 1.2, _pf(const Color(0xFFD99A4A)));
    cv.drawLine(
      const Offset(-1.2, -5),
      const Offset(1.4, 7),
      _ps(_al(const Color(0xFFFFF4E0), .8), 1),
    );
    cv.restore();
  });
  _spark(s, at(.3) + up * (r0 * .5), .8, a: .8);
}

// ───────────────────────────── cake ─────────────────────────────

void _cake(_Scene s) {
  final cv = s.canvas;
  final tira = s.any(['tiramisu']);
  final cheese = s.any(['cheesecake', 'cheese cake']);
  final tart = !tira && !cheese && s.any(['tart', 'fig', 'pie']);
  const plateC = Offset(50, 67);
  _ground(s, Offset(50, plateC.dy + 3), 40);
  _plate(s, plateC, 40, 3, _cream, well: .78);

  // Layers from the bottom: (from, to, colour) as shares of the height.
  const sponge = Color(0xFF5C2E1A);
  const cream = Color(0xFFF8E6C4);
  final layers = tira
      ? const [
          (0.0, .2, Color(0xFFC9965C)),
          (.2, .45, Color(0xFFFFF1D0)),
          (.45, .62, Color(0xFFC9965C)),
          (.62, .93, Color(0xFFFFF1D0)),
          (.93, 1.0, Color(0xFF5A3418)),
        ]
      : cheese
      ? const [
          (0.0, .17, Color(0xFFB27A38)),
          (.17, .8, Color(0xFFFFF0CC)),
          (.8, 1.0, Color(0xFFD2324A)),
        ]
      : tart
      ? const [
          (0.0, .28, Color(0xFFD9A257)),
          (.28, .88, Color(0xFFF6DE9A)),
          (.88, 1.0, Color(0xFFE9B04A)),
        ]
      : const [
          (0.0, .23, sponge),
          (.23, .31, cream),
          (.31, .54, sponge),
          (.54, .62, cream),
          (.62, .84, sponge),
          (.84, 1.0, Color(0xFF2C1109)),
        ];
  final topColor = tira
      ? const Color(0xFF6A4020)
      : cheese
      ? const Color(0xFFD9344C)
      : tart
      ? const Color(0xFFEDB955)
      : const Color(0xFF2C1109);

  const x0 = 22.0;
  const x1 = 60.0;
  const yb = 64.0;
  const hgt = 26.0;
  const dx = 14.0;
  const dy = -10.0;
  // Shadow of the slice on the plate.
  cv.drawPath(
    Path()
      ..moveTo(x0 + 2, yb + 1)
      ..lineTo(x1 + 4, yb + 1)
      ..lineTo(x1 + dx + 7, yb + dy + 5)
      ..lineTo(x0 + dx, yb + dy + 4)
      ..close(),
    _pb(_al(_black, s.shadowA * .6), 2),
  );
  for (final (v0, v1, col) in layers) {
    final ff = Rect.fromLTRB(x0, yb - v1 * hgt, x1, yb - v0 * hgt);
    cv.drawRect(ff, _pf(col));
    final rf = Path()
      ..moveTo(x1, yb - v0 * hgt)
      ..lineTo(x1 + dx, yb - v0 * hgt + dy)
      ..lineTo(x1 + dx, yb - v1 * hgt + dy)
      ..lineTo(x1, yb - v1 * hgt)
      ..close();
    cv.drawPath(rf, _pf(_lo(col, .42)));
    final light = col.computeLuminance() > .5;
    if (light && v1 < .99) {
      cv.drawLine(
        Offset(x0, yb - v1 * hgt + .5),
        Offset(x1, yb - v1 * hgt + .5),
        _ps(_al(const Color(0xFFFFFFFF), .6), .5),
      );
    }
    if (!light && s.detail > .2) {
      cv.save();
      cv.clipRect(ff);
      for (var i = 0; i < s.n(6, 34); i++) {
        cv.drawCircle(
          Offset(s.r(x0, x1), s.r(ff.top, ff.bottom)),
          s.r(.25, .55),
          _pf(_al(i.isEven ? _hi(col, .5) : _lo(col, .5), .55)),
        );
      }
      cv.restore();
    }
  }
  // Light across the cut face, a deeper shade into the corner.
  cv.drawRect(
    const Rect.fromLTRB(x0, yb - hgt, x1, yb),
    _pg(
      _lin(const Offset(x0, yb - hgt), const Offset(x1, yb), [
        _al(s.spec, .16),
        _al(_black, .2),
      ]),
    ),
  );
  // The top face.
  final top = Path()
    ..moveTo(x0, yb - hgt)
    ..lineTo(x0 + dx, yb - hgt + dy)
    ..lineTo(x1 + dx, yb - hgt + dy)
    ..lineTo(x1, yb - hgt)
    ..close();
  cv.drawPath(
    top,
    _pg(
      _lin(const Offset(x0, yb - hgt + dy), const Offset(x1 + dx, yb - hgt), [
        _hi(topColor, .18),
        topColor,
      ]),
    ),
  );
  if (!tira) {
    _gloss(s, const Offset(40, 31.5), 8, 1.1, rot: -.4, a: .3);
  }
  // Cocoa dust over the top and the plate.
  if (tira || !cheese) {
    final dust = <Offset>[
      for (var i = 0; i < s.n(20, 80); i++)
        () {
          final u = s.rnd.nextDouble();
          final v = s.rnd.nextDouble();
          return Offset(x0 + u * (x1 - x0) + v * dx, yb - hgt + v * dy);
        }(),
    ];
    cv.drawPoints(
      ui.PointMode.points,
      dust,
      _ps(_al(const Color(0xFF3A1C0A), tira ? .6 : .45), .6),
    );
    cv.drawPoints(ui.PointMode.points, [
      for (var i = 0; i < s.n(6, 36); i++)
        _inEll(s.rnd, const Offset(70, 73), 14, 5.5),
    ], _ps(_al(const Color(0xFF3A1C0A), .45), .6));
  }
  // The berry, or a fig half on the tart.
  if (tart) {
    _at(cv, const Offset(46, 31.5), -.3, () {
      final fig = Rect.fromCenter(center: Offset.zero, width: 11, height: 7.4);
      cv.drawOval(
        fig.shift(const Offset(.6, 1.2)),
        _pb(_al(_black, s.shadowA * .5), .8),
      );
      cv.drawOval(fig, _pf(const Color(0xFF6B2A4E)));
      cv.drawOval(
        fig.deflate(1.1),
        _pg(
          _rad(const Offset(-1, -.6), 5.2, const [
            Color(0xFFF7B7BE),
            Color(0xFFE0708A),
            Color(0xFF9A3A58),
          ]),
        ),
      );
      for (var i = 0; i < s.n(5, 9); i++) {
        cv.drawCircle(
          _inEll(s.rnd, Offset.zero, 3.6, 2.2),
          .32,
          _pf(_al(const Color(0xFFFFE9A8), .9)),
        );
      }
    });
    _spark(s, const Offset(43, 29.8), .7, a: .8);
  } else {
    const bc = Offset(44, 31.2);
    _herbLeaf(s, const Offset(45.5, 29.8), -.5, 6.6);
    cv.drawOval(
      _ell(bc + const Offset(1.4, 3.2), 4.8),
      _pb(_al(_black, s.shadowA * .55), .9),
    );
    cv.drawCircle(
      bc,
      4.4,
      _pg(
        _rad(
          bc + const Offset(-1.4, -1.6),
          6.2,
          const [Color(0xFFF56E86), Color(0xFFD72A4A), Color(0xFF8E1230)],
          st: const [0, .55, 1],
        ),
      ),
    );
    for (var i = 0; i < s.n(7, 12); i++) {
      final p = _inEll(s.rnd, bc, 3.6, 3.6, .95);
      cv.drawCircle(p, s.r(.8, 1.1), _pf(_al(const Color(0xFFFF9AAA), .35)));
      cv.drawCircle(
        p + const Offset(-.25, -.3),
        .3,
        _pf(_al(const Color(0xFFFFE4EA), .75)),
      );
    }
    _spark(s, bc + const Offset(-1.6, -1.8), .7, a: .8);
  }
  if (tira) {
    for (final p in const [Offset(23, 73), Offset(30, 77.5)]) {
      _at(s.canvas, p, p.dx > 25 ? .5 : -.6, () {
        final bean = Rect.fromCenter(
          center: Offset.zero,
          width: 4.6,
          height: 3.2,
        );
        cv.drawOval(
          bean.shift(const Offset(.5, .9)),
          _pb(_al(_black, s.shadowA * .5), .6),
        );
        cv.drawOval(bean, _pf(const Color(0xFF3A2010)));
        cv.drawLine(
          const Offset(-1.8, 0),
          const Offset(1.8, 0),
          _ps(_al(_black, .8), .45),
        );
        cv.drawOval(
          Rect.fromCenter(
            center: const Offset(-.8, -.7),
            width: 1.6,
            height: .8,
          ),
          _pf(_al(s.spec, .6)),
        );
      });
    }
  } else if (!cheese) {
    // A swoosh of chocolate sauce across the front of the plate.
    final pts = <Offset>[
      for (var i = 0; i <= 18; i++)
        Offset(
          19 + i * 1.5,
          75 - 3.2 * math.sin(i / 18 * math.pi * 1.4) + (i / 18) * 2.4,
        ),
    ];
    final swoosh = _ribbon(
      pts,
      (t) => 2.1 * math.sin(math.pi * (t * .86 + .08)) + .3,
    );
    cv.drawPath(
      swoosh.shift(const Offset(.4, .8)),
      _pb(_al(_black, s.shadowA * .4), .6),
    );
    cv.drawPath(swoosh, _pf(const Color(0xFF3A1A0C)));
    cv.drawLine(
      const Offset(25, 74.1),
      const Offset(38, 73.4),
      _ps(_al(s.spec, .5), .5),
    );
  }
}

// ───────────────────────────── sweet ─────────────────────────────

void _sweet(_Scene s) {
  final cv = s.canvas;
  final milk = s.any(['rasgulla', 'rasmalai']);
  final scoop = s.any(['ice cream', 'icecream', 'kulfi', 'sundae', 'gelato']);
  const c = Offset(50, 52);
  _ground(s, const Offset(52, 78), 28);
  final g = _bowl(s, c, 34, 21, _cream, foot: .62, wall: 2.4);
  // A fine gold line round the lip and the wall.
  const gold = [Color(0xFFF6D77C), Color(0xFFC99A3C), Color(0xFF7A5418)];
  cv.drawOval(
    g.rim,
    _ps(_black, .9)
      ..shader = _lin(Offset(c.dx - 34, 0), Offset(c.dx + 34, 0), gold, const [
        0,
        .5,
        1,
      ]),
  );
  cv.drawArc(
    _ell(Offset(c.dx, c.dy + 4.6), 33),
    .04,
    math.pi - .08,
    false,
    _ps(_black, .9, cap: StrokeCap.butt)
      ..shader = _lin(Offset(c.dx - 34, 0), Offset(c.dx + 34, 0), gold, const [
        0,
        .5,
        1,
      ]),
  );

  // The pool the sweets sit in.
  final pool = milk
      ? const [Color(0xFFFFF7DE), Color(0xFFF5E1AE), Color(0xFFD2B572)]
      : scoop
      ? const [Color(0xFFFFF5E0), Color(0xFFF1DFBA), Color(0xFFC4AE86)]
      : const [Color(0xFFF9C25C), Color(0xFFDE8E20), Color(0xFF98580C)];
  cv.save();
  cv.clipPath(g.holePath);
  final surf = _ell(const Offset(50, 54), 30.4);
  cv.drawOval(
    surf,
    _pg(
      _rad(const Offset(40, 50), 38, pool, st: const [0, .55, 1], tilt: _kTilt),
    ),
  );
  cv.drawOval(surf, _ps(_al(pool[2], .6), 1.2, blur: .6));
  cv.drawArc(
    _ell(const Offset(50, 54), 25),
    math.pi * 1.05,
    math.pi * .36,
    false,
    _ps(_al(s.spec, .5), 1.4, blur: .8),
  );
  cv.restore();

  if (scoop) {
    _scoops(s);
    return;
  }

  // Five spheres in a small heap: back pair, one on top, front pair.
  const spots = [
    (Offset(40, 48.5), 8.8),
    (Offset(60, 48), 8.8),
    (Offset(50, 39.5), 8.6),
    (Offset(41, 56.5), 9.2),
    (Offset(59, 56.5), 9.2),
  ];
  for (var i = 0; i < spots.length; i++) {
    final (p, r0) = spots[i];
    final base = milk ? const Color(0xFFF1E6CE) : const Color(0xFF7A3216);
    final hl = milk ? _hi(base, .6) : const Color(0xFFC87240);
    final dk = milk ? _lo(base, .42) : const Color(0xFF36120A);
    cv.drawOval(
      _ell(p + Offset(2.4, r0 * .8), r0 * 1.02),
      _pb(
        _al(milk ? const Color(0xFF6A4A1A) : const Color(0xFF4A2204), .55),
        1.3,
      ),
    );
    cv.drawCircle(
      p,
      r0,
      _pg(
        _rad(
          p + Offset(-r0 * .38, -r0 * .42),
          r0 * 1.7,
          [hl, base, dk],
          st: const [0, .5, 1],
        ),
      ),
    );
    // The part sunk in syrup takes the syrup's colour.
    cv.drawCircle(
      p,
      r0,
      _pg(
        _lin(p + Offset(0, r0 * .05), p + Offset(0, r0), [
          _al(pool[1], 0),
          _al(pool[1], milk ? .5 : .62),
        ]),
      ),
    );
    for (var j = 0; j < s.n(0, 3); j++) {
      cv.drawCircle(
        p + Offset(s.r(-r0 * .6, r0 * .6), s.r(-r0 * .7, r0 * .2)),
        s.r(.2, .45),
        _pf(_al(dk, .5)),
      );
    }
    _gloss(
      s,
      p + Offset(-r0 * .38, -r0 * .45),
      r0 * .42,
      r0 * .2,
      rot: -.55,
      a: .85,
    );
    _spark(s, p + Offset(-r0 * .5, -r0 * .58), r0 * .09 + .3, a: .9);
  }

  // Pistachio, saffron and a rose petal over the top.
  for (var i = 0; i < s.n(5, 8); i++) {
    final (p, r0) = spots[i % 3 == 0 ? 2 : i % 4];
    final q = p + Offset(s.r(-r0 * .7, r0 * .7), s.r(-r0 * .9, r0 * .1));
    _at(cv, q, s.r(0, math.pi), () {
      cv.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 2.6, height: 1.05),
          const Radius.circular(.4),
        ),
        _pf(const Color(0xFF9BC34F)),
      );
      cv.drawLine(
        const Offset(-1, -.2),
        const Offset(.9, -.2),
        _ps(_al(const Color(0xFFD6EB9C), .8), .3),
      );
    });
  }
  for (var i = 0; i < s.n(2, 3); i++) {
    final p = const Offset(50, 36) + Offset(s.r(-4, 4), s.r(-2, 2));
    final path = Path()
      ..moveTo(p.dx, p.dy)
      ..quadraticBezierTo(
        p.dx + s.r(-2, 2),
        p.dy + 2.4,
        p.dx + s.r(-3, 3),
        p.dy + 4.6,
      );
    cv.drawPath(path, _ps(const Color(0xFFE8571C), .45));
  }
  _at(cv, const Offset(61, 42.6), -.5, () {
    final petal = Rect.fromCenter(center: Offset.zero, width: 4.4, height: 2.6);
    cv.drawOval(petal.shift(const Offset(.3, .6)), _pb(_al(_black, .35), .5));
    cv.drawOval(
      petal,
      _pg(
        _lin(petal.topLeft, petal.bottomRight, const [
          Color(0xFFF59AB4),
          Color(0xFFC94A72),
        ]),
      ),
    );
  });
}

/// Ice cream: three scoops with a cherry, a wafer and a thread of chocolate.
void _scoops(_Scene s) {
  final cv = s.canvas;
  // A wafer stood behind the scoops.
  _at(cv, const Offset(70, 37), .5, () {
    final w = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 5.4, height: 19),
      const Radius.circular(.8),
    );
    cv.drawRRect(w.shift(const Offset(.8, 1)), _pb(_al(_black, .35), .6));
    cv.drawRRect(
      w,
      _pg(
        _lin(const Offset(-3, -9), const Offset(3, 9), const [
          Color(0xFFF3D49A),
          Color(0xFFC99650),
        ]),
      ),
    );
    for (var k = -3; k <= 3; k++) {
      cv.drawLine(
        Offset(-2.4, k * 2.6),
        Offset(2.4, k * 2.6 + 1.4),
        _ps(_al(const Color(0xFF8A5A22), .5), .4),
      );
    }
  });
  // Vanilla on top, strawberry and chocolate in front.
  const scoops = [
    (Offset(50.5, 41), 10.6, Color(0xFFFFEFC6)),
    (Offset(40.5, 52.5), 9.8, Color(0xFFF4A3B5)),
    (Offset(60.5, 53), 9.2, Color(0xFF7D4B2F)),
  ];
  for (var i = 0; i < scoops.length; i++) {
    final (p, r0, base) = scoops[i];
    cv.drawOval(
      _ell(p + Offset(2.6, r0 * .78), r0 * 1.04),
      _pb(_al(const Color(0xFF6A4A1A), .5), 1.3),
    );
    // The ruffled foot of the scoop.
    cv.drawOval(
      _ell(p + Offset(0, r0 * .72), r0 * 1.05, .34),
      _pf(_lo(base, .16)),
    );
    cv.drawCircle(
      p,
      r0,
      _pg(
        _rad(
          p + Offset(-r0 * .36, -r0 * .42),
          r0 * 1.7,
          [_hi(base, .5), base, _lo(base, .36)],
          st: const [0, .5, 1],
        ),
      ),
    );
    for (var j = 0; j < s.n(3, 9); j++) {
      final q = _inEll(s.rnd, p + Offset(0, -r0 * .1), r0 * .8, r0 * .7);
      cv.drawCircle(
        q,
        s.r(.2, .42),
        _pf(_al(i == 2 ? _hi(base, .5) : _lo(base, .5), .55)),
      );
    }
    _gloss(
      s,
      p + Offset(-r0 * .4, -r0 * .48),
      r0 * .3,
      r0 * .12,
      rot: -.55,
      a: .2,
    );
  }
  // A thread of chocolate sauce over the top scoop.
  final thread = Path()..moveTo(43, 37.5);
  for (var i = 1; i <= 6; i++) {
    thread.lineTo(43 + i * 2.5, 37.5 + i * .5 + (i.isEven ? 0 : 2.8));
  }
  cv.drawPath(thread.shift(const Offset(.3, .6)), _ps(_al(_black, .25), 1.1));
  cv.drawPath(thread, _ps(const Color(0xFF3A1A0C), 1.1));
  // And a cherry.
  const cherry = Offset(50.8, 30.6);
  final stem = Path()
    ..moveTo(cherry.dx, cherry.dy - 2.6)
    ..quadraticBezierTo(
      cherry.dx + 1.6,
      cherry.dy - 8,
      cherry.dx + 6,
      cherry.dy - 9.4,
    );
  cv.drawPath(stem, _ps(const Color(0xFF5A7A2A), .7));
  cv.drawOval(
    _ell(cherry + const Offset(1.4, 3), 3.6),
    _pb(_al(_black, .35), .6),
  );
  cv.drawCircle(
    cherry,
    3.5,
    _pg(
      _rad(
        cherry + const Offset(-1.2, -1.2),
        5,
        const [Color(0xFFFF7A7A), Color(0xFFD2232E), Color(0xFF7E0F18)],
        st: const [0, .5, 1],
      ),
    ),
  );
  _spark(s, cherry + const Offset(-1.3, -1.4), .6, a: .9);
}

// ───────────────────────────── drink ─────────────────────────────

class _Kit {
  const _Kit({
    required this.top,
    required this.bottom,
    this.foam,
    this.layer,
    this.ice = false,
    this.fizz = false,
    this.mint = false,
    this.drizzle = false,
    this.straw = const Color(0xFFE05A3E),
    this.wheel,
  });
  final Color top, bottom, straw;
  final Color? foam, layer;
  final bool ice, fizz, mint, drizzle;
  final (Color, Color)? wheel;
}

const _kLime = _Kit(
  top: Color(0xFFEFF7A6),
  bottom: Color(0xFFAFD556),
  ice: true,
  fizz: true,
  mint: true,
  wheel: (Color(0xFF4E9A2C), Color(0xFFC6E27A)),
);
const _kCream = _Kit(
  top: Color(0xFFFFFBF0),
  bottom: Color(0xFFF1D9AE),
  foam: Color(0xFFFFFFFF),
  straw: Color(0xFFD94A6E),
);
const _kBerry = _Kit(
  top: Color(0xFFFBC2CF),
  bottom: Color(0xFFE0708A),
  foam: Color(0xFFFFF1F3),
  mint: true,
  straw: Color(0xFFFFFFFF),
);
const _kOrange = _Kit(
  top: Color(0xFFFFD473),
  bottom: Color(0xFFF0861C),
  ice: true,
  wheel: (Color(0xFFF08A1E), Color(0xFFFFC95A)),
);
const _kCola = _Kit(
  top: Color(0xFF7A4526),
  bottom: Color(0xFF2E1408),
  foam: Color(0xFFC9A27A),
  ice: true,
  fizz: true,
  wheel: (Color(0xFFE5B422), Color(0xFFFBE98A)),
  straw: Color(0xFFFFFFFF),
);
const _kCoffee = _Kit(
  top: Color(0xFFB07A48),
  bottom: Color(0xFF4E2A14),
  layer: Color(0xFFF1DDBA),
  foam: Color(0xFFFFF3DC),
  ice: true,
  drizzle: true,
  straw: Color(0xFF3A2A22),
);
const _kBeer = _Kit(
  top: Color(0xFFF8C93E),
  bottom: Color(0xFFD38A14),
  foam: Color(0xFFFFFBEA),
  fizz: true,
  straw: Color(0xFFFFFFFF),
);

void _drink(_Scene s) {
  final k = s.any(['coffee', 'frappe', 'chocolate', 'mocha', 'latte'])
      ? _kCoffee
      : s.any(['shake', 'smoothie', 'strawberry', 'berry', 'rose'])
      ? _kBerry
      : s.any(['lassi', 'buttermilk', 'chaas', 'milk', 'falooda', 'thandai'])
      ? _kCream
      : s.any(['orange', 'mango', 'juice', 'pineapple'])
      ? _kOrange
      : s.any(['cola', 'coke', 'pepsi', 'sprite'])
      ? _kCola
      : s.any(['beer'])
      ? _kBeer
      : _kLime;
  _glass(s, k);
}

void _glass(_Scene s, _Kit k) {
  final cv = s.canvas;
  const white = Color(0xFFFFFFFF);
  const baseC = Offset(50, 80);
  _ground(s, const Offset(50, 83.2), 19);
  // The coloured light the drink throws on the table.
  cv.drawOval(
    _ell(const Offset(69, 85.5), 15),
    _pb(_al(k.bottom, s.onDark ? .36 : .22), 2.6),
  );

  Path body(double rr, double br, double yTop, double yBot) => Path()
    ..moveTo(50 - rr, yTop)
    ..lineTo(50 - br, yBot)
    ..arcTo(_ell(Offset(50, yBot), br), math.pi, -math.pi, false)
    ..lineTo(50 + rr, yTop)
    ..arcTo(_ell(Offset(50, yTop), rr), 0, math.pi, false)
    ..close();
  double inner(double y) => 17.2 + (12.6 - 17.2) * (y - 22) / (75.5 - 22);

  final glass = body(18.5, 14.2, 22, 80);
  cv.drawPath(glass, _pf(_al(white, s.onDark ? .07 : .1)));
  // Faint back wall seen through the open top.
  cv.drawOval(_ell(const Offset(50, 22), 18.5), _pf(_al(white, .06)));

  final lv = k.foam != null ? 30.0 : 33.0;
  final rl = inner(lv);
  final liquid = body(rl, 12.6, lv, 75.5);
  cv.drawPath(
    liquid,
    _pg(
      _lin(Offset(0, lv), const Offset(0, 75.5), [
        _al(k.top, .94),
        _al(k.bottom, .96),
      ]),
    ),
  );
  cv.save();
  cv.clipPath(liquid);
  if (k.layer != null) {
    final band = Path()..moveTo(30, lv);
    for (var x = 30.0; x <= 70; x += 2) {
      band.lineTo(x, lv + 13 + 1.6 * math.sin(x * .35));
    }
    band
      ..lineTo(70, lv)
      ..close();
    cv.drawPath(
      band,
      _pg(
        _lin(Offset(0, lv), Offset(0, lv + 15), [
          _al(k.layer!, .96),
          _al(k.layer!, .7),
        ]),
      ),
    );
  }
  // Light falling through the drink: bright on the left, deep on the right.
  cv.drawRect(
    const Rect.fromLTRB(30, 20, 70, 80),
    _pg(
      _lin(
        const Offset(34, 0),
        const Offset(66, 0),
        [_al(white, .22), _al(white, 0), _al(_black, .22)],
        const [0, .35, 1],
      ),
    ),
  );
  if (k.drizzle) {
    for (final x in const [-9.0, -1.0, 8.0]) {
      final line = Path()..moveTo(50 + x, lv + 1);
      for (var y = lv + 1; y <= 72; y += 3) {
        line.lineTo(50 + x + 1.3 * math.sin(y * .4 + x), y);
      }
      cv.drawPath(line, _ps(_al(const Color(0xFF2A1208), .75), 1.1));
    }
  }
  cv.restore();

  // The straw, inside the drink first so the ice can sit in front of it.
  const sA = Offset(45, 71);
  const sB = Offset(60, 3);
  void straw(double t0, double t1, double a) {
    final p0 = Offset.lerp(sA, sB, t0)!;
    final p1 = Offset.lerp(sA, sB, t1)!;
    cv.drawLine(p0, p1, _ps(_al(k.straw, a), 2.7, cap: StrokeCap.butt));
    if (k.straw == const Color(0xFFFFFFFF)) {
      for (var t = t0; t < t1; t += .08) {
        cv.drawLine(
          Offset.lerp(sA, sB, t)!,
          Offset.lerp(sA, sB, math.min(t + .035, t1))!,
          _ps(_al(const Color(0xFFD94A4A), a), 2.7, cap: StrokeCap.butt),
        );
      }
    }
  }

  straw(0, 1, .92);
  cv.drawLine(
    sA + const Offset(-.7, 0),
    sB + const Offset(-.7, 0),
    _ps(_al(white, .3), .5),
  );

  // Ice, bubbles.
  if (k.ice) {
    const cubes = [
      (Offset(41, 34), 10.0, .25),
      (Offset(56, 32), 10.5, -.2),
      (Offset(47.5, 45), 10.0, .4),
      (Offset(58.5, 47), 9.4, -.35),
      (Offset(41, 57), 9.0, .15),
      (Offset(52, 61), 8.6, -.1),
    ];
    for (final (p, w, rot) in cubes) {
      _at(cv, p, rot, () {
        final r = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: w * .94),
          const Radius.circular(2),
        );
        cv.drawRRect(
          r,
          _pg(
            _lin(r.outerRect.topLeft, r.outerRect.bottomRight, [
              _al(white, .5),
              _al(white, .12),
            ]),
          ),
        );
        cv.drawRRect(r, _ps(_al(white, .7), .55));
        cv.drawRRect(
          r.deflate(1.5).shift(const Offset(.5, .5)),
          _ps(_al(white, .28), .4),
        );
        cv.drawLine(
          Offset(-w * .36, -w * .36),
          Offset(-w * .1, -w * .4),
          _ps(_al(s.spec, .9), .6),
        );
      });
    }
  }
  for (var i = 0; i < s.n(k.fizz ? 14 : 5, k.fizz ? 30 : 12); i++) {
    final y = s.r(lv + 3, 73);
    final rr = inner(y);
    final p = Offset(50 + s.r(-rr + 1.4, rr - 1.4), y);
    final r0 = s.r(.35, 1.1);
    cv.drawCircle(p, r0, _pf(_al(white, .1)));
    cv.drawCircle(p, r0, _ps(_al(white, .55), .35));
    cv.drawCircle(
      p + Offset(-r0 * .35, -r0 * .35),
      r0 * .25,
      _pf(_al(white, .85)),
    );
  }

  // The surface: foam or a bright disc of liquid.
  final surf = _ell(Offset(50, lv), rl);
  if (k.foam != null) {
    cv.drawOval(
      surf,
      _pg(
        _rad(Offset(44, lv - 1), rl * 1.4, [
          k.foam!,
          _lo(k.foam!, .12),
        ], tilt: _kTilt),
      ),
    );
    for (var i = 0; i < s.n(7, 14); i++) {
      final a = s.r(0, math.pi * 2);
      final p = _on(Offset(50, lv), rl * s.r(.55, .98), a);
      cv.drawCircle(p, s.r(.7, 1.5), _ps(_al(_lo(k.foam!, .2), .45), .4));
    }
  } else {
    cv.drawOval(
      surf,
      _pg(
        _rad(Offset(44, lv - 1), rl * 1.3, [
          _hi(k.top, .45),
          k.top,
        ], tilt: _kTilt),
      ),
    );
    cv.drawOval(surf, _ps(_al(white, .5), .5));
  }
  if (k.ice) {
    // The two cubes that float above the surface.
    for (final (p, w, rot) in const [
      (Offset(41, 31), 10.0, .25),
      (Offset(56, 29), 10.5, -.2),
    ]) {
      _at(cv, p, rot, () {
        final r = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: w * .94),
          const Radius.circular(2),
        );
        cv.drawRRect(
          r,
          _pg(
            _lin(r.outerRect.topLeft, r.outerRect.bottomRight, [
              _al(white, .62),
              _al(white, .2),
            ]),
          ),
        );
        cv.drawRRect(r, _ps(_al(white, .85), .6));
        cv.drawLine(
          Offset(-w * .36, -w * .36),
          Offset(-w * .1, -w * .4),
          _ps(_al(s.spec, .95), .7),
        );
      });
    }
  }
  straw(.5, 1, 1);

  // Condensation on the front of the glass.
  for (var i = 0; i < s.n(2, 14); i++) {
    final y = s.r(30, 74);
    final rr = inner(y) + 1;
    final p = Offset(50 + s.r(-rr, rr), y);
    cv.drawCircle(p, s.r(.35, .8), _pf(_al(white, .22)));
    cv.drawCircle(p + const Offset(-.15, -.2), .22, _pf(_al(white, .8)));
  }

  // The glass itself: thick base, lit left edge, rim.
  final base = Path()
    ..moveTo(50 - 12.6, 75.5)
    ..lineTo(50 - 14.2, 80)
    ..arcTo(_ell(baseC, 14.2), math.pi, -math.pi, false)
    ..lineTo(50 + 12.6, 75.5)
    ..arcTo(_ell(const Offset(50, 75.5), 12.6), 0, math.pi, false)
    ..close();
  cv.drawPath(base, _pf(_al(white, .24)));
  cv.drawArc(_ell(baseC, 14.2), 0, math.pi, false, _ps(_al(white, .55), .7));
  cv.drawArc(
    _ell(const Offset(50, 75.5), 12.6),
    0,
    math.pi,
    false,
    _ps(_al(white, .3), .5),
  );
  final edgeL = Path()
    ..moveTo(32.6, 24)
    ..lineTo(36.6, 76);
  cv.drawPath(edgeL, _ps(_al(white, s.onDark ? .34 : .6), 2.2, blur: .8));
  cv.drawPath(
    edgeL.shift(const Offset(.4, 0)),
    _ps(_al(s.spec, s.onDark ? .5 : .75), .9, blur: .3),
  );
  cv.drawLine(
    const Offset(67.4, 26),
    const Offset(63.4, 72),
    _ps(_al(white, .2), .8, blur: .4),
  );
  final rim = _ell(const Offset(50, 22), 18.5);
  cv.drawOval(rim, _ps(_al(white, s.onDark ? .5 : .85), .8));
  cv.drawOval(rim.inflate(.5), _ps(_al(white, .22), .5));
  if (!s.onDark) {
    // On a pale card the clear glass needs a faint edge to be seen at all.
    final edge = _ps(_al(const Color(0xFF8A7560), .4), .7);
    cv.drawPath(glass, edge);
    cv.drawOval(rim, edge);
  }
  _rim(s, rim, w: .9, a: s.onDark ? .6 : 1);

  // Garnish: mint behind, a citrus wheel on the rim.
  if (k.mint) {
    const mint = [
      (-.6, 8.0, 18.0),
      (-1.4, 7.0, 14.0),
      (-.1, 7.0, 15.0),
      (-2.2, 6.2, 17.0),
    ];
    for (var i = 0; i < mint.length; i++) {
      final (rot, len, y) = mint[i];
      _herbLeaf(s, Offset(35.5 + i * 2.2, y), rot - 1.0, len);
    }
  }
  if (k.wheel != null) {
    final (rind, flesh) = k.wheel!;
    _at(cv, const Offset(67, 22), -.3, () {
      cv.drawCircle(
        const Offset(.7, 1.4),
        7.4,
        _pb(_al(_black, s.shadowA * .45), .8),
      );
      cv.drawCircle(Offset.zero, 7.2, _pf(rind));
      cv.drawCircle(Offset.zero, 6.2, _pf(const Color(0xFFFFF6D2)));
      cv.drawCircle(
        Offset.zero,
        5.5,
        _pg(_rad(const Offset(-1.5, -1.5), 8, [_hi(flesh, .4), flesh])),
      );
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 + .2;
        cv.drawLine(
          Offset(math.cos(a), math.sin(a)) * .8,
          Offset(math.cos(a), math.sin(a)) * 5.2,
          _ps(_al(const Color(0xFFFFF6D2), .85), .45),
        );
      }
      cv.drawCircle(const Offset(-2.4, -2.6), .5, _pf(_al(white, .8)));
    });
  }
}

// ────────────────────────────── cup ──────────────────────────────

Path _heart(double w, double h) => Path()
  ..moveTo(0, h * .38)
  ..cubicTo(-w * .6, -h * .08, -w * .52, -h * .66, -w * .18, -h * .56)
  ..cubicTo(-w * .06, -h * .52, 0, -h * .42, 0, -h * .34)
  ..cubicTo(0, -h * .42, w * .06, -h * .52, w * .18, -h * .56)
  ..cubicTo(w * .52, -h * .66, w * .6, -h * .08, 0, h * .38)
  ..close();

void _cup(_Scene s) {
  if (s.any(['iced', 'cold', 'frappe', 'shake'])) {
    _glass(s, _kCoffee);
    return;
  }
  final cv = s.canvas;
  final tea = s.any(['chai', 'tea', 'kahwa', 'masala']);
  const sc = Offset(50, 70);
  const cc = Offset(46, 49);
  _ground(s, Offset(sc.dx, sc.dy + 2.2), 38);
  _plate(s, sc, 38, 2.2, _cream, well: .6);
  cv.drawOval(
    _ell(const Offset(49, 72), 14.5),
    _pb(_al(_black, s.shadowA * .65), 1.6),
  );

  // The handle, behind the cup.
  final handle = Path()
    ..moveTo(67.5, 50.5)
    ..cubicTo(81, 47, 82.5, 64, 65.5, 62.5);
  cv.drawPath(
    handle.shift(const Offset(1.2, 2.4)),
    _ps(_al(_black, s.shadowA * .45), 4.2, blur: 1),
  );
  cv.drawPath(
    handle,
    _ps(_black, 4.2)
      ..shader = _lin(
        const Offset(66, 48),
        const Offset(82, 60),
        [_cream.lit, _cream.mid, _cream.dark],
        const [0, .5, 1],
      ),
  );
  cv.drawPath(
    handle.shift(const Offset(-.4, -.7)),
    _ps(_al(const Color(0xFFFFFFFF), .6), .8),
  );

  final g = _bowl(s, cc, 23, 20, _cream, foot: .5, wall: 2.2);
  cv.save();
  cv.clipPath(g.holePath);
  const surfC = Offset(46, 50.8);
  final surf = _ell(surfC, 19.6);
  cv.drawOval(
    surf,
    _pg(
      _rad(
        const Offset(39, 47),
        26,
        tea
            ? const [Color(0xFFDDAA72), Color(0xFFB9783C), Color(0xFF7A4A22)]
            : const [Color(0xFFA8683A), Color(0xFF6B3A1E), Color(0xFF3A1D0C)],
        st: const [0, .55, 1],
        tilt: _kTilt,
      ),
    ),
  );
  cv.drawOval(surf, _ps(_al(const Color(0xFF2A1208), .5), 1.1, blur: .5));
  if (!tea) {
    // Latte art: stacked hearts pulled through, laid down in perspective.
    _at(cv, surfC + const Offset(0, .4), 0, () {
      cv.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 27, height: 24),
        _pb(_al(const Color(0xFFF3DDB6), .28), 2.4),
      );
      for (var i = 0; i < 5; i++) {
        final w = 17.0 - i * 2.5;
        final h = 15.0 - i * 2.3;
        final heart = _heart(w, h).shift(Offset(0, 6.2 - i * 3.3));
        cv.drawPath(
          heart,
          _pg(
            _lin(Offset(-w / 2, -h / 2), Offset(w / 2, h / 2), const [
              Color(0xFFFFF6E4),
              Color(0xFFEBCFA2),
            ]),
          ),
        );
        cv.drawPath(heart, _ps(_al(const Color(0xFF7A4A28), .55), .55));
      }
      cv.drawLine(
        const Offset(0, -9),
        const Offset(0, 11),
        _ps(_al(const Color(0xFF5A3018), .75), .55),
      );
    }, sy: _kTilt);
  } else {
    cv.drawArc(
      _ell(surfC, 12),
      math.pi * 1.1,
      math.pi * .6,
      false,
      _ps(_al(const Color(0xFFF3DDB6), .35), 2, blur: 1),
    );
  }
  _gloss(s, surfC + const Offset(-9.6, -3), 6, 1.2, rot: -.3, a: .5);
  cv.restore();

  // Spoon on the saucer.
  const sp = Offset(27, 77.5);
  cv.drawLine(
    sp + const Offset(4, .5),
    const Offset(53, 82.2),
    _ps(_al(_black, s.shadowA * .45), 1.7, blur: .8),
  );
  cv.drawLine(
    sp + const Offset(3.5, 0),
    const Offset(52, 81.4),
    _ps(_black, 1.5)
      ..shader = _lin(
        const Offset(30, 76),
        const Offset(52, 84),
        [_steel.lit, _steel.mid, _steel.dark],
        const [0, .5, 1],
      ),
  );
  _at(cv, sp, .12, () {
    final head = Rect.fromCenter(center: Offset.zero, width: 8.8, height: 5.4);
    cv.drawOval(
      head.shift(const Offset(.6, 1)),
      _pb(_al(_black, s.shadowA * .45), .8),
    );
    cv.drawOval(
      head,
      _pg(
        _rad(
          const Offset(-1.4, -1),
          6,
          [_steel.lit, _steel.mid, _steel.dark],
          st: const [0, .55, 1],
        ),
      ),
    );
    cv.drawOval(head, _ps(_al(const Color(0xFFFFFFFF), .6), .4));
  });
  if (tea) {
    // Cinnamon stick and a star anise.
    cv.drawLine(
      const Offset(62, 82),
      const Offset(80, 77),
      _ps(_al(_black, s.shadowA * .4), 3.2, blur: .8),
    );
    cv.drawLine(
      const Offset(62, 81),
      const Offset(80, 76),
      _ps(_black, 3)
        ..shader = _lin(const Offset(62, 78), const Offset(66, 84), const [
          Color(0xFFC48A5A),
          Color(0xFF7A4526),
        ]),
    );
    cv.drawCircle(const Offset(80, 76), 1.5, _pf(const Color(0xFF5A2E16)));
    _at(cv, const Offset(72, 72.6), .3, () {
      final star = Path();
      for (var i = 0; i < 16; i++) {
        final a = i * math.pi / 8;
        final r0 = i.isEven ? 3.4 : 1.4;
        i == 0
            ? star.moveTo(r0 * math.cos(a), r0 * math.sin(a))
            : star.lineTo(r0 * math.cos(a), r0 * math.sin(a));
      }
      star.close();
      cv.drawPath(star.shift(const Offset(.4, .8)), _pb(_al(_black, .4), .5));
      cv.drawPath(star, _pf(const Color(0xFF6B3516)));
      cv.drawCircle(Offset.zero, .7, _pf(const Color(0xFFA8683A)));
    });
  } else if (s.detail > .15) {
    // A small caramel biscuit.
    _at(cv, const Offset(72, 77.8), -.14, () {
      final bis = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 11.5, height: 5.8),
        const Radius.circular(1.5),
      );
      cv.drawRRect(
        bis.shift(const Offset(.8, 1.4)),
        _pb(_al(_black, s.shadowA * .55), .9),
      );
      cv.drawRRect(
        bis,
        _pg(
          _lin(const Offset(-5, -3), const Offset(5, 3), const [
            Color(0xFFDDA05C),
            Color(0xFFA8642A),
          ]),
        ),
      );
      for (var i = 0; i < 5; i++) {
        cv.drawCircle(
          Offset(-4 + i * 2, i.isEven ? -.8 : .9),
          .35,
          _pf(_al(const Color(0xFF6A3A12), .6)),
        );
      }
    });
  }
}

// ────────────────────────────── loaf ──────────────────────────────

void _loaf(_Scene s) {
  final cv = s.canvas;
  _ground(s, const Offset(50, 73), 43);
  _plate(s, const Offset(50, 70), 43, 3, _oak, wellOn: false);
  if (s.detail > .25) {
    for (final k in const [.92, .8, .66]) {
      cv.drawOval(
        _ell(const Offset(50, 70), 43 * k),
        _ps(_al(_oak.dark, .1), .5),
      );
    }
  }
  // Flour and crumbs spilled across the board.
  cv.drawPoints(ui.PointMode.points, [
    for (var i = 0; i < s.n(10, 50); i++)
      _inEll(s.rnd, const Offset(38, 78), 26, 8),
  ], _ps(_al(const Color(0xFFFFF8EA), .5), .7));

  const base = Offset(50, 64);
  const rx = 29.5;
  cv.drawOval(
    _ell(base + const Offset(3.4, 2.8), rx + 1.5),
    _pb(_al(_black, s.shadowA * .7), 2.2),
  );
  final dome = Path()
    ..moveTo(base.dx - rx, base.dy)
    ..cubicTo(
      base.dx - rx - 1,
      base.dy - 22,
      base.dx - 17,
      base.dy - 35,
      base.dx,
      base.dy - 35,
    )
    ..cubicTo(
      base.dx + 17,
      base.dy - 35,
      base.dx + rx + 1,
      base.dy - 22,
      base.dx + rx,
      base.dy,
    )
    ..arcTo(_ell(base, rx), 0, math.pi, false)
    ..close();
  cv.save();
  cv.clipPath(dome);
  cv.drawPath(
    dome,
    _pg(
      _rad(
        const Offset(39, 44),
        48,
        const [Color(0xFFF2BC76), Color(0xFFC87F36), Color(0xFF7F4313)],
        st: const [0, .5, 1],
      ),
    ),
  );
  cv.drawPath(
    dome,
    _pg(
      _lin(const Offset(0, 50), const Offset(0, 79), [
        _al(const Color(0xFF3A1A06), 0),
        _al(const Color(0xFF3A1A06), .4),
      ]),
    ),
  );
  // Small cracks in the crust.
  for (var i = 0; i < s.n(0, 18); i++) {
    final p = Offset(s.r(24, 76), s.r(38, 72));
    if (!dome.contains(p)) continue;
    final q = p + Offset(s.r(-3, 3), s.r(-1.4, 1.4));
    cv.drawLine(p, q, _ps(_al(const Color(0xFF4A2208), .3), .4));
  }
  // The ear: a long curved score, opened up.
  final score = Path()
    ..moveTo(31, 52)
    ..quadraticBezierTo(50, 30, 72, 54);
  cv.drawPath(
    score.shift(const Offset(0, 2.4)),
    _ps(_al(const Color(0xFF5E2E0E), .6), 1.1),
  );
  cv.drawPath(score, _ps(const Color(0xFF6A3510), 4.4));
  cv.drawPath(
    score.shift(const Offset(0, .35)),
    _ps(const Color(0xFFF3DAA2), 2.9),
  );
  cv.drawPath(
    score.shift(const Offset(0, -2.2)),
    _ps(_al(const Color(0xFFF8CF86), .9), 1.2),
  );
  if (s.detail > .3) {
    for (final (p, q) in const [
      (Offset(28, 60), Offset(40, 64)),
      (Offset(60, 38), Offset(70, 45)),
    ]) {
      cv.drawLine(p, q, _ps(const Color(0xFF6A3510), 2.4));
      cv.drawLine(
        p + const Offset(0, .3),
        q + const Offset(0, .3),
        _ps(const Color(0xFFF3DAA2), 1.3),
      );
    }
  }
  // Flour dusting, heaviest where the light lands and fine as a bakery's.
  for (var i = 0; i < 4; i++) {
    cv.drawOval(
      Rect.fromCenter(
        center: Offset(s.r(32, 58), s.r(36, 54)),
        width: s.r(8, 14),
        height: s.r(3, 6),
      ),
      _pb(_al(const Color(0xFFFFF6E4), .2), 1.8),
    );
  }
  final b = dome.getBounds();
  var flour = 0;
  final want = s.n(12, 70);
  for (var tries = 0; flour < want && tries < want * 6; tries++) {
    final p = Offset(
      b.left + s.rnd.nextDouble() * b.width,
      b.top + s.rnd.nextDouble() * b.height,
    );
    if (!dome.contains(p)) continue;
    final k = ((60 - p.dx) / 40 + (62 - p.dy) / 30).clamp(0.0, 1.5);
    if (s.rnd.nextDouble() > .3 + k * .4) continue;
    flour++;
    cv.drawCircle(
      p,
      s.r(.25, .7),
      _pf(_al(const Color(0xFFFFF6E4), s.r(.25, .55))),
    );
  }
  cv.restore();
  _gloss(s, const Offset(37, 42), 7, 2.2, rot: -.7, a: .26);
  _rim(s, _ell(base, rx), mid: 1.1 * math.pi, span: .5 * math.pi, w: .8, a: .6);

  // A sprig of wheat lying on the board, where there is room to read it.
  if (s.detail > .45) {
    final stem = Path()
      ..moveTo(57, 80.5)
      ..quadraticBezierTo(71, 83.5, 86.5, 72);
    cv.drawPath(
      stem.shift(const Offset(.6, 1.4)),
      _ps(_al(_black, s.shadowA * .4), 1.2, blur: .6),
    );
    cv.drawPath(stem, _ps(const Color(0xFFC9A04E), 1));
    final metric = stem.computeMetrics().first;
    for (var i = 0; i < 7; i++) {
      final tan = metric.getTangentForOffset(metric.length * (.4 + i * .08))!;
      for (final side in const [-1.0, 1.0]) {
        _at(cv, tan.position, tan.angle + side * .6, () {
          final grain = Rect.fromCenter(
            center: const Offset(2.2, 0),
            width: 4.8,
            height: 2,
          );
          cv.drawOval(grain.shift(const Offset(.2, .5)), _pf(_al(_black, .25)));
          cv.drawOval(grain, _pf(const Color(0xFFDDB45E)));
          cv.drawLine(
            const Offset(.6, -.4),
            const Offset(3.4, -.4),
            _ps(_al(const Color(0xFFFFF0B8), .8), .35),
          );
        });
      }
    }
    final tip = metric.getTangentForOffset(metric.length)!;
    cv.drawLine(
      tip.position,
      tip.position + Offset(math.cos(tip.angle), math.sin(tip.angle)) * 5,
      _ps(const Color(0xFFC9A04E), .5),
    );
  }
}

// ───────────────────────────── pastry ─────────────────────────────

/// The direction of the key light as seen inside something rotated by [rot].
Offset _lightLocal(double rot) {
  final c = math.cos(-rot);
  final s = math.sin(-rot);
  return Offset(
    _kLight.dx * c - _kLight.dy * s,
    _kLight.dx * s + _kLight.dy * c,
  );
}

void _pastry(_Scene s) {
  _ground(s, const Offset(50, 71), 42);
  // Slate on a night card; a bakery board on a daylight one.
  _plate(
    s,
    const Offset(50, 68),
    42,
    2.8,
    s.onDark ? _slate : _oak,
    well: .84,
    wellOn: s.onDark,
  );
  if (s.any(['scroll', 'cinnamon', 'bun', 'roll'])) {
    _scroll(s);
  } else if (s.any(['danish', 'turnover', 'strudel'])) {
    _danish(s);
  } else {
    _croissant(s);
  }
  // Crumbs and flakes on the plate.
  final cv = s.canvas;
  cv.drawPoints(ui.PointMode.points, [
    for (var i = 0; i < s.n(4, 22); i++)
      _inEll(s.rnd, const Offset(50, 72), 32, 11),
  ], _ps(_al(const Color(0xFFD9A04E), .85), .8));
}

void _croissant(_Scene s) {
  final cv = s.canvas;
  final pistachio = s.any(['pistachio']);
  final almond = s.any(['almond']);
  // The spine of the croissant: an arch whose horns come down toward us.
  Offset spine(double u) =>
      Offset(50 + 27 * math.sin(u * 1.5), 63 + 17 * (1 - math.cos(u * 1.5)));
  Offset slope(double u) =>
      Offset(27 * 1.5 * math.cos(u * 1.5), 17 * 1.5 * math.sin(u * 1.5));
  double reach(double u) => 3.4 + 10.2 * math.pow(1 - math.min(1.0, u * u), .9);

  // One continuous body underneath, so the ridges never leave a gap.
  final pts = [for (var i = 0; i <= 26; i++) spine(-1 + i / 13)];
  final body = _ribbon(pts, (t) => 2 * reach(-1 + t * 2) * .95);
  cv.drawPath(
    body.shift(const Offset(2.8, 4)),
    _pb(_al(_black, s.shadowA * .7), 2.4),
  );
  cv.drawPath(body, _pf(const Color(0xFFA85F20)));

  // Ridges, from the horns in to the fat middle (which sits on top).
  for (final u in const [-1.0, 1.0, -.75, .75, -.5, .5, -.25, .25, 0.0]) {
    final p = spine(u);
    final t = slope(u);
    final n = Offset(-t.dy, t.dx) / t.distance;
    final rot = math.atan2(n.dy, n.dx);
    final h = reach(u);
    final w = u.abs() > .8 ? 5.6 : 7.2;
    final l = _lightLocal(rot);
    _at(cv, p, rot, () {
      final seg = Rect.fromCenter(
        center: Offset.zero,
        width: h * 2,
        height: w * 2,
      );
      cv.drawOval(
        seg.shift(const Offset(1.3, 1.9)),
        _pb(_al(const Color(0xFF3A1A06), .5), 1.2),
      );
      cv.drawOval(
        seg,
        _pg(
          _rad(
            Offset(l.dx * h * .45, l.dy * w * .55),
            h * 1.7,
            const [Color(0xFFFFDC96), Color(0xFFE8A24A), Color(0xFFA85F20)],
            st: const [0, .55, 1],
          ),
        ),
      );
      cv.drawOval(seg, _ps(_al(const Color(0xFF7A3F10), .5), .65));
      final la = math.atan2(l.dy, l.dx);
      cv.drawArc(
        seg.deflate(.8),
        la - .8,
        1.6,
        false,
        _ps(_al(const Color(0xFFFFE6AE), .6), .5),
      );
      if (s.detail > .2) {
        cv.drawArc(
          seg.deflate(2.6),
          la - .5,
          1.0,
          false,
          _ps(_al(const Color(0xFFFFE6AE), .38), .4),
        );
        cv.drawArc(
          seg.deflate(2.6),
          la + math.pi - .5,
          1.0,
          false,
          _ps(_al(const Color(0xFF7A3F10), .32), .4),
        );
      }
    });
  }
  // The egg-wash shine running along the top of the crescent.
  final shine = Path();
  for (var i = 0; i <= 16; i++) {
    final u = -.62 + i / 16 * .9;
    final t = slope(u);
    var n = Offset(-t.dy, t.dx) / t.distance;
    if (n.dy > 0) n = -n;
    final q = spine(u) + n * (reach(u) * .52);
    i == 0 ? shine.moveTo(q.dx, q.dy) : shine.lineTo(q.dx, q.dy);
  }
  cv.drawPath(shine, _ps(_al(s.spec, .42), 2.4, blur: 1));

  if (pistachio) {
    // A muted crumble of pistachio down the middle.
    for (var i = 0; i < s.n(7, 16); i++) {
      final p = spine(s.r(-.45, .45)) + Offset(s.r(-3, 3), s.r(-9, 2));
      _at(cv, p, s.r(0, math.pi), () {
        cv.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: s.r(1.5, 2.4),
              height: 1,
            ),
            const Radius.circular(.4),
          ),
          _pf(i.isEven ? const Color(0xFF86A648) : const Color(0xFFA9C26A)),
        );
      });
    }
  }
  if (almond) {
    for (var i = 0; i < s.n(6, 12); i++) {
      final p = spine(s.r(-.5, .5)) + Offset(s.r(-3, 3), s.r(-9, 2));
      _at(cv, p, s.r(0, math.pi), () {
        final nut = Rect.fromCenter(
          center: Offset.zero,
          width: 3.6,
          height: 1.7,
        );
        cv.drawOval(nut.shift(const Offset(.3, .5)), _pf(_al(_black, .3)));
        cv.drawOval(nut, _pf(const Color(0xFFF3E2B8)));
      });
    }
    cv.drawPoints(ui.PointMode.points, [
      for (var i = 0; i < s.n(10, 50); i++)
        _inEll(s.rnd, const Offset(50, 63), 24, 11),
    ], _ps(_al(const Color(0xFFFFFFFF), .7), .6));
  }
}

void _scroll(_Scene s) {
  final cv = s.canvas;
  const top = Offset(50, 52);
  const rx = 29.0;
  const th = 13.0;
  cv.drawOval(
    _ell(top + const Offset(3.4, th + 1.6), rx + 1),
    _pb(_al(_black, s.shadowA * .7), 2.2),
  );
  final side = Path()
    ..moveTo(top.dx - rx, top.dy)
    ..lineTo(top.dx - rx, top.dy + th)
    ..arcTo(_ell(top + const Offset(0, th), rx), math.pi, -math.pi, false)
    ..lineTo(top.dx + rx, top.dy)
    ..close();
  cv.drawPath(
    side,
    _pg(
      _lin(
        Offset(top.dx - rx, 0),
        Offset(top.dx + rx, 0),
        const [Color(0xFFF3C27A), Color(0xFFD58E3C), Color(0xFF8E5220)],
        const [0, .5, 1],
      ),
    ),
  );
  for (final y in const [4.2, 8.6]) {
    cv.drawArc(
      _ell(top + Offset(0, y), rx - .6),
      .08,
      math.pi - .16,
      false,
      _ps(_al(const Color(0xFF7A3F10), .38), .6),
    );
  }
  final face = _ell(top, rx);
  cv.drawOval(
    face,
    _pg(
      _rad(
        const Offset(40, 46),
        38,
        const [Color(0xFFF9D590), Color(0xFFE2A24E), Color(0xFFB06A28)],
        st: const [0, .55, 1],
        tilt: _kTilt,
      ),
    ),
  );
  // The spiral of dough and cinnamon.
  final pts = <Offset>[
    for (var i = 0; i <= 150; i++)
      () {
        final th0 = i / 150 * math.pi * 5.4;
        final r = 2.2 + th0 * 1.58;
        return Offset(
          top.dx + r * math.cos(th0),
          top.dy + r * math.sin(th0) * _kTilt,
        );
      }(),
  ];
  final spiral = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final p in pts.skip(1)) {
    spiral.lineTo(p.dx, p.dy);
  }
  cv.drawPath(
    spiral.shift(const Offset(0, .8)),
    _ps(_al(const Color(0xFF6A3510), .35), 3.6),
  );
  cv.drawPath(spiral, _ps(const Color(0xFFA85A22), 3.2));
  cv.drawPath(
    spiral.shift(const Offset(-.3, -.7)),
    _ps(_al(const Color(0xFFFFE0A0), .6), 1),
  );
  // White icing in zigzags, with a few drips over the front edge.
  cv.save();
  cv.clipPath(Path()..addOval(_ell(top, rx - 1)));
  for (var i = 0; i < 7; i++) {
    final y0 = top.dy - 9 + i * 3.1;
    final z = Path()..moveTo(top.dx - 30, y0);
    for (var x = top.dx - 30; x <= top.dx + 30; x += 3) {
      z.lineTo(x, y0 + ((x ~/ 3).isEven ? -1.1 : 1.1));
    }
    cv.drawPath(
      z.shift(const Offset(0, 1)),
      _ps(_al(const Color(0xFF8A4A1E), .25), 2.2),
    );
    cv.drawPath(z, _ps(_al(const Color(0xFFFFF8EC), .94), 2.1));
  }
  cv.restore();
  for (final x in const [38.0, 50.0, 61.0]) {
    final y = _arcY(x, top.dx, top.dy, rx);
    final drip = Path()
      ..moveTo(x - 2, y - 1)
      ..quadraticBezierTo(x - 2, y + 5, x, y + 6)
      ..quadraticBezierTo(x + 2, y + 5, x + 2, y - 1)
      ..close();
    cv.drawPath(drip, _pf(const Color(0xFFFFF8EC)));
  }
  cv.drawPoints(ui.PointMode.points, [
    for (var i = 0; i < s.n(6, 30); i++) _inEll(s.rnd, top, 22, 9),
  ], _ps(_al(const Color(0xFF6A3510), .55), .6));
  _gloss(s, const Offset(38, 44), 8, 2.2, rot: -.35, a: .35);
  _rim(s, face, w: .9);
}

void _danish(_Scene s) {
  final cv = s.canvas;
  final jam = s.any(['blueberry'])
      ? const Color(0xFF3F4FA0)
      : s.any(['raspberry', 'strawberry', 'cherry'])
      ? const Color(0xFFC9244A)
      : const Color(0xFFD9563A);
  const c = Offset(50, 56);
  const rr = 29.0;
  List<Offset> diamond(double dy) => [
    Offset(c.dx, c.dy - rr * _kTilt * 1.15 + dy),
    Offset(c.dx + rr, c.dy + dy),
    Offset(c.dx, c.dy + rr * _kTilt * 1.15 + dy),
    Offset(c.dx - rr, c.dy + dy),
  ];
  Path poly(List<Offset> p) => Path()
    ..moveTo(p[0].dx, p[0].dy)
    ..lineTo(p[1].dx, p[1].dy)
    ..lineTo(p[2].dx, p[2].dy)
    ..lineTo(p[3].dx, p[3].dy)
    ..close();
  cv.drawPath(
    poly(diamond(4.4)).shift(const Offset(3, 2)),
    _pb(_al(_black, s.shadowA * .7), 2),
  );
  for (var k = 5; k >= 1; k--) {
    final p = poly(diamond(k * .9));
    final col = _mix(const Color(0xFFD99440), const Color(0xFF8A5120), k / 5);
    cv.drawPath(p, _pf(col));
    cv.drawPath(p, _ps(col, 3));
  }
  final d0 = diamond(0);
  final mid = c;
  final tones = [
    const [Color(0xFFFBD78C), Color(0xFFE9A94E)],
    const [Color(0xFFEDB058), Color(0xFFC8802E)],
    const [Color(0xFFE29E46), Color(0xFFA85F20)],
    const [Color(0xFFF6C66E), Color(0xFFD99440)],
  ];
  for (var i = 0; i < 4; i++) {
    final a = d0[i];
    final b = d0[(i + 1) % 4];
    final tri = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(mid.dx, mid.dy)
      ..close();
    cv.drawPath(tri, _pg(_lin(a, mid, tones[i])));
    cv.drawPath(tri, _ps(_al(const Color(0xFF7A3F10), .4), .6));
    cv.drawPath(tri, _ps(_al(const Color(0xFFFFE6AE), .3), 2.4));
  }
  cv.drawPath(
    poly(d0),
    _ps(_black, 3)
      ..shader = _lin(d0[3], d0[1], const [
        Color(0xFFF6C66E),
        Color(0xFFB87428),
      ]),
  );
  // Jam in the middle.
  final jr = Rect.fromCenter(
    center: c + const Offset(0, -.4),
    width: 17,
    height: 8.6,
  );
  cv.drawOval(
    jr.shift(const Offset(.6, 1.2)),
    _pb(_al(const Color(0xFF3A1A06), .6), .9),
  );
  cv.drawOval(jr, _pf(_lo(jam, .3)));
  cv.drawOval(
    jr.deflate(1),
    _pg(
      _rad(
        c + const Offset(-2.6, -1.8),
        11,
        [_hi(jam, .5), jam, _lo(jam, .25)],
        st: const [0, .55, 1],
        tilt: _kTilt,
      ),
    ),
  );
  _gloss(s, c + const Offset(-3.2, -1.7), 3.4, .9, rot: -.3, a: .7);
  cv.drawPoints(ui.PointMode.points, [
    for (var i = 0; i < s.n(5, 25); i++) _inEll(s.rnd, c, 20, 9),
  ], _ps(_al(const Color(0xFFFFFFFF), .75), .6));
}

// ───────────────────────────── snack ─────────────────────────────

void _snack(_Scene s) {
  final cv = s.canvas;
  final corn = s.any(['corn', 'popcorn']);
  final fries = s.any(['fries', 'chips', 'wedges', 'nachos']);
  final samosa = s.any(['samosa', 'kachori']);
  final momo = s.any(['momo', 'dumpling', 'dim sum']);
  const t = Offset(50, 46);
  const bc = Offset(50, 84);
  const rt = 24.0;
  const rb = 11.5;
  const red = Color(0xFFC8362A);
  const paper = Color(0xFFF8EBD2);
  _ground(s, const Offset(51, 85), 17);

  // The paper cone, striped, seen from slightly above.
  final body = Path()
    ..moveTo(t.dx - rt, t.dy)
    ..lineTo(bc.dx - rb, bc.dy)
    ..arcTo(_ell(bc, rb), math.pi, -math.pi, false)
    ..lineTo(t.dx + rt, t.dy)
    ..arcTo(_ell(t, rt), 0, math.pi, false)
    ..close();
  const stripes = 9;
  for (var i = 0; i < stripes; i++) {
    final a0 = math.pi * i / stripes;
    final a1 = math.pi * (i + 1) / stripes;
    final quad = Path()
      ..moveTo(t.dx + rt * math.cos(a0), t.dy + rt * _kTilt * math.sin(a0))
      ..lineTo(t.dx + rt * math.cos(a1), t.dy + rt * _kTilt * math.sin(a1))
      ..lineTo(bc.dx + rb * math.cos(a1), bc.dy + rb * _kTilt * math.sin(a1))
      ..lineTo(bc.dx + rb * math.cos(a0), bc.dy + rb * _kTilt * math.sin(a0))
      ..close();
    cv.drawPath(quad, _pf(i.isEven ? red : paper));
  }
  cv.drawPath(
    body,
    _pg(
      _lin(
        Offset(t.dx - rt, 0),
        Offset(t.dx + rt, 0),
        [_al(const Color(0xFFFFFFFF), .2), _al(_black, 0), _al(_black, .4)],
        const [0, .4, 1],
      ),
    ),
  );
  cv.drawPath(
    body,
    _pg(
      _lin(Offset(0, t.dy), Offset(0, bc.dy + 6), [
        _al(_black, 0),
        _al(_black, .22),
      ]),
    ),
  );
  if (s.onDark) {
    cv.drawLine(
      Offset(t.dx + rt, t.dy),
      Offset(bc.dx + rb, bc.dy),
      _ps(_al(s.light, .26), .9, blur: .5),
    );
  }

  // The open mouth and what is heaped in it.
  final mouth = _ell(t, rt);
  cv.drawOval(
    mouth,
    _pg(
      _lin(mouth.centerLeft, mouth.centerRight, const [
        Color(0xFFB59B6E),
        Color(0xFFE8D6B0),
      ]),
    ),
  );
  cv.save();
  cv.clipPath(
    Path()
      ..addOval(mouth)
      ..addRect(Rect.fromLTRB(t.dx - rt, 0, t.dx + rt, t.dy)),
  );
  // A dome of sample points, back to front: (position, how lit it is).
  List<(Offset, double)> heap(int n, double rx0, double h) {
    final raw = <(Offset, double, double)>[];
    for (var i = 0; i < n; i++) {
      final a = s.r(0, math.pi * 2);
      final d = math.sqrt(s.rnd.nextDouble());
      final u = d * math.cos(a);
      final v = d * math.sin(a);
      final hh = h * math.pow(1 - d * d, .6);
      final lit = (.55 - .35 * u - .3 * v + .3 * hh / h).clamp(0.0, 1.0);
      raw.add((
        Offset(t.dx + u * rx0, t.dy + v * rx0 * _kTilt - hh),
        v + hh * .02,
        lit,
      ));
    }
    raw.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final r in raw) (r.$1, r.$3)];
  }

  if (corn) {
    for (final (p, lit) in heap(s.n(60, 90), 21, 17)) {
      final rot = s.r(0, math.pi);
      _at(cv, p, rot, () {
        final kern = Rect.fromCenter(
          center: Offset.zero,
          width: 3.7,
          height: 2.9,
        );
        cv.drawOval(
          kern.shift(const Offset(.3, .6)),
          _pf(_al(const Color(0xFF3A1A06), .4)),
        );
        cv.drawOval(
          kern,
          _pf(_mix(const Color(0xFFB87A10), const Color(0xFFFFE27A), lit)),
        );
        cv.drawCircle(
          const Offset(1.3, .1),
          .5,
          _pf(_al(const Color(0xFF9A5A0C), .8)),
        );
        if (lit > .6) {
          cv.drawCircle(
            const Offset(-.8, -.6),
            .45,
            _pf(_al(const Color(0xFFFFF4C0), .8)),
          );
        }
      });
    }
    for (var i = 0; i < s.n(5, 10); i++) {
      _coriander(
        s,
        _inEll(s.rnd, t + const Offset(0, -9), 15, 6),
        s.r(0, 6.28),
        .55,
      );
    }
    cv.drawPoints(ui.PointMode.points, [
      for (var i = 0; i < s.n(6, 22); i++)
        _inEll(s.rnd, t + const Offset(0, -9), 17, 7),
    ], _ps(_al(const Color(0xFFC0301E), .8), .7));
  } else if (fries) {
    final sticks = <(Offset, Offset)>[
      for (var i = 0; i < s.n(13, 8); i++)
        () {
          final bx = s.r(33, 67);
          final by = 47 + s.r(-3, 3);
          final lean = (bx - 50) / 16 * s.r(.5, 1.3);
          return (
            Offset(bx, by),
            Offset(bx + lean * 5 + s.r(-2, 2), by - s.r(15, 25)),
          );
        }(),
    ]..sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
    for (final (b0, tip) in sticks) {
      cv.drawLine(
        b0 + const Offset(.8, 0),
        tip + const Offset(.8, 0),
        _ps(_al(const Color(0xFF3A1A06), .35), 3.2, cap: StrokeCap.butt),
      );
      cv.drawLine(
        b0,
        tip,
        _ps(const Color(0xFFEFC25A), 3.1, cap: StrokeCap.butt),
      );
      cv.drawLine(
        b0 + const Offset(-.9, 0),
        tip + const Offset(-.9, 0),
        _ps(const Color(0xFFFBE49A), .9, cap: StrokeCap.butt),
      );
      cv.drawLine(
        b0 + const Offset(1.1, 0),
        tip + const Offset(1.1, 0),
        _ps(const Color(0xFFC1892A), .8, cap: StrokeCap.butt),
      );
      cv.drawOval(
        Rect.fromCenter(center: tip, width: 3.1, height: 1.3),
        _pf(const Color(0xFFFFF0B8)),
      );
    }
    cv.drawPoints(ui.PointMode.points, [
      for (var i = 0; i < s.n(8, 30); i++)
        _inEll(s.rnd, t + const Offset(0, -10), 15, 9),
    ], _ps(_al(const Color(0xFFFFFFFF), .85), .6));
  } else if (samosa) {
    const spots = [
      (Offset(39, 40), 11.0, .12),
      (Offset(61, 37.5), 11.0, -.22),
      (Offset(50, 44), 12.0, .05),
    ];
    for (final (p, size, rot) in spots) {
      final pts = <Offset>[
        for (var i = 0; i < 3; i++) ...[
          Offset(
                math.cos(-math.pi / 2 + i * math.pi * 2 / 3),
                math.sin(-math.pi / 2 + i * math.pi * 2 / 3),
              ) *
              size,
          Offset(
                math.cos(-math.pi / 6 + i * math.pi * 2 / 3),
                math.sin(-math.pi / 6 + i * math.pi * 2 / 3),
              ) *
              size *
              .6,
        ],
      ];
      final tri = _smooth(pts);
      _at(cv, p, rot, () {
        cv.drawPath(
          tri.shift(const Offset(1, 1.8)),
          _pb(_al(_black, s.shadowA * .6), 1),
        );
        cv.drawPath(
          tri,
          _pg(
            _litLin(
              rot,
              size,
              const Color(0xFFF6C468),
              const Color(0xFFD58C2E),
              const Color(0xFF8E5018),
            ),
          ),
        );
        for (var i = 0; i < s.n(4, 12); i++) {
          cv.drawCircle(
            _inEll(s.rnd, Offset.zero, size * .55, size * .5),
            s.r(.35, .9),
            _pf(
              _al(
                i.isEven ? const Color(0xFF9A5A14) : const Color(0xFFFFDC96),
                .55,
              ),
            ),
          );
        }
        cv.drawPath(tri, _ps(_al(const Color(0xFF7A3F10), .5), .7));
        _gloss(
          s,
          Offset(-size * .25, -size * .3),
          size * .3,
          size * .09,
          rot: -.4,
          a: .4,
        );
      });
    }
  } else {
    // Pakora or dumplings: a heap of golden pieces.
    for (final (p, lit) in heap(s.n(22, 26), 20, 15)) {
      final piece = _blob(s.rnd, Offset.zero, 4.8, 3.9, n: 7, wob: .28);
      final rot = s.r(0, math.pi);
      _at(cv, p, rot, () {
        cv.drawPath(
          piece.shift(const Offset(.5, 1)),
          _pf(_al(const Color(0xFF3A1A06), .45)),
        );
        cv.drawPath(
          piece,
          _pf(
            momo
                ? _mix(const Color(0xFFCDB68C), const Color(0xFFFFF8E6), lit)
                : _mix(const Color(0xFF8E5018), const Color(0xFFF0B04C), lit),
          ),
        );
        if (momo) {
          for (var i = -1; i <= 1; i++) {
            cv.drawArc(
              Rect.fromCenter(
                center: Offset(i * 1.8, -1.4),
                width: 2.6,
                height: 3.2,
              ),
              .3,
              2.4,
              false,
              _ps(_al(const Color(0xFFA8926A), .55), .35),
            );
          }
        } else {
          cv.drawCircle(
            Offset(s.r(-2, 2), s.r(-1.4, 1.4)),
            s.r(.3, .7),
            _pf(_al(const Color(0xFFFFD58A), .6)),
          );
          cv.drawCircle(
            Offset(s.r(-2, 2), s.r(-1.4, 1.4)),
            s.r(.3, .6),
            _pf(_al(const Color(0xFF6E3A0C), .6)),
          );
        }
      });
    }
    for (var i = 0; i < s.n(2, 4); i++) {
      _coriander(
        s,
        _inEll(s.rnd, t + const Offset(0, -9), 14, 6),
        s.r(0, 6.28),
        .6,
      );
    }
  }
  cv.restore();
  cv.drawOval(mouth, _ps(_al(const Color(0xFFFFF6E0), .8), .8));
  _rim(s, mouth, w: .9, a: .8);
  _spark(s, const Offset(34, 62), .9, a: .5);
}

// ───────────────────────────── plate ─────────────────────────────

/// An unknown dish: a clean plate with a swoosh of sauce and a little garnish.
/// It claims to be nothing in particular.
void _plateDish(_Scene s) {
  final cv = s.canvas;
  const c = Offset(50, 62);
  _ground(s, const Offset(50, 65.2), 40);
  _plate(s, c, 40, 3.2, _cream, well: .74);

  // A swoosh of dark jus, fat at the start and drawn out to a point.
  final pts = <Offset>[
    for (var i = 0; i <= 30; i++)
      () {
        final u = i / 30;
        final x = 23 + 54 * u;
        final y =
            65 - 17 * math.pow(u, 1.5) - 6.5 * math.sin(u * math.pi * 1.1);
        return Offset(x, y);
      }(),
  ];
  final swoosh = _ribbon(
    pts,
    (u) => 5.4 * math.pow(math.sin(math.pi * math.pow(u, .8)), .9) + .25,
  );
  cv.drawPath(
    swoosh.shift(const Offset(.5, 1)),
    _pb(_al(const Color(0xFF3A1A08), s.onDark ? .55 : .3), .8),
  );
  cv.drawPath(
    swoosh,
    _pg(
      _lin(
        const Offset(23, 66),
        const Offset(77, 48),
        const [Color(0xFF9A5A2A), Color(0xFF5A2C12), Color(0xFF2E1408)],
        const [0, .5, 1],
      ),
    ),
  );
  final lit = Path();
  for (var i = 2; i <= 16; i++) {
    final q = pts[i] + const Offset(-.4, -1.1);
    i == 2 ? lit.moveTo(q.dx, q.dy) : lit.lineTo(q.dx, q.dy);
  }
  cv.drawPath(lit, _ps(_al(s.spec, .5), .6));

  // Three drops of green oil.
  for (final (p, r0) in const [
    (Offset(35, 52.5), 2.4),
    (Offset(41, 50.5), 1.7),
    (Offset(45.6, 49.8), 1.1),
  ]) {
    cv.drawOval(
      _ell(p + const Offset(.5, .9), r0 * 1.1, .8),
      _pb(_al(_black, .3), .5),
    );
    cv.drawCircle(
      p,
      r0,
      _pg(
        _rad(
          p + Offset(-r0 * .4, -r0 * .4),
          r0 * 1.6,
          const [Color(0xFFC9E48A), Color(0xFF6FA83A), Color(0xFF3F7A26)],
          st: const [0, .5, 1],
        ),
      ),
    );
    _spark(s, p + Offset(-r0 * .4, -r0 * .45), r0 * .25 + .15, a: .8);
  }
  // A small sprig of micro-herbs and two petals.
  const sprig = Offset(61, 54);
  for (var i = 0; i < s.n(5, 5); i++) {
    final a = -2.4 + i * .5;
    final tip = sprig + Offset(math.cos(a), math.sin(a)) * s.r(5, 7.5);
    cv.drawLine(sprig, tip, _ps(const Color(0xFF3F7A26), .45));
    cv.drawCircle(
      tip,
      s.r(1, 1.7),
      _pf(i.isEven ? const Color(0xFF8CC24A) : const Color(0xFF4E9A3A)),
    );
    cv.drawCircle(
      tip + const Offset(-.3, -.4),
      .5,
      _pf(const Color(0xFFD2EE9A)),
    );
  }
  cv.drawCircle(sprig + const Offset(.8, 0), 1.3, _pf(const Color(0xFFC13A7A)));
  for (final (p, col, rot) in const [
    (Offset(67, 57.4), Color(0xFFF4A6C0), .4),
    (Offset(55.4, 58.6), Color(0xFFFFD25A), -.5),
  ]) {
    _at(cv, p, rot, () {
      final petal = Rect.fromCenter(
        center: Offset.zero,
        width: 4.2,
        height: 2.4,
      );
      cv.drawOval(petal.shift(const Offset(.3, .6)), _pb(_al(_black, .3), .5));
      cv.drawOval(
        petal,
        _pg(_lin(petal.topLeft, petal.bottomRight, [_hi(col, .4), col])),
      );
    });
  }
  // Salt flakes, a crumble and a few flecks of the house's light.
  cv.drawPoints(ui.PointMode.points, [
    for (var i = 0; i < s.n(5, 16); i++)
      _inEll(s.rnd, const Offset(50, 58), 22, 9),
  ], _ps(_al(const Color(0xFFFFFFFF), .9), .8));
  cv.drawPoints(ui.PointMode.points, [
    for (var i = 0; i < s.n(4, 14); i++)
      _inEll(s.rnd, const Offset(40, 63), 15, 5),
  ], _ps(_al(const Color(0xFF4A2E18), .8), .9));
  for (var i = 0; i < 3; i++) {
    cv.drawCircle(
      _inEll(s.rnd, const Offset(50, 58), 20, 8),
      .5,
      _pf(_al(s.light, .95)),
    );
  }
}
