import 'package:flutter/material.dart';

import '../application/inbox_controller.dart';
import '../application/ring_player.dart';
import '../application/session_controller.dart';
import '../config/app_config.dart';
import '../data/backend.dart';
import '../data/local_prefs.dart';

/// Everything long-lived, created once in `main` and reachable from any
/// widget with `AppScope.of(context)`.
class AppServices {
  AppServices({
    required this.config,
    required this.prefs,
    required this.backend,
  }) {
    session.onReset(_features.clear);
  }

  final AppConfig config;
  final LocalPrefs prefs;
  final Backend backend;

  late final session = SessionController(
    config: config,
    backend: backend,
    prefs: prefs,
  );
  late final ring = RingPlayer(prefs);
  late final inbox = InboxController(session: session, ring: ring);
  late final themeMode = ValueNotifier<ThemeMode>(prefs.themeMode);

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
