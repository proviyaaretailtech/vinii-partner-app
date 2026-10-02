import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/guest_catalog.dart';
import '../theme/guest_theme.dart';
import '../widgets/chips.dart';
import '../widgets/food_art.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';
import 'look/motion.dart';

/// The deck's alternative when the storefront turns `swipeDeck` off: a calm
/// scrolling list of photo cards, each with an "Add" pill that turns into a
/// quantity stepper once the dish is in the order.
class DishList extends StatelessWidget {
  const DishList({super.key, required this.items});
  final List<GuestItem> items;

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const ValueKey('dish-list'),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
    itemCount: items.length,
    separatorBuilder: (context, i) => const SizedBox(height: 14),
    // The first few rows arrive one after another; later rows, met while
    // scrolling, appear at once.
    itemBuilder: (context, i) => Reveal(
      index: i < 6 ? i : 0,
      child: DishRow(item: items[i]),
    ),
  );
}

class DishRow extends StatelessWidget {
  const DishRow({super.key, required this.item});
  final GuestItem item;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final i = item.item;
    final qty = s.qtyOf(i.id);
    final liked = s.liked.contains(i.id);
    return GuestCard(
      padding: const EdgeInsets.all(10),
      onTap: () => GuestFlow.openItem(context, item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            height: 116,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FoodArt(name: i.name, imageUrl: i.imageUrl, radius: 18),
                if (s.features.likes)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: RoundIcon(
                      icon: liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 30,
                      color: liked ? p.danger : Colors.white,
                      background: Colors.black.withValues(alpha: 0.35),
                      tooltip: liked ? 'Saved for later' : 'Save for later',
                      onTap: () => s.toggleLike(i.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            // At least as tall as the picture, taller when the words need it
            // (a long description and tags): it grows, it never overflows.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 116),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          FoodTypeMark(i.foodType, size: 13),
                          if (i.foodType != null) const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              i.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: p.display(16.5, weight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      if ((i.description ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            i.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: p.body(12.5, color: p.inkMuted),
                          ),
                        ),
                      if (item.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: SizedBox(
                            height: 24,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final t in item.tags)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: TagChip(t),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(rupees(i.price), style: p.price(18)),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, a) =>
                              ScaleTransition(scale: a, child: child),
                          child: qty == 0
                              ? _AddPill(
                                  key: ValueKey('list-add-${i.id}'),
                                  onTap: () => addWithHaptic(context, item),
                                )
                              : QtyStepper(
                                  key: ValueKey('list-qty-${i.id}'),
                                  qty: qty,
                                  compact: true,
                                  onChanged: (v) => s.setQty(i.id, v),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPill extends StatelessWidget {
  const _AddPill({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final outline = p.buttonOutline;
    final fg = outline ? p.accent : p.onAccent;
    final shape = p.buttonShape(
      outline ? BorderSide(color: p.accent, width: 1.6) : BorderSide.none,
    );
    return Material(
      color: outline ? Colors.transparent : p.accent,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 18, color: fg),
              const SizedBox(width: 4),
              Text(
                GuestCopy.of(context)('menu.add'),
                style: p.body(14, weight: FontWeight.w800, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
