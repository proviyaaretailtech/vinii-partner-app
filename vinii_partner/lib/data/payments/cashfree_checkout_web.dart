import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../application/guest_payments.dart';
import '../../core/failure.dart';

/// Cashfree's checkout script. Cashfree asks that it is loaded from their
/// CDN (never bundled), and it is only loaded when a guest actually chooses
/// to pay online, so no other page carries a third-party script.
const _sdkUrl = 'https://sdk.cashfree.com/js/v3/cashfree.js';

/// Opens Cashfree's checkout as a modal over the page, in the browser.
///
/// Only the payment session id is used here; the secret key lives on the
/// server. What the modal reports back is a hint, not proof of payment: the
/// caller always asks the server for the verified outcome.
///
/// Written from Cashfree's published web integration guide
/// (`Cashfree({mode}).checkout({paymentSessionId, redirectTarget: '_modal'})`)
/// and not yet run against Cashfree's sandbox: that needs a Cashfree account
/// and the server pieces in docs/PAYMENTS_CASHFREE.md.
class CashfreeCheckout {
  const CashfreeCheckout({this.production = false});

  /// False uses Cashfree's sandbox (test money only).
  final bool production;

  Future<void> _ensureSdk() async {
    if (globalContext.has('Cashfree')) return;
    final doc = globalContext['document'] as JSObject;
    final script = doc.callMethod<JSObject>(
      'createElement'.toJS,
      'script'.toJS,
    );
    final loaded = Completer<void>();
    script['src'] = _sdkUrl.toJS;
    script['async'] = true.toJS;
    script['onload'] = (JSAny? _) {
      if (!loaded.isCompleted) loaded.complete();
    }.toJS;
    script['onerror'] = (JSAny? _) {
      if (!loaded.isCompleted) loaded.completeError(_unreachable);
    }.toJS;
    (doc['head'] as JSObject).callMethod<JSAny?>('appendChild'.toJS, script);
    await loaded.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw _unreachable,
    );
  }

  static const _unreachable = AppFailure(
    'We could not reach the payment service. Check your connection and try '
    'again, or ask a member of staff to take the payment.',
    kind: FailureKind.offline,
  );

  Future<CheckoutResult> open(OnlinePayment payment) async {
    await _ensureSdk();
    final options = {'mode': production ? 'production' : 'sandbox'}.jsify();
    final sdk = globalContext.callMethod<JSObject>('Cashfree'.toJS, options);
    final args = {
      'paymentSessionId': payment.sessionId,
      'redirectTarget': '_modal',
    }.jsify();
    final result = await sdk
        .callMethod<JSPromise<JSAny?>>('checkout'.toJS, args)
        .toDart;
    final out = result as JSObject?;
    if (out == null) return CheckoutResult.completed;
    // An `error` means the modal was closed or the attempt failed; either
    // way the server's verified outcome decides what the guest is told.
    if (out.has('error')) return CheckoutResult.dropped;
    return CheckoutResult.completed;
  }
}
