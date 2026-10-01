import 'package:flutter/widgets.dart';

import '../domain/pos_order.dart';

/// Online payment of the guest's bill, behind two small seams so the screen
/// never knows which gateway it is talking to and never holds a secret.
///
/// The flow (see docs/PAYMENTS_CASHFREE.md):
///   1. [GuestPayments.start]: the SERVER creates the gateway order (it alone
///      holds the secret key) and returns an [OnlinePayment] carrying only a
///      payment session id, which is safe to hold in a browser.
///   2. [GuestPayments.openCheckout]: the gateway's own checkout opens over
///      the page; the guest pays inside it.
///   3. [GuestPayments.outcome]: the SERVER says whether the money arrived
///      (from the gateway's signed webhook or by asking the gateway). What
///      the browser reports after checkout is never taken as proof.
enum PaymentOutcome {
  /// Not settled yet (a UPI approval can take a minute).
  pending,
  paid,
  failed,

  /// The guest closed the checkout without paying.
  dropped,
  expired,
}

/// What the browser comes back with after the checkout closes. It is only a
/// hint of what to expect; always confirm with [GuestPayments.outcome].
enum CheckoutResult { completed, dropped, failed }

/// One attempt to pay [amount] rupees. A new attempt gets a new [attemptId]
/// (the gateway refuses to reuse an order id, whatever happened to the first).
@immutable
class OnlinePayment {
  const OnlinePayment({
    required this.attemptId,
    required this.sessionId,
    required this.amount,
    this.linkUrl,
    this.expiresAt,
  });

  final String attemptId;

  /// The gateway's payment session id. Not a secret.
  final String sessionId;
  final double amount;

  /// A link that opens this payment on any phone, for the "pay from your own
  /// phone" QR code. Null when the server does not offer one.
  final String? linkUrl;
  final DateTime? expiresAt;
}

abstract class GuestPayments {
  const GuestPayments();

  /// Whether this restaurant can take online payments right now.
  bool get available;

  /// Cashfree wants a mobile number on every order, even a guest's. When true
  /// the payment screen asks for one before it lets the guest pay.
  bool get needsPayerPhone => false;

  /// Asks the server for a payment of [amount] against [orders].
  /// [idempotencyKey] stays the same for the same choice, so a double tap or
  /// a retry returns the first attempt instead of opening a second.
  Future<OnlinePayment> start({
    required List<PlacedOrder> orders,
    required double amount,
    required String idempotencyKey,
    String? payerPhone,
  });

  /// Opens the gateway's checkout over the page and returns when it closes.
  Future<CheckoutResult> openCheckout(
    BuildContext context,
    OnlinePayment payment,
  );

  /// The server's verified status of [payment].
  Future<PaymentOutcome> outcome(OnlinePayment payment);
}
