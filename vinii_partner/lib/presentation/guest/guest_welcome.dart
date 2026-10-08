import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../domain/storefront.dart';
import '../../l10n/l10n.dart';
import '../theme/guest_theme.dart';
import '../widgets/dish_art.dart';
import 'guest_effects.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';
import 'look/look.dart';
import 'look/motion.dart';
import 'look/spread.dart';

/// Board 1 #1 / Board 2 #2: the full-bleed welcome. Everything written here
/// is the merchant's own words; empty brand fields are simply left out.
/// The picture behind it is the CMS's welcome picture, else its cover,
/// else the restaurant's first dish photo, else a glow in the accent.
class GuestWelcomeScreen extends StatelessWidget {
  const GuestWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final t = GuestCopy.of(context);
    final l = context.l10n;
    final brand = s.definition.brand;
    // The layout follows the template; the faces may be the CMS's.
    final artisan = p.template == StorefrontTemplate.artisanDay;
    final hasHero = brand.heroTitle.trim().isNotEmpty;
    final modes = s.definition.serviceModes;
    final cover =
        GuestScope.mediaUrlOf(context, s.definition.media.hero) ??
        GuestScope.mediaUrlOf(context, brand.coverUrl) ??
        s.catalog.allItems
            .where((i) => i.item.imageUrl != null)
            .firstOrNull
            ?.item
            .imageUrl;
    // Shown only when the restaurant wrote it; the screen never had one.
    final tableLine = s.tableName == null
        ? null
        : t.own('welcome.table_line', {'table': l.guestTableNameOf(s)!});

    final names = cover == null
        ? DishSpread.pick([...s.catalog.chefsPicks, ...s.catalog.allItems])
        : const <String>[];

