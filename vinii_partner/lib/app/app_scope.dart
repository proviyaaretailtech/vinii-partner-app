import 'dart:async';

import 'package:flutter/material.dart';

import '../application/inbox_controller.dart';
import '../application/ring_player.dart';
import '../application/session_controller.dart';
import '../config/app_config.dart';
import '../data/backend.dart';
import '../data/local_prefs.dart';
import '../l10n/locale_controller.dart';

/// Everything long-lived, created once in `main` and reachable from any
/// widget with `AppScope.of(context)`.
class AppServices {
  AppServices({
    required this.config,
    required this.prefs,
    required this.backend,
    LocaleController? localeController,
  }) : _localeOverride = localeController {
    session.onReset(_features.clear);
    session.addListener(_followSignedInUser);
  }

  final AppConfig config;
  final LocalPrefs prefs;
  final Backend backend;
  final LocaleController? _localeOverride;

  late final session = SessionController(
    config: config,
    backend: backend,
    prefs: prefs,
  );
  late final ring = RingPlayer(prefs);
  late final inbox = InboxController(session: session, ring: ring);
  late final themeMode = ValueNotifier<ThemeMode>(prefs.themeMode);

  /// The app's language as state: `MaterialApp.locale` follows it, so a
  /// change repaints in place. `main` awaits `locale.restore()` before the
  /// first frame.
  late final locale =
      _localeOverride ??
      LocaleController(prefs: prefs, server: backend.userPreferences);

  String? _localeUser;

  /// Mirrors the language to the signed-in person's row on the server (and
  /// picks it up on a new phone) whenever the signed-in person changes.
  void _followSignedInUser() {
    final id = session.user?.id;
    if (id == _localeUser) return;
    _localeUser = id;
    if (id == null) {
      locale.detachUser();
    } else {
      unawaited(locale.syncForUser(id));
    }
  }

  final _features = FeatureStore();

  /// A controller shared by several screens of one feature (e.g. the Sell
  /// cart used by Sell and Checkout). Created on first use; thrown away on
  /// sign-out and organization switch so no organization's data leaks into
  /// another's screens.
  T feature<T extends ChangeNotifier>(T Function() create) =>
      _features.use(create);

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await prefs.setThemeMode(mode);
  }
}

class FeatureStore {
  final _items = <Type, ChangeNotifier>{};

  T use<T extends ChangeNotifier>(T Function() create) =>
      (_items[T] ??= create()) as T;

  void clear() {
    final old = _items.values.toList();
    _items.clear();
    // Disposed after the frame, so widgets still listening can detach first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in old) {
        c.dispose();
      }
    });
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
