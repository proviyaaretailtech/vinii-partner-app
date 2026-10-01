import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../application/sell_keys.dart';
import '../../core/failure.dart';
import '../../core/money.dart';
import '../../domain/billing.dart' show money;
import '../../domain/pos_order.dart';
import '../orders/order_widgets.dart' show SectionCard;
import '../theme/staff_theme.dart';
import '../widgets/state_views.dart';
import 'pos_widgets.dart' show showNotAvailableDialog;

/// One tender taken against an order.
class PaymentPart {
  const PaymentPart(this.method, this.amount);

  final PaymentMethod method;
  final double amount;
}

/// "Cash", "Cash + UPI": the methods used, each once, in the order taken.
String methodsLabel(Iterable<PaymentPart> parts) {
  final seen = <PaymentMethod>[];
  for (final p in parts) {
    if (!seen.contains(p.method)) seen.add(p.method);
  }
  return seen.map((m) => m.label).join(' + ');
}

/// Take payment: Cash, UPI, Card or Split.
///
/// Cash shows what the guest handed over and the change to give back, with
/// the notes a counter actually sees as one-tap shortcuts. UPI and Card take
/// an optional reference. **Split** divides the bill across two tenders that
/// must add up to what is due, exactly: short or over blocks the button, as
/// the web counter does. Each tender is its own payment on the server with
/// its own saved key (contract R3), so a dropped connection can be retried
/// without charging twice. If the second part does not go through, the first
/// stays recorded and the card says so and offers to try the second again.
///
/// The figures are the server's: the card never works out a total itself.
class PaymentCard extends StatefulWidget {
  const PaymentCard({super.key, required this.order, required this.onRecorded});

  /// The order being paid; the card reads what is due from it.
  final PlacedOrder order;

  /// After each payment the server accepted: the order as it answered, what
  /// was taken and, for a single cash payment, what the guest handed over.
  final void Function(
    PlacedOrder order,
    List<PaymentPart> parts,
    double? cashReceived,
  )
  onRecorded;

  @override
  State<PaymentCard> createState() => _PaymentCardState();
}

/// The second part of a split that was not confirmed.
class _RetryLeg {
  const _RetryLeg(this.method, this.amount, this.reference);

  final PaymentMethod method;
  final double amount;
  final String? reference;
}

class _PaymentCardState extends State<PaymentCard> {
  PaymentMethod _method = PaymentMethod.cash;
  bool _split = false;
  bool _paying = false;
  _RetryLeg? _retry;

  final _amount = TextEditingController();
  final _received = TextEditingController();
  final _reference = TextEditingController();

  PaymentMethod _methodA = PaymentMethod.cash;
  PaymentMethod _methodB = PaymentMethod.upi;
  final _partA = TextEditingController();
  final _partB = TextEditingController();
  final _refA = TextEditingController();
  final _refB = TextEditingController();

  static const _notes = [50, 100, 200, 500];

