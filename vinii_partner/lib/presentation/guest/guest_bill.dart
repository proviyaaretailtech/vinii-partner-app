import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/billing.dart';
import '../../domain/pos_order.dart';
import '../../l10n/l10n.dart';
import '../theme/guest_theme.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';
import 'look/motion.dart';

/// Subtotal → service charge → GST → round-off → total, the same order as
/// the printed bill. [estimated] labels a pre-order preview as such.
class BillLines extends StatelessWidget {
  const BillLines({
    super.key,
    required this.bill,
    this.estimated = false,
    this.discountLabel,
  });
  final BillSummary bill;
  final bool estimated;

  /// What the discount line says when it is a named coupon ("Coupon SAVE10").
  final String? discountLabel;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final l = context.l10n;
    Widget row(String label, double v, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong
                  ? p.body(16, weight: FontWeight.w800)
                  : p.body(14, color: p.inkMuted),
            ),
          ),
          strong
              ? CountUp(
                  value: v,
                  format: rupees,
                  duration: GuestMotion.slow,
                  style: p.price(22),
                )
              : Text(rupees(v), style: p.price(14.5)),
        ],
      ),
    );
    return Column(
      children: [
        row(l.commonSubtotal, bill.itemTotal),
        if (bill.discount > 0)
          row(discountLabel ?? l.commonDiscount, -bill.discount),
        if (bill.serviceCharge > 0)
          row(l.guestBillServiceCharge, bill.serviceCharge),
        if (bill.gst > 0)
          row(l.guestBillGst(percent: bill.gstPercentText), bill.gst),
        if (bill.roundOff != 0) row(l.guestBillRoundOff, bill.roundOff),
        Divider(color: p.border, height: 20),
        row(
          estimated
              ? GuestCopy.of(context).own('cart.estimated') ??
                    l.guestOrderEstimatedTotal
              : l.commonTotal,
          bill.payable,
          strong: true,
        ),
      ],
    );
  }
}

/// Every order this party placed, added up from the server's own figures.
BillSummary combinedBill(List<PlacedOrder> orders) {
  if (orders.length == 1) return orders.single.bill;
  double sum(double Function(BillSummary b) f) =>
      orders.fold(0, (s, o) => s + f(o.bill));
  return BillSummary.stored(
    itemTotal: sum((b) => b.itemTotal),
    discount: sum((b) => b.discount),
    serviceCharge: sum((b) => b.serviceCharge),
    gst: sum((b) => b.gst),
    roundOff: sum((b) => b.roundOff),
    payable: sum((b) => b.payable),
    gstPercent: orders.isEmpty ? 0 : orders.first.bill.charges.gstPercent,
  );
}

/// Board 1 #16 / Board 2 #16: the bill with the budget verdict. Money is taken
/// either online (when the server offers it) or by staff at the table. There
/// is no way yet to call staff from here, so the screen says what to do
/// instead of offering a button that does nothing.
class GuestBillScreen extends StatefulWidget {
  const GuestBillScreen({super.key});

  @override
  State<GuestBillScreen> createState() => _GuestBillScreenState();
}

