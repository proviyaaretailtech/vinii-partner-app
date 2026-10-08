import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../l10n/l10n.dart';
import '../theme/staff_theme.dart';

/// The moment after the last rupee is taken. Calm on purpose: a check mark
/// that settles in, what was paid and how, the change to give back if there
/// is any, and the one thing to do next. No confetti, no sound; the cashier
/// has a queue.
///
/// The check settles in over a third of a second, and not at all when the
/// device asks for reduced motion.
class PaymentSuccess extends StatelessWidget {
  const PaymentSuccess({
    super.key,
    required this.headline,
    required this.onNewOrder,
    this.changeDue,
  });

  /// "Paid · ₹504 by UPI".
  final String headline;

  /// Cash to hand back, when the guest paid with more than was due.
  final double? changeDue;
  final VoidCallback onNewOrder;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final change = changeDue != null && changeDue! > 0 ? changeDue : null;
    return Container(
      key: const Key('payment-success'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      decoration: BoxDecoration(
        color: t.tint(t.success),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.success.withValues(alpha: 0.25)),
      ),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.scale(scale: 0.7 + 0.3 * v, child: child),
                ),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: ViniiColors.brandGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 38,
                    color: ViniiColors.ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            if (change != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.paySuccessGiveBackChange,
                        style: TextStyle(
                          color: t.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      rupees(change),
                      key: const Key('success-change'),
                      style: TextStyle(
                        color: t.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('success-new-order'),
              style: FilledButton.styleFrom(
                backgroundColor: t.ink,
                foregroundColor: t.page,
                minimumSize: const Size(64, 56),
              ),
              onPressed: onNewOrder,
              child: Text(context.l10n.paySuccessNewOrder),
            ),
          ],
        ),
      ),
    );
  }
}
