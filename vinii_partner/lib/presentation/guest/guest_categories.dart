import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/guest_catalog.dart';
import '../../domain/storefront.dart';
import '../theme/guest_theme.dart';
import '../widgets/food_art.dart';
import 'guest_effects.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';

/// Board 1 #3 (photo tile grid) or Board 2 #4 (curved wheel), picked by the
/// storefront's `categoryStyle`. "All dishes" always comes first; the
/// categories are exactly the catalog's visible ones, in its order.
class GuestCategoriesScreen extends StatelessWidget {
  const GuestCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final wheel = s.definition.categoryStyle == CategoryStyle.wheel;
    final hasDiscover =
        s.catalog.chefsPicks.isNotEmpty || s.catalog.limitedToday.isNotEmpty;
    return GuestPage(
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
              wheel
                  ? 'Swipe to explore categories'
                  : 'What are you in the mood for?',
              style: wheel ? p.hero(30) : p.display(28),
            ),
          ),
          Expanded(child: wheel ? const _Wheel() : const _Grid()),
        ],
      ),
    );
  }
}

/// A category's picture: its first dish with a photo, else the illustrated
/// fallback with the category's emoji.
Widget categoryArt(
  GuestCategory? c,
  GuestCatalog catalog, {
  double radius = 0,
}) {
  final items = c?.items ?? catalog.allItems;
  final photo = items.where((i) => i.item.imageUrl != null).firstOrNull;
  return FoodArt(
    name: photo?.item.name ?? c?.category.name ?? 'All dishes',
    imageUrl: photo?.item.imageUrl,
    emoji: photo == null ? (c?.emoji ?? (c == null ? '🍽️' : null)) : null,
    radius: radius,
  );
}

class _Grid extends StatelessWidget {
  const _Grid();

  @override
  Widget build(BuildContext context) {
    final s = GuestScope.of(context);
    final cats = <GuestCategory?>[null, ...s.catalog.categories];
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.92,
      ),
      itemCount: cats.length,
      itemBuilder: (context, i) => _Tile(category: cats[i], index: i),
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 60),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(
        scale: 0.9 + 0.1 * v,
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: GestureDetector(
        onTap: () => GuestFlow.browse(context, category),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: all ? Border.all(color: p.accent, width: 2.5) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.4 : 0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(all ? 21.5 : 24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                categoryArt(category, s.catalog),
                const PhotoScrim(strength: 0.8),
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
                        categoryArt(cats[i], s.catalog),
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
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? p.accent : p.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active ? p.accent : p.border,
                          ),
                        ),
                        child: Text(
                          c == null
                              ? '🍽️'
                              : c.emoji ?? FoodArt.emojiFor(c.category.name),
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
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

/// The floating "3 items · ₹1,440 — View order" bar.
class CartBar extends StatelessWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    return Material(
      color: p.accent,
      shape: const StadiumBorder(),
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
                child: Text(
                  '${s.itemCount}',
                  style: p.price(16, color: p.onAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'View order (${s.itemCount})',
                  style: p.body(16, weight: FontWeight.w700, color: p.onAccent),
                ),
              ),
              Text(
                rupees(s.estimate.itemTotal),
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
                decoration: const InputDecoration(
                  hintText: 'Search dishes',
                  prefixIcon: Icon(Icons.search_rounded),
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
