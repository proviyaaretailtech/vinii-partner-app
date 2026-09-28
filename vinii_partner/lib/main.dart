import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_scope.dart';
import 'config/app_config.dart';
import 'data/live/live_backend.dart';
import 'data/local_prefs.dart';

/// VINII Partner: the restaurant's phone app on the Proviyaa platform —
/// marketplace delivery orders, a phone POS, the menu, and Storefront Studio
/// for the guest ordering site. See docs/PLAN_VINII_PARTNER_FLUTTER.md.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromDartDefines();
  final prefs = await LocalPrefs.open();
  final services = AppServices(
    config: config,
    prefs: prefs,
    backend: LiveBackend(config, prefs),
  );
  runApp(ViniiPartnerApp(services: services));
}
