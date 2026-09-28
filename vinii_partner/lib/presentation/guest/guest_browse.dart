import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/guest_catalog.dart';
import '../theme/guest_theme.dart';
import 'guest_categories.dart';
import 'guest_deck.dart';
import 'guest_flow.dart';
import 'guest_list.dart';
import 'guest_widgets.dart';

/// Board 1 #4 / Board 2 #6 & #15: the main browsing screen. The header
/// carries the brand, the current category and the budget ring; the body is
/// the swipe deck, or a plain list when the storefront turned the deck off;
/// the bottom strip switches category in place.
class GuestBrowseScreen extends StatefulWidget {
  const GuestBrowseScreen({super.key, this.category});

  /// Null = "All dishes".
  final GuestCategory? category;

  @override
  State<GuestBrowseScreen> createState() => _GuestBrowseScreenState();
}

class _GuestBrowseScreenState extends State<GuestBrowseScreen> {
  late GuestCategory? _category = widget.category;

  @override
  Widget build(BuildContext context) {
    final s = GuestScope.of(context);
    final items = _category?.items ?? s.catalog.allItems;
    final label = _category?.category.name ?? 'All dishes';
    return GuestPage(
      child: Column(
        children: [
          _Header(categoryName: label),
          if (s.budgetStatus != null) const _BudgetStrip(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: s.features.swipeDeck
                  ? SwipeDeck(
                      key: ValueKey('deck-${_category?.category.id}'),
                      items: items,
                      categoryName: label,
                    )
                  : DishList(
                      key: ValueKey('list-${_category?.category.id}'),
                      items: items,
                    ),
            ),
          ),
          if (s.lines.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: CartBar(),
            ),
          _CategoryStrip(
            selected: _category,
            onSelect: (c) => setState(() => _category = c),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.categoryName});
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final hasDiscover =
        s.catalog.chefsPicks.isNotEmpty || s.catalog.limitedToday.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
      child: Row(
        children: [
          RoundIcon(
            icon: Icons.arrow_back_ios_new_rounded,
            size: 40,
            tooltip: 'Back',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
          const GuestLogo(size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.definition.brand.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.body(12.5, color: p.inkMuted),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    categoryName,
                    key: ValueKey(categoryName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: p.display(19, color: p.isDark ? p.accent : p.ink),
                  ),
                ),
              ],
            ),
          ),
          if (hasDiscover)
            RoundIcon(
              icon: Icons.auto_awesome_rounded,
              size: 40,
              tooltip: 'Specials',
              onTap: () => GuestFlow.discover(context),
            ),
          const SizedBox(width: 6),
          RoundIcon(
            icon: Icons.search_rounded,
            size: 40,
            tooltip: 'Search',
            onTap: () => showGuestSearch(context),
          ),
          const GuestExitButton(),
        ],
      ),
    );
  }
}

/// Ring + "₹1,300 / ₹7,000 · 19% used". Tapping opens the budget overview.
class _BudgetStrip extends StatelessWidget {
  const _BudgetStrip();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final status = GuestScope.of(context).budgetStatus!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: GuestCard(
        key: const ValueKey('budget-strip'),
        padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
        onTap: () => GuestFlow.budgetOverview(context),
        child: Row(
          children: [
            BudgetRing(status: status, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rupees(status.spent)} / ${rupees(status.budget)}',
                    style: p.price(15),
                  ),
                  Text(
                    '${status.percentUsed}% used',
                    style: p.body(12.5, color: budgetColor(p, status)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// "All · Starters · Mains · Pizza" with an accent dot under the active one.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.selected, required this.onSelect});
  final GuestCategory? selected;
  final ValueChanged<GuestCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final cats = <GuestCategory?>[null, ...s.catalog.categories];
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: cats.length,
        itemBuilder: (context, i) {
          final c = cats[i];
          final active = c?.category.id == selected?.category.id;
          return InkWell(
            onTap: () => onSelect(c),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    c?.category.name ?? 'All',
                    style: p.body(
                      14,
                      weight: active ? FontWeight.w800 : FontWeight.w500,
                      color: active ? p.ink : p.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: active ? 18 : 0,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
