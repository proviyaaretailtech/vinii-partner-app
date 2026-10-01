import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/presentation/widgets/dish_art.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Center(child: child),
  ),
);

/// Renders [art] at [size] logical pixels and returns its RGBA bytes.
Future<List<int>> _pixels(
  WidgetTester tester,
  Widget art, {
  double size = 160,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    _host(
      RepaintBoundary(
        key: key,
        child: SizedBox.square(dimension: size, child: art),
      ),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

double _coverage(List<int> rgba) {
  var painted = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] > 12) painted++;
  }
  return painted / (rgba.length / 4);
}

void main() {
  group('DishFamily.of', () {
    const cases = <String, DishFamily>{
      'Chicken Biryani': DishFamily.rice,
      'Paneer Tikka': DishFamily.skewers,
      'Chicken 65': DishFamily.skewers,
      'Penne Arrabbiata': DishFamily.pasta,
      'Masala Dosa': DishFamily.flatbread,
      'Gulab Jamun': DishFamily.sweet,
      'Cold Coffee': DishFamily.cup,
      'Fresh Lime Soda': DishFamily.drink,
      'Crispy Corn': DishFamily.snack,
      'Butter Chicken': DishFamily.curry,
      'Dal Makhani': DishFamily.curry,
      'Veg Hakka Noodles': DishFamily.noodles,
      'Margherita Pizza': DishFamily.pizza,
      'Pepperoni Pizza': DishFamily.pizza,
      'Tiramisu': DishFamily.cake,
      'Cinnamon Scroll': DishFamily.pastry,
      'Pistachio Croissant': DishFamily.pastry,
      'Sourdough Loaf': DishFamily.loaf,
      'Honey Fig Tart': DishFamily.cake,
      'Vada Pav': DishFamily.handheld,
      'Egg Fried Rice': DishFamily.rice,
      'Zzz': DishFamily.plate,
      // The rest of the pilot menu and the bakery board.
      'Almond Croissant': DishFamily.pastry,
      'Blueberry Danish': DishFamily.pastry,
      'Raspberry Danish': DishFamily.pastry,
      'Iced Latte': DishFamily.cup,
      // Words only: "starter" must not turn into a tart, "steak" into tea.
      'Veg Starter Platter': DishFamily.plate,
      'Grilled Steak': DishFamily.skewers,
      'Sweet Corn Soup': DishFamily.snack,
      'Milkshake': DishFamily.drink,
      'Paneer Tikka Masala': DishFamily.curry,
      'Pav Bhaji': DishFamily.curry,
      'Spring Rolls': DishFamily.snack,
      'Chicken Biryani Combo': DishFamily.rice,
    };
    cases.forEach((name, family) {
      test('"$name" is drawn as ${family.name}', () {
        expect(DishFamily.of(name), family);
      });
    });

    test('empty and punctuation-only names get the plate', () {
      expect(DishFamily.of(''), DishFamily.plate);
      expect(DishFamily.of('  --  '), DishFamily.plate);
    });

    test('only hot dishes steam', () {
      expect(DishFamily.curry.steams, isTrue);
      expect(DishFamily.cup.steams, isTrue);
      expect(DishFamily.pizza.steams, isFalse);
      expect(DishFamily.drink.steams, isFalse);
      expect(DishFamily.cake.steams, isFalse);
    });
  });

  group('DishArt paints without errors', () {
    for (final family in DishFamily.values) {
      testWidgets('${family.name} at 24, 160 and 400, both stages', (
        tester,
      ) async {
        for (final size in const [24.0, 160.0, 400.0]) {
          for (final onDark in const [true, false]) {
            for (final animate in const [true, false]) {
              await tester.pumpWidget(
                _host(
                  SizedBox.square(
                    dimension: size,
                    child: DishArt(
                      name: 'Test ${family.name}',
                      family: family,
                      onDark: onDark,
                      animate: animate,
                    ),
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 900));
              expect(
                tester.takeException(),
                isNull,
                reason: '${family.name} $size onDark=$onDark animate=$animate',
              );
            }
          }
        }
      });
    }

    testWidgets('name-driven variants all paint', (tester) async {
      const names = [
        'Pepperoni Pizza',
        'Margherita Pizza',
        'Dal Makhani',
        'Palak Paneer',
        'Chicken Korma',
        'Paneer Butter Masala',
        'Egg Fried Rice',
        'Mutton Biryani',
        'Chicken 65',
        'Chicken Tikka',
        'Seekh Kebab',
        'Cold Coffee',
        'Cappuccino',
        'Masala Chai',
        'Butter Naan',
        'Vada Pav',
        'Veg Burger',
        'Kathi Roll',
        'Cinnamon Scroll',
        'Blueberry Danish',
        'Almond Croissant',
        'Pistachio Croissant',
        'Tiramisu',
        'Cheesecake',
        'Honey Fig Tart',
        'Chocolate Brownie',
        'Rasgulla',
        'Vanilla Ice Cream',
        'Mango Lassi',
        'Strawberry Shake',
        'Orange Juice',
        'Cola',
        'Masala Fries',
        'Samosa',
        'Veg Momos',
        'Crispy Corn',
        'Onion Pakora',
        'Penne Alfredo',
        'Veg Hakka Noodles',
      ];
      for (final name in names) {
        for (final onDark in const [true, false]) {
          await tester.pumpWidget(
            _host(
              SizedBox.square(
                dimension: 200,
                child: DishArt(name: name, onDark: onDark),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: name);
        }
      }
    });

    testWidgets('falls back to 160 when nothing bounds it', (tester) async {
      await tester.pumpWidget(
        _host(const UnconstrainedBox(child: DishArt(name: 'Paneer Tikka'))),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(DishArt)), const Size.square(160));
    });
  });

  group('DishArt looks right', () {
    testWidgets('every family fills a good share of a transparent frame', (
      tester,
    ) async {
      for (final family in DishFamily.values) {
        final px = await _pixels(
          tester,
          DishArt(name: 'Test ${family.name}', family: family, animate: false),
        );
        final share = _coverage(px);
        expect(share, greaterThan(.22), reason: '${family.name} looks empty');
        expect(share, lessThan(.85), reason: '${family.name} overflows');
        // The card behind supplies the atmosphere: the corners stay clear.
        const w = 160;
        for (final i in const [0, w - 1, w * (w - 1), w * w - 1]) {
          expect(px[i * 4 + 3], lessThan(12), reason: '${family.name} corner');
        }
      }
    });

    testWidgets('the same name is always drawn the same way', (tester) async {
      Future<List<int>> draw(String name) =>
          _pixels(tester, DishArt(name: name, animate: false));
      final a = await draw('Chicken Biryani');
      final b = await draw('Chicken Biryani');
      expect(a, b);
    });

    testWidgets('different dishes and stages are drawn differently', (
      tester,
    ) async {
      final tikka = await _pixels(
        tester,
        const DishArt(name: 'Paneer Tikka', animate: false),
      );
      final chicken = await _pixels(
        tester,
        const DishArt(name: 'Chicken Tikka', animate: false),
      );
      final onLight = await _pixels(
        tester,
        const DishArt(name: 'Paneer Tikka', onDark: false, animate: false),
      );
      expect(tikka, isNot(chicken));
      expect(tikka, isNot(onLight));
    });
  });

  group('DishArt motion', () {
    testWidgets('steam runs only when asked for and allowed', (tester) async {
      const steaming = DishArt(name: 'Butter Chicken', animate: true);
      await tester.pumpWidget(
        _host(const SizedBox.square(dimension: 160, child: steaming)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(
        _host(
          const SizedBox.square(
            dimension: 160,
            child: DishArt(name: 'Butter Chicken', animate: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(
        _host(
          const SizedBox.square(dimension: 160, child: steaming),
          reduceMotion: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a dish that is served cold never animates', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox.square(
            dimension: 160,
            child: DishArt(name: 'Tiramisu', animate: true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the still life and the steam are separate layers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox.square(
            dimension: 160,
            child: DishArt(name: 'Butter Chicken'),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(DishArt),
          matching: find.byType(RepaintBoundary),
        ),
        findsNWidgets(2),
      );
    });
  });

  // A developer aid, skipped unless asked for: it paints some dishes on both
  // stages into one PNG so they can be looked at without a browser.
  //   DISH_SHEET_PNG=/tmp/dishes.png flutter test test/dish_art_test.dart \
  //     --plain-name "contact sheet"
  // DISH_SHEET_NAMES takes a comma-separated list of dish names.
  group('contact sheet', () {
    final out = Platform.environment['DISH_SHEET_PNG'];
    final names =
        (Platform.environment['DISH_SHEET_NAMES'] ??
                'Penne Arrabbiata,Chicken Biryani,Butter Naan,'
                    'Vanilla Ice Cream,Sourdough Loaf')
            .split(',');
    testWidgets('writes the pictures to DISH_SHEET_PNG', (tester) async {
      tester.view.physicalSize = Size(names.length * 264.0 + 8, 2 * 264.0 + 8);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget stage(String name, bool dark) => Container(
        width: 256,
        height: 256,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: dark ? null : const Color(0xFFF6F0E7),
          gradient: dark
              ? const RadialGradient(
                  center: Alignment(-.3, -.5),
                  radius: 1.2,
                  colors: [Color(0xFF3A2A1B), Color(0xFF0F0B08)],
                )
              : null,
        ),
        child: DishArt(name: name, onDark: dark, animate: false),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: const Color(0xFF14100C),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final dark in const [true, false])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [for (final n in names) stage(n, dark)],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(out!).writeAsBytes(data!.buffer.asUint8List());
      });
    }, skip: out == null);
  });
}
