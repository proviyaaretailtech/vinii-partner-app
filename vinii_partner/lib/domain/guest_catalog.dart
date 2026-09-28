import 'menu.dart';
import 'storefront.dart';

/// What a guest can see and order: the organization's real menu filtered
/// and arranged by its storefront definition. Pure, so the guest runtime,
/// Studio's preview and tests all agree.
class GuestCatalog {
  GuestCatalog({required this.menu, required this.definition, DateTime? now})
    : _now = now ?? DateTime.now() {
    _build();
  }

  final MenuSnapshot menu;
  final StorefrontDefinition definition;
  final DateTime _now;

  late final List<GuestCategory> categories;
  late final Map<String, GuestItem> _items;

  List<GuestItem> get allItems => [for (final c in categories) ...c.items];

  GuestItem? item(String id) => _items[id];

  /// "Chef's picks" that still exist and are on sale.
  List<GuestItem> get chefsPicks => definition.features.chefsPicks
      ? [for (final id in definition.chefsPicks) ?_items[id]]
      : const [];

  /// "Limited today" offers that have not ended yet, soonest first.
  List<({GuestItem item, DateTime endsAt})> get limitedToday {
    if (!definition.features.limitedToday) return const [];
    final list = [
      for (final o in definition.limitedToday)
        if (_items[o.itemId] != null && o.endsOn(_now).isAfter(_now))
          (item: _items[o.itemId]!, endsAt: o.endsOn(_now)),
    ]..sort((a, b) => a.endsAt.compareTo(b.endsAt));
    return list;
  }

  bool get isEmpty => categories.isEmpty;

  void _build() {
    final byId = {for (final c in menu.categories) c.id: c};
    final unplaced =
        menu.categories
            .where((c) => definition.categoryPresentation(c.id) == null)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final ordered = <MenuCategory>[
      for (final p in definition.categories)
        if (byId[p.categoryId] != null) byId[p.categoryId]!,
      ...unplaced,
    ];
    final cats = <GuestCategory>[];
    final items = <String, GuestItem>{};
    for (final c in ordered) {
      final p = definition.categoryPresentation(c.id);
      if (p != null && !p.visible) continue;
      final guestItems = [
        for (final i in menu.itemsIn(c.id))
          if (_sellable(i)) _guestItem(i, c),
      ];
      if (guestItems.isEmpty) continue;
      for (final g in guestItems) {
        items[g.item.id] = g;
      }
      cats.add(GuestCategory(category: c, emoji: p?.emoji, items: guestItems));
    }
    categories = cats;
    _items = items;
  }

  /// On sale in the POS, not hidden from the storefront, and priced above
  /// ₹0 (the same rule One Local uses for its catalogue).
  bool _sellable(MenuItem i) =>
      i.isAvailable && i.price > 0 && !definition.presentationOf(i.id).hidden;

  GuestItem _guestItem(MenuItem i, MenuCategory c) {
    final p = definition.presentationOf(i.id);
    final tags = [
      if (i.isRecommended && !p.tags.contains('Bestseller')) 'Bestseller',
      ...p.tags,
    ];
    return GuestItem(item: i, category: c, presentation: p, tags: tags);
  }
}

class GuestCategory {
  const GuestCategory({
    required this.category,
    required this.items,
    this.emoji,
  });
  final MenuCategory category;
  final String? emoji;
  final List<GuestItem> items;
}

class GuestItem {
  const GuestItem({
    required this.item,
    required this.category,
    required this.presentation,
    required this.tags,
  });
  final MenuItem item;
  final MenuCategory category;
  final ItemPresentation presentation;

  /// Chips on the card: "Bestseller" (from the POS flag) plus Studio's tags.
  final List<String> tags;
}
