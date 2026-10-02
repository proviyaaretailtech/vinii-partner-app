import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/guest_session.dart';
import '../../core/money.dart';
import '../../domain/guest_catalog.dart';
import '../../domain/menu.dart';
import '../theme/guest_theme.dart';
import '../widgets/chips.dart';
import 'guest_categories.dart';
import 'guest_deck.dart';
import 'guest_flow.dart';
import 'guest_list.dart';
import 'guest_order_panel.dart';
import 'guest_widgets.dart';
import 'look/motion.dart';

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

  /// Where an added dish's price lands, and the beat the strip gives when it
  /// does.
  final _stripKey = GlobalKey();
  final _landed = ValueNotifier<int>(0);

  @override
  void dispose() {
    _landed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = GuestScope.of(context);
    final items = [
      for (final i in _category?.items ?? s.catalog.allItems)
        if (s.diet.allows(i)) i,
    ];
    final label = _category?.category.name ?? 'All dishes';
    // A wide screen keeps the order in view beside the deck.
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final browse = Column(
      children: [
        _Header(categoryName: label),
        if (s.budgetStatus != null && !wide)
          KeyedSubtree(
            key: _stripKey,
            child: _BudgetStrip(landed: _landed),
          ),
        if (s.dietOptions.length > 1) const _DietBar(),
        Expanded(
          child: items.isEmpty
              ? const _NoMatch()
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: s.browseView == GuestBrowseView.swipe
                      ? SwipeDeck(
                          key: ValueKey(
                            'deck-${_category?.category.id}-${s.diet.name}',
                          ),
                          items: items,
                          categoryName: label,
                          budgetTarget: _stripKey,
                          onLanded: () => _landed.value++,
                        )
                      : DishList(
                          key: ValueKey(
                            'list-${_category?.category.id}-${s.diet.name}',
                          ),
                          items: items,
                        ),
                ),
        ),
        if (s.lines.isNotEmpty && !wide)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: CartBar(),
          ),
        _CategoryStrip(
          selected: _category,
          onSelect: (c) => setState(() => _category = c),
        ),
      ],
    );
    if (!wide) return GuestPage(alerts: true, child: browse);
    return GuestPage(
      alerts: true,
      alertsEndInset: 380,
      maxWidth: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: browse,
              ),
            ),
          ),
          GuestOrderPanel(budgetKey: _stripKey, landed: _landed),
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
/// When a dish's price lands the strip gives a short pop.
class _BudgetStrip extends StatelessWidget {
  const _BudgetStrip({required this.landed});
  final ValueNotifier<int> landed;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final status = GuestScope.of(context).budgetStatus!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
      child: Pulse(
        trigger: landed,
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
                    CountUp(
                      value: status.spent,
                      format: (v) => '${rupees(v)} / ${rupees(status.budget)}',
                      duration: GuestMotion.slow,
                      style: p.price(15),
                    ),
                    Text(
                      '${status.percentUsed}% used',
                      style: p.body(12.5, color: budgetTextColor(p, status)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// "All · Veg · Non-veg · Jain": a row of chips under the header, only for
/// the diets that actually split this menu. The marks match the dish marks
/// (green dot veg, red triangle non-veg).
class _DietBar extends StatelessWidget {
  const _DietBar();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    Widget mark(GuestDiet d) => switch (d) {
      GuestDiet.veg => const FoodTypeMark(FoodType.veg, size: 14),
      GuestDiet.nonVeg => const FoodTypeMark(FoodType.nonVeg, size: 14),
      GuestDiet.jain => Icon(Icons.spa_rounded, size: 16, color: p.success),
      GuestDiet.all => const SizedBox.shrink(),
    };
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final d in s.dietOptions)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Semantics(
                button: true,
                selected: s.diet == d,
                label: d.label,
                child: GestureDetector(
                  key: ValueKey('diet-${d.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    s.setDiet(d);
                  },
                  child: AnimatedContainer(
                    duration: GuestMotion.base,
                    curve: GuestMotion.arrive,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.diet == d ? p.accent : p.surfaceAlt,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (d != GuestDiet.all) ...[
                          mark(d),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          d.label,
                          style: p.body(
                            13.5,
                            weight: FontWeight.w700,
                            color: s.diet == d ? p.onAccent : p.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nothing ${s.diet.label.toLowerCase()} here',
              style: p.display(20),
            ),
            const SizedBox(height: 12),
            TextButton(
              key: const ValueKey('diet-clear'),
              onPressed: () => s.setDiet(GuestDiet.all),
              child: Text(
                'Show everything',
                style: p.body(15, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The quick switch between swiping through dishes and the traditional menu
/// of blocks. Two icons in one pill, the chosen one filled; it sits at the
/// end of the category strip, under the thumb, and remembers the choice for
/// the visit.
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    Widget option(GuestBrowseView v, IconData icon, String label) {
      final on = s.browseView == v;
      return Semantics(
        button: true,
        selected: on,
        label: label,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            key: ValueKey('view-${v.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              s.setBrowseView(v);
            },
            child: AnimatedContainer(
              duration: GuestMotion.base,
              curve: GuestMotion.arrive,
              width: 44,
              height: 36,
              decoration: BoxDecoration(
                color: on ? p.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 20, color: on ? p.onAccent : p.inkMuted),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(GuestBrowseView.swipe, Icons.style_rounded, 'Swipe dishes'),
          option(GuestBrowseView.menu, Icons.view_agenda_rounded, 'Menu view'),
        ],
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
    final list = ListView.builder(
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
    );
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: s.canSwitchView
          ? Row(
              children: [
                Expanded(child: list),
                const Padding(
                  padding: EdgeInsets.only(left: 4, right: 12),
                  child: _ViewSwitch(),
                ),
              ],
            )
          : list,
    );
  }
}
