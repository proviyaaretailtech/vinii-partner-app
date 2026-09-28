import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../application/sell_keys.dart';
import '../../core/failure.dart';
import '../../core/money.dart';
import '../../core/time_format.dart';
import '../../domain/billing.dart' show money;
import '../../domain/pos_order.dart';
import '../../domain/staff.dart';
import '../orders/order_widgets.dart' show AmountRow, SectionCard;
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/state_views.dart';
import 'pos_widgets.dart';

/// One saved POS order and its payment.
///
/// Everything money-related shows the figures the server stored on the
/// order ([PlacedOrder.bill]) — never a recomputation — so this phone, the
/// POS and the printed bill agree. Payments go through the POS front door
/// with a per-order idempotency key (contract R3): a retry after a dropped
/// connection cannot charge the guest twice.
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

  PaymentMethod _method = PaymentMethod.cash;
  final _amount = TextEditingController();
  final _received = TextEditingController();
  final _reference = TextEditingController();
  bool _paying = false;

  /// The payment made on this screen, for "Paid · ₹X by UPI".
  PaymentMethod? _paidBy;

  @override
  void initState() {
    super.initState();
    _order = widget.initial;
    if (_order == null) {
      _load();
    } else {
      _amount.text = _plain(_order!.due);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _received.dispose();
    _reference.dispose();
    super.dispose();
  }

  static String _plain(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  static double? _parse(String v) => double.tryParse(v.trim());

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final o = await AppScope.of(context).backend.pos.refresh(widget.orderId);
      if (!mounted) return;
      setState(() => _order = o);
      _amount.text = _plain(o.due);
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

  /// Why the payment cannot be recorded yet, or null.
  String? _paymentProblem(PlacedOrder o) {
    final amount = _parse(_amount.text);
    if (amount == null || amount <= 0) return 'Enter the amount.';
    if (amount > o.due + 0.009) {
      return 'That is more than the ${rupees(o.due)} due.';
    }
    if (_method == PaymentMethod.cash) {
      final got = _parse(_received.text);
      if (got != null && got + 0.009 < amount) {
        return 'Cash received is less than ${rupees(amount)}.';
      }
    }
    return null;
  }

  Future<void> _charge() async {
    final o = _order;
    if (o == null || _paying || _paymentProblem(o) != null) return;
    final amount = money(_parse(_amount.text)!);
    final method = _method;
    final reference = method == PaymentMethod.cash
        ? null
        : _reference.text.trim().isEmpty
        ? null
        : _reference.text.trim();
    final services = AppScope.of(context);
    setState(() => _paying = true);
    try {
      final updated = await PendingKeys(services.prefs).run(
        PendingKeys.paymentScope(o.id),
        (key) => services.backend.pos.recordPayment(
          o,
          method,
          amount,
          idempotencyKey: key,
          reference: reference,
        ),
      );
      if (!mounted) return;
      setState(() {
        _order = updated;
        _paidBy = method;
        _received.clear();
        _reference.clear();
        _amount.text = _plain(updated.due);
      });
      showDone(
        context,
        updated.isPaid
            ? 'Paid in full.'
            : '${rupees(amount)} received by ${method.label}. ${rupees(updated.due)} still due.',
      );
    } on AppFailure catch (e) {
      if (!mounted) return;
      // Stop the spinner first: the dialog waits for the cashier.
      setState(() => _paying = false);
      if (e.kind == FailureKind.notReady) {
        await showNotAvailableDialog(context, e.message);
      } else {
        showFailure(context, e);
        if (e.isConflict) await _load();
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      appBar: AppBar(
        title: Text(o?.displayNo ?? 'Order'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          TextButton(
            onPressed: () => context.go(Routes.sell),
            child: const Text('New order'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: o == null
          ? (_failure != null && !_loading
                ? FailureView(failure: _failure!, onRetry: _load)
                : const LoadingView(label: 'Loading order…'))
          : RefreshIndicator(onRefresh: _load, child: _body(context, o)),
    );
  }

  Widget _body(BuildContext context, PlacedOrder o) {
    final t = ViniiTokens.of(context);
    final canPay = AppScope.of(context).session.can(Capability.takePayment);
    final cancelled = o.status == PosStatus.cancelled;
    final where = [
      o.serviceType.label,
      if (o.table != null) o.table!.displayName,
      clockTime(o.createdAt),
    ].join(' · ');
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      o.displayNo,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(width: 10),
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
        if (cancelled) ...[
          const SizedBox(height: 12),
          NoticeBanner(
            icon: Icons.cancel_outlined,
            tone: t.danger,
            message: 'This order was cancelled. Nothing is due.',
          ),
        ] else if (o.isPaid) ...[
          const SizedBox(height: 12),
          _PaidCard(order: o, method: _paidBy),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: o.itemCount == 1 ? '1 item' : '${o.itemCount} items',
          child: Column(
            children: [
              for (final l in o.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${l.qty}×',
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
                              l.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: t.ink,
                              ),
                            ),
                            if (l.notes != null && l.notes!.isNotEmpty)
                              Text(
                                l.notes!,
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
                        rupees(l.lineTotal),
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
          title: 'Bill',
          child: Column(
            children: [
              BillLines(bill: o.bill),
              if (!cancelled) ...[
                AmountRow('Paid', rupees(o.paidAmount)),
                AmountRow('Due', rupees(o.due), strong: o.due > 0),
              ],
            ],
          ),
        ),
        if (!cancelled && !o.isPaid) ...[
          const SizedBox(height: 12),
          if (canPay)
            _paymentCard(context, o)
          else
            Text(
              'A biller or manager takes the payment for this order.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.inkMuted),
            ),
        ],
      ],
    );
  }

  Widget _paymentCard(BuildContext context, PlacedOrder o) {
    final t = ViniiTokens.of(context);
    final problem = _paymentProblem(o);
    final amount = _parse(_amount.text);
    final got = _parse(_received.text);
    final change =
        _method == PaymentMethod.cash &&
            amount != null &&
            got != null &&
            got >= amount
        ? money(got - amount)
        : null;
    final numbers = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      LengthLimitingTextInputFormatter(10),
    ];
    return SectionCard(
      title: 'Take payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final m in PaymentMethod.values)
                ChoiceChip(
                  avatar: Icon(
                    switch (m) {
                      PaymentMethod.cash => Icons.payments_outlined,
                      PaymentMethod.upi => Icons.qr_code_2_rounded,
                      PaymentMethod.card => Icons.credit_card_rounded,
                    },
                    size: 18,
                    color: m == _method ? t.page : t.ink,
                  ),
                  label: Text(m.label),
                  selected: m == _method,
                  showCheckmark: false,
                  selectedColor: t.ink,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: m == _method ? t.page : t.ink,
                  ),
                  onSelected: _paying
                      ? null
                      : (_) => setState(() => _method = m),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            enabled: !_paying,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numbers,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          if (_method == PaymentMethod.cash)
            TextField(
              controller: _received,
              enabled: !_paying,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: numbers,
              decoration: InputDecoration(
                labelText: 'Cash received (optional)',
                prefixText: '₹ ',
                helperText: change == null
                    ? 'Type what the guest handed over to see the change.'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            )
          else
            TextField(
              controller: _reference,
              enabled: !_paying,
              decoration: InputDecoration(
                labelText: _method == PaymentMethod.upi
                    ? 'UPI reference (optional)'
                    : 'Card slip number (optional)',
              ),
            ),
          if (change != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.tint(t.success),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.currency_rupee_rounded, color: t.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Change to return',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      ),
                    ),
                  ),
                  Text(
                    rupees(change),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: t.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (problem != null && _amount.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              problem,
              style: TextStyle(color: t.danger, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: problem == null && !_paying ? _charge : null,
            child: _paying
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: t.onAccent,
                    ),
                  )
                : Text(
                    amount == null || amount <= 0
                        ? 'Charge'
                        : 'Charge ${rupees(money(amount))}',
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Paid · ₹1,240 by UPI" and the way to the next guest.
class _PaidCard extends StatelessWidget {
  const _PaidCard({required this.order, this.method});

  final PlacedOrder order;
  final PaymentMethod? method;

  @override
  Widget build(BuildContext context) {
    final total = rupees(order.bill.payable);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ViniiColors.brandGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: ViniiColors.ink,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            method == null
                ? 'Paid · $total'
                : 'Paid · $total by ${method!.label}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ViniiColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ViniiColors.ink,
              foregroundColor: ViniiColors.brandGreen,
            ),
            onPressed: () => context.go(Routes.sell),
            child: const Text('New order'),
          ),
        ],
      ),
    );
  }
}
