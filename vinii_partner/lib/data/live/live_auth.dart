import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/failure.dart';
import '../../domain/staff.dart';
import '../backend.dart';
import 'errors.dart';
import 'live_backend.dart';

/// Staff sign in with the email and password they already use for the POS
/// (partner PRD PD6). One login serves every Proviyaa app.
class LiveAuth implements AuthGateway {
  LiveAuth(this.b);
  final LiveBackend b;

  GoTrueClient get _auth => b.client.auth;

  @override
  StaffUser? get currentUser => _toStaff(_auth.currentUser);

  @override
  Stream<StaffUser?> get changes => _auth.onAuthStateChange
      .where((s) => s.event == AuthChangeEvent.signedOut)
      .map((s) => _toStaff(s.session?.user));

  @override
  Future<StaffUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = _toStaff(res.user);
      if (user == null) {
        throw const AppFailure(
          'Could not sign in. Please try again.',
          kind: FailureKind.auth,
        );
      }
      return user;
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim().toLowerCase());
    } catch (e) {
      final f = fromSupabase(e);
      // Never reveal whether an account exists; only real faults surface.
      if (f.kind == FailureKind.offline || f.kind == FailureKind.rejected) {
        throw f;
      }
    }
  }

  @override
  Future<void> signOut({bool everywhere = false}) async {
    try {
      await _auth.signOut(
        scope: everywhere ? SignOutScope.global : SignOutScope.local,
      );
    } catch (e) {
      // Signing out must always leave this phone signed out, even offline:
      // the local session is cleared by the client before the network call.
      if (_auth.currentSession != null) throw fromSupabase(e);
    } finally {
      b.activeOrganization = null;
    }
  }

  StaffUser? _toStaff(User? u) {
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    return StaffUser(
      id: u.id,
      email: u.email ?? '',
      fullName: (meta['full_name'] ?? meta['name']) as String?,
    );
  }
}
