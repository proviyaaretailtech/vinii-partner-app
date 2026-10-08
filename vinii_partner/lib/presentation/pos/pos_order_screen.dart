import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/failure.dart';
import '../../core/money.dart';
import '../../core/time_format.dart';
import '../../domain/billing.dart';
import '../../domain/pos_order.dart';
import '../../domain/staff.dart';
import '../../l10n/failure_text.dart';
import '../../l10n/l10n.dart';
import '../../l10n/labels.dart';
import '../orders/order_widgets.dart' show AmountRow, SectionCard;
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/state_views.dart';
import 'payment_card.dart';
import 'payment_success.dart';
import 'pos_widgets.dart';
import 'service_charge.dart';

/// One saved POS order and its payment.
///
/// Everything money-related shows the figures the server stored on the
/// order ([PlacedOrder.bill]) — never a recomputation — so this phone, the
/// POS and the printed bill agree. Payments go through the POS front door
/// with a per-order idempotency key (contract R3): a retry after a dropped
/// connection cannot charge the guest twice.
///
/// On a phone it is one column: the order, its bill, then the payment. From
/// [Breakpoints.wide] up it is two panes, the order on the left and the
/// payment (or the confirmation) on the right, so the cashier never scrolls
/// to find the button.
class PosOrderScreen extends StatefulWidget {
  const PosOrderScreen({super.key, required this.orderId, this.initial});

  final String orderId;

  /// The order as Checkout received it, so the screen opens instantly.
  final PlacedOrder? initial;

  @override
  State<PosOrderScreen> createState() => _PosOrderScreenState();
}

class _PosOrderScreenState extends State<PosOrderScreen> {
  PlacedOrder? _order;
  AppFailure? _failure;
  bool _loading = false;

  /// What was taken on this screen, for "Paid · ₹504 by Cash + UPI".
  final _taken = <PaymentPart>[];

  /// Cash to hand back after the last payment, when there is any.
  double? _change;

  /// The organization's rates, to name the service charge's percentage when
  /// the saved order does not carry it.
  BillCharges? _charges;
  bool _adjusting = false;

