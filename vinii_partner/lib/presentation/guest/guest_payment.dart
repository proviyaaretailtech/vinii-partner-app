import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../application/guest_payments.dart';
import '../../core/failure.dart';
import '../../core/money.dart';
import '../../domain/billing.dart';
import '../../domain/pos_order.dart';
import '../../l10n/failure_text.dart';
import '../../l10n/l10n.dart';
import '../theme/guest_theme.dart';
import 'guest_bill.dart';
import 'guest_flow.dart';
import 'guest_placed.dart';
import 'guest_widgets.dart';
import 'look/look.dart';
import 'look/motion.dart';

enum _Phase {
  choose,
  starting,
  checkout,
  verifying,
  pending,
  paid,
  failed,
  dropped,
}

/// "Pay your bill": the whole bill or one person's share, through the
/// gateway's own checkout (UPI, cards, netbanking, wallets). The screen only
/// ever holds a payment session id; the server creates the order and says
/// whether the money arrived. What the checkout window reports is a hint,
/// never proof, so every finish is confirmed with the server before the
/// guest is told they have paid.
class GuestPaymentScreen extends StatefulWidget {
  const GuestPaymentScreen({super.key});

  /// How long to wait between asking the server whether it has been paid.
  /// Tests shorten it.
  static Duration pollEvery = const Duration(seconds: 2);

  @override
  State<GuestPaymentScreen> createState() => _GuestPaymentScreenState();
}

class _GuestPaymentScreenState extends State<GuestPaymentScreen> {
  static const _uuid = Uuid();

  _Phase _phase = _Phase.choose;
  bool _share = false;
  late int _people = GuestScope.read(context).partySize.clamp(2, 30);
  String _key = _uuid.v4();
  OnlinePayment? _attempt;
  AppFailure? _problem;
  bool _showQr = false;
  bool _showBill = false;
  double _paid = 0;
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  /// Said only once the guest has typed enough digits to be wrong, and says
  /// what to change.
  String? _phoneError(AppLocalizations l) {
    final d = _digits;
    if (d.length > 10) return l.guestPayPhoneTooLong;
    if (d.length == 10 && !RegExp(r'^[6-9]').hasMatch(d)) {
      return l.guestPayPhoneBadStart;
    }
    return null;
  }

  /// An Indian mobile number, which is all the payment service needs.
  bool get _phoneOk =>
      !_payments.needsPayerPhone || RegExp(r'^[6-9]\d{9}$').hasMatch(_digits);

  GuestPayments get _payments => GuestScope.read(context).gateway.payments!;

  List<PlacedOrder> get _orders => GuestScope.read(context).placed;

  double get _due => _orders.fold<double>(0, (a, o) => a + o.due);

  double get _amount {
    final due = _due;
    if (!_share || _people < 2) return due;
    return money(due / _people).clamp(1, due).toDouble();
  }

  /// A different choice is a different payment: a new key, and the old
  /// attempt (if any) is left to expire on its own.
  void _changed(VoidCallback change) => setState(() {
    change();
    _key = _uuid.v4();
    _attempt = null;
    _showQr = false;
  });

  Future<OnlinePayment> _ensureAttempt() async =>
      _attempt ??= await _payments.start(
        orders: _orders,
        amount: _amount,
        idempotencyKey: _key,
        payerPhone: _payments.needsPayerPhone ? _digits : null,
      );

