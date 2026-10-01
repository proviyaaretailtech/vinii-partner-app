import 'package:flutter/material.dart';

import '../../../domain/pos_order.dart';
import '../../theme/guest_theme.dart';
import '../../widgets/food_art.dart';
import '../guest_widgets.dart';
import 'look.dart';
import 'motion.dart';

/// The dishes in an order as round pictures laid over one another, each with
/// its quantity, so the moments around ordering (checkout, placed, served)
/// show the food and not only a count. Up to five; the rest are counted.
class DishTray extends StatelessWidget {
  const DishTray({super.key, required this.lines, this.size = 84});

  final List<CartLine> lines;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    if (lines.isEmpty) return const SizedBox.shrink();
    final shown = lines.take(5).toList();
    final step = size * 0.7;
    final width = size + step * (shown.length - 1);
    return Reveal(
      dy: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width,
            height: size + 8,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final (i, l) in shown.indexed)
                  Positioned(
                    left: i * step,
                    top: 0,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: p.background, width: 3),
                        boxShadow: p.lift(0.5),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: FoodArt(
                              name: l.name,
                              imageUrl: s.catalog.item(l.itemId)?.item.imageUrl,
                              radius: size,
                              animate: false,
                            ),
                          ),
                          if (l.qty > 1)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: p.accent,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: p.background,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  '×${l.qty}',
                                  style: p.price(11.5, color: p.onAccent),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (lines.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${lines.length - shown.length} more',
                style: p.body(12.5, color: p.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}
