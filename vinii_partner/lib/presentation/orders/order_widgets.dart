import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/delivery_order.dart';
import '../theme/staff_theme.dart';
import '../widgets/rings.dart';

/// Small pieces shared by the Orders list, the order detail and the
/// new-order alert, so the three always describe an order the same way.

/// "Priya" from "Priya Deshmukh" — staff see first names only (PRD §6).
String firstName(String full) {
  final parts = full.trim().split(RegExp(r'\s+'));
  return parts.isEmpty || parts.first.isEmpty ? 'Customer' : parts.first;
}

/// "2 × Chicken Biryani, 1 × Coke".
String itemsSummary(DeliveryOrder o) =>
    o.items.map((l) => '${l.qty} × ${l.name}').join(', ');

String itemCountLabel(int n) => n == 1 ? '1 item' : '$n items';

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
            label: Text('$m min'),
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

  bool get _isOther => _reason == 'Other';
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
              Text('Reject this order?', style: text.titleLarge),
              const SizedBox(height: 6),
              Text(
                'The customer sees the reason on One Local. Pick the closest one.',
                style: text.bodyMedium,
              ),
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
                          r,
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
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'e.g. Gas cylinder finished',
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
                child: const Text('Reject order'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep the order'),
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
              title!.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: t.inkMuted,
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
