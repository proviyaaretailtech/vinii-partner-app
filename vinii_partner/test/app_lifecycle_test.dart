import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/app/app.dart';
import 'package:vinii_partner/application/session_controller.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/domain/organization.dart';
import 'package:vinii_partner/domain/staff.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  const second = Organization(
    id: 'org-2',
    name: 'Second Cafe',
    slug: 'second-cafe',
    type: 'cafe',
  );

  testWidgets('loader → sign in → choose organization → tabs → sign out', (
    tester,
  ) async {
    final backend = FakeBackend(
      memberships: [
        membershipAs('org_owner'),
        membershipAs('manager', org: second),
      ],
    );
    backend.inboxAvailable = false;
    final services = await testServices(backend);
    await tester.pumpWidget(ViniiPartnerApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'owner@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'secret',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a restaurant'), findsOneWidget);
    await tester.tap(find.text('Second Cafe'));
    await tester.pumpAndSettle();

    expect(services.session.stage, SessionStage.ready);
    expect(backend.active?.id, 'org-2');
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Second Cafe'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Sign out'),
      200,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out of this phone'));
    await tester.pumpAndSettle();

    expect(services.session.stage, SessionStage.signedOut);
    expect(backend.signOutCalls, [false]);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('a wrong password is explained on the sign-in screen', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..failSignIn = const AppFailure(
        'That email and password do not match.',
        kind: FailureKind.auth,
      );
    final services = await testServices(backend);
    await tester.pumpWidget(ViniiPartnerApp(services: services));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'x@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'nope',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('That email and password do not match.'), findsOneWidget);
    expect(services.session.stage, SessionStage.signedOut);
  });

  testWidgets('no memberships → the no-access screen, with sign-out', (
    tester,
  ) async {
    final backend = FakeBackend(
      user: const StaffUser(id: 'u', email: 'new@example.com'),
    );
    final services = await testServices(backend);
    await tester.pumpWidget(ViniiPartnerApp(services: services));
    await tester.pumpAndSettle();
    expect(find.text('No restaurant yet'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(services.session.stage, SessionStage.signedOut);
  });

  testWidgets('a kitchen login only gets the tabs its role allows', (
    tester,
  ) async {
    final backend = FakeBackend(
      user: const StaffUser(id: 'u', email: 'k@example.com'),
      memberships: [membershipAs('kitchen')],
    )..inboxAvailable = false;
    final services = await testServices(backend);
    await tester.pumpWidget(ViniiPartnerApp(services: services));
    await tester.pumpAndSettle();
    final labels = services.session.definition!.tabs
        .map((t) => t.label)
        .toList();
    expect(labels, ['Orders', 'Menu', 'More']);
  });

  testWidgets('first launch shows the intro once', (tester) async {
    final services = await testServices(FakeBackend(), introSeen: false);
    await tester.pumpWidget(ViniiPartnerApp(services: services));
    await tester.pumpAndSettle();
    expect(find.text('New orders ring here'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(services.prefs.introSeen, isTrue);
  });
}
