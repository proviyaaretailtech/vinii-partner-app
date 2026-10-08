import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/failure.dart';

/// Turns a Supabase/PostgREST error into words for the person holding the
/// phone. Database functions raise `POS_<CODE>: message` (contract §4.1),
/// like One Local's `OL_<CODE>: message`; the message after the colon is
/// already written for people.
///
/// [notReady] is the English sentence for "this database piece is missing";
/// pass [notReadyCode] (a code in lib/l10n/failure_texts/) so it can be
/// translated.
AppFailure fromSupabase(
  Object error, {
  String? notReady,
  String? notReadyCode,
  Map<String, Object?> notReadyArgs = const {},
}) {
  if (error is AppFailure) return error;
  if (error is AuthException) return _fromAuth(error);
  if (error is PostgrestException) {
    final (:code, :message) = _unwrap(error);
    final coded = RegExp(
      r'^(POS|OL|VINII)_([A-Z_]+):\s*(.+)$',
      dotAll: true,
    ).firstMatch(message);
    if (coded != null) {
      final name = coded.group(2)!;
      final raw = coded.group(3)!.trim();
      final text = _sentence(raw);
      final failureCode = serverFailureCode(name, raw);
      final kind = switch (name) {
        'STALE' ||
        'WRONG_STATE' ||
        'EXPIRED' ||
        'CONFLICT' => FailureKind.conflict,
        'FORBIDDEN' => FailureKind.forbidden,
        _ => FailureKind.rejected,
      };
      return AppFailure(text, kind: kind, code: failureCode);
    }
    // Function or table the app expects is not in this database yet.
    if (code == 'PGRST202' ||
        code == '42883' ||
        code == 'PGRST205' ||
        code == '42P01') {
      return AppFailure(
        notReady ??
            'This needs a database update that has not been applied yet.',
        kind: FailureKind.notReady,
        code: notReady == null ? 'not_ready' : notReadyCode,
        args: notReadyArgs,
      );
    }
    if (code == '42501' || code == 'PGRST301') {
      return const AppFailure(
        'You do not have permission to do that.',
        kind: FailureKind.forbidden,
        code: 'permission_denied',
      );
    }
    if (code == '23505') {
      return const AppFailure(
        'That already exists.',
        kind: FailureKind.conflict,
        code: 'already_exists',
      );
    }
    if (code == '23514' || code == '23502' || code == '22P02') {
      return const AppFailure(
        'Some of the details are not valid. Check them and try again.',
        kind: FailureKind.rejected,
        code: 'invalid_details',
      );
    }
    if (code == 'PGRST116') {
      return const AppFailure(
        'That record no longer exists.',
        kind: FailureKind.rejected,
        code: 'record_gone',
      );
    }
    if (code == 'PGRST303' || code == '401') {
      return const AppFailure(
        'Your session has ended. Sign in again.',
        kind: FailureKind.auth,
        code: 'session_ended',
      );
    }
  }
  if (error is StorageException) {
    final status = '${error.statusCode}';
    if (status == '403' || status == '401') {
      return const AppFailure(
        'You do not have permission to upload photos.',
        kind: FailureKind.forbidden,
        code: 'upload_denied',
      );
    }
    if (status == '413') {
      return const AppFailure(
        'That photo is too large. Choose one under 5 MB.',
        kind: FailureKind.rejected,
        code: 'photo_too_large',
      );
    }
  }
  return asFailure(error);
}

/// postgrest 2.9 `maybeSingle()` re-throws its error inside a catch-all,
/// which replaces PostgREST's code (e.g. `PGRST205`, table not found) with the
/// HTTP status (`404`) and puts the raw JSON body in the message. Recover the
/// real code and message so "not ready yet" and `POS_…` errors still map.
({String code, String message}) _unwrap(PostgrestException e) {
  final code = e.code ?? '';
  final message = e.message;
  if (RegExp(r'^\d{3}$').hasMatch(code) && message.trimLeft().startsWith('{')) {
    try {
      final body = jsonDecode(message);
      if (body is Map && body['code'] is String) {
        return (
          code: body['code'] as String,
          message: '${body['message'] ?? message}',
        );
      }
    } on FormatException {
      // Not JSON after all: keep what we have.
    }
  }
  return (code: code, message: message);
}

AppFailure _fromAuth(AuthException e) {
  final code = e.code ?? '';
  if (code == 'invalid_credentials' ||
      e.message.toLowerCase().contains('invalid login')) {
    return const AppFailure(
      'That email and password do not match. Check them and try again.',
      kind: FailureKind.auth,
      code: 'bad_credentials',
    );
  }
  if (code == 'email_not_confirmed') {
    return const AppFailure(
      'Confirm your email address first. Look for the link in your inbox.',
      kind: FailureKind.auth,
      code: 'email_unconfirmed',
    );
  }
  if (code == 'over_request_rate_limit' ||
      code == 'over_email_send_rate_limit' ||
      e.statusCode == '429') {
    return const AppFailure(
      'Too many attempts. Wait a minute and try again.',
      kind: FailureKind.rejected,
      code: 'rate_limited',
    );
  }
  if (code == 'user_banned') {
    return const AppFailure(
      'This account has been blocked. Contact your organization admin.',
      kind: FailureKind.forbidden,
      code: 'user_banned',
    );
  }
  if (e is AuthRetryableFetchException) {
    return const AppFailure(
      'You are offline. Check the connection and try again.',
      kind: FailureKind.offline,
      code: 'offline',
    );
  }
  return const AppFailure(
    'Could not sign in. Please try again.',
    kind: FailureKind.auth,
    code: 'sign_in_failed',
  );
}

String _sentence(String s) => s.isEmpty
    ? s
    : '${s[0].toUpperCase()}${s.substring(1)}${s.endsWith('.') ? '' : '.'}';

/// The translation code for a coded database error (`POS_STALE: …`):
/// `server_stale`, `server_forbidden`… Messages the screens must act on
/// (a reason is needed, enter the amount) get their own more helpful code;
/// a name with no translation falls back to the server's English sentence.
String serverFailureCode(String name, String message) {
  final m = message.toLowerCase();
  if (m.startsWith('a reason is needed')) {
    return 'server_reason_needed';
  }
  if (m.startsWith('enter the amount received')) {
    return 'server_amount_received';
  }
  return 'server_${name.toLowerCase()}';
}
