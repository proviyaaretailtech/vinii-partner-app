/// The one error type screens show. [message] is already written for the
/// person holding the phone — never a stack trace or a Postgres code.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.kind = FailureKind.unknown});

  final String message;
  final FailureKind kind;

  bool get isOffline => kind == FailureKind.offline;
  bool get isConflict => kind == FailureKind.conflict;

  @override
  String toString() => 'AppFailure($kind): $message';
}

enum FailureKind {
  /// No connection. Screens offer "Try again" and keep what they have.
  offline,

  /// Wrong email or password, or the session expired.
  auth,

  /// Signed in, but this role may not do that.
  forbidden,

  /// Someone else changed it first (e.g. another phone accepted the order).
  conflict,

  /// The request was understood and refused (bad input, wrong state).
  rejected,

  /// A database change the app needs has not been applied yet.
  notReady,
  unknown,
}

/// Wraps anything thrown by a data source into an [AppFailure].
AppFailure asFailure(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is AppFailure) return error;
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException') ||
      text.contains('Connection refused') ||
      text.contains('XMLHttpRequest error')) {
    return const AppFailure(
      'You are offline. Check the connection and try again.',
      kind: FailureKind.offline,
    );
  }
  return AppFailure(fallback);
}
