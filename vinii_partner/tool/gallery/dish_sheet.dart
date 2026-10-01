// Dish art sheet: NOT part of the app and never built into it.
//
// Shows every family of illustrated dish at 64, 160 and 320 px, on a dark warm
// stage and on a cream stage, so the paintings can be reviewed side by side.
// Names here are only prompts for the painters; nothing is read from or
// written to any database.
//
//   flutter run -d web-server --web-port 8092 -t tool/gallery/dish_sheet.dart
//
// Query parameters: ?f=curry,rice (only these families)  &animate=0
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vinii_partner/presentation/widgets/dish_art.dart';

void main() => runApp(const DishSheetApp());

class DishSheetApp extends StatelessWidget {
  const DishSheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VINII dish art (sheet)',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFF14100C),
      ),
      home: const DishSheet(),
    );
  }
}

/// A name that exercises each family's main picture.
const _samples = <DishFamily, String>{
  DishFamily.curry: 'Butter Chicken',
  DishFamily.rice: 'Chicken Biryani',
  DishFamily.skewers: 'Paneer Tikka',
  DishFamily.pizza: 'Margherita Pizza',
  DishFamily.pasta: 'Penne Arrabbiata',
  DishFamily.noodles: 'Veg Hakka Noodles',
  DishFamily.flatbread: 'Masala Dosa',
  DishFamily.handheld: 'Veg Burger',
  DishFamily.cake: 'Chocolate Truffle Cake',
  DishFamily.sweet: 'Gulab Jamun',
  DishFamily.drink: 'Fresh Lime Soda',
  DishFamily.cup: 'Cappuccino',
  DishFamily.loaf: 'Sourdough Loaf',
  DishFamily.pastry: 'Pistachio Croissant',
  DishFamily.snack: 'Crispy Corn',
  DishFamily.plate: 'Chef Special',
};

/// Names that pick a different picture inside the same family.
const _variants = <String>[
  'Pepperoni Pizza',
  'Dal Makhani',
  'Palak Paneer',
  'Chicken Korma',
  'Chicken 65',
  'Chicken Tikka',
  'Egg Fried Rice',
  'Butter Naan',
  'Vada Pav',
  'Kathi Roll',
  'Cold Coffee',
  'Masala Chai',
  'Cinnamon Scroll',
  'Blueberry Danish',
  'Almond Croissant',
  'Tiramisu',
  'Honey Fig Tart',
  'Cheesecake',
  'Rasgulla',
  'Vanilla Ice Cream',
  'Mango Lassi',
  'Strawberry Shake',
  'Masala Fries',
  'Samosa',
  'Veg Momos',
  'Onion Pakora',
];

class DishSheet extends StatefulWidget {
  const DishSheet({super.key});

  @override
  State<DishSheet> createState() => _DishSheetState();
}

class _DishSheetState extends State<DishSheet> {
  late bool _animate = Uri.base.queryParameters['animate'] != '0';
  final _name = TextEditingController(text: 'Paneer Butter Masala');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// ?pager=1 shows two families per page with Back / Next (or the arrow
  /// keys), so a review needs one page load; ?p=3 starts on page 3.
  bool get _paged => Uri.base.queryParameters['pager'] == '1';
  late int _page = int.tryParse(Uri.base.queryParameters['p'] ?? '') ?? 0;
  int get _familyPages => (_families.length + 1) ~/ 2;
  int get _pageCount => _familyPages + 2;

  void _go(int delta) =>
      setState(() => _page = (_page + delta).clamp(0, _pageCount - 1));

  List<DishFamily> get _shownFamilies {
    if (!_paged) return _families;
    if (_page >= _familyPages) return const [];
    final from = _page * 2;
    return _families.sublist(from, (from + 2).clamp(0, _families.length));
  }

  List<String> get _shownVariants {
    if (!_paged) return _variantNames;
    final i = _page - _familyPages;
    if (i < 0) return const [];
    final from = (i * 14).clamp(0, _variants.length);
    return _variants.sublist(from, (from + 14).clamp(0, _variants.length));
  }

  /// ?bare=1 hides the title and the name box, for reviewing a few families.
  bool get _bare => _paged || Uri.base.queryParameters['bare'] == '1';

  /// Variants show unless ?f= picks families; ?variants=1 forces them, and
  /// ?vp=0 / ?vp=1 pages through them.
  bool get _showVariants =>
      Uri.base.queryParameters['variants'] == '1' ||
      Uri.base.queryParameters['f'] == null;

  List<String> get _variantNames {
    final page = int.tryParse(Uri.base.queryParameters['vp'] ?? '');
    if (page == null) return _variants;
    final from = (page * 14).clamp(0, _variants.length);
    return _variants.sublist(from, (from + 14).clamp(0, _variants.length));
  }

