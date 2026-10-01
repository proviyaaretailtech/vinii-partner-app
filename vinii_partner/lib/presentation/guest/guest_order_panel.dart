import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/billing.dart';
import '../theme/guest_theme.dart';
import '../widgets/dish_art.dart';
import '../widgets/food_art.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';
import 'look/look.dart';
import 'look/motion.dart';

/// On a wide screen the order stays in view beside the deck: what has been
/// added, what it comes to and how it sits against the table budget, with
/// the way on to review. On a phone this is the "Your order" screen and the
/// bar at the bottom; here it is simply always there.
class GuestOrderPanel extends StatelessWidget {
  const GuestOrderPanel({super.key, this.budgetKey, this.landed});

  /// Where an added dish's price flies to, and the beat the budget gives when
  /// it lands. Both come from the browse screen.
  final GlobalKey? budgetKey;
  final ValueNotifier<int>? landed;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final t = GuestCopy.of(context);
    final status = s.budgetStatus;
    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: p.isDark ? 0.55 : 0.8),
        border: Border(left: BorderSide(color: p.hairline)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
              child: Row(
                children: [
                  Expanded(child: Text(t('cart.title'), style: p.display(22))),
                  if (s.lines.isNotEmpty)
                    Text(
                      '${s.itemCount} ${s.itemCount == 1 ? 'item' : 'items'}',
                      style: p.body(13.5, color: p.inkMuted),
                    ),
                ],
              ),
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                child: KeyedSubtree(
                  key: budgetKey,
                  child: _BudgetBlock(status: status, landed: landed),
                ),
              ),
            Expanded(
              child: s.lines.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 120,
                            child: DishArt(
                              name: 'plate',
                              family: DishFamily.plate,
                              light: p.keyLight,
                              onDark: p.isDark,
                              animate: false,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nothing here yet',
                            style: p.display(18, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Swipe a dish right, or tap the heart, and it '
                            'lands here.',
                            textAlign: TextAlign.center,
                            style: p.body(13.5, color: p.inkMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        for (final (n, l) in s.lines.indexed)
                          Reveal(
                            key: ValueKey(l.itemId),
                            index: n,
                            dx: 14,
                            dy: 0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  SizedBox.square(
                                    dimension: 46,
                                    child: FoodArt(
                                      name: l.name,
                                      imageUrl: s.catalog
                                          .item(l.itemId)
                                          ?.item
                                          .imageUrl,
                                      radius: 14,
                                      animate: false,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      l.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: p.body(
                                        14,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  QtyStepper(
                                    qty: l.qty,
                                    compact: true,
                                    onChanged: (v) => s.setQty(l.itemId, v),
                                  ),
                                  SizedBox(
                                    width: 64,
                                    child: Text(
                                      rupees(l.lineTotal),
                                      textAlign: TextAlign.right,
                                      style: p.price(14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            if (s.lines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t('cart.estimated'),
                            style: p.body(15, weight: FontWeight.w700),
                          ),
                        ),
                        CountUp(
                          value: s.estimate.payable,
                          format: rupees,
                          duration: GuestMotion.base,
                          style: p.price(22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GuestButton(
                      label: 'Continue to review',
                      trailingArrow: true,
                      onTap: () => GuestFlow.toReview(context),
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

/// The table budget at the top of the panel: the same ring as on a phone,
/// counting up and giving a short pop when a dish's price lands in it.
class _BudgetBlock extends StatelessWidget {
  const _BudgetBlock({required this.status, required this.landed});
  final BudgetStatus status;
  final ValueNotifier<int>? landed;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final row = Row(
      children: [
        BudgetRing(status: status, size: 52),
        const SizedBox(width: 14),
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
      ],
    );
    final trigger = landed;
    return trigger == null ? row : Pulse(trigger: trigger, child: row);
  }
}
