import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/delivery_order.dart';
import '../../l10n/l10n.dart';
import '../theme/staff_theme.dart';
import '../widgets/rings.dart';

/// Small pieces shared by the Orders list, the order detail and the
/// new-order alert, so the three always describe an order the same way.

/// "Priya" from "Priya Deshmukh" — staff see first names only (PRD §6). A
/// missing name (or the "Customer" One Local sends for it) reads "Customer"
/// in the reader's language.
String firstName(AppLocalizations l, String full) {
  final parts = full.trim().split(RegExp(r'\s+'));
  return parts.isEmpty ||
          parts.first.isEmpty ||
          parts.first == customerNameFallback
      ? l.commonCustomer
      : parts.first;
}

/// The customer's name as written, or "Customer" in the reader's language
/// when One Local sent none.
String customerDisplayName(AppLocalizations l, String full) {
  final name = full.trim();
  return name.isEmpty || name == customerNameFallback ? l.commonCustomer : full;
}

/// How the customer pays. One Local's default "Cash on delivery" is shown in
/// the reader's language; any other text is shown as stored.
String orderPaymentLabel(AppLocalizations l, String payment) =>
    payment == paymentCashOnDelivery ? l.ordersPaymentCod : payment;

/// A timeline step by its code (`order_events.kind`). A code this build does
/// not know shows as readable words, never blank.
String orderEventLabel(AppLocalizations l, OrderEvent e) => switch (e.kind) {
  'placed' => l.ordersEventPlaced,
  'accepted' => l.ordersEventAccepted,
  'kot_fired' => l.ordersEventKotFired,
  'kot_preparing' => l.ordersEventKotPreparing,
  'kot_ready' => l.ordersEventKotReady,
  'out_for_delivery' => l.ordersEventOutForDelivery,
  'delivered' => l.ordersEventDelivered,
  'paid' => l.ordersEventPaid,
  'rejected' => l.ordersEventRejected,
  'timed_out' => l.ordersEventTimedOut,
  _ => e.kind.replaceAll('_', ' '),
};

/// A reject reason in the reader's language. [reason] is one of
/// [rejectReasons] (the English text One Local receives).
String rejectReasonLabel(AppLocalizations l, String reason) => switch (reason) {
  'Item out of stock' => l.ordersReasonOutOfStock,
  'Kitchen busy' => l.ordersReasonKitchenBusy,
  'Closing soon' => l.ordersReasonClosingSoon,
  'Other' => l.ordersReasonOther,
  _ => reason,
};

/// Why an order was cancelled, as One Local stored it. The restaurant's own
/// reject reasons (with or without a "Restaurant: " prefix) are shown in the
/// reader's language; any other text is shown as stored.
String cancelReasonLabel(AppLocalizations l, String stored) {
  const prefix = 'Restaurant: ';
  final byRestaurant = stored.startsWith(prefix);
  final reason = byRestaurant ? stored.substring(prefix.length) : stored;
  final shown = rejectReasonLabel(l, reason);
  if (shown == reason && !byRestaurant) return stored;
  return byRestaurant ? l.ordersCancelReasonByRestaurant(reason: shown) : shown;
}

/// The message under "Delivery orders are not connected": the build's reason
/// (translated when it is the known "no server address" one), else a default.
String inboxUnavailableText(AppLocalizations l, String? reason) {
  if (reason == null) return l.ordersNotConnectedFallback;
  return reason == partnerApiUnavailableReason
      ? l.failOrdersUnavailable
      : reason;
}

/// Letter spacing for a Latin heading. Devanagari joins letters into
/// conjuncts, so tracking it (positive or negative) breaks the shapes: Hindi
/// gets none.
double tracking(BuildContext context, double latin) =>
    Localizations.maybeLocaleOf(context)?.languageCode == 'hi' ? 0 : latin;

/// "2 × Chicken Biryani, 1 × Coke".
String itemsSummary(DeliveryOrder o) =>
    o.items.map((l) => '${l.qty} × ${l.name}').join(', ');

String itemCountLabel(AppLocalizations l, int n) => l.ordersItemCount(count: n);

/// The accept-by deadline, or placed time + the outlet's accept window when
/// the server did not send one, so the countdown is never missing.
DateTime acceptDeadline(DeliveryOrder o, OutletStatus? outlet) =>
    o.deadline ??
    o.placedAt.add(Duration(seconds: outlet?.acceptWindowSeconds ?? 60));

/// The full length of the accept window, for the ring's fraction.
Duration acceptWindow(DeliveryOrder o, OutletStatus? outlet) {
  final d = o.deadline?.difference(o.placedAt);
  if (d != null && d.inSeconds > 0) return d;
  return Duration(seconds: outlet?.acceptWindowSeconds ?? 60);
}

