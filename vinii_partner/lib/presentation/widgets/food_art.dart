import 'package:flutter/material.dart';

import '../guest/look/look.dart';
import '../theme/guest_theme.dart';
import 'dish_art.dart';

/// A menu item's picture. With a photo (`menu_items.image_url`) it shows the
/// photo, fading in over the stage; without one it shows an illustrated dish
/// ([DishArt]) lit on a stage drawn from the surrounding palette, so a menu
/// that has no photos yet still looks deliberate. Nothing here is data: the
/// fallback is purely visual and never pretends to be a photograph.
///
/// Inside the guest runtime the stage takes the storefront's light and
/// colours; in the staff app it is a warm dark stage that dishes pop from.
class FoodArt extends StatelessWidget {
  const FoodArt({
    super.key,
    required this.name,
    this.imageUrl,
    this.emoji,
    this.radius = 16,
    this.emojiSize,
    this.dim = false,
    this.parallax = Offset.zero,
    this.animate = true,
    this.dishScale = 0.78,
    this.dishAlign = const Alignment(0, -0.06),
  });

  final String name;
  final String? imageUrl;

  /// A glyph the merchant chose for this picture (a category tile's emoji).
  /// It replaces the illustration; it is never invented by the app.
  final String? emoji;
  final double radius;
  final double? emojiSize;

  /// Greys the art out (sold out / unavailable).
  final bool dim;

  /// Shifts the dish a little against its stage, for depth while a card is
  /// dragged. Logical pixels; zero for a still picture.
  final Offset parallax;

  /// Allows the dish's own ambient motion (steam). Off for tiny thumbnails.
  final bool animate;

  /// How much of the picture's shorter side the illustrated dish fills, and
  /// where it sits. A hero card sets these so the dish leads and the words
  /// have the lower part to themselves. Photos ignore both.
  final double dishScale;
  final Alignment dishAlign;

  @override
  Widget build(BuildContext context) {
    final illustration = _Illustration(
      name: name,
      emoji: emoji,
      emojiSize: emojiSize,
      parallax: parallax,
      animate: animate,
      dishScale: dishScale,
      dishAlign: dishAlign,
    );
    final art = imageUrl == null
        ? illustration
        : Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) => Stack(
              fit: StackFit.expand,
              children: [
                illustration,
                AnimatedOpacity(
                  opacity: sync || frame != null ? 1 : 0,
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOut,
                  child: child,
                ),
              ],
            ),
            errorBuilder: (context, error, stack) => illustration,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: dim
          ? ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.33, 0.33, 0.33, 0, 0, //
                0.33, 0.33, 0.33, 0, 0,
                0.33, 0.33, 0.33, 0, 0,
                0, 0, 0, 0.6, 0,
              ]),
              child: art,
            )
          : art,
    );
  }

  /// An emoji for a dish name. Word matches only; unknown dishes get a plate.
  static String emojiFor(String name) {
    final n = name.toLowerCase();
    const table = <String, String>{
      'biryani': '🍛',
      'biriyani': '🍛',
      'curry': '🍛',
      'kurma': '🍛',
      'dal': '🍲',
      'thali': '🍱',
      'combo': '🍱',
      'rice': '🍚',
      'pulao': '🍚',
      'pizza': '🍕',
      'pasta': '🍝',
      'penne': '🍝',
      'spaghetti': '🍝',
      'noodle': '🍜',
      'hakka': '🍜',
      'ramen': '🍜',
      'dim sum': '🥟',
      'momo': '🥟',
      'dumpling': '🥟',
      'burger': '🍔',
      'sandwich': '🥪',
      'wrap': '🌯',
      'roll': '🌯',
      'dosa': '🫓',
      'dose': '🫓',
      'roti': '🫓',
      'parota': '🫓',
      'naan': '🫓',
      'idli': '🍘',
      'chicken': '🍗',
      'mutton': '🍖',
      'lamb': '🍖',
      'fish': '🐟',
      'prawn': '🍤',
      'egg': '🥚',
      'paneer': '🧀',
      'salad': '🥗',
      'soup': '🥣',
      'fries': '🍟',
      'corn': '🌽',
      'bread': '🍞',
      'loaf': '🍞',
      'sourdough': '🍞',
      'focaccia': '🍞',
      'croissant': '🥐',
      'bun': '🥯',
      'bagel': '🥯',
      'danish': '🥧',
      'tart': '🥧',
      'pie': '🥧',
      'scroll': '🥮',
      'cinnamon': '🥮',
      'cake': '🍰',
      'babka': '🍰',
      'brownie': '🍫',
      'chocolate': '🍫',
      'tiramisu': '🍰',
      'ice cream': '🍨',
      'kulfi': '🍨',
      'jamun': '🍡',
      'sweet': '🍬',
      'halwa': '🍮',
      'kheer': '🍮',
      'coffee': '☕',
      'latte': '☕',
      'cappuccino': '☕',
      'espresso': '☕',
      'tea': '🍵',
      'chai': '🍵',
      'lassi': '🥛',
      'milk': '🥛',
      'shake': '🥤',
      'soda': '🥤',
      'juice': '🧃',
      'lime': '🍋',
      'lemon': '🍋',
      'mojito': '🍹',
      'water': '💧',
      'beer': '🍺',
      'wine': '🍷',
    };
    for (final e in table.entries) {
      if (n.contains(e.key)) return e.value;
    }
    return '🍽️';
  }
}

