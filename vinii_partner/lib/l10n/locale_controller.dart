import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Intl;

import '../data/backend.dart';
import '../data/local_prefs.dart';
import 'app_localizations.dart';
import 'locales.dart';
import 'script_fonts.dart';

/// Says something to a screen reader. Replaceable so tests can listen.
typedef Announcer = void Function(String message, ui.TextDirection direction);

void _announceToPlatform(String message, ui.TextDirection direction) {
  final view = ui.PlatformDispatcher.instance.implicitView;
  if (view == null) return;
  SemanticsService.sendAnnouncement(view, message, direction);
}

/// The app's language, as app state.
///
/// * [locale] feeds `MaterialApp.locale`, so a change repaints every screen in
///   the same frame: no restart, the navigator and every screen's state stay.
/// * Setting [Intl.defaultLocale] in that same step switches the number and
///   date formats with it.
/// * Hindi needs the Devanagari font. [select] loads it FIRST, keeps showing
///   the current language meanwhile ([pending] says what is loading), and
///   swaps only once the font is registered, so there is never a half-
///   translated screen or a row of empty boxes. A load that takes more than
///   [timeout] or fails leaves the current language in place and sets
///   [failed], for an inline error and Retry. The last selection wins.
/// * The choice is saved in local prefs and mirrored to
///   `user_preferences.locale`; the mirror is silent and retried next launch.
class LocaleController extends ChangeNotifier {
  LocaleController({
    required this.prefs,
    required this.server,
    ScriptFontLoader? fonts,
    this.timeout = const Duration(seconds: 8),
    this._deviceLocales,
    Announcer? announcer,
  }) : fonts = fonts ?? BundledScriptFonts(),
       _announce = announcer ?? _announceToPlatform;

  final LocalPrefs prefs;
  final UserPreferencesRepository server;
  final ScriptFontLoader fonts;

  /// How long a font may take before the switch is given up on.
  final Duration timeout;
  final List<Locale>? _deviceLocales;
  final Announcer _announce;

  AppLocale _active = englishLocale;
  AppLocale? _pending;
  AppLocale? _failed;
  var _ticket = 0;
  String? _userId;
  Timer? _restoreRetry;

  /// The language on screen now.
  AppLocale get active => _active;
  Locale get locale => _active.locale;

  /// The language being loaded, while the current one is still showing.
  AppLocale? get pending => _pending;

  /// The language whose font could not be loaded (inline error + Retry).
  AppLocale? get failed => _failed;

  /// What `MaterialApp.supportedLocales` lists.
  List<Locale> get supportedLocales => [
    for (final l in selectableLocales) l.locale,
    // A test can select the pseudo-language without the build flag.
    if (_active == pseudoLocale && !kPseudoLocale) pseudoLocale.locale,
  ];

  List<Locale> get _device =>
      _deviceLocales ?? ui.PlatformDispatcher.instance.locales;

  /// Reads the saved language (else the phone's) BEFORE the first frame, so a
  /// Hindi user never sees English first. `main` awaits this before `runApp`.
  /// When the font cannot be loaded in time the app starts in English, keeps
  /// the saved choice, and tries again in the background.
  Future<void> restore() async {
    final saved = appLocaleFor(prefs.localeCode);
    final target =
        saved ?? (kPseudoLocale ? pseudoLocale : resolveDeviceLocale(_device));
    if (target == _active) return;
    final ticket = ++_ticket;
    try {
      await _loadFontFor(target);
    } catch (_) {
      _retryRestoreLater(target, ticket, 1);
      return;
    }
    if (ticket != _ticket) return;
    _apply(target, announce: false);
  }

  void _retryRestoreLater(AppLocale target, int ticket, int attempt) {
    if (attempt > 3) return;
    _restoreRetry?.cancel();
    _restoreRetry = Timer(Duration(seconds: 5 * attempt * attempt), () async {
      if (ticket != _ticket) return;
      try {
        await _loadFontFor(target);
      } catch (_) {
        _retryRestoreLater(target, ticket, attempt + 1);
        return;
      }
      if (ticket == _ticket) _apply(target, announce: false);
    });
  }

