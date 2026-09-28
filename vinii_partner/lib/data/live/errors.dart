import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/failure.dart';

/// Turns a Supabase/PostgREST error into words for the person holding the
/// phone. Database functions raise `POS_<CODE>: message` (contract §4.1),
/// like One Local's `OL_<CODE>: message`; the message after the colon is
/// already written for people.
AppFailure fromSupabase(Object error, {String? notReady}) {
  if (error is AppFailure) return error;
  if (error is AuthException) return _fromAuth(error);
  if (error is PostgrestException) {
    final (:code, :message) = _unwrap(error);
    final coded = RegExp(
      r'^(POS|OL|VINII)_([A-Z_]+):\s*(.+)$',
      dotAll: true,
    ).firstMatch(message);
    if (coded != null) {
      final text = _sentence(coded.group(3)!.trim());
      return switch (coded.group(2)) {
        'STALE' ||
        'WRONG_STATE' ||
        'EXPIRED' ||
        'CONFLICT' => AppFailure(text, kind: FailureKind.conflict),
        'FORBIDDEN' => AppFailure(text, kind: FailureKind.forbidden),
        'NOT_FOUND' => AppFailure(text, kind: FailureKind.rejected),
        _ => AppFailure(text, kind: FailureKind.rejected),
      };
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
      );
    }
    if (code == '42501' || code == 'PGRST301') {
      return const AppFailure(
        'You do not have permission to do that.',
        kind: FailureKind.forbidden,
      );
    }
    if (code == '23505') {
      return const AppFailure(
        'That already exists.',
        kind: FailureKind.conflict,
      );
    }
    if (code == '23514' || code == '23502' || code == '22P02') {
      return const AppFailure(
        'Some of the details are not valid. Check them and try again.',
        kind: FailureKind.rejected,
      );
    }
    if (code == 'PGRST116') {
      return const AppFailure(
        'That record no longer exists.',
        kind: FailureKind.rejected,
      );
    }
    if (code == 'PGRST303' || code == '401') {
      return const AppFailure(
        'Your session has ended. Sign in again.',
        kind: FailureKind.auth,
      );
    }
  }
  if (error is StorageException) {
    final status = '${error.statusCode}';
    if (status == '403' || status == '401') {
      return const AppFailure(
        'You do not have permission to upload photos.',
        kind: FailureKind.forbidden,
      );
    }
    if (status == '413') {
      return const AppFailure(
        'That photo is too large. Choose one under 5 MB.',
        kind: FailureKind.rejected,
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
    );
  }
  if (code == 'email_not_confirmed') {
    return const AppFailure(
      'Confirm your email address first. Look for the link in your inbox.',
      kind: FailureKind.auth,
    );
  }
  if (code == 'over_request_rate_limit' ||
      code == 'over_email_send_rate_limit' ||
      e.statusCode == '429') {
    return const AppFailure(
      'Too many attempts. Wait a minute and try again.',
      kind: FailureKind.rejected,
    );
  }
  if (code == 'user_banned') {
    return const AppFailure(
      'This account has been blocked. Contact your organization admin.',
      kind: FailureKind.forbidden,
    );
  }
  if (e is AuthRetryableFetchException) {
    return const AppFailure(
      'You are offline. Check the connection and try again.',
      kind: FailureKind.offline,
    );
  }
  return const AppFailure(
    'Could not sign in. Please try again.',
    kind: FailureKind.auth,
  );
}

String _sentence(String s) => s.isEmpty
    ? s
    : '${s[0].toUpperCase()}${s.substring(1)}${s.endsWith('.') ? '' : '.'}';