  Future<void> _pay() async {
    setState(() {
      _phase = _Phase.starting;
      _problem = null;
    });
    try {
      final attempt = await _ensureAttempt();
      if (!mounted) return;
      setState(() => _phase = _Phase.checkout);
      final hint = await _payments.openCheckout(context, attempt);
      if (!mounted) return;
      await _confirm(attempt, hint);
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _problem = e;
      });
    }
  }

  /// Asks the server until it has an answer. The checkout window closing is
  /// only the cue to start asking.
  Future<void> _confirm(OnlinePayment attempt, CheckoutResult hint) async {
    setState(() => _phase = _Phase.verifying);
    for (var i = 0; i < 20; i++) {
      final PaymentOutcome outcome;
      try {
        outcome = await _payments.outcome(attempt);
      } on AppFailure catch (e) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.pending;
          _problem = e;
        });
        return;
      }
      if (!mounted) return;
      switch (outcome) {
        case PaymentOutcome.paid:
          _paid = attempt.amount;
          setState(() => _phase = _Phase.paid);
          _finish();
          return;
        case PaymentOutcome.failed:
        case PaymentOutcome.expired:
          _attempt = null;
          _key = _uuid.v4();
          setState(() => _phase = _Phase.failed);
          return;
        case PaymentOutcome.dropped:
          // The window was closed; the same session can be reopened.
          setState(() => _phase = _Phase.dropped);
          return;
        case PaymentOutcome.pending:
          // A closed window with nothing pending is a drop, not a wait.
          if (i == 0 && hint == CheckoutResult.dropped) {
            setState(() => _phase = _Phase.dropped);
            return;
          }
          setState(() => _phase = _Phase.pending);
          await Future<void>.delayed(GuestPaymentScreen.pollEvery);
          if (!mounted) return;
      }
    }
  }

  void _finish() {
    final remaining = (_due - _paid).clamp(0, double.infinity);
    Navigator.of(context).pushReplacement(
      guestRoute<void>(
        _PaidScreen(paid: _paid, remaining: remaining.toDouble()),
        up: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final l = context.l10n;
    final payments = s.gateway.payments;
    final orders = _orders;
    final busy =
        _phase == _Phase.starting ||
        _phase == _Phase.checkout ||
        _phase == _Phase.verifying;
    final canSplit = s.features.splitBill && s.features.splitParty;
    final bill = orders.isEmpty ? null : combinedBill(orders);
    final subtitle = [
      ?l.guestTableNameOf(s),
      for (final o in orders) '#${o.displayNo}',
    ].join(' · ');
    return GuestPage(
      bottom: payments == null || orders.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A disabled button with no reason is a dead end.
                if (!_phoneOk && !busy)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      l.guestPayNeedPhone,
                      textAlign: TextAlign.center,
                      style: p.body(13.5, color: p.inkMuted),
                    ),
                  ),
                GuestButton(
                  key: const ValueKey('pay-now'),
                  label: l.guestPayButton(amount: rupees(_amount)),
                  icon: Icons.lock_outline_rounded,
                  busy: busy,
                  onTap: busy || _amount <= 0 || !_phoneOk ? null : _pay,
                ),
              ],
            ),
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              GuestTopBar(title: l.guestPayTitle),
              const Center(child: PreviewBanner()),
              if (payments == null || orders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l.guestPayNotSetUp,
                    textAlign: TextAlign.center,
                    style: p.body(15, color: p.inkMuted),
                  ),
                )
              else ...[
                Reveal(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        _share ? l.guestPayYourShare : l.guestPayAmountToPay,
                        style: p.body(14, color: p.inkMuted),
                      ),
                      const SizedBox(height: 4),
                      CountUp(
                        value: _amount,
                        format: rupees,
                        duration: GuestMotion.slow,
                        style: p.price(52),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle, style: p.body(13, color: p.inkMuted)),
                      ],
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                if (_problem != null || _phase == _Phase.failed)
                  _Notice(
                    icon: Icons.error_outline_rounded,
                    color: p.danger,
                    title: l.guestPayFailedTitle,
                    body: _problem == null
                        ? l.guestPayFailedBody
                        : failureText(l, _problem!),
                  ),
                if (_phase == _Phase.dropped)
                  _Notice(
                    icon: Icons.info_outline_rounded,
                    color: p.keyLight,
                    title: l.guestPayClosedTitle,
                    body: l.guestPayClosedBody,
                  ),
                if (canSplit && _due > 0)
                  Reveal(
                    index: 1,
                    child: _SplitCard(
                      share: _share,
                      people: _people,
                      whole: _due,
                      onChoose: (share) => _changed(() => _share = share),
                      onPeople: (n) => _changed(() => _people = n.clamp(2, 30)),
                    ),
                  ),
                Reveal(
                  index: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: GuestCard(
                      onTap: () => setState(() => _showBill = !_showBill),
                      child: AnimatedSize(
                        duration: GuestMotion.base,
                        curve: GuestMotion.arrive,
                        alignment: Alignment.topCenter,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 20,
                                  color: p.inkMuted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l.guestPaySeeBill,
                                    style: p.body(15, weight: FontWeight.w700),
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: _showBill ? 0.5 : 0,
                                  duration: GuestMotion.base,
                                  child: Icon(
                                    Icons.expand_more_rounded,
                                    color: p.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                            if (_showBill && bill != null) ...[
                              const SizedBox(height: 12),
                              BillLines(bill: bill),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (payments.needsPayerPhone)
                  Reveal(
                    index: 3,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: GuestCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.guestPayYourMobile,
                              style: p.body(15, weight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              key: const ValueKey('pay-phone'),
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              maxLength: 14,
                              onChanged: (_) => setState(() {}),
                              style: p.body(16),
                              decoration: InputDecoration(
                                // Always visible, unlike prefixText.
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 8,
                                  ),
                                  child: Center(
                                    widthFactor: 1,
                                    child: Text(
                                      // i18n-ignore: country calling code
                                      '+91',
                                      style: p.body(
                                        16,
                                        weight: FontWeight.w700,
                                        color: p.inkMuted,
                                      ),
                                    ),
                                  ),
                                ),
                                // i18n-ignore: sample phone number
                                hintText: '98765 43210',
                                counterText: '',
                                errorText: _phoneError(l),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l.guestPayMobileWhy,
                              style: p.body(12.5, color: p.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Reveal(
                  index: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                          color: p.inkMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.guestPayMethods,
                            style: p.body(13.5, color: p.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (GuestScope.exitOf(context) != null)
                  Reveal(
                    index: 5,
                    child: _PhoneQr(
                      open: _showQr,
                      attempt: _attempt,
                      ready: _phoneOk,
                      onToggle: () async {
                        if (!_phoneOk) return;
                        setState(() => _showQr = !_showQr);
                        if (_showQr && _attempt == null) {
                          try {
                            await _ensureAttempt();
                          } on AppFailure catch (e) {
                            if (mounted) {
                              setState(() {
                                _showQr = false;
                                _problem = e;
                              });
                            }
                          }
                          if (mounted) setState(() {});
                        }
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: p.inkMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l.guestPayProcessedBy,
                          style: p.body(12.5, color: p.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (_phase == _Phase.starting ||
              _phase == _Phase.checkout ||
              _phase == _Phase.verifying ||
              _phase == _Phase.pending)
            _Overlay(
              phase: _phase,
              problem: _problem == null ? null : failureText(l, _problem!),
              onCheck: _attempt == null
                  ? null
                  : () => unawaited(
                      _confirm(_attempt!, CheckoutResult.completed),
                    ),
            ),
        ],
      ),
    );
  }
}

/// A soft banner for what just happened.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: p.isDark ? 0.14 : 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: p.body(14.5, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(body, style: p.body(13.5, color: p.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Whole bill" or "My share of N people".
class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.share,
    required this.people,
    required this.whole,
    required this.onChoose,
    required this.onPeople,
  });
  final bool share;
  final int people;
  final double whole;
  final ValueChanged<bool> onChoose;
  final ValueChanged<int> onPeople;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final l = context.l10n;
    Widget option(bool value, String title, String sub) {
      final on = share == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: GestureDetector(
            onTap: () => onChoose(value),
            child: AnimatedContainer(
              duration: GuestMotion.base,
              curve: GuestMotion.arrive,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: on ? p.accent.withValues(alpha: 0.14) : p.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: on ? p.accent : Colors.transparent,
                  width: 1.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: p.body(14, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(sub, style: p.price(15, color: on ? p.ink : p.inkMuted)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              option(false, l.guestPaySplitWhole, rupees(whole)),
              const SizedBox(width: 10),
              option(
                true,
                l.guestPaySplitMine,
                rupees(money(whole / people).clamp(1, whole)),
              ),
            ],
          ),
          AnimatedSize(
            duration: GuestMotion.base,
            curve: GuestMotion.arrive,
            alignment: Alignment.topCenter,
            child: share
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.guestPaySplitBetween,
                            style: p.body(14, color: p.inkMuted),
                          ),
                        ),
                        QtyStepper(qty: people, min: 2, onChanged: onPeople),
                        const SizedBox(width: 8),
                        Text(
                          l.guestPayPeople,
                          style: p.body(14, color: p.inkMuted),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// "Pay from your own phone": a QR code that opens this payment on another
/// phone. Shown only on a phone that was handed to the table.
class _PhoneQr extends StatelessWidget {
  const _PhoneQr({
    required this.open,
    required this.attempt,
    required this.ready,
    required this.onToggle,
  });
  final bool open;
  final OnlinePayment? attempt;

  /// The payment service has the number it needs, so a code can be made.
  final bool ready;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final l = context.l10n;
    final link = attempt?.linkUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: GuestCard(
        key: const ValueKey('pay-from-phone'),
        onTap: onToggle,
        child: AnimatedSize(
          duration: GuestMotion.base,
          curve: GuestMotion.arrive,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.phone_iphone_rounded, size: 20, color: p.inkMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.guestPayOwnPhone,
                          style: p.body(
                            15,
                            weight: FontWeight.w700,
                            color: ready ? p.ink : p.inkMuted,
                          ),
                        ),
                        if (!ready)
                          Text(
                            l.guestPayOwnPhoneNeedNumber,
                            style: p.body(12.5, color: p.inkMuted),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: GuestMotion.base,
                    child: Icon(Icons.expand_more_rounded, color: p.inkMuted),
                  ),
                ],
              ),
              if (open) ...[
                const SizedBox(height: 14),
                if (link == null)
                  const SizedBox.square(
                    dimension: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: QrImageView(
                      data: link,
                      size: 184,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.guestPayScanToPay(amount: rupees(attempt!.amount)),
                    textAlign: TextAlign.center,
                    style: p.body(13.5, color: p.inkMuted),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What the guest sees while the payment is in flight: one calm card over
/// the page, with the one instruction that matters ("don't pay twice").
class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.phase,
    required this.problem,
    required this.onCheck,
  });
  final _Phase phase;
  final String? problem;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final l = context.l10n;
    final (title, body) = switch (phase) {
      _Phase.starting => (l.guestPayStartingTitle, ''),
      _Phase.checkout => (l.guestPayCheckoutTitle, l.guestPayCheckoutBody),
      _Phase.verifying => (l.guestPayVerifyingTitle, l.guestPayVerifyingBody),
      _ => (l.guestPayPendingTitle, problem ?? l.guestPayPendingBody),
    };
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Container(
              key: ValueKey('pay-${phase.name}'),
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: p.hairline),
                boxShadow: p.lift(),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: p.accent,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: p.display(21),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: p.body(14, color: p.inkMuted),
                    ),
                  ],
                  if (phase == _Phase.pending && onCheck != null) ...[
                    const SizedBox(height: 18),
                    GuestButton(
                      label: l.guestPayCheckNow,
                      dense: true,
                      style: GuestButtonStyle.soft,
                      onTap: onCheck,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// After the server has confirmed the money: a receipt, and what (if
/// anything) is still owed at the table.
class _PaidScreen extends StatelessWidget {
  const _PaidScreen({required this.paid, required this.remaining});
  final double paid;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final l = context.l10n;
    final allPaid = remaining < 0.5;
    return CelebrationPage(
      title: allPaid ? l.guestPayReceivedTitle : l.guestPayShareTitle,
      lines: [
        rupees(paid),
        if (allPaid)
          l.guestPayThanks(name: s.definition.brand.displayName)
        else
          l.guestPayRemaining(
            amount: rupees(remaining),
            table: l.guestTableWordFor(s.definition).toLowerCase(),
          ),
      ],
      primary: GuestButton(
        label: allPaid ? l.guestPlacedOrderMore : l.guestPayBackToBill,
        trailingArrow: true,
        onTap: () => allPaid
            ? GuestFlow.orderMore(context)
            : Navigator.of(context).maybePop(),
      ),
      secondary: GuestButton(
        label: allPaid ? l.commonDone : l.guestPlacedOrderMore,
        style: GuestButtonStyle.outline,
        onTap: () => allPaid
            ? Navigator.of(context).popUntil((r) => r.isFirst)
            : GuestFlow.orderMore(context),
      ),
      dark: p.isDark,
    );
  }
}