/// Green, then amber under 20 s, then red under 10 s.
Color countdownColor(BuildContext context, Duration left) {
  final t = ViniiTokens.of(context);
  if (left.inSeconds < 10) return t.danger;
  if (left.inSeconds < 20) return t.warning;
  return ViniiColors.brandGreen;
}

/// The prep-time choice the chips start on: the outlet's default when it is
/// one of the chips, otherwise 20 minutes (PRD PD3).
int defaultPrepMinutes(OutletStatus? outlet) {
  final d = outlet?.defaultPrepMinutes;
  return d != null && prepTimeChoices.contains(d) ? d : 20;
}

/// A small ring with the seconds left, for order cards on the New tab.
class MiniCountdown extends StatelessWidget {
  const MiniCountdown({
    super.key,
    required this.deadline,
    required this.window,
  });

  final DateTime deadline;
  final Duration window;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Countdown(
      deadline: deadline,
      builder: (context, left) => ProgressRing(
        value: window.inMilliseconds == 0
            ? 0
            : left.inMilliseconds / window.inMilliseconds,
        color: countdownColor(context, left),
        trackColor: t.surfaceMuted,
        size: 38,
        stroke: 4,
        child: Text(
          '${left.inSeconds}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: t.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// "Ready in" chips: 10 · 15 · 20 · 30 · 45 min.
class PrepTimeChips extends StatelessWidget {
  const PrepTimeChips({
    super.key,
    required this.value,
    required this.onChanged,
    this.dark = false,
  });

  final int value;
  final ValueChanged<int> onChanged;

  /// On the near-black alert screen the selected chip is brand green.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in prepTimeChoices)
          ChoiceChip(
            label: Text(context.l10n.ordersMinutesShort(minutes: m)),
            selected: m == value,
            showCheckmark: false,
            onSelected: (_) => onChanged(m),
            selectedColor: dark ? ViniiColors.brandGreen : t.ink,
            backgroundColor: t.surface,
            side: BorderSide(
              color: m == value
                  ? (dark ? ViniiColors.brandGreen : t.ink)
                  : t.border,
            ),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: m == value ? (dark ? ViniiColors.ink : t.page) : t.ink,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          ),
      ],
    );
  }
}

/// One line of an order: "2 ×  Chicken Biryani   ₹480", with its note.
class DeliveryLineRow extends StatelessWidget {
  const DeliveryLineRow(this.line, {super.key, this.showPrice = true});

  final DeliveryLine line;
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 34),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: t.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${line.qty}×',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: t.ink,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: t.ink,
                  ),
                ),
                if (line.notes != null && line.notes!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
                          size: 14,
                          color: t.warning,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            line.notes!,
                            style: TextStyle(
                              fontSize: 13,
                              color: t.inkSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (showPrice) ...[
            const SizedBox(width: 12),
            Text(
              rupees(line.price * line.qty),
              style: TextStyle(fontWeight: FontWeight.w600, color: t.ink),
            ),
          ],
        ],
      ),
    );
  }
}

/// Asks why the order is being rejected. Returns the reason to send, or
/// null if the person changed their mind. "Other" needs a few words, so the
/// customer is never told nothing.
Future<String?> showRejectSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _RejectSheet(),
    );

class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  String _reason = rejectReasons.first;
  final _other = TextEditingController();

  bool get _isOther =>
      _reason == 'Other'; // i18n-ignore: code sent to One Local
  String? get _result {
    if (!_isOther) return _reason;
    final text = _other.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.ordersRejectTitle, style: text.titleLarge),
              const SizedBox(height: 6),
              Text(l.ordersRejectIntro, style: text.bodyMedium),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v ?? _reason),
                child: Column(
                  children: [
                    for (final r in rejectReasons)
                      RadioListTile<String>(
                        value: r,
                        title: Text(
                          rejectReasonLabel(l, r),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        contentPadding: EdgeInsets.zero,
                        activeColor: t.danger,
                      ),
                  ],
                ),
              ),
              if (_isOther) ...[
                const SizedBox(height: 4),
                TextField(
                  controller: _other,
                  autofocus: true,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l.commonReason,
                    hintText: l.ordersRejectHint,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: t.danger,
                  foregroundColor: Colors.white,
                ),
                onPressed: _result == null
                    ? null
                    : () => Navigator.pop(context, _result),
                child: Text(l.ordersRejectConfirm),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.ordersKeepOrder),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded section with an optional small uppercase title.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final String? title;
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

/// "Subtotal ........ ₹480". [strong] is the total line.
class AmountRow extends StatelessWidget {
  const AmountRow(this.label, this.amount, {super.key, this.strong = false});

  final String label;
  final String amount;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: strong ? 6 : 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? t.ink : t.inkSecondary,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                fontSize: strong ? 17 : 14.5,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: t.ink,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              fontSize: strong ? 24 : 14.5,
              letterSpacing: strong ? -0.5 : 0,
            ),
          ),
        ],
      ),
    );
  }
}
