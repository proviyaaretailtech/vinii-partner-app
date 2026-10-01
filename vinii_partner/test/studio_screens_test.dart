import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/app/routes.dart';
import 'package:vinii_partner/application/studio_changes.dart';
import 'package:vinii_partner/application/studio_controller.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/staff.dart';
import 'package:vinii_partner/domain/storefront.dart';
import 'package:vinii_partner/presentation/guest/guest_app.dart';
import 'package:vinii_partner/presentation/menu/menu_routes.dart';
import 'package:vinii_partner/presentation/studio/phone_preview.dart';
import 'package:vinii_partner/presentation/studio/studio_routes.dart';
import 'package:vinii_partner/presentation/studio/studio_sections.dart';
import 'package:vinii_partner/presentation/theme/staff_theme.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

/// Rows for these tests only; the app itself never ships any.
const _sellable = MenuSnapshot(
  categories: [MenuCategory(id: 'c1', name: 'Biriyani', sortOrder: 1)],
  items: [
    MenuItem(id: 'i1', categoryId: 'c1', name: 'Chicken Biriyani', price: 280),
  ],
);

Future<AppServices> _services(FakeBackend backend, String role) async {
  final s = await testServices(backend);
  s.session.user = const StaffUser(
    id: 'u-1',
    email: 'aarav@example.com',
    fullName: 'Aarav',
  );
  s.session.membership = membershipAs(role);
  return s;
}