    // The words and the button, the same on every screen size. On a phone the
    // dishes fill the space above them; on a wide screen they stand beside.
    Widget words({required bool wide, double minHeight = 0}) {
      final align = artisan
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start;
      // Above the dishes: the brand and the language switch.
      final top = <Widget>[
        _BrandRow(artisan: artisan, showName: hasHero || artisan),
        if (s.languages.length > 1) ...[
          const SizedBox(height: 14),
          const _LanguageSwitch(),
        ],
      ];
      // Below them: the headline, the words and the button.
      final bottom = <Widget>[
        _Rise(
          delay: 0,
          child: hasHero
              ? _Headline(
                  text: brand.heroTitle,
                  artisan: artisan,
                  size: wide ? 52 : 40,
                )
              : Text(
                  brand.displayName,
                  textAlign: artisan ? TextAlign.center : TextAlign.start,
                  style: p.display(wide ? 54 : 44, color: Colors.white),
                ),
        ),
        if (brand.heroSubtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          _Rise(
            delay: 120,
            child: Text(
              brand.heroSubtitle,
              textAlign: artisan ? TextAlign.center : TextAlign.start,
              style: p.body(
                wide ? 18 : 16,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
        ],
        if (tableLine != null) ...[
          const SizedBox(height: 14),
          _Rise(
            delay: 160,
            child: Text(
              tableLine,
              textAlign: artisan ? TextAlign.center : TextAlign.start,
              style: p.body(15, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
        const SizedBox(height: 28),
        _Rise(
          delay: 220,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: modes.length == 2
                ? Column(
                    children: [
                      for (final (i, m) in modes.indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _ModePill(
                          key: ValueKey('welcome-mode-${m.name}'),
                          mode: m,
                          primary: i == 0,
                        ),
                      ],
                    ],
                  )
                : GuestButton(
                    key: const ValueKey('welcome-cta'),
                    label: t.own('welcome.cta') ?? l.guestWelcomeStart,
                    trailingArrow: true,
                    onImage: true,
                    onTap: () => GuestFlow.start(context),
                  ),
          ),
        ),
      ];
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 12, wide ? 24 : 16, 20),
        child: wide
            ? Column(
                crossAxisAlignment: align,
                children: [
                  ...top,
                  const Spacer(flex: 3),
                  ...bottom,
                  const Spacer(flex: 2),
                ],
              )
            // A phone: the dishes fill whatever the words leave, and when the
            // words alone are taller than the screen (Hindi, large text, a
            // phone on its side) the dishes shrink to nothing and the
            // screen scrolls instead of overflowing.
            : _SceneColumn(
                minHeight: (minHeight - 32).clamp(0.0, double.infinity),
                top: Column(
                  crossAxisAlignment: align,
                  mainAxisSize: MainAxisSize.min,
                  children: top,
                ),
                scene: cover == null
                    ? _HeroDishes(names: names)
                    : const SizedBox.shrink(),
                bottom: Column(
                  crossAxisAlignment: align,
                  mainAxisSize: MainAxisSize.min,
                  children: bottom,
                ),
              ),
      );
    }

    return Scaffold(
      backgroundColor: p.isDark ? p.background : p.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _HeroBackdrop(url: cover),
          PhotoScrim(strength: cover == null ? 0.7 : 0.92, top: true),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                // A wide screen (a tablet on its side, a counter display) puts
                // the dishes beside the words, not under a phone-width column.
                if (c.maxWidth < 900) {
                  return GuestColumn(
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        child: words(wide: false, minHeight: box.maxHeight),
                      ),
                    ),
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: names.isEmpty
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(48, 32, 8, 48),
                              // The dishes stay a table's width apart, not the
                              // width of the screen.
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 640,
                                    maxHeight: 640,
                                  ),
                                  child: _HeroDishes(names: names),
                                ),
                              ),
                            ),
                    ),
                    SizedBox(width: 540, child: words(wide: true)),
                    const SizedBox(width: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Three stacked parts: [top] and [bottom] at their natural height, and the
/// [scene] (the dishes) in whatever is left between them, which may be
/// nothing. The whole is at least [minHeight] tall, so on a tall screen it
/// fills it exactly as a Column with an Expanded would; on a short one it is
/// as tall as [top] + [bottom] and the surrounding scroll view scrolls.
class _SceneColumn extends MultiChildRenderObjectWidget {
  _SceneColumn({
    required this.minHeight,
    required Widget top,
    required Widget scene,
    required Widget bottom,
  }) : super(children: [top, scene, bottom]);

  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSceneColumn(minHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSceneColumn renderObject,
  ) => renderObject.minHeight = minHeight;
}

class _SceneParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderSceneColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SceneParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SceneParentData> {
  _RenderSceneColumn(this._minHeight);

  double _minHeight;
  set minHeight(double v) {
    if (v == _minHeight) return;
    _minHeight = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SceneParentData) {
      child.parentData = _SceneParentData();
    }
  }

  RenderBox get _top => firstChild!;
  RenderBox get _scene => childAfter(firstChild!)!;
  RenderBox get _bottom => lastChild!;

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    final natural = BoxConstraints(minWidth: w, maxWidth: w);
    _top.layout(natural, parentUsesSize: true);
    _bottom.layout(natural, parentUsesSize: true);
    final words = _top.size.height + _bottom.size.height;
    final total = words > _minHeight ? words : _minHeight;
    final sceneHeight = total - words;
    _scene.layout(BoxConstraints.tight(Size(w, sceneHeight)));
    (_top.parentData! as _SceneParentData).offset = Offset.zero;
    (_scene.parentData! as _SceneParentData).offset = Offset(
      0,
      _top.size.height,
    );
    (_bottom.parentData! as _SceneParentData).offset = Offset(
      0,
      _top.size.height + sceneHeight,
    );
    size = constraints.constrain(Size(w, total));
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _top.getMinIntrinsicHeight(width) + _bottom.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _top.getMaxIntrinsicHeight(width) + _bottom.getMaxIntrinsicHeight(width);

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final natural = BoxConstraints(minWidth: w, maxWidth: w);
    final words =
        _top.getDryLayout(natural).height +
        _bottom.getDryLayout(natural).height;
    return constraints.constrain(
      Size(w, words > _minHeight ? words : _minHeight),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    // The hero is always night-dark so the white headline reads; light
    // templates use their own ink (espresso) instead of pure black. Embers
    // rise in a night room, flour dust in a bakery.
    final room = GuestStage(
      night: true,
      motes: p.isDark ? 16 : 22,
      spot: const Alignment(-0.6, -0.55),
    );
    if (url == null) return room;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.12, end: 1),
      duration: const Duration(seconds: 6),
      curve: Curves.easeOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => room,
      ),
    );
  }
}

/// The restaurant's own dishes, set on the lit scene: the first large in the
/// middle, two more smaller behind it, each rising into place and then
/// floating on its own slow loop. Shown when the restaurant has no welcome
/// photograph; with one, the photograph leads instead.
class _HeroDishes extends StatefulWidget {
  const _HeroDishes({required this.names});
  final List<String> names;

