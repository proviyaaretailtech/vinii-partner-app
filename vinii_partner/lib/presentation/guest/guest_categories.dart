import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/guest_catalog.dart';
import '../../domain/storefront.dart';
import '../theme/guest_theme.dart';
import '../widgets/dish_art.dart';
import '../widgets/food_art.dart';
import 'guest_effects.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';
import 'look/look.dart';
import 'look/motion.dart';
import 'look/spread.dart';

/// Board 1 #3 (photo tile grid) or Board 2 #4 (curved wheel), picked by the
/// storefront's `categoryStyle`. "All dishes" always comes first; the
/// categories are exactly the catalog's visible ones, in its order.
class GuestCategoriesScreen extends StatelessWidget {
  const GuestCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final t = GuestCopy.of(context);
    final wheel = s.definition.categoryStyle == CategoryStyle.wheel;
    final hasDiscover =
        s.catalog.chefsPicks.isNotEmpty || s.catalog.limitedToday.isNotEmpty;
    // A wide screen shows more tiles per row; the wheel stays a carousel.
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return GuestPage(
      maxWidth: wide ? (wheel ? 640 : 1040) : 480,
      bottom: s.lines.isEmpty ? null : const CartBar(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GuestTopBar(
            trailing: [
              if (hasDiscover)
                RoundIcon(
                  icon: Icons.auto_awesome_rounded,
                  size: 40,
                  tooltip: 'Specials',
                  onTap: () => GuestFlow.discover(context),
                ),
              const SizedBox(width: 8),
              RoundIcon(
                icon: Icons.search_rounded,
                size: 40,
                tooltip: 'Search',
                onTap: () => showGuestSearch(context),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Text(
              // The wheel keeps its own instruction unless the restaurant
              // wrote its own menu heading.
              wheel
                  ? t.own('menu.title') ?? 'Swipe to explore categories'
                  : t('menu.title'),
              style: wheel ? p.hero(30) : p.display(28),
            ),
          ),
          Expanded(child: wheel ? const _Wheel() : const _Grid()),
        ],
      ),
    );
  }
}

/// A category's picture: the one uploaded for it in the CMS, else its first
/// dish with a photo, else the glyph the restaurant chose for it, else an
/// illustration of one of its own dishes ("All dishes" shows a small spread of
/// three different ones). A picture that fails to load turns back into the
/// illustration.
Widget categoryArt(
  BuildContext context,
  GuestCategory? c,
  GuestCatalog catalog, {
  double radius = 0,
  bool animate = true,
}) {
  final picture = c == null
      ? null
      : GuestScope.mediaUrlOf(
          context,
          GuestScope.read(context).definition.media.categories[c.category.id],
        );
  if (c != null && picture != null) {
    return FoodArt(
      key: ValueKey('category-picture-${c.category.id}'),
      name: _representative(c.items) ?? c.category.name,
      imageUrl: picture,
      emoji: c.emoji,
      radius: radius,
      animate: animate,
    );
  }
  final items = c?.items ?? catalog.allItems;
  final photo = items.where((i) => i.item.imageUrl != null).firstOrNull;
  if (photo != null) {
    return FoodArt(
      name: photo.item.name,
      imageUrl: photo.item.imageUrl,
      radius: radius,
      animate: animate,
    );
  }
  if (c?.emoji != null) {
    return FoodArt(
      name: c!.category.name,
      emoji: c.emoji,
      radius: radius,
      animate: animate,
    );
  }
  if (c == null) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DishSpread(names: DishSpread.pick(items), animate: animate),
    );
  }
  return FoodArt(
    name: _representative(items) ?? c.category.name,
    radius: radius,
    animate: animate,
    dishScale: 0.92,
    dishAlign: const Alignment(0, -0.28),
  );
}

/// The dish that stands for a category: its bestseller, else its first.
String? _representative(List<GuestItem> items) =>
    (items.where((i) => i.item.isRecommended).firstOrNull ?? items.firstOrNull)
        ?.item
        .name;

class _Grid extends StatelessWidget {
  const _Grid();

