/// The one error type screens show. [message] is already written for the
/// person holding the phone — never a stack trace or a Postgres code.
///
/// [message] is ENGLISH and stays the fallback, the log line and what tests
/// read. What a Hindi reader sees comes from [code]: a stable snake_case
/// word (`not_ready`, `server_pos_stale`…) that `failureText()` in
/// lib/l10n/failure_text.dart turns into a sentence in the current language,
/// using [args] for any numbers or names. A failure with no code shows
/// [message] as it is.
class AppFailure implements Exception {
  const AppFailure(
    this.message, {
    this.kind = FailureKind.unknown,
    this.code,
    this.args = const {},
  });

  final String message;
  final FailureKind kind;

  /// Key into the area maps in lib/l10n/failure_texts/. Null = untranslated.
  final String? code;

  /// Values the translated sentence needs (`{'name': 'Table 4'}`).
  final Map<String, Object?> args;

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
///
/// [fallback] is the English sentence for "this action failed for an unknown
/// reason"; give [fallbackCode] too so it can be translated (see
/// [AppFailure.code]).
AppFailure asFailure(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
  String fallbackCode = 'something_wrong',
  Map<String, Object?> fallbackArgs = const {},
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
      code: 'offline',
    );
  }
  return AppFailure(fallback, code: fallbackCode, args: fallbackArgs);
}