class _GuestBillScreenState extends State<GuestBillScreen> {
  int? _feedback;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final t = GuestCopy.of(context);
    final l = context.l10n;
    final orders = s.placed;
    final bill = combinedBill(orders);
    final merged = <String, CartLine>{};
    for (final o in orders) {
      for (final l in o.lines) {
        final k = '${l.itemId}|${l.unitPrice}';
        merged[k] = merged[k] == null
            ? l
            : merged[k]!.copyWith(qty: merged[k]!.qty + l.qty);
      }
    }
    final status = s.budget == null
        ? null
        : BudgetStatus(budget: s.budget!, spent: bill.payable);
    final dineIn =
        orders.isNotEmpty && orders.last.serviceType == ServiceType.dineIn;
    final table = l.guestTableNameOf(s);
    final subtitle = [
      if (dineIn && table != null) table,
      for (final o in orders) l.guestBillOrderNo(number: o.displayNo),
    ].join(' · ');
    // Online payment, when the server offers it for this restaurant. Paying
    // staff at the table or the counter always stays possible.
    final online = s.gateway.payments?.available == true;
    final payNote = dineIn
        ? (online ? l.guestBillPayTableOnline : l.guestBillPayTable)
        : (online ? l.guestBillPayCounterOnline : l.guestBillPayCounter);
    final due = orders.fold<double>(0, (a, o) => a + o.due);
    return GuestPage(
      bottom: Row(
        children: [
          if (s.features.splitBill && !online) ...[
            Expanded(
              child: GuestButton(
                label: t.own('bill.split') ?? l.guestBillSplit,
                style: GuestButtonStyle.outline,
                onTap: () => _split(bill.payable),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 3,
            child: online
                ? GuestButton(
                    key: const ValueKey('pay-online'),
                    label: due <= 0
                        ? l.statusPaid
                        : l.guestBillPay(amount: rupees(due)),
                    icon: Icons.lock_outline_rounded,
                    onTap: due <= 0 ? null : () => GuestFlow.pay(context),
                  )
                : GuestButton(
                    key: const ValueKey('order-more'),
                    label: l.guestBillOrderMore,
                    icon: Icons.add_rounded,
                    onTap: () => GuestFlow.orderMore(context),
                  ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GuestTopBar(
            title: t.own('bill.title') ?? l.guestBillTitle,
            trailing: [
              // Without online payment "Order more" is the bottom button.
              if (online)
                TextButton(
                  onPressed: () => GuestFlow.orderMore(context),
                  child: Text(
                    l.guestBillOrderMore,
                    style: p.body(14, weight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const Center(child: PreviewBanner()),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: p.body(13, color: p.inkMuted),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GuestCard(
              child: Column(
                children: [
                  for (final l in merged.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.name,
                              style: p.body(14.5, weight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '×${l.qty}',
                            style: p.body(13, color: p.inkMuted),
                          ),
                          SizedBox(
                            width: 84,
                            child: Text(
                              rupees(l.lineTotal),
                              textAlign: TextAlign.right,
                              style: p.price(14.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Divider(color: p.border, height: 20),
                  BillLines(bill: bill),
                ],
              ),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: GuestCard(
                color: budgetColor(p, status).withValues(alpha: 0.10),
                borderColor: budgetColor(p, status).withValues(alpha: 0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.over
                          ? l.guestBillOverBudget(
                              amount: rupees(-status.remaining),
                            )
                          : l.guestBillWithinBudget,
                      style: p.body(15, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    BudgetBar(status: status),
                  ],
                ),
              ),
            ),
          if (orders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: GuestButton(
                key: const ValueKey('repeat-order'),
                label: l.guestBillRepeat,
                icon: Icons.replay_rounded,
                style: GuestButtonStyle.soft,
                dense: true,
                onTap: () {
                  if (s.repeatLatest() > 0) GuestFlow.toOrder(context);
                },
              ),
            ),
          Padding(
            key: const ValueKey('pay-at-table'),
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.room_service_outlined, size: 20, color: p.inkMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    payNote,
                    style: p.body(14, color: p.inkMuted).copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          // Only when the gateway can actually store it (none can today).
          if (s.features.feedback && s.gateway.acceptsFeedback)
            _Feedback(
              selected: _feedback,
              onPick: (i) => setState(() => _feedback = i),
            ),
        ],
      ),
    );
  }

  void _split(double total) {
    final s = GuestScope.read(context);
    var people = s.partySize;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, set) {
          final p = GuestPalette.of(context);
          final l = context.l10n;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.guestBillSplitTitle,
                    textAlign: TextAlign.center,
                    style: p.display(22),
                  ),
                  const SizedBox(height: 16),
                  QtyStepper(
                    qty: people,
                    min: 1,
                    onChanged: (v) => set(() => people = v.clamp(1, 30)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.guestBillPeople(count: people),
                    style: p.body(14, color: p.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.guestBillEach(amount: rupees(money(total / people))),
                    textAlign: TextAlign.center,
                    style: p.price(30),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.guestBillStaffSettle,
                    textAlign: TextAlign.center,
                    style: p.body(13, color: p.inkMuted),
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

class _Feedback extends StatelessWidget {
  const _Feedback({required this.selected, required this.onPick});
  final int? selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final l = context.l10n;
    final faces = [
      (
        Icons.sentiment_very_satisfied_rounded,
        l.guestBillFeedbackLoved,
        p.success,
      ),
      (
        Icons.sentiment_satisfied_rounded,
        l.guestBillFeedbackGood,
        const Color(0xFF84CC16),
      ),
      (
        Icons.sentiment_neutral_rounded,
        l.guestBillFeedbackOkay,
        const Color(0xFFF59E0B),
      ),
      (
        Icons.sentiment_dissatisfied_rounded,
        l.guestBillFeedbackBetter,
        p.danger,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          Text(
            l.guestBillFeedbackTitle,
            textAlign: TextAlign.center,
            style: p.display(18),
          ),
          const SizedBox(height: 12),
          // Four equal columns, so a longer word (Hindi) wraps under its
          // face instead of pushing the others off the screen.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, f) in faces.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected == i,
                    label: f.$2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onPick(i),
                      child: AnimatedScale(
                        scale: selected == i ? 1.18 : 1,
                        duration: GuestMotion.base,
                        curve: Curves.easeOutBack,
                        child: Column(
                          children: [
                            Icon(
                              f.$1,
                              size: 40,
                              color: selected == null || selected == i
                                  ? f.$3
                                  : p.inkMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              f.$2,
                              textAlign: TextAlign.center,
                              style: p.body(11, color: p.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
