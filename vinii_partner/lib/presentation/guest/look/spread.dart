import 'package:flutter/material.dart';

import '../../../domain/guest_catalog.dart';
import '../../widgets/dish_art.dart';
import '../../widgets/food_art.dart';

/// A small table-spread of up to three different dishes on one lit stage:
/// the face of "All dishes" and of a welcome screen that has no photograph.
/// It uses the restaurant's own dishes (different kinds first, bestsellers
/// first) and draws nothing when there are none.
class DishSpread extends StatelessWidget {
  const DishSpread({super.key, required this.names, this.animate = false});

  final List<String> names;
  final bool animate;

  /// Up to [count] dish names from [items], preferring different kinds of
  /// dish and bestsellers, so the spread looks like a table and not a
  /// repeated plate.
  static List<String> pick(List<GuestItem> items, {int count = 3}) {
    final ranked = [...items]
      ..sort((a, b) {
        final ar = a.item.isRecommended ? 0 : 1;
        final br = b.item.isRecommended ? 0 : 1;
        return ar.compareTo(br);
      });
    final seen = <DishFamily>{};
    final out = <String>[];
    for (final i in ranked) {
      if (seen.add(DishFamily.of(i.item.name))) out.add(i.item.name);
      if (out.length == count) break;
    }
    for (final i in ranked) {
      if (out.length == count) break;
      if (!out.contains(i.item.name)) out.add(i.item.name);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final stage = foodStageOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.biggest.shortestSide.isFinite
            ? c.biggest.shortestSide
            : 160.0;
        Widget dish(String name, double size, Alignment at) => Align(
          alignment: at,
          child: SizedBox.square(
            dimension: size,
            child: DishArt(
              name: name,
              light: stage.light,
              onDark: stage.dark,
              animate: animate,
            ),
          ),
        );
        return FoodStageBackdrop(
          child: names.isEmpty
              ? const SizedBox.expand()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (names.length > 1)
                      dish(
                        names[1],
                        side * 0.52,
                        const Alignment(-0.78, -0.42),
                      ),
                    if (names.length > 2)
                      dish(names[2], side * 0.48, const Alignment(0.8, -0.3)),
                    dish(names[0], side * 0.74, const Alignment(0, 0.2)),
                  ],
                ),
        );
      },
    );
  }
}
