import '../../application/guest_payments.dart';
import '../../core/failure.dart';

/// Builds that are not a browser cannot open Cashfree's web checkout yet.
class CashfreeCheckout {
  const CashfreeCheckout({this.production = false});
  final bool production;

  Future<CheckoutResult> open(OnlinePayment payment) async {
    throw const AppFailure(
      'Paying online opens in the web version for now. Please ask a member '
      'of staff to take the payment.',
      kind: FailureKind.notReady,
      code: 'guest_pay_web_only',
    );
  }
}
