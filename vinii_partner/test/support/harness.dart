import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/config/app_config.dart';
import 'package:vinii_partner/data/local_prefs.dart';
import 'package:vinii_partner/domain/organization.dart';
import 'package:vinii_partner/domain/staff.dart';
import 'package:vinii_partner/l10n/delegates.dart';
import 'package:vinii_partner/l10n/locale_controller.dart';
import 'package:vinii_partner/presentation/theme/guest_theme.dart';
import 'package:vinii_partner/presentation/theme/staff_theme.dart';

import 'fake_backend.dart';

const testConfig = AppConfig(
  appEnv: 'test',
  supabaseUrl: 'https://example.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
  partnerApiBaseUrl: 'https://onelocal.example',
  storefrontBaseUrl: 'https://vinii.app',
);

const testOrg = Organization(
  id: 'org-1',
  name: 'Test Kitchen',
  slug: 'test-kitchen',
  type: 'restaurant',
);

Membership membershipAs(String roleSlug, {Organization org = testOrg}) =>
    Membership(organization: org, roleSlug: roleSlug, roleName: roleSlug);

/// Services wired to a [FakeBackend], with prefs in memory and remote fonts
/// off (tests have no network).
///
/// [prefsValues] are extra stored settings (`{'locale': 'hi'}`); pass
/// [localeController] to give the language machinery fake fonts/timeouts.
Future<AppServices> testServices(
  FakeBackend backend, {
  bool introSeen = true,
  Map<String, Object> prefsValues = const {},
  LocaleController Function(LocalPrefs prefs)? localeController,
}) async {
  SharedPreferences.setMockInitialValues({
    'intro_seen': introSeen,
    ...prefsValues,
  });
  GuestPalette.remoteFonts = false;
  final prefs = await LocalPrefs.open();
  return AppServices(
    config: testConfig,
    prefs: prefs,
    backend: backend,
    localeController: localeController?.call(prefs),
  );
}

/// Wraps a single screen with the app's theme and scope, for widget tests
/// that do not need the router.
Widget wrapScreen(AppServices services, Widget child) => AppScope(
  services: services,
  child: MaterialApp(
    theme: staffTheme(brightness: Brightness.light),
    home: child,
  ),
);

/// The delegates lib/app/app.dart mounts.
const testLocalizationDelegates = appLocalizationsDelegates;

/// Like [wrapScreen] but with the app's real localisation setup: the
/// MaterialApp follows `services.locale` exactly as lib/app/app.dart does, so
/// a language switch repaints the screen in place.
Widget wrapLocalized(AppServices services, Widget child) => AppScope(
  services: services,
  child: ListenableBuilder(
    listenable: services.locale,
    builder: (context, _) => MaterialApp(
      theme: staffTheme(brightness: Brightness.light),
      locale: services.locale.locale,
      supportedLocales: services.locale.supportedLocales,
      localizationsDelegates: testLocalizationDelegates,
      home: child,
    ),
  ),
);