  @override
  State<_HeroDishes> createState() => _HeroDishesState();
}

class _HeroDishesState extends State<_HeroDishes>
    with SingleTickerProviderStateMixin {
  AnimationController? _float;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_float == null && !reducedMotion(context)) {
      _float = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 7),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _float?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.names.isEmpty) return const SizedBox.shrink();
    final p = GuestPalette.of(context);
    final names = widget.names;
    return LayoutBuilder(
      builder: (context, c) {
        final side =
            (c.maxWidth * 0.78 < c.maxHeight * 1.05
                    ? c.maxWidth * 0.78
                    : c.maxHeight * 1.05)
                .clamp(120.0, 380.0);
        Widget dish(
          String name,
          double size,
          Alignment at,
          double phase,
          int order,
        ) {
          final art = SizedBox.square(
            dimension: size,
            child: DishArt(
              name: name,
              light: p.keyLight,
              onDark: true,
              animate: size > 150,
            ),
          );
          return Align(
            alignment: at,
            child: Reveal(
              delay: Duration(milliseconds: 120 + order * 120),
              dy: 36,
              scaleFrom: 0.86,
              duration: GuestMotion.hero,
              child: _float == null
                  ? art
                  : AnimatedBuilder(
                      animation: _float!,
                      child: art,
                      builder: (context, child) {
                        final bob = _sin(_float!.value + phase) * 5;
                        return Transform.translate(
                          offset: Offset(0, bob),
                          child: child,
                        );
                      },
                    ),
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (names.length > 1)
                dish(
                  names[1],
                  side * 0.5,
                  const Alignment(-0.95, -0.55),
                  0.33,
                  1,
                ),
              if (names.length > 2)
                dish(
                  names[2],
                  side * 0.46,
                  const Alignment(0.98, -0.2),
                  0.66,
                  2,
                ),
              dish(names[0], side, const Alignment(0, 0.25), 0, 0),
            ],
          ),
        );
      },
    );
  }

  /// sin of a 0..1 loop, as a full turn.
  static double _sin(double turns) => math.sin(turns * 2 * math.pi);
}

/// Logo + name + location pin (bistro), or the centred serif wordmark
/// with the tagline beneath (artisan).
class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.artisan, required this.showName});
  final bool artisan;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final brand = GuestScope.read(context).definition.brand;
    final muted = Colors.white.withValues(alpha: 0.72);
    if (artisan) {
      return Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Column(
              children: [
                if (GuestLogo.hasPicture(context)) ...[
                  const GuestLogo(size: 56, initials: false),
                  const SizedBox(height: 10),
                ],
                Text(
                  brand.displayName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: p
                      .display(22, weight: FontWeight.w700, color: Colors.white)
                      .copyWith(letterSpacing: 3),
                ),
                if (brand.tagline.trim().isNotEmpty)
                  Text(
                    brand.tagline,
                    textAlign: TextAlign.center,
                    style: p.body(12.5, color: muted),
                  ),
                if (brand.locationLine.trim().isNotEmpty)
                  _Location(text: brand.locationLine, color: muted),
              ],
            ),
          ),
          const SizedBox(width: 40, child: GuestExitButton()),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GuestLogo(size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showName)
                Text(
                  brand.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.display(18, color: Colors.white),
                ),
              if (brand.tagline.trim().isNotEmpty)
                Text(
                  brand.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.body(12.5, color: muted),
                ),
              if (brand.locationLine.trim().isNotEmpty)
                _Location(text: brand.locationLine, color: muted),
            ],
          ),
        ),
        const GuestExitButton(),
      ],
    );
  }
}

