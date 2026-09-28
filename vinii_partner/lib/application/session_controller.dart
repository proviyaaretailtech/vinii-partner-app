import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../core/failure.dart';
import '../data/backend.dart';
import '../data/local_prefs.dart';
import '../domain/app_definition.dart';
import '../domain/staff.dart';

/// Where the person is in the app's lifecycle. The router shows exactly one
/// screen per stage, so there is never a half-signed-in state.
enum SessionStage {
  /// Loader: starting Supabase, restoring the session, reading memberships.
  booting,

  /// The build is missing its Supabase settings.
  notConfigured,

  /// Something failed while booting (offline, server error). Retry.
  bootError,

  /// First launch on this phone: three intro pages.
  intro,
  signedOut,

  /// Signed in, but not an active member of any organization.
  noAccess,

  /// Belongs to several organizations and must pick one.
  choosingOrg,

  /// This build is older than the organization allows.
  updateRequired,
  ready,
}

class SessionController extends ChangeNotifier {
  SessionController({
    required this.config,
    required this.backend,
    required this.prefs,
  });

  final AppConfig config;
  final Backend backend;
  final LocalPrefs prefs;

  SessionStage _stage = SessionStage.booting;
  SessionStage get stage => _stage;

  /// Human words for the loader: "Checking your account…".
  String bootStep = 'Starting…';
  AppFailure? bootFailure;

  StaffUser? user;
  List<Membership> memberships = const [];
  Membership? membership;
  AppDefinition? definition;

  /// Set when switching organization failed, shown on the picker.
  AppFailure? switchFailure;

  StreamSubscription<StaffUser?>? _authSub;

  /// Runs on sign-out and organization switch, so controllers holding one
  /// organization's data (inbox poller, ring) can stop and forget it.
  final _resetHooks = <VoidCallback>[];
  void onReset(VoidCallback hook) => _resetHooks.add(hook);

  List<Membership> get activeMemberships =>
      memberships.where((m) => m.active).toList();

  bool can(Capability c) => membership?.can(c) ?? false;

  void _go(SessionStage s) {
    _stage = s;
    notifyListeners();
  }

  void _step(String text) {
    bootStep = text;
    notifyListeners();
  }

  Future<void> boot() async {
    bootFailure = null;
    _go(SessionStage.booting);
    if (!config.isConfigured) return _go(SessionStage.notConfigured);
    try {
      _step('Connecting…');
      await backend.start();
      _authSub ??= backend.auth.changes.listen((u) {
        if (u == null && user != null) _signedOutElsewhere();
      });
      if (!prefs.introSeen) return _go(SessionStage.intro);
      final current = backend.auth.currentUser;
      if (current == null) return _go(SessionStage.signedOut);
      user = current;
      await _loadWorkspace();
    } catch (e) {
      bootFailure = asFailure(e);
      if (e is AppFailure) bootFailure = e;
      if (bootFailure!.kind == FailureKind.auth) {
        user = null;
        return _go(SessionStage.signedOut);
      }
      _go(SessionStage.bootError);
    }
  }

  Future<void> finishIntro() async {
    await prefs.setIntroSeen();
    await boot();
  }

  /// Throws [AppFailure] for the sign-in screen to show.
  Future<void> signIn(String email, String password) async {
    user = await backend.auth.signIn(email: email, password: password);
    try {
      await _loadWorkspace();
    } on AppFailure catch (e) {
      bootFailure = e;
      _go(SessionStage.bootError);
    }
  }

  Future<void> sendPasswordReset(String email) =>
      backend.auth.sendPasswordReset(email);

  Future<void> _loadWorkspace() async {
    _step('Finding your restaurants…');
    memberships = await backend.workspace.memberships(user!);
    final usable = activeMemberships;
    if (usable.isEmpty) return _go(SessionStage.noAccess);
    final last = prefs.lastOrganization(user!.id);
    final remembered = usable
        .where((m) => m.organization.id == last)
        .firstOrNull;
    if (remembered != null) return _open(remembered);
    if (usable.length == 1) return _open(usable.single);
    _go(SessionStage.choosingOrg);
  }

  Future<void> _open(Membership m) async {
    _step('Opening ${m.organization.name}…');
    await backend.workspace.activate(m.organization);
    final def = await backend.workspace.appDefinition(m);
    membership = m;
    definition = def;
    await prefs.setLastOrganization(user!.id, m.organization.id);
    if (compareVersions(AppConfig.appVersion, def.minAppVersion) < 0) {
      return _go(SessionStage.updateRequired);
    }
    _go(SessionStage.ready);
  }

  /// From the organization picker.
  Future<void> chooseOrganization(Membership m) async {
    switchFailure = null;
    _runResetHooks();
    try {
      await _open(m);
    } on AppFailure catch (e) {
      switchFailure = e;
      _go(SessionStage.choosingOrg);
    }
  }

  /// "Switch organization" in More: back to the picker.
  void switchOrganization() {
    _runResetHooks();
    membership = null;
    definition = null;
    _go(SessionStage.choosingOrg);
  }

  /// Re-reads memberships and configuration (pull-to-refresh in More, or
  /// after an admin changed roles).
  Future<void> reload() => boot();

  Future<void> signOut({bool everywhere = false}) async {
    _runResetHooks();
    try {
      await backend.auth.signOut(everywhere: everywhere);
    } finally {
      _clear();
      _go(SessionStage.signedOut);
    }
  }

  void _signedOutElsewhere() {
    _runResetHooks();
    _clear();
    bootFailure = const AppFailure(
      'You were signed out. Sign in again to continue.',
      kind: FailureKind.auth,
    );
    _go(SessionStage.signedOut);
  }

  void _clear() {
    user = null;
    memberships = const [];
    membership = null;
    definition = null;
  }

  void _runResetHooks() {
    for (final h in _resetHooks) {
      h();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
