import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../domain/guest_catalog.dart';
import '../../domain/pos_order.dart';
import '../../domain/storefront.dart';
import '../theme/guest_theme.dart';
import '../widgets/food_art.dart';
import 'guest_bill.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';

/// Board 1 #9 / Board 2 #7 & #12: "Your order" — steppers, the saved-for-
/// later row, and the budget against the estimated total.
class GuestOrderScreen extends StatelessWidget {
  const GuestOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final status = s.budgetStatus;
    final saved = s.features.likes
        ? <GuestItem>[
            for (final id in s.liked)
              if (s.catalog.item(id) != null && s.qtyOf(id) == 0)
                s.catalog.item(id)!,
          ]
        : const <GuestItem>[];
    final context2 = [
      if (s.tableName != null && s.mode == GuestServiceMode.dineIn)
        s.tableName!,
      s.mode.label,
    ].join(' • ');
    return GuestPage(
      bottom: s.lines.isEmpty
          ? null
          : GuestButton(
              label: s.mode == GuestServiceMode.preOrder
                  ? 'Add to pre-order'
                  : 'Continue to review',
              trailingArrow: true,
              onTap: () => GuestFlow.toReview(context),
            ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GuestTopBar(
            title: 'Your order',
            trailing: [
              if (s.lines.isNotEmpty)
                TextButton(
                  onPressed: s.clearCart,
                  child: Text(
                    'Clear all',
                    style: p.body(14, weight: FontWeight.w700, color: p.danger),
                  ),
                ),
            ],
          ),
          Center(
            child: Text(context2, style: p.body(13, color: p.inkMuted)),
          ),
          if (s.mode == GuestServiceMode.preOrder && s.scheduledFor != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${DateFormat('EEEE, d MMM').format(s.scheduledFor!)} • '
                  '${DateFormat('h:mm a').format(s.scheduledFor!)}',
                  style: p.body(14, weight: FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (s.lines.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text('🧺', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('Your order is empty', style: p.display(22)),
                  const SizedBox(height: 20),
                  GuestButton(
                    label: 'Browse dishes',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          for (final l in s.lines) _LineRow(line: l),
          if (saved.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Icon(Icons.favorite_rounded, size: 18, color: p.danger),
                  const SizedBox(width: 8),
                  Text(
                    'Saved for later',
                    style: p.display(17, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: saved.length,
                separatorBuilder: (context, i) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final item = saved[i];
                  return GuestCard(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                    onTap: () => GuestFlow.openItem(context, item),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 50,
                          child: FoodArt(
                            name: item.item.name,
                            imageUrl: item.item.imageUrl,
                            radius: 14,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            item.item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: p.body(13, weight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        RoundIcon(
                          icon: Icons.add_rounded,
                          size: 34,
                          tooltip: 'Add',
                          background: p.accent,
                          color: p.onAccent,
                          onTap: () => addWithHaptic(context, item),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          if (s.lines.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: GuestCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Estimated total',
                            style: p.body(15, weight: FontWeight.w700),
                          ),
                        ),
                        Text(rupees(s.estimate.payable), style: p.price(22)),
                      ],
                    ),
                    if (s.charges != null)
                      Text(
                        'Includes ${s.estimate.gstLabel}',
                        style: p.body(12, color: p.inkMuted),
                      ),
                    if (status != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Table budget ${rupees(status.budget)}',
                        style: p.body(13, color: p.inkMuted),
                      ),
                      const SizedBox(height: 6),
                      BudgetBar(status: status),
                    ],
                  ],
                ),
              ),
            ),
            if (status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: BudgetNote(status: status),
              ),
          ],
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final item = s.catalog.item(line.itemId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 58,
            child: FoodArt(
              name: line.name,
              imageUrl: item?.item.imageUrl,
              radius: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: p.body(15, weight: FontWeight.w700),
                ),
                Text(
                  rupees(line.unitPrice),
                  style: p.body(13, color: p.inkMuted),
                ),
              ],
            ),
          ),
          QtyStepper(
            qty: line.qty,
            compact: true,
            onChanged: (v) => s.setQty(line.itemId, v),
          ),
          SizedBox(
            width: 70,
            child: Text(
              rupees(line.lineTotal),
              textAlign: TextAlign.right,
              style: p.price(15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Board 1 #10 / Board 2 #8: compact list, a note for the kitchen and the
/// estimated bill.
class GuestReviewScreen extends StatefulWidget {
  const GuestReviewScreen({super.key});

  @override
  State<GuestReviewScreen> createState() => _GuestReviewScreenState();
}

class _GuestReviewScreenState extends State<GuestReviewScreen> {
  late final _notes = TextEditingController(
    text: GuestScope.read(context).notes,
  );

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    return GuestPage(
      bottom: GuestButton(
        label: 'Proceed to checkout',
        trailingArrow: true,
        onTap: s.lines.isEmpty
            ? null
            : () {
                s.notes = _notes.text;
                GuestFlow.toConfirm(context);
              },
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const GuestTopBar(title: 'Review your order'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GuestCard(
              child: Column(
                children: [
                  for (final l in s.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Text('${l.qty}×', style: p.price(14)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l.name,
                              style: p.body(14.5, weight: FontWeight.w600),
                            ),
                          ),
                          Text(rupees(l.lineTotal), style: p.price(14.5)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              'Special instructions (optional)',
              style: p.body(14, weight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              key: const ValueKey('guest-notes'),
              controller: _notes,
              minLines: 3,
              maxLines: 5,
              maxLength: 240,
              onChanged: (v) => s.notes = v,
              style: p.body(15),
              decoration: const InputDecoration(
                hintText: 'e.g. Less spicy, no onions, extra cheese…',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: GuestCard(
              child: BillLines(bill: s.estimate, estimated: true),
            ),
          ),
        ],
      ),
    );
  }
}