  /// The phone's one column scrolls; after the last payment it goes back to
  /// the top, where the confirmation is.
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCharges();
    _order = widget.initial;
    if (_order == null) _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadCharges() async {
    try {
      final c = await AppScope.of(context).backend.pos.billCharges();
      if (mounted) setState(() => _charges = c);
    } on AppFailure {
      // The row falls back to what the saved order says.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final o = await AppScope.of(context).backend.pos.refresh(widget.orderId);
      if (!mounted) return;
      setState(() => _order = o);
    } on AppFailure catch (e) {
      if (!mounted) return;
      if (_order == null) {
        setState(() => _failure = e);
      } else {
        showFailure(context, e);
      }
    } catch (e) {
      if (!mounted) return;
      if (_order == null) {
        setState(() => _failure = asFailure(e));
      } else {
        showFailure(context, e);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _recorded(PlacedOrder order, List<PaymentPart> parts, double? cash) {
    if (order.isPaid) {
      final still = MediaQuery.disableAnimationsOf(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        if (still) {
          _scroll.jumpTo(0);
        } else {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
    setState(() {
      _order = order;
      _taken.addAll(parts);
      final only = parts.length == 1 ? parts.first : null;
      _change =
          only != null &&
              only.method == PaymentMethod.cash &&
              cash != null &&
              cash > only.amount + 0.009
          ? money(cash - only.amount)
          : null;
    });
  }

  // ── The service charge ─────────────────────────────────────────────────

  /// A manager may take the service charge off while nothing has been paid.
  bool _mayAdjust(PlacedOrder o) =>
      AppScope.of(context).session.can(Capability.waiveServiceCharge) &&
      o.status != PosStatus.cancelled &&
      !o.isPaid &&
      o.paidAmount <= 0.009;

  /// The service charge row: its percentage, what it comes to (or came to,
  /// when removed) and, for a manager, Remove / Add back.
  ServiceChargeLine? _serviceLine(PlacedOrder o) {
    final bill = o.bill;
    if (!bill.serviceChargeWaived && bill.serviceCharge <= 0) return null;
    final percent = bill.servicePercent > 0
        ? bill.servicePercent
        : (_charges?.serviceChargePercent ?? 0);
    final amount = !bill.serviceChargeWaived
        ? bill.serviceCharge
        : bill.waivedServiceCharge > 0
        ? bill.waivedServiceCharge
        : money((bill.itemTotal - bill.discount) * percent / 100);
    final may = _mayAdjust(o) && !_adjusting;
    return ServiceChargeLine(
      percent: percent,
      amount: amount,
      waived: bill.serviceChargeWaived,
      onRemove: may && !bill.serviceChargeWaived
          ? () => _removeServiceCharge(o)
          : null,
      onAddBack: may && bill.serviceChargeWaived
          ? () => _adjust(o, waive: false)
          : null,
    );
  }

  /// How much less the guest pays without the service charge: worked out
  /// from the saved order's own lines and GST. The server's figure is final.
  double _payLess(PlacedOrder o) {
    final without = BillSummary.of(
      o.lines.map((l) => (unitPrice: l.unitPrice, qty: l.qty)),
      charges: BillCharges(
        sgstPercent: o.bill.charges.sgstPercent,
        cgstPercent: o.bill.charges.cgstPercent,
        serviceChargePercent: o.bill.servicePercent,
        roundOff: _charges?.roundOff ?? o.bill.roundOff != 0,
      ),
      discount: o.bill.discount,
      waiveServiceCharge: true,
    );
    return money((o.bill.payable - without.payable).clamp(0, double.infinity));
  }

  /// Asks, then removes. Returns true if the service charge came off.
  Future<bool> _removeServiceCharge(PlacedOrder o) async {
    final removal = await showRemoveServiceChargeSheet(
      context,
      payLess: _payLess(o),
    );
    if (removal == null || !mounted) return false;
    return _adjust(o, waive: true, reason: removal.reason);
  }

  Future<bool> _adjust(
    PlacedOrder o, {
    required bool waive,
    String? reason,
  }) async {
    if (_adjusting) return false;
    final services = AppScope.of(context);
    final l = context.l10n;
    setState(() => _adjusting = true);
    try {
      final updated = await services.backend.pos.adjustBill(
        o,
        waiveServiceCharge: waive,
        reason: reason,
      );
      if (!mounted) return false;
      setState(() => _order = updated);
      showDone(
        context,
        waive ? l.posServiceChargeRemoved : l.posServiceChargeAdded,
      );
      return true;
    } on AppFailure catch (e) {
      if (!mounted) return false;
      setState(() => _adjusting = false);
      if (e.kind == FailureKind.notReady) {
        await showNotAvailableDialog(context, failureText(l, e));
      } else {
        showFailure(context, e);
        if (e.isConflict) await _load();
      }
      return false;
    } finally {
      if (mounted) setState(() => _adjusting = false);
    }
  }

  /// The one-time question above the payment form: it never blocks paying,
  /// and either answer is remembered for this order, even after a restart.
  bool _showPrompt(PlacedOrder o) =>
      _mayAdjust(o) &&
      !o.bill.serviceChargeWaived &&
      o.bill.serviceCharge > 0 &&
      AppScope.of(context).prefs.serviceChargeChoice(o.id) == null;

  Future<void> _answerPrompt(PlacedOrder o, {required bool keep}) async {
    final prefs = AppScope.of(context).prefs;
    if (keep) {
      await prefs.setServiceChargeChoice(o.id, 'keep');
      if (mounted) setState(() {});
      return;
    }
    if (await _removeServiceCharge(o)) {
      await prefs.setServiceChargeChoice(o.id, 'remove');
    }
  }

  // ── Building ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final o = _order;
    return Scaffold(
      appBar: AppBar(
        title: Text(o?.displayNo ?? l.commonOrder),
        actions: [
          IconButton(
            tooltip: l.commonRefresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          TextButton(
            onPressed: () => context.go(Routes.sell),
            child: Text(l.posNewOrder),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: o == null
          ? (_failure != null && !_loading
                ? FailureView(failure: _failure!, onRetry: _load)
                : LoadingView(label: l.posLoadingOrder))
          : RefreshIndicator(
              onRefresh: _load,
              child: LayoutBuilder(
                builder: (context, box) => box.maxWidth >= Breakpoints.wide
                    ? _wide(context, o)
                    : _narrow(context, o),
              ),
            ),
    );
  }

  Widget _narrow(BuildContext context, PlacedOrder o) {
    // A paid bill opens with its confirmation; an unpaid one ends with the
    // payment, after the bill the cashier is about to take money for.
    final paid = o.isPaid && o.status != PosStatus.cancelled;
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        ..._header(context, o),
        if (paid) ..._payment(context, o, gapFirst: true),
        const SizedBox(height: 12),
        ..._lines(context, o),
        if (!paid) ..._payment(context, o, gapFirst: true),
      ],
    );
  }

  /// Order on the left, payment on the right.
  Widget _wide(BuildContext context, PlacedOrder o) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 10, 32),
              children: [
                ..._header(context, o),
                const SizedBox(height: 12),
                ..._lines(context, o),
              ],
            ),
          ),
          SizedBox(
            width: 420,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(10, 4, 16, 32),
              children: _payment(context, o, gapFirst: false),
            ),
          ),
        ],
      ),
    ),
  );

  /// Who and where.
  List<Widget> _header(BuildContext context, PlacedOrder o) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final where = [
      l.serviceTypeLabel(o.serviceType),
      if (o.table != null) o.table!.nameIn(l),
      clockTime(o.createdAt),
    ].join(' · ');
    return [
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wraps under the number when the status word is long.
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  o.displayNo,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                StatusChip.pos(context, o.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(where, style: TextStyle(color: t.inkSecondary)),
            if (o.customerName != null &&
                o.customerName!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                o.customerName!,
                style: TextStyle(color: t.ink, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  /// What was ordered, and the bill.
  List<Widget> _lines(BuildContext context, PlacedOrder o) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final cancelled = o.status == PosStatus.cancelled;
    return [
      SectionCard(
        title: l.posItemCount(count: o.itemCount),
        child: Column(
          children: [
            for (final line in o.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 36),
                      child: Text(
                        '${line.qty}×',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: t.ink,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: t.ink,
                            ),
                          ),
                          if (line.notes != null && line.notes!.isNotEmpty)
                            Text(
                              line.notes!,
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: t.inkSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      rupees(line.lineTotal),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: l.commonBill,
        child: Column(
          children: [
            BillLines(bill: o.bill, serviceCharge: _serviceLine(o)),
            if (!cancelled) ...[
              AmountRow(l.posBillPaid, rupees(o.paidAmount)),
              AmountRow(l.posBillDue, rupees(o.due), strong: o.due > 0),
            ],
          ],
        ),
      ),
    ];
  }

  /// What to do about the money: the cancelled note, the confirmation, or the
  /// question about the service charge and the payment form.
  List<Widget> _payment(
    BuildContext context,
    PlacedOrder o, {
    required bool gapFirst,
  }) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final canPay = AppScope.of(context).session.can(Capability.takePayment);
    final gap = gapFirst ? const SizedBox(height: 12) : const SizedBox.shrink();
    if (o.status == PosStatus.cancelled) {
      return [
        gap,
        NoticeBanner(
          icon: Icons.cancel_outlined,
          tone: t.danger,
          message: l.posCancelledNotice,
        ),
      ];
    }
    if (o.isPaid) {
      final total = rupees(o.bill.payable);
      return [
        gap,
        PaymentSuccess(
          headline: _taken.isEmpty
              ? l.posPaidHeadline(total: total)
              : l.posPaidByHeadline(
                  total: total,
                  methods: methodsLabel(_taken, l: l),
                ),
          changeDue: _change,
          onNewOrder: () => context.go(Routes.sell),
        ),
      ];
    }
    if (!canPay) {
      return [
        const SizedBox(height: 12),
        Text(
          l.posPaymentByBiller,
          textAlign: TextAlign.center,
          style: TextStyle(color: t.inkMuted),
        ),
      ];
    }
    return [
      gap,
      if (_showPrompt(o)) ...[
        ServiceChargePrompt(
          amount: o.bill.serviceCharge,
          onKeep: () => _answerPrompt(o, keep: true),
          onRemove: () => _answerPrompt(o, keep: false),
        ),
        const SizedBox(height: 12),
      ],
      PaymentCard(order: o, onRecorded: _recorded),
    ];
  }
}
