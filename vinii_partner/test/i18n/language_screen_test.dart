import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/app/routes.dart';
import 'package:vinii_partner/domain/staff.dart';
import 'package:vinii_partner/l10n/locale_controller.dart';
import 'package:vinii_partner/l10n/locales.dart';
import 'package:vinii_partner/presentation/settings/language_screen.dart';
import 'package:vinii_partner/presentation/settings/settings_screen.dart';
import 'package:vinii_partner/presentation/theme/staff_theme.dart';

import '../support/fake_backend.dart';
import '../support/fake_fonts.dart';
import '../support/harness.dart';

Future<(AppServices, FakeScriptFonts)> _services({
  Map<String, Object> prefs = const {},
}) async {
  final backend = FakeBackend();
  final fonts = FakeScriptFonts(ready: true);
  final services = await testServices(
    backend,
    prefsValues: prefs,
    localeController: (p) => LocaleController(
      prefs: p,
      server: backend.userPreferences,
      fonts: fonts,
      deviceLocales: const [Locale('en')],
      announcer: (_, _) {},
    ),
  );
  return (services, fonts);
}

void _phone(WidgetTester tester, {double width = 360, double scale = 1}) {
  tester.view.physicalSize = Size(width * 3, 1800 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  group('the Language screen', () {
    testWidgets('lists every language from the registry, English selected', (
      tester,
    ) async {
      final (services, _) = await _services();
      _phone(tester);
      await tester.pumpWidget(wrapLocalized(services, const LanguageScreen()));

      expect(find.text('Language'), findsOneWidget);
      for (final l in appLocales) {
        expect(find.text(l.nativeName), findsOneWidget);
        expect(
          find.text(l.sample),
          findsOneWidget,
          reason: 'live preview line',
        );
      }
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      // Large tap targets.
      for (final l in appLocales) {
        final tile = find.ancestor(
          of: find.text(l.nativeName),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(tile).height, greaterThanOrEqualTo(72));
      }
      // The pseudo-locale only exists in a pseudo build.
      expect(find.text(pseudoLocale.nativeName), findsNothing);
    });

    for (final (width, scale) in [(360.0, 1.0), (320.0, 1.3), (320.0, 2.0)]) {
      testWidgets('no overflow in Hindi at ${width.toInt()}px, text x$scale', (
        tester,
      ) async {
        final (services, _) = await _services(prefs: {'locale': 'hi'});
        await services.locale.restore();
        _phone(tester, width: width, scale: scale);
        await tester.pumpWidget(
          wrapLocalized(services, const LanguageScreen()),
        );
        expect(find.text('भाषा'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'no overflow with the inline error at ${width.toInt()}px, text x$scale',
        (tester) async {
          final (services, fonts) = await _services();
          fonts
            ..ready = false
            ..failWith = Exception('offline');
          _phone(tester, width: width, scale: scale);
          await tester.pumpWidget(
            wrapLocalized(services, const LanguageScreen()),
          );
          await tester.tap(find.text('हिन्दी'));
          await tester.pump();
          await tester.pump();
          expect(find.text('Try again'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('the sheet used by sign-in and the intro fits and switches', (
      tester,
    ) async {
      final (services, _) = await _services();
      _phone(tester, width: 320, scale: 1.3);
      await tester.pumpWidget(
        wrapLocalized(
          services,
          const Scaffold(body: Center(child: LanguageButton())),
        ),
      );
      expect(find.text('English'), findsOneWidget);
      await tester.tap(find.byType(LanguageButton));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      await tester.tap(find.text('हिन्दी').last);
      await tester.pumpAndSettle();
      expect(find.text('भाषा'), findsOneWidget, reason: 'the sheet switched');
      expect(tester.takeException(), isNull);
    });
  });

  group('More > Language', () {
    testWidgets('the Settings tile shows the current language and opens the '
        'screen; switching never rebuilds the route stack', (tester) async {
      final (services, _) = await _services();
      services.session.membership = membershipAs('org_owner');
      services.session.user = const StaffUser(
        id: 'u1',
        email: 'owner@example.com',
        fullName: 'Asha Verma',
      );
      _phone(tester);
      final router = GoRouter(
        initialLocation: Routes.more,
        routes: [
          GoRoute(
            path: Routes.more,
            builder: (_, _) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'language',
                builder: (_, _) => const LanguageScreen(),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        AppScope(
          services: services,
          child: ListenableBuilder(
            listenable: services.locale,
            builder: (context, _) => MaterialApp.router(
              theme: staffTheme(brightness: Brightness.light),
              locale: services.locale.locale,
              supportedLocales: services.locale.supportedLocales,
              localizationsDelegates: testLocalizationDelegates,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('App language: English'), findsOneWidget);

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageScreen), findsOneWidget);
      await tester.tap(find.text('हिन्दी'));
      await tester.pumpAndSettle();
      expect(find.text('भाषा'), findsOneWidget);
      expect(find.byType(LanguageScreen), findsOneWidget, reason: 'still here');

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('ऐप की भाषा: हिन्दी'), findsOneWidget);
    });
  });
}