class _Location extends StatelessWidget {
  const _Location({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_outlined, size: 14, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: p.body(12.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The giant headline. Bistro: bold sans with the second half in the
/// accent. Artisan: the handwritten script, centred.
class _Headline extends StatelessWidget {
  const _Headline({required this.text, required this.artisan, this.size = 40});
  final String text;
  final bool artisan;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    if (artisan) {
      // The handwriting is written on, not faded in.
      return WriteOn(
        delay: const Duration(milliseconds: 520),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: p.hero(size + 6, color: Colors.white),
        ),
      );
    }
    final words = text.trim().split(RegExp(r'\s+'));
    final cut = words.length < 3 ? words.length : words.length ~/ 2;
    final first = words.take(cut).join(' ');
    // The last two words stay together, so a single word never sits alone on
    // the final line.
    final restWords = words.skip(cut).toList();
    final rest = restWords.length < 2
        ? restWords.join(' ')
        : '${restWords.take(restWords.length - 1).join(' ')}\u00A0${restWords.last}';
    final base = p.display(size, color: Colors.white).copyWith(height: 1.05);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: first),
          if (rest.isNotEmpty)
            TextSpan(
              // i18n-ignore: the restaurant's own headline
              text: '\n$rest',
              style: base.copyWith(color: p.accent),
            ),
        ],
      ),
    );
  }
}

/// "Order now · Dine-in at Table 12" / "Pre-order · Schedule for later".
class _ModePill extends StatelessWidget {
  const _ModePill({super.key, required this.mode, required this.primary});
  final GuestServiceMode mode;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.read(context);
    final l = context.l10n;
    final table = l.guestTableNameOf(s);
    final (title, hint) = switch (mode) {
      GuestServiceMode.dineIn => (
        l.guestWelcomeOrderNow,
        table == null ? l.serviceDineIn : l.guestWelcomeDineInAt(table: table),
      ),
      GuestServiceMode.preOrder => (
        l.guestModePreOrder,
        l.guestWelcomePreOrderHint,
      ),
      _ => (l.guestModeLabel(mode), l.guestModeHint(mode)),
    };
    // An outlined main button sits on the dark welcome picture: white.
    final outline = primary && p.buttonOutline;
    final bg = outline
        ? Colors.transparent
        : primary
        ? p.accent
        : p.isDark
        ? p.surfaceAlt
        : p.background;
    final fg = outline
        ? Colors.white
        : primary
        ? p.onAccent
        : p.ink;
    // A dark pill on the dark welcome stage needs a fine light edge to read
    // as a button at all (on the founder's board it sits on a photograph).
    final darkOnDark = !outline && bg.computeLuminance() < 0.1;
    return Material(
      color: bg,
      shape: p.buttonShape(
        outline
            ? const BorderSide(color: Colors.white, width: 1.8)
            : darkOnDark
            ? BorderSide(color: Colors.white.withValues(alpha: 0.28))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => GuestFlow.start(context, chosen: mode),
        child: Container(
          // At least 58 high; a longer line (Hindi) grows the pill.
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: LayoutBuilder(
            builder: (context, c) {
              final titleStyle = p.body(16, weight: FontWeight.w800, color: fg);
              final hintStyle = p.body(14, color: fg.withValues(alpha: 0.72));
              // i18n-ignore: the dot between the two parts
              const dot = '  ·  ';
              // One line when both parts fit (English); otherwise the hint
              // goes under the title, so nothing is squeezed or cut.
              final inline =
                  _lineWidth(context, title, titleStyle) +
                      _lineWidth(context, '$dot$hint', hintStyle) <=
                  c.maxWidth;
              if (!inline) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, textAlign: TextAlign.center, style: titleStyle),
                    Text(hint, textAlign: TextAlign.center, style: hintStyle),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: titleStyle),
                  Text('$dot$hint', style: hintStyle),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// How wide [text] is on one line at the reader's text size.
  static double _lineWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

/// English · हिन्दी · मराठी — only the languages the restaurant wrote guest
/// text in (English is always readable). Glass chips over the picture.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final current = s.languages.contains(s.language)
        ? s.language
        : CopyLanguage.en;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: p.template == StorefrontTemplate.artisanDay
          ? WrapAlignment.center
          : WrapAlignment.start,
      children: [
        for (final l in s.languages)
          Semantics(
            button: true,
            selected: l == current,
            label: l.label,
            child: GestureDetector(
              key: ValueKey('guest-language-${l.key}'),
              onTap: () => s.setLanguage(l),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: l == current
                      ? Colors.white
                      : Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  l.nativeName,
                  style: p.body(
                    12.5,
                    weight: FontWeight.w700,
                    color: l == current ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Content rises and fades in, staggered by [delay] ms (the welcome's own
/// authored sequence, after the dishes have landed).
class _Rise extends StatelessWidget {
  const _Rise({required this.delay, required this.child});
  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) => Reveal(
    delay: Duration(milliseconds: 380 + delay),
    dy: 22,
    duration: GuestMotion.hero,
    child: child,
  );
}