/// The lighting of a dish stage, taken from the surrounding palette: inside
/// the guest runtime the storefront's own light and colours, in the staff app
/// a warm dark stage that dishes pop from.
class FoodStageColors {
  const FoodStageColors({
    required this.room,
    required this.centre,
    required this.light,
    required this.dark,
  });

  /// The colour at the edges of the stage.
  final Color room;

  /// The colour where the light falls.
  final Color centre;

  /// The key-light tint (rim light, the pool under a dish).
  final Color light;
  final bool dark;
}

FoodStageColors foodStageOf(BuildContext context) {
  final guest = Theme.of(context).extension<GuestPalette>();
  final dark = guest?.isDark ?? true;
  final light = guest?.keyLight ?? const Color(0xFFE9B36B);
  final room = guest == null
      ? const Color(0xFF17110C)
      : dark
      ? guest.night
      : guest.surfaceAlt;
  return FoodStageColors(
    room: room,
    centre: Color.lerp(room, light, dark ? 0.22 : 0.34)!,
    light: light,
    dark: dark,
  );
}

/// The lit backdrop dishes are shown on: a radial pool of light from the
/// upper left, with [child] drawn over it.
class FoodStageBackdrop extends StatelessWidget {
  const FoodStageBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = foodStageOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.15, -0.28),
          radius: 1.05,
          colors: [c.centre, c.room],
        ),
      ),
      child: child,
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.name,
    required this.emoji,
    required this.emojiSize,
    required this.parallax,
    required this.animate,
    required this.dishScale,
    required this.dishAlign,
  });
  final String name;
  final String? emoji;
  final double? emojiSize;
  final Offset parallax;
  final bool animate;
  final double dishScale;
  final Alignment dishAlign;

  @override
  Widget build(BuildContext context) {
    final stage = foodStageOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.biggest.shortestSide.isFinite
            ? c.biggest.shortestSide
            : 80.0;
        final dish = side * dishScale;
        return FoodStageBackdrop(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The pool of light the dish sits in.
              Align(
                alignment: Alignment(0, dishAlign.y + 0.18),
                child: Container(
                  width: dish * 1.1,
                  height: dish * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        stage.light.withValues(alpha: stage.dark ? 0.20 : 0.28),
                        stage.light.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: dishAlign,
                child: Transform.translate(
                  offset: parallax,
                  child: SizedBox.square(
                    dimension: dish,
                    child: emoji != null
                        ? FittedBox(
                            child: Text(
                              emoji!,
                              style: TextStyle(
                                fontSize: emojiSize ?? dish * 0.7,
                              ),
                            ),
                          )
                        : DishArt(
                            name: name,
                            light: stage.light,
                            onDark: stage.dark,
                            animate: animate && side > 120,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