  List<DishFamily> get _families {
    final only = Uri.base.queryParameters['f'];
    if (only == null || only.isEmpty) return DishFamily.values;
    final keep = only.split(',').map((e) => e.trim()).toSet();
    return [
      for (final f in DishFamily.values)
        if (keep.contains(f.name)) f,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final typed = _name.text;
    final showVariants = _paged ? _shownVariants.isNotEmpty : _showVariants;
    final page = SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
        children: [
          if (!_bare) ...[
            Wrap(
              spacing: 28,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Dish art',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF3E7D3),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _animate,
                      onChanged: (v) => setState(() => _animate = v),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Animate steam',
                      style: TextStyle(color: Color(0xFFD9C7A8)),
                    ),
                  ],
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _name,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Try a dish name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Text(
                  typed.trim().isEmpty
                      ? ''
                      : 'drawn as ${DishFamily.of(typed).name}',
                  style: const TextStyle(color: Color(0xFFD9C7A8)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final dark in const [true, false])
                  _Stage(
                    dark: dark,
                    size: 200,
                    child: DishArt(
                      name: typed,
                      onDark: dark,
                      animate: _animate,
                    ),
                  ),
              ],
            ),
          ],
          for (final f in _shownFamilies) ...[
            const SizedBox(height: 28),
            Text(
              f.name,
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD9C7A8),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final dark in const [true, false])
                  _FamilyPanel(
                    family: f,
                    name: _samples[f] ?? f.name,
                    dark: dark,
                    animate: _animate,
                  ),
              ],
            ),
          ],
          if (showVariants) ...[
            const SizedBox(height: 36),
            const Text(
              'variants chosen by name',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD9C7A8),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final v in _shownVariants)
                  _VariantCell(name: v, animate: _animate),
              ],
            ),
          ],
        ],
      ),
    );
    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              page,
              if (_paged)
                Positioned(
                  top: 6,
                  right: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _go(-1),
                        child: const Text('Back'),
                      ),
                      Text(
                        '${_page + 1} / $_pageCount',
                        style: const TextStyle(color: Color(0xFFD9C7A8)),
                      ),
                      TextButton(
                        onPressed: () => _go(1),
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card standing in for the guest card behind a dish: a dark warm stage lit
/// from the upper left, or flat cream.
class _Stage extends StatelessWidget {
  const _Stage({required this.dark, required this.child, required this.size});
  final bool dark;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Container(
      width: size + 32,
      height: size + 32,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: dark ? null : const Color(0xFFF6F0E7),
        gradient: dark
            ? const RadialGradient(
                center: Alignment(-.3, -.5),
                radius: 1.2,
                colors: [Color(0xFF3A2A1B), Color(0xFF0F0B08)],
              )
            : null,
      ),
      child: Stack(
        children: [
          if (dark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: const RadialGradient(
                    center: Alignment(-.35, -.45),
                    radius: .75,
                    colors: [Color(0x40FFC27A), Color(0x00FFC27A)],
                  ),
                ),
              ),
            ),
          Center(
            child: SizedBox.square(dimension: size, child: child),
          ),
        ],
      ),
    );
  }
}

/// One family at 320, 160 and 64 px on one stage.
class _FamilyPanel extends StatelessWidget {
  const _FamilyPanel({
    required this.family,
    required this.name,
    required this.dark,
    required this.animate,
  });
  final DishFamily family;
  final String name;
  final bool dark;
  final bool animate;

  Widget _art(double size) => SizedBox.square(
    dimension: size,
    child: DishArt(name: name, family: family, onDark: dark, animate: animate),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: dark ? null : const Color(0xFFF6F0E7),
        gradient: dark
            ? const RadialGradient(
                center: Alignment(-.5, -.6),
                radius: 1.3,
                colors: [Color(0xFF3A2A1B), Color(0xFF0F0B08)],
              )
            : null,
      ),
      child: Stack(
        children: [
          if (dark)
            const Positioned(
              left: -40,
              top: -40,
              child: SizedBox(
                width: 380,
                height: 380,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x38FFC27A), Color(0x00FFC27A)],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _art(320),
              const SizedBox(width: 16),
              Column(
                children: [_art(160), const SizedBox(height: 16), _art(64)],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A named dish on both stages at 120 px, to show what the name picks.
class _VariantCell extends StatelessWidget {
  const _VariantCell({required this.name, required this.animate});
  final String name;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final family = DishFamily.of(name);
    return SizedBox(
      width: 272,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name  ·  ${family.name}',
            style: const TextStyle(fontSize: 11, color: Color(0xFFD9C7A8)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final dark in const [true, false]) ...[
                Expanded(
                  child: _Stage(
                    dark: dark,
                    size: 100,
                    child: DishArt(name: name, onDark: dark, animate: animate),
                  ),
                ),
                if (dark) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