  /// The person chose [target] (or the server said so: [fromServer]).
  Future<void> select(AppLocale target, {bool fromServer = false}) async {
    final ticket = ++_ticket;
    _restoreRetry?.cancel();
    if (target == _active) {
      // Back to what is showing: cancel whatever was loading, clear an error.
      if (_pending != null || _failed != null) {
        _pending = null;
        _failed = null;
        notifyListeners();
      }
      return;
    }
    _pending = target;
    _failed = null;
    notifyListeners();
    try {
      await _loadFontFor(target);
    } catch (_) {
      if (ticket != _ticket) return; // a later choice already took over
      _pending = null;
      _failed = target;
      notifyListeners();
      return;
    }
    if (ticket != _ticket) return; // last selection wins
    _apply(target, announce: !fromServer);
    await _remember(target, fromServer: fromServer);
  }

  /// Tries the failed language again.
  Future<void> retry() async {
    final target = _failed;
    if (target != null) await select(target);
  }

  Future<void> _loadFontFor(AppLocale target) async {
    if (target.needsDevanagari && !fonts.isReady(ScriptKind.devanagari)) {
      await fonts.ensureLoaded(ScriptKind.devanagari).timeout(timeout);
    }
  }

  /// The swap: language, number/date formats and listeners, in one step.
  void _apply(AppLocale target, {required bool announce}) {
    _active = target;
    _pending = null;
    _failed = null;
    Intl.defaultLocale = target.intlName;
    // Widgets that format a date or amount without asking for a translated
    // string have no reason to rebuild on their own: mark every element dirty
    // so the whole tree repaints with the new formats in this same frame
    // (state is untouched; this is a rebuild, not a restart).
    _rebuildEverything();
    notifyListeners();
    if (announce) {
      final said = lookupAppLocalizations(target.locale)
          .languageChanged(language: target.nativeName);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _announce(said, ui.TextDirection.ltr),
      );
    }
  }

  void _rebuildEverything() {
    final binding = WidgetsBinding.instance;
    final root = binding.rootElement;
    if (root == null) return;
    void rebuild() {
      void dirty(Element e) {
        e.markNeedsBuild();
        e.visitChildren(dirty);
      }

      root.visitChildren(dirty);
    }

    // Never mark elements dirty from inside a build/layout/paint pass.
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) => rebuild());
    } else {
      rebuild();
    }
  }

  Future<void> _remember(AppLocale target, {required bool fromServer}) async {
    if (target == pseudoLocale) return; // a test language: never stored
    await prefs.setLocaleCode(target.code);
    if (fromServer) return; // the server already has it
    await prefs.setLocaleSyncPending(true);
    unawaited(_push());
  }

  /// Writes the saved choice to `user_preferences`. Silent on failure: the
  /// pending flag stays set and the next launch tries again.
  Future<void> _push() async {
    final user = _userId;
    final code = prefs.localeCode;
    if (user == null || code == null) return;
    try {
      await server.saveLocale(user, code);
      await prefs.setLocaleSyncPending(false);
    } catch (_) {
      // Offline or not set up: retried by [syncForUser] on the next launch.
    }
  }

  /// Called when a person is signed in. Pushes a choice that never reached
  /// the server; or, when this phone has no choice yet, adopts the one saved
  /// on the server (a new phone starts in the language they picked before).
  Future<void> syncForUser(String userId) async {
    _userId = userId;
    try {
      if (prefs.localeSyncPending) {
        await _push();
      } else if (prefs.localeCode == null) {
        final remote = appLocaleFor(await server.loadLocale(userId));
        if (_userId == userId &&
            prefs.localeCode == null &&
            remote != null &&
            remote != pseudoLocale &&
            remote != _active) {
          await select(remote, fromServer: true);
        }
      }
    } catch (_) {
      // Silent: offline now, tried again next launch.
    }
  }

  /// Called on sign-out: nothing is written for nobody.
  void detachUser() => _userId = null;

  @override
  void dispose() {
    _restoreRetry?.cancel();
    super.dispose();
  }
}
