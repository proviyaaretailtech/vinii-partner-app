import 'package:uuid/uuid.dart';

import '../core/failure.dart';
import '../data/local_prefs.dart';

/// Idempotency keys for POS writes (platform contract R3).
///
/// A POS write can reach the server and still look like a failure on the
/// phone: the connection drops after the order was saved, the app is killed
/// mid-request. If the retry carried a new key, the kitchen would get the
/// same order twice. So the key is created when the cashier confirms, saved
/// on the phone *before* the request leaves, and reused on every retry —
/// even after a restart — until the server gives a definite answer.
///
/// "Definite" means: it succeeded, or it refused the request itself
/// ([FailureKind.rejected], [FailureKind.forbidden]), so nothing was
/// created. Offline, "not ready yet" and unknown errors keep the key.
class PendingKeys {
  PendingKeys(this.prefs);

  final LocalPrefs prefs;

  static const _uuid = Uuid();

  /// One pending order per organization on this phone.
  static String orderScope(String orgId) => 'order:$orgId';

  /// One pending payment per order.
  static String paymentScope(String orderId) => 'payment:$orderId';

  /// The key a retry would reuse, if one is waiting.
  String? pending(String scope) => prefs.pendingKey(scope);

  /// Runs [send] with the scope's key: the waiting one if there is one,
  /// otherwise a new UUID that is saved first.
  Future<T> run<T>(String scope, Future<T> Function(String key) send) async {
    final key = prefs.pendingKey(scope) ?? _uuid.v4();
    await prefs.setPendingKey(scope, key);
    try {
      final result = await send(key);
      await prefs.clearPendingKey(scope);
      return result;
    } on AppFailure catch (e) {
      if (e.kind == FailureKind.rejected || e.kind == FailureKind.forbidden) {
        await prefs.clearPendingKey(scope);
      }
      rethrow;
    }
  }
}