  @override
  Widget build(BuildContext context) {
    final s = GuestScope.of(context);
    final cats = <GuestCategory?>[null, ...s.catalog.categories];
    return LayoutBuilder(
      builder: (context, c) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          // Two on a phone; one more for every ~230 px beyond that.
          crossAxisCount: (c.maxWidth / 230).floor().clamp(2, 5),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.92,
        ),
        itemCount: cats.length,
        itemBuilder: (context, i) => _Tile(category: cats[i], index: i),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.category, required this.index});
  final GuestCategory? category;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.read(context);
    final all = category == null;
    return Reveal(
      index: index,
      dy: 20,
      scaleFrom: 0.94,
      child: Pressable(
        hoverScale: 1.025,
        child: GestureDetector(
          onTap: () => GuestFlow.browse(context, category),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: all ? Border.all(color: p.accent, width: 2.5) : null,
              boxShadow: p.lift(0.6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(all ? 21.5 : 24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  categoryArt(context, category, s.catalog, animate: false),
                  const PhotoScrim(strength: 0.82),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          all ? 'All dishes' : category!.category.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: p.display(17, color: Colors.white),
                        ),
                        Text(
                          '${(category?.items ?? s.catalog.allItems).length} dishes',
                          style: p.body(
                            12,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The curved carousel: the centre card large, neighbours smaller, tilted
/// and lowered, with an icon tab row underneath.
class _Wheel extends StatefulWidget {
  const _Wheel();

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  final _pages = PageController(viewportFraction: 0.64);
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final cats = <GuestCategory?>[null, ...s.catalog.categories];
    final current = cats[_index.clamp(0, cats.length - 1)];
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: cats.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => AnimatedBuilder(
              animation: _pages,
              builder: (context, child) {
                final page = _pages.hasClients && _pages.position.haveDimensions
                    ? _pages.page ?? _index.toDouble()
                    : _index.toDouble();
                final d = (i - page).clamp(-1.5, 1.5);
                return Transform.translate(
                  offset: Offset(0, 36 * d * d),
                  child: Transform.rotate(
                    angle: d * 0.14,
                    child: Transform.scale(
                      scale: 1 - 0.16 * d.abs(),
                      child: child,
                    ),
                  ),
                );
              },
              child: GestureDetector(
                onTap: () => i == _index
                    ? GuestFlow.browse(context, cats[i])
                    : _pages.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        categoryArt(context, cats[i], s.catalog),
                        const PhotoScrim(strength: 0.75),
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 20,
                          child: Text(
                            cats[i]?.category.name ?? 'All dishes',
                            maxLines: 2,
                            style: p.display(22, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GuestButton(
            label: 'Explore ${current?.category.name ?? 'all dishes'}',
            trailingArrow: true,
            dense: true,
            onTap: () => GuestFlow.browse(context, current),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 86,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cats.length,
            itemBuilder: (context, i) {
              final active = i == _index;
              final c = cats[i];
              return GestureDetector(
                onTap: () => _pages.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                ),
                child: SizedBox(
                  width: 74,
                  child: Column(
                    children: [
                      _Glyph(category: c, active: active),
                      const SizedBox(height: 6),
                      Text(
                        c?.category.name ?? 'All',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: p.body(
                          11.5,
                          weight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? p.ink : p.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The round glyph in the wheel's tab row: the restaurant's own emoji when
/// it chose one, otherwise a small illustration of the category's dish.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.category, required this.active});
  final GuestCategory? category;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.read(context);
    final stage = foodStageOf(context);
    final items = category?.items ?? s.catalog.allItems;
    final emoji = category?.emoji;
    return AnimatedContainer(
      duration: GuestMotion.base,
      curve: GuestMotion.arrive,
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.2, -0.3),
          colors: [stage.centre, stage.room],
        ),
        border: Border.all(
          color: active ? p.accent : p.hairline,
          width: active ? 2.4 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: emoji != null
          ? Text(emoji, style: const TextStyle(fontSize: 22))
          : SizedBox.square(
              dimension: 38,
              child: DishArt(
                name: _representative(items) ?? 'plate',
                family: category == null && items.isEmpty
                    ? DishFamily.plate
                    : null,
                light: stage.light,
                onDark: stage.dark,
                animate: false,
              ),
            ),
    );
  }
}

/// The floating "3 items · ₹1,440 — View order" bar.
class CartBar extends StatelessWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final t = GuestCopy.of(context);
    // Always filled: it floats over the menu. Its corners follow the theme.
    return Material(
      color: p.accent,
      shape: p.buttonShape(),
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      shadowColor: p.accent.withValues(alpha: 0.4),
      child: InkWell(
        onTap: () => GuestFlow.toOrder(context),
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.onAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: AnimatedSwitcher(
                  duration: GuestMotion.base,
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: a,
                      curve: Curves.easeOutBack,
                    ),
                    child: FadeTransition(opacity: a, child: child),
                  ),
                  child: Text(
                    '${s.itemCount}',
                    key: ValueKey(s.itemCount),
                    style: p.price(16, color: p.onAccent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${t('cart.view')} (${s.itemCount})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.body(16, weight: FontWeight.w700, color: p.onAccent),
                ),
              ),
              CountUp(
                value: s.estimate.itemTotal,
                format: rupees,
                duration: GuestMotion.base,
                style: p.price(16, color: p.onAccent),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, color: p.onAccent),
              const SizedBox(width: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search every visible dish by name, opened from the magnifier.
Future<void> showGuestSearch(BuildContext context) async {
  final picked = await showModalBottomSheet<GuestItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _SearchSheet(),
  );
  if (picked != null && context.mounted) {
    await GuestFlow.openItem(context, picked);
  }
}

class _SearchSheet extends StatefulWidget {
  const _SearchSheet();

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final q = _q.trim().toLowerCase();
    final results = q.isEmpty
        ? const <GuestItem>[]
        : s.catalog.allItems
              .where(
                (i) =>
                    i.item.name.toLowerCase().contains(q) ||
                    (i.item.description ?? '').toLowerCase().contains(q),
              )
              .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                style: p.body(16),
                decoration: InputDecoration(
                  hintText: GuestCopy.of(context)('menu.search'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final i in results)
                    ListTile(
                      leading: SizedBox.square(
                        dimension: 48,
                        child: FoodArt(
                          name: i.item.name,
                          imageUrl: i.item.imageUrl,
                          radius: 14,
                        ),
                      ),
                      title: Text(
                        i.item.name,
                        style: p.body(15, weight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        i.category.name,
                        style: p.body(12.5, color: p.inkMuted),
                      ),
                      trailing: Text(rupees(i.item.price), style: p.price(15)),
                      onTap: () => Navigator.of(context).pop(i),
                    ),
                  if (q.isNotEmpty && results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Nothing matches "$_q".',
                        textAlign: TextAlign.center,
                        style: p.body(14, color: p.inkMuted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