  static String _plain(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
  static double? _parse(String v) =>
      double.tryParse(v.trim().replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();
    _amount.text = _plain(widget.order.due);
  }

  @override
  void didUpdateWidget(PaymentCard old) {
    super.didUpdateWidget(old);
    if (old.order.id != widget.order.id) {
      _resetAll();
    } else if ((old.order.due - widget.order.due).abs() > 0.004) {
      // Something moved what is due (a payment, the service charge): start
      // the form from the new figure.
      _amount.text = _plain(widget.order.due);
      _received.clear();
      _reference.clear();
      if (_retry == null) {
        _partA.clear();
        _partB.clear();
      }
    }
  }

  void _resetAll() {
    _split = false;
    _retry = null;
    _amount.text = _plain(widget.order.due);
    for (final c in [_received, _reference, _partA, _partB, _refA, _refB]) {
      c.clear();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _amount,
      _received,
      _reference,
      _partA,
      _partB,
      _refA,
      _refB,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Checking ───────────────────────────────────────────────────────────

  String? _singleProblem(PlacedOrder o) {
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

  double _gap(PlacedOrder o) {
    final total = money(
      (_parse(_partA.text) ?? 0) + (_parse(_partB.text) ?? 0),
    );
    return money(o.due - total);
  }

  String? _splitProblem(PlacedOrder o) {
    final a = _parse(_partA.text) ?? 0;
    final b = _parse(_partB.text) ?? 0;
    if (a <= 0 || b <= 0) return 'Enter an amount for both parts.';
    final gap = _gap(o);
    if (gap > 0.005) return 'Short by ${rupees(gap)}.';
    if (gap < -0.005) return 'Over by ${rupees(-gap)}.';
    return null;
  }

  String? _ref(PaymentMethod m, TextEditingController c) =>
      m == PaymentMethod.cash || c.text.trim().isEmpty ? null : c.text.trim();

  // ── Charging ───────────────────────────────────────────────────────────

  Future<void> _charge() async {
    final o = widget.order;
    if (_paying) return;
    if (_split) return _chargeSplit(o);
    if (_singleProblem(o) != null) return;
    final amount = money(_parse(_amount.text)!);
    final method = _method;
    final reference = _ref(method, _reference);
    final cash = method == PaymentMethod.cash ? _parse(_received.text) : null;
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
        _received.clear();
        _reference.clear();
      });
      widget.onRecorded(updated, [PaymentPart(method, amount)], cash);
      if (!mounted) return;
      showDone(
        context,
        updated.isPaid
            ? 'Paid in full.'
            : '${rupees(amount)} received by ${method.label}. '
                  '${rupees(updated.due)} still due.',
      );
    } on AppFailure catch (e) {
      await _fail(e);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _chargeSplit(PlacedOrder o) async {
    if (_splitProblem(o) != null) return;
    final a = money(_parse(_partA.text)!);
    final b = money(_parse(_partB.text)!);
    final leg1 = (_methodA, a, _ref(_methodA, _refA));
    final leg2 = _RetryLeg(_methodB, b, _ref(_methodB, _refB));
    final services = AppScope.of(context);
    final keys = PendingKeys(services.prefs);
    setState(() => _paying = true);
    PlacedOrder? afterFirst;
    try {
      final first = await keys.run(
        PendingKeys.paymentScope(o.id),
        (key) => services.backend.pos.recordPayment(
          o,
          leg1.$1,
          leg1.$2,
          idempotencyKey: key,
          reference: leg1.$3,
        ),
      );
      afterFirst = first;
      if (!mounted) return;
      widget.onRecorded(first, [PaymentPart(leg1.$1, leg1.$2)], null);
      await _secondPart(first, leg2, keys);
    } on AppFailure catch (e) {
      if (afterFirst != null) {
        // Part 1 is recorded and cannot be undone; say what is left.
        if (mounted) setState(() => _retry = leg2);
      }
      await _fail(e, afterFirst: afterFirst != null);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Takes the second part of a split, with its own saved key so a retry
  /// after a dropped connection cannot charge it twice.
  Future<void> _secondPart(
    PlacedOrder afterFirst,
    _RetryLeg leg,
    PendingKeys keys,
  ) async {
    final services = AppScope.of(context);
    final done = await keys.run(
      '${PendingKeys.paymentScope(afterFirst.id)}:2',
      (key) => services.backend.pos.recordPayment(
        afterFirst,
        leg.method,
        leg.amount,
        idempotencyKey: key,
        reference: leg.reference,
      ),
    );
    if (!mounted) return;
    setState(() {
      _retry = null;
      _split = false;
    });
    widget.onRecorded(done, [PaymentPart(leg.method, leg.amount)], null);
    if (!mounted) return;
    showDone(context, 'Paid in full.');
  }

  Future<void> _retrySecondPart() async {
    final leg = _retry;
    if (leg == null || _paying) return;
    final services = AppScope.of(context);
    setState(() => _paying = true);
    try {
      await _secondPart(widget.order, leg, PendingKeys(services.prefs));
    } on AppFailure catch (e) {
      await _fail(e, afterFirst: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _fail(AppFailure e, {bool afterFirst = false}) async {
    if (!mounted) return;
    // Stop the spinner first: the dialog waits for the cashier.
    setState(() => _paying = false);
    if (e.kind == FailureKind.notReady) {
      await showNotAvailableDialog(context, e.message);
    } else {
      showFailure(
        context,
        afterFirst
            ? AppFailure(
                'The first part was received, but the second was not '
                'confirmed. ${e.message}',
                kind: e.kind,
              )
            : e,
      );
    }
  }

  // ── Building ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final o = widget.order;
    final problem = _split ? _splitProblem(o) : _singleProblem(o);
    final amount = _parse(_amount.text);
    final label = _split
        ? (problem == null ? 'Charge ${rupees(o.due)}' : 'Charge')
        : (amount == null || amount <= 0
              ? 'Charge'
              : 'Charge ${rupees(money(amount))}');
    if (_retry != null) {
      return SectionCard(
        key: const Key('payment-card'),
        title: 'Take payment',
        child: _retryBanner(context, _retry!),
      );
    }
    return SectionCard(
      key: const Key('payment-card'),
      title: 'Take payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tiles(context),
          const SizedBox(height: 16),
          if (_split) _splitParts(context, o) else _single(context, o),
          if (problem != null && !_split && _amount.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            _problem(context, problem, o),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('pay-charge'),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 58)),
            onPressed: problem == null && !_paying ? _charge : null,
            child: _paying
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: t.onAccent,
                    ),
                  )
                : Text(label),
          ),
        ],
      ),
    );
  }

  Widget _problem(BuildContext context, String problem, PlacedOrder o) {
    final t = ViniiTokens.of(context);
    final short =
        _split && (problem.startsWith('Short') || problem.startsWith('Over'));
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Icon(
            short ? Icons.balance_rounded : Icons.error_outline_rounded,
            size: 18,
            color: t.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              problem,
              style: TextStyle(color: t.danger, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _retryBanner(BuildContext context, _RetryLeg leg) {
    final t = ViniiTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: t.tint(t.warning),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sync_problem_rounded, size: 20, color: t.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The first part is recorded. The second part '
                  '(${leg.method.label} ${rupees(leg.amount)}) was not '
                  'confirmed.',
                  style: TextStyle(color: t.ink, fontSize: 14.5, height: 1.35),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                TextButton(
                  key: const Key('split-forget'),
                  style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                  onPressed: _paying
                      ? null
                      : () => setState(() {
                          _retry = null;
                          _split = false;
                          _amount.text = _plain(widget.order.due);
                        }),
                  child: const Text('Take it another way'),
                ),
                TextButton(
                  key: const Key('split-retry'),
                  style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                  onPressed: _paying ? null : _retrySecondPart,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tiles(BuildContext context) {
    return Row(
      children: [
        for (final m in PaymentMethod.values) ...[
          Expanded(
            child: _MethodTile(
              icon: switch (m) {
                PaymentMethod.cash => Icons.payments_outlined,
                PaymentMethod.upi => Icons.qr_code_2_rounded,
                PaymentMethod.card => Icons.credit_card_rounded,
              },
              label: m.label,
              selected: !_split && m == _method,
              onTap: _paying || _retry != null
                  ? null
                  : () => setState(() {
                      _method = m;
                      _split = false;
                    }),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: _MethodTile(
            key: const Key('pay-split'),
            icon: Icons.call_split_rounded,
            label: 'Split',
            selected: _split,
            onTap: _paying || _retry != null
                ? null
                : () => setState(() => _split = true),
          ),
        ),
      ],
    );
  }

  Widget _single(BuildContext context, PlacedOrder o) {
    final t = ViniiTokens.of(context);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('pay-amount'),
          controller: _amount,
          enabled: !_paying,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: numbers,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (_method == PaymentMethod.cash) ...[
          TextField(
            key: const Key('pay-received'),
            controller: _received,
            enabled: !_paying,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numbers,
            decoration: InputDecoration(
              labelText: 'Cash received (optional)',
              prefixText: '₹ ',
              helperText: change == null
                  ? 'Type what the guest handed over to see the change.'
                  : null,
              helperMaxLines: 2,
              suffixIcon: _received.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_received.clear),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in _notes)
                _ShortcutButton(
                  key: Key('cash-$n'),
                  label: '+₹$n',
                  onPressed: _paying
                      ? null
                      : () => setState(() {
                          final now = _parse(_received.text) ?? 0;
                          _received.text = _plain(money(now + n));
                        }),
                ),
              _ShortcutButton(
                key: const Key('cash-exact'),
                label: 'Exact',
                onPressed: _paying || amount == null
                    ? null
                    : () => setState(() => _received.text = _plain(amount)),
              ),
            ],
          ),
        ] else
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
                    style: TextStyle(fontWeight: FontWeight.w600, color: t.ink),
                  ),
                ),
                Text(
                  rupees(change),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _splitParts(BuildContext context, PlacedOrder o) {
    final t = ViniiTokens.of(context);
    final gap = _gap(o);
    final covered =
        _splitProblem(o) == null ||
        (gap.abs() <= 0.005 && (_parse(_partA.text) ?? 0) > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SplitPart(
          index: 1,
          method: _methodA,
          onMethod: (m) => setState(() => _methodA = m),
          amount: _partA,
          reference: _refA,
          enabled: !_paying && _retry == null,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        _SplitPart(
          index: 2,
          method: _methodB,
          onMethod: (m) => setState(() => _methodB = m),
          amount: _partB,
          reference: _refB,
          enabled: !_paying && _retry == null,
          onChanged: () => setState(() {}),
          onRest: () => setState(() {
            final a = _parse(_partA.text) ?? 0;
            _partB.text = _plain(money((o.due - a).clamp(0, double.infinity)));
          }),
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Container(
            key: const Key('split-status'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.tint(covered ? t.success : t.warning),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  covered ? Icons.check_circle_rounded : Icons.pending_outlined,
                  size: 20,
                  color: covered ? t.success : t.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    covered
                        ? 'Covered'
                        : gap > 0
                        ? 'Short by'
                        : 'Over by',
                    style: TextStyle(color: t.ink, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  covered ? rupees(o.due) : rupees(gap.abs()),
                  style: TextStyle(
                    color: t.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Cash · UPI · Card · Split: a tall target with an icon and a word.
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final fg = selected ? t.page : t.ink;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? t.ink : t.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? t.ink : t.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: onTap == null ? t.inkMuted : fg),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: onTap == null ? t.inkMuted : fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// One tender of a split: how it is paid and how much.
class _SplitPart extends StatelessWidget {
  const _SplitPart({
    required this.index,
    required this.method,
    required this.onMethod,
    required this.amount,
    required this.reference,
    required this.enabled,
    required this.onChanged,
    this.onRest,
  });

  final int index;
  final PaymentMethod method;
  final ValueChanged<PaymentMethod> onMethod;
  final TextEditingController amount;
  final TextEditingController reference;
  final bool enabled;
  final VoidCallback onChanged;

  /// "Rest" fills this part with what the other part leaves.
  final VoidCallback? onRest;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Column(
      key: Key('split-part-$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Part $index',
          style: TextStyle(
            color: t.inkSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SegmentedButton<PaymentMethod>(
          showSelectedIcon: false,
          segments: [
            for (final m in PaymentMethod.values)
              ButtonSegment(value: m, label: Text(m.label)),
          ],
          selected: {method},
          onSelectionChanged: enabled ? (s) => onMethod(s.first) : null,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: t.ink,
            selectedForegroundColor: t.page,
            foregroundColor: t.ink,
            backgroundColor: t.surface,
            side: BorderSide(color: t.border),
            minimumSize: const Size(0, 44),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: Key('split-amount-$index'),
                controller: amount,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  labelText: 'Part $index amount',
                  prefixText: '₹ ',
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            if (onRest != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('split-rest'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 56),
                ),
                onPressed: enabled ? onRest : null,
                child: const Text('Rest'),
              ),
            ],
          ],
        ),
        if (method != PaymentMethod.cash) ...[
          const SizedBox(height: 8),
          TextField(
            controller: reference,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: method == PaymentMethod.upi
                  ? 'UPI reference (optional)'
                  : 'Card slip number (optional)',
            ),
          ),
        ],
      ],
    );
  }
}