Future<void> _pumpStudio(
  WidgetTester tester,
  AppServices services, {
  String at = Routes.storefront,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: at,
    routes: [
      ...menuBranchRoutes,
      ...storefrontBranchRoutes,
      ...studioRootRoutes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp.router(
        theme: staffTheme(brightness: Brightness.light),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

StudioController _studio(AppServices s) =>
    s.feature<StudioController>(() => throw StateError('Studio not opened'));

Future<void> _openSection(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(
    find.text(title),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(title));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => PhoneScreen.embedGuestApp = false);

  testWidgets('a never-published storefront starts blank, with the real name', (
    tester,
  ) async {
    final services = await _services(FakeBackend(), 'org_owner');
    await _pumpStudio(tester, services);

    expect(find.textContaining('Not published yet'), findsOneWidget);
    final draft = _studio(services).draft;
    expect(draft.brand.displayName, testOrg.name);
    expect(draft.brand.heroTitle, isEmpty);
    expect(draft.brand.heroSubtitle, isEmpty);
    expect(draft.brand.tagline, isEmpty);
    expect(draft.chefsPicks, isEmpty);
    expect(draft.limitedToday, isEmpty);
    expect(find.text('https://vinii.app/s/test-kitchen'), findsNothing);
    expect(find.text('vinii.app/s/test-kitchen'), findsOneWidget);

    // The template's example wording is only a hint in an empty field.
    await _openSection(tester, 'Brand & welcome');
    final headline = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Welcome headline'),
    );
    expect(headline.controller!.text, isEmpty);
    expect(
      headline.decoration!.hintText,
      StorefrontTemplate.bistroNight.defaultHeroTitle,
    );
    expect(_studio(services).dirty, isFalse);
  });

  testWidgets('editing the brand and saving stores the draft', (tester) async {
    final backend = FakeBackend(menu: _sellable);
    final services = await _services(backend, 'org_owner');
    await _pumpStudio(tester, services);

    await _openSection(tester, 'Brand & welcome');
    await tester.enterText(
      find.widgetWithText(TextField, 'Welcome headline'),
      'Biriyani worth the wait',
    );
    await tester.pumpAndSettle();
    expect(_studio(services).dirty, isTrue);
    expect(backend.storefrontState.draft, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Unsaved changes'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Save draft'));
    await tester.pumpAndSettle();

    expect(
      backend.storefrontState.draft?.brand.heroTitle,
      'Biriyani worth the wait',
    );
    expect(backend.storefrontState.published, isNull);
    expect(_studio(services).dirty, isFalse);
    expect(find.text('Draft saved'), findsOneWidget);
    expect(find.text('Unpublished changes'), findsOneWidget);
  });

  testWidgets('a Studio save keeps what the VINII OS CMS set', (tester) async {
    // A draft last saved by the CMS: colours, fonts, pictures, guest text
    // and keys this app has never heard of.
    final starter = StorefrontDefinition.starter(testOrg).toJson();
    final cms = jsonDecode(
      jsonEncode({
        ...starter,
        'brand': {
          ...starter['brand'] as Map<String, dynamic>,
          'logo_url': 'org-1/logo.png',
          'instagram': '@testkitchen',
        },
        'theme': {
          'colors': {'background': '#101418', 'on_accent': '#FFFFFF'},
          'buttons': {'shape': 'rounded', 'style': 'outline'},
          'fonts': {'heading': 'poppins'},
        },
        'media': {
          'hero': 'org-1/hero.webp',
          'categories': {'c1': 'org-1/biriyani.jpg'},
        },
        'copy': {
          'en': {'cart.place': 'Send to kitchen'},
          'hi': {'cart.place': 'ऑर्डर भेजें'},
        },
        'default_language': 'hi',
        'seo': {'title': 'Test Kitchen'},
      }),
    ) as Map<String, dynamic>;
    final backend = FakeBackend(menu: _sellable)
      ..storefrontState = StorefrontState(
        draft: StorefrontDefinition.fromJson(cms, org: testOrg),
      );
    final services = await _services(backend, 'org_owner');
    await _pumpStudio(tester, services);

    // The look section says where these are edited, and what is set there.
    await _openSection(tester, 'Template & colour');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('cms-look-summary')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('VINII OS storefront CMS'), findsOneWidget);
    expect(find.textContaining('Poppins headings'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Edit something the phone owns, and save.
    await _openSection(tester, 'Brand & welcome');
    await tester.enterText(
      find.widgetWithText(TextField, 'Welcome headline'),
      'Biriyani worth the wait',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Save draft'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Draft saved'), findsOneWidget);

    // What would reach the database: the edit, and every CMS field as it was.
    final saved = jsonDecode(
      jsonEncode(backend.storefrontState.draft!.toJson()),
    ) as Map<String, dynamic>;
    for (final k in ['theme', 'media', 'copy', 'default_language', 'seo']) {
      expect(jsonEncode(saved[k]), jsonEncode(cms[k]), reason: k);
    }
    final brand = saved['brand'] as Map<String, dynamic>;
    expect(brand['hero_title'], 'Biriyani worth the wait');
    expect(brand['logo_url'], 'org-1/logo.png');
    expect(brand['instagram'], '@testkitchen');
  });

  testWidgets('publishing sends the draft and shows the new version', (
    tester,
  ) async {
    final backend = FakeBackend(menu: _sellable);
    final services = await _services(backend, 'org_owner');
    await _pumpStudio(tester, services);

    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();
    expect(find.text('Publish version 1?'), findsOneWidget);
    expect(
      find.text('Your storefront goes live for the first time.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Publish now'));
    await tester.pumpAndSettle();

    final live = backend.storefrontState.published;
    expect(live?.version, 1);
    expect(live?.publishedBy, 'Aarav');
    expect(live?.definition.brand.displayName, testOrg.name);
    expect(find.text('Published version 1'), findsOneWidget);
    expect(find.textContaining('Live · version 1'), findsOneWidget);
  });

  testWidgets('publishing is blocked, with the reason, when guests would '
      'see an empty menu', (tester) async {
    final backend = FakeBackend();
    final services = await _services(backend, 'org_admin');
    await _pumpStudio(tester, services);

    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Almost ready to publish'), findsOneWidget);
    expect(find.textContaining('empty menu'), findsOneWidget);
    expect(backend.storefrontState.published, isNull);
  });

  testWidgets('a refused publish is shown honestly, never as success', (
    tester,
  ) async {
    const pending =
        'Publishing needs the storefront tables. Your draft is kept on this phone until then.';
    final backend = FakeBackend(menu: _sellable)
      ..storefrontState = const StorefrontState(note: pending)
      ..failStorefrontPublish = const AppFailure(
        pending,
        kind: FailureKind.notReady,
      );
    final services = await _services(backend, 'org_owner');
    await _pumpStudio(tester, services);

    expect(find.text(pending), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish now'));
    await tester.pumpAndSettle();

    expect(find.text('Publishing is not available yet'), findsOneWidget);
    expect(find.textContaining('Published version'), findsNothing);
    expect(backend.storefrontState.published, isNull);
  });

  testWidgets('a manager can save drafts but not publish', (tester) async {
    final services = await _services(FakeBackend(menu: _sellable), 'manager');
    await _pumpStudio(tester, services);

    expect(find.widgetWithText(OutlinedButton, 'Save draft'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Publish'), findsNothing);
  });

  testWidgets('the template can be switched and follows its own accent', (
    tester,
  ) async {
    final services = await _services(FakeBackend(), 'org_owner');
    await _pumpStudio(tester, services);
    await _openSection(tester, 'Template & colour');

    await tester.tap(find.text(StorefrontTemplate.freshMinimal.label));
    await tester.pumpAndSettle();

    final d = _studio(services).draft;
    expect(d.template, StorefrontTemplate.freshMinimal);
    expect(d.accentHex, StorefrontTemplate.freshMinimal.defaultAccent);
  });

  testWidgets('restoring an old version publishes it as a new number', (
    tester,
  ) async {
    final org = testOrg;
    final v1 = StorefrontVersion(
      version: 1,
      definition: StorefrontDefinition.starter(org),
      publishedAt: DateTime(2026, 9, 1),
      publishedBy: 'Aarav',
    );
    final v2 = StorefrontVersion(
      version: 2,
      definition: StorefrontDefinition.starter(org)
          .copyWith(template: StorefrontTemplate.artisanDay),
      publishedAt: DateTime(2026, 9, 20),
      publishedBy: 'Aarav',
    );
    final backend = FakeBackend(menu: _sellable)
      ..storefrontState = StorefrontState(published: v2, history: [v2, v1]);
    final services = await _services(backend, 'org_owner');
    await _pumpStudio(
      tester,
      services,
      at: Routes.storefrontSection('history'),
    );

    expect(find.text('Version 2'), findsOneWidget);
    expect(find.text('Version 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pumpAndSettle();

    final live = backend.storefrontState.published!;
    expect(live.version, 3);
    expect(live.definition.template, v1.definition.template);
  });

  testWidgets('every Studio section opens cleanly on a phone', (tester) async {
    final starter = StorefrontDefinition.starter(testOrg);
    final draft = starter.copyWith(
      serviceModes: const [GuestServiceMode.dineIn, GuestServiceMode.preOrder],
      chefsPicks: const ['i1', 'gone'],
      limitedToday: const [LimitedOffer(itemId: 'i1', endsAt: '21:30')],
      categories: const [CategoryPresentation(categoryId: 'c1', emoji: '🍛')],
    );
    final backend = FakeBackend(menu: _sellable)
      ..storefrontState = StorefrontState(draft: draft);
    final services = await _services(backend, 'org_owner');
    await _pumpStudio(tester, services);

    for (final section in StudioSection.values) {
      await _openSection(tester, section.title);
      expect(
        find.widgetWithText(AppBar, section.title),
        findsOneWidget,
        reason: section.key,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(find.text('vinii.app/s/test-kitchen'), findsOneWidget);
    expect(_studio(services).dirty, isFalse);
  });

  testWidgets('the full preview says orders are not sent, and closes', (
    tester,
  ) async {
    final services = await _services(FakeBackend(menu: _sellable), 'manager');
    await _pumpStudio(tester, services);

    await tester.scrollUntilVisible(
      find.text('Open full preview'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Open full preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open full preview'));
    await tester.pumpAndSettle();
    expect(find.text('Preview · orders are not sent'), findsOneWidget);
    expect(_studio(services).fullPreviewOpen, isTrue);

    await tester.tap(find.byTooltip('Close preview'));
    await tester.pumpAndSettle();
    expect(find.text('Preview · orders are not sent'), findsNothing);
    expect(_studio(services).fullPreviewOpen, isFalse);
  });

  testWidgets('the live preview embeds the guest runtime at phone size', (
    tester,
  ) async {
    PhoneScreen.embedGuestApp = true;
    addTearDown(() => PhoneScreen.embedGuestApp = false);
    final services = await _services(FakeBackend(menu: _sellable), 'org_owner');
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: Routes.storefront,
      routes: [...storefrontBranchRoutes, ...studioRootRoutes],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp.router(
          theme: staffTheme(brightness: Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final guest = find.byType(GuestApp);
    expect(guest, findsOneWidget);
    expect(tester.widget<GuestApp>(guest).gateway.isPreview, isTrue);
    expect(tester.getSize(guest), PhoneScreen.virtualSize);
    final revision = _studio(services).revision;

    // An edit reaches the running runtime without restarting it.
    _studio(services)
        .edit((d) => d.copyWith(brand: d.brand.copyWith(heroTitle: 'Hello')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<GuestApp>(guest).definition.brand.heroTitle, 'Hello');
    expect(_studio(services).revision, revision);
  });

  test('the publish summary names only real differences', () {
    final a = StorefrontDefinition.starter(testOrg);
    final b = a.copyWith(
      template: StorefrontTemplate.artisanDay,
      brand: a.brand.copyWith(heroTitle: 'Hello'),
    );
    expect(describeStorefrontChanges(a, a), isEmpty);
    expect(describeStorefrontChanges(a, b), [
      'Template: Bistro Night → Artisan Day',
      'Welcome headline',
    ]);
  });
}
