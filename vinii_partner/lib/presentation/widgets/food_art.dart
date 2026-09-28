import 'package:flutter/material.dart';

/// A menu item's picture. With a photo (`menu_items.image_url`) it shows the
/// photo; without one it draws a warm gradient with an emoji chosen from the
/// item's name, so a menu that has no photos yet still looks deliberate.
/// Nothing here is data: the fallback is purely visual.
class FoodArt extends StatelessWidget {
  const FoodArt({
    super.key,
    required this.name,
    this.imageUrl,
    this.emoji,
    this.radius = 16,
    this.emojiSize,
    this.dim = false,
  });

  final String name;
  final String? imageUrl;

  /// Forces the emoji (e.g. a category tile's chosen emoji).
  final String? emoji;
  final double radius;
  final double? emojiSize;

  /// Greys the art out (sold out / unavailable).
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final art = imageUrl == null
        ? _Illustration(
            name: name,
            emoji: emoji ?? emojiFor(name),
            emojiSize: emojiSize,
          )
        : Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : _Illustration(
                    name: name,
                    emoji: emoji ?? emojiFor(name),
                    emojiSize: emojiSize,
                  ),
            errorBuilder: (context, error, stack) => _Illustration(
              name: name,
              emoji: emoji ?? emojiFor(name),
              emojiSize: emojiSize,
            ),
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

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.name,
    required this.emoji,
    this.emojiSize,
  });
  final String name;
  final String emoji;
  final double? emojiSize;

  static const _palettes = [
    [Color(0xFF3A2416), Color(0xFFB4642D)],
    [Color(0xFF2A1C12), Color(0xFFD08A3C)],
    [Color(0xFF332016), Color(0xFFC0503A)],
    [Color(0xFF1E2A1A), Color(0xFF7FA04A)],
    [Color(0xFF2B1E2E), Color(0xFFB0587A)],
    [Color(0xFF16242C), Color(0xFF3F8FA8)],
  ];

  @override
  Widget build(BuildContext context) {
    final p =
        _palettes[name.codeUnits.fold<int>(0, (a, c) => a + c) %
            _palettes.length];
    return LayoutBuilder(
      builder: (context, c) {
        final size =
            emojiSize ??
            (c.biggest.shortestSide.isFinite
                ? c.biggest.shortestSide * 0.42
                : 40);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.1),
              radius: 1.1,
              colors: [p[1], p[0]],
            ),
          ),
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(
                fontSize: size,
                shadows: const [
                  Shadow(blurRadius: 24, color: Color(0x66000000)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
