import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/l10n/locale_controller.dart';
import 'package:vinii_partner/presentation/auth/sign_in_screen.dart';
import 'package:vinii_partner/presentation/onboarding/intro_screen.dart';
import 'package:vinii_partner/presentation/settings/language_screen.dart';

import '../support/fake_backend.dart';
import '../support/fake_fonts.dart';
import '../support/harness.dart';

/// The language can be chosen before anybody has signed in: a button on the
/// first-run intro and on the sign-in screen opens the same tiles.
void main() {
  Future<dynamic> boot(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(960, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final backend = FakeBackend();
    final services = await testServices(
      backend,
      localeController: (p) => LocaleController(
        prefs: p,
        server: backend.userPreferences,
        fonts: FakeScriptFonts(ready: true),
        deviceLocales: const [Locale('en')],
        announcer: (_, _) {},
      ),
    );
    await tester.pumpWidget(wrapLocalized(services, screen));
    await tester.pump();
    return services;
  }

  testWidgets('sign-in: the button switches the page to Hindi and keeps what '
      'was typed', (tester) async {
    final services = await boot(tester, const SignInScreen());
    expect(find.text('Sign in'), findsWidgets);
    await tester.enterText(
      find.byType(TextFormField).first,
      'asha@example.com',
    );
    expect(find.byType(LanguageButton), findsOneWidget);

    await tester.tap(find.byType(LanguageButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिन्दी').last);
    await tester.pumpAndSettle();

    expect(services.locale.active.code, 'hi');
    expect(find.text('साइन इन करें'), findsWidgets);
    expect(find.text('asha@example.com'), findsOneWidget);
  });

  testWidgets('first-run intro: the button is there beside Skip', (
    tester,
  ) async {
    final services = await boot(tester, const IntroScreen());
    expect(find.byType(LanguageButton), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.byType(LanguageButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिन्दी').last);
    await tester.pumpAndSettle();

    expect(services.locale.active.code, 'hi');
    expect(find.text('छोड़ें'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
