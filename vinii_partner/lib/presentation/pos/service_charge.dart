import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/billing.dart' show formatPercent;
import '../theme/staff_theme.dart';

/// The service charge row of a bill and what a manager can do with it.
///
/// [percent] and [amount] describe the charge as it would be if it stayed on
/// the bill, so a removed charge can still be shown struck through with what
/// the guest was spared.
class ServiceChargeLine {
  const ServiceChargeLine({
    required this.percent,
    required this.amount,
    required this.waived,
    this.onRemove,
    this.onAddBack,
  });

  final double percent;
  final double amount;

  /// The charge has been taken off this bill.
  final bool waived;

  /// Null for people who may not remove the charge: they see the row only.
  final VoidCallback? onRemove;
  final VoidCallback? onAddBack;
}

/// "Service charge (10%)   ₹55   Remove" and, once removed, the same line
/// struck through with "Removed" and "Add back". The amounts stay in the
/// bill's right-hand column; the action sits beside the label.
class ServiceChargeRow extends StatelessWidget {
  const ServiceChargeRow(this.line, {super.key});

  final ServiceChargeLine line;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final waived = line.waived;
    final strike = waived ? TextDecoration.lineThrough : null;
    final muted = waived ? t.inkMuted : t.inkSecondary;
    final action = waived ? line.onAddBack : line.onRemove;
    final label = line.percent > 0
        ? 'Service charge (${formatPercent(line.percent)}%)'
        : 'Service charge';
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: muted,
                    decoration: strike,
                    decorationColor: muted,
                    fontWeight: FontWeight.w500,
                    fontSize: 14.5,
                  ),
                ),
                if (waived) _RemovedTag(color: t.warning),
                if (action != null)
                  TextButton(
                    key: Key(
                      waived
                          ? 'service-charge-add-back'
                          : 'service-charge-remove',
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      foregroundColor: t.ink,
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    onPressed: action,
                    child: Text(waived ? 'Add back' : 'Remove'),
                  ),
              ],
            ),
          ),
          Text(
            rupees(line.amount),
            style: TextStyle(
              color: waived ? t.inkMuted : t.ink,
              decoration: strike,
              decorationColor: t.inkMuted,
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovedTag extends StatelessWidget {
  const _RemovedTag({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.tint(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.remove_circle_outline_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'Removed',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the manager typed when removing the service charge.
class ServiceChargeRemoval {
  const ServiceChargeRemoval(this.reason);

  /// Optional, trimmed; null when left empty.
  final String? reason;
}

/// Asks before the service charge comes off a bill. [payLess] is how much
/// less the guest pays once it is gone (the charge and the GST on it).
/// Returns null if the manager keeps the charge.
Future<ServiceChargeRemoval?> showRemoveServiceChargeSheet(
  BuildContext context, {
  required double payLess,
}) => showModalBottomSheet<ServiceChargeRemoval>(
  context: context,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (context) => _RemoveSheet(payLess: payLess),
);

class _RemoveSheet extends StatefulWidget {
  const _RemoveSheet({required this.payLess});
  final double payLess;

  @override
  State<_RemoveSheet> createState() => _RemoveSheetState();
}

class _RemoveSheetState extends State<_RemoveSheet> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
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
              Text(
                'Remove the service charge from this bill?',
                style: text.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'The guest will pay ${rupees(widget.payLess)} less. '
                'This is recorded with your name.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('service-charge-reason'),
                controller: _reason,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'e.g. Regular guest, complaint about service',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('service-charge-confirm-remove'),
                style: FilledButton.styleFrom(
                  backgroundColor: t.danger,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final reason = _reason.text.trim();
                  Navigator.pop(
                    context,
                    ServiceChargeRemoval(reason.isEmpty ? null : reason),
                  );
                },
                child: const Text('Remove service charge'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep it'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gentle one-time question at the payment step. It never blocks paying:
/// it sits above the payment form, and either answer makes it go away for
/// good on this order.
class ServiceChargePrompt extends StatelessWidget {
  const ServiceChargePrompt({
    super.key,
    required this.amount,
    required this.onKeep,
    required this.onRemove,
  });

  final double amount;
  final VoidCallback onKeep;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Container(
      key: const Key('service-charge-prompt'),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      decoration: BoxDecoration(
        color: t.tint(t.info),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.info.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: t.info),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Service charge ${rupees(amount)} is on this bill. Remove it?',
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                TextButton(
                  key: const Key('service-charge-prompt-keep'),
                  style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                  onPressed: onKeep,
                  child: const Text('Keep'),
                ),
                TextButton(
                  key: const Key('service-charge-prompt-remove'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(64, 44),
                    foregroundColor: t.danger,
                  ),
                  onPressed: onRemove,
                  child: const Text('Remove'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
