import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinii_partner/app/app.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/app/routes.dart';
import 'package:vinii_partner/application/sell_cart.dart';
import 'package:vinii_partner/domain/delivery_order.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/l10n/delegates.dart';
import 'package:vinii_partner/l10n/locale_controller.dart';
import 'package:vinii_partner/l10n/locales.dart';

import '../../tool/gallery/staff_fixtures.dart';
import '../support/fake_fonts.dart';
import '../support/harness.dart';

/// The whole staff app, walked screen by screen on the gallery's invented
/// data, in Hindi and in the pseudo-language.
///
/// * Hindi at phone width and large text: no layout exception on any screen
///   (the test font draws Devanagari as full-width boxes, harsher than the
///   real font, so a pass here is conservative).
/// * Pseudo-language: every string from the catalogue is wrapped in [ ]. A
///   piece of text that has letters but no brackets was not read from the
///   catalogue: it is hard-coded English, or restaurant/customer data. The
///   allow-list below is the invented data of the gallery; anything else
///   fails the test and names the screen it was on.
const _routes = <String>[
  Routes.orders,
  '/orders/d1',
  '/orders/d2',
  Routes.sell,
  Routes.sellCheckout,
  '/sell/order/o-101',
  Routes.menu,
  '/menu/item/i-tikka',
  Routes.menuNewItem,
  Routes.menuCategories,
  Routes.storefront,
  '/storefront/section/look',
  '/storefront/section/brand',
  '/storefront/section/service',
  '/storefront/section/features',
  '/storefront/section/categories',
  '/storefront/section/highlights',
  '/storefront/section/share',
  '/storefront/section/history',
  Routes.storefrontPreview,
  Routes.more,
  Routes.language,
  Routes.billSettings,
  Routes.team,
  Routes.tableCodes,
  Routes.about,
  '/alert/d3',
];

/// Things to do on a screen (open a sheet, a dialog, a second state), so the
/// walk also reads the words that only appear after a tap.
typedef _Act = Future<void> Function(_Walk w);

Future<void> _tapKey(_Walk w, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) return;
  await w.tester.ensureVisible(f.first);
  await w.tester.tap(f.first, warnIfMissed: false);
  await w.settle(6);
}

Future<void> _tapFirst(_Walk w, Finder f) async {
  if (f.evaluate().isEmpty) return;
  await w.tester.ensureVisible(f.first);
  await w.tester.tap(f.first, warnIfMissed: false);
  await w.settle(6);
}

/// Close the sheets and dialogs on top.
Future<void> _dismiss(_Walk w) => w.closeModals();

final _interactions = <(String, List<(String, _Act)>)>[
  (
    Routes.orders,
    [
      ('close sheet', (w) => _tapKey(w, 'outlet-closed')),
      (
        'pause sheet',
        (w) async {
          await _dismiss(w);
          await _tapKey(w, 'outlet-paused');
        },
      ),
    ],
  ),
  (
    '/orders/d3',
    [('reject sheet', (w) => _tapFirst(w, find.byType(OutlinedButton)))],
  ),
  (
    '/sell/order/o-101',
    [
      ('split payment', (w) => _tapKey(w, 'pay-split')),
      ('cash', (w) => _tapKey(w, 'cash-500')),
    ],
  ),
  (
    '/sell/checkout',
    [('remove service charge', (w) => _tapKey(w, 'service-charge-remove'))],
  ),
  (
    Routes.team,
    [
      ('person sheet', (w) => _tapFirst(w, find.byKey(const Key('team-m2')))),
      ('role list', (w) => _tapKey(w, 'team-change-role')),
      (
        'suspend',
        (w) async {
          await _dismiss(w);
          await _tapKey(w, 'team-suspend');
        },
      ),
      (
        'invite',
        (w) async {
          await _dismiss(w);
          await _tapKey(w, 'team-invite');
        },
      ),
    ],
  ),
  (
    Routes.more,
    [
      (
        'sign-out sheet',
        (w) => _tapFirst(w, find.byIcon(Icons.logout_rounded)),
      ),
    ],
  ),
  (
    Routes.tableCodes,
    [
      ('replace a code', (w) => _tapKey(w, 'replace-tb1')),
      (
        'issue a code',
        (w) async {
          await _dismiss(w);
          await _tapKey(w, 'issue-tb4');
        },
      ),
    ],
  ),
  (
    Routes.billSettings,
    [('service charge on', (w) => _tapKey(w, 'bill-service-switch'))],
  ),
];

class _Walk {
  _Walk(this.tester, this.services);
  final WidgetTester tester;
  final AppServices services;

  /// Framework errors raised since the last [takeErrors] (overflow, assertion).
  final errors = <FlutterErrorDetails>[];
  void Function(FlutterErrorDetails)? previousOnError;

  /// What went wrong on this screen, one line each, with where in lib/.
  List<String> takeErrors() {
    tester.takeException(); // clear the binding's own copy
    final out = [for (final d in errors) _describe(d)];
    errors.clear();
    return out;
  }

  Future<void> settle([int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> closeModals() async {
    final ctx = tester.element(find.byType(Scaffold).first);
    Navigator.of(ctx, rootNavigator: true).popUntil((r) => r is! PopupRoute);
    await settle(4);
  }

  Future<void> go(String route) async {
    await closeModals();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
    await settle();
  }

  /// Every screen in [_routes], then every interaction in [_interactions]:
  /// calls [check] after each, with a label for what was on screen.
  Future<void> visitAll(void Function(String where) check) async {
    for (final route in _routes) {
      await go(route);
      check(route);
    }
    for (final (route, acts) in _interactions) {
      for (final (label, act) in acts) {
        await go(route);
        await act(this);
        check('$route, $label');
      }
    }
  }

  /// The ring and the inbox poll are timers: stop them before the test ends.
  Future<void> finish() async {
    // Hand error reporting back before any expect() can fail.
    FlutterError.onError = previousOnError;
    await services.ring.stop();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  /// Every string a person can read right now: text, rich text, tooltips.
  List<String> texts() {
    final out = <String>[];
    for (final e in find.byType(RichText).evaluate()) {
      final t = (e.widget as RichText).text.toPlainText().trim();
      if (t.isNotEmpty) out.add(t);
    }
    for (final e in find.byType(Tooltip).evaluate()) {
      final m = (e.widget as Tooltip).message;
      if (m != null && m.trim().isNotEmpty) out.add(m.trim());
    }
    return out;
  }
}

Future<_Walk> _boot(
  WidgetTester tester, {
  required AppLocale language,
  required Size size,
  double scale = 1,
  bool pseudo = false,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  final backend = staffGalleryBackend(role: 'org_owner');
  backend.deliveries.add(
    DeliveryOrder(
      id: 'd3',
      displayNo: 'OL-00042',
      status: DeliveryStatus.placed,
      version: 'v1',
      placedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      deadline: DateTime.now().add(const Duration(seconds: 50)),
      customerName: 'Anita Kale',
      area: 'Shivaji Nagar',
      items: const [DeliveryLine(name: 'Veg Thali', qty: 1, price: 220)],
      subtotal: 220,
      gst: 11,
      deliveryFee: 30,
      total: 261,
    ),
  );
  final fonts = FakeScriptFonts(ready: true);
  final services = await testServices(
    backend,
    localeController: (p) => LocaleController(
      prefs: p,
      server: backend.userPreferences,
      fonts: fonts,
      deviceLocales: const [Locale('en')],
      announcer: (_, _) {},
    ),
  );
  await services.prefs.setRingEnabled(false);
  final dish = {for (final i in staffGalleryMenu.items) i.id: i};
  services.feature(
      () => SellCart(
        menuRepository: backend.menu,
        pos: backend.pos,
        prefs: services.prefs,
        orgId: galleryOrg.id,
      ),
    )
    ..charges = backend.billCharges
    ..add(dish['i-biryani-c']!, qty: 2)
    ..add(dish['i-tikka']!)
    ..setTable(const DiningTable(id: 'tb2', label: 'T2', seats: 4))
    ..setGuestCount(3);
  await services.locale.select(language);
  await tester.pumpWidget(
    ViniiPartnerApp(
      services: services,
      localizationsDelegates: pseudo
          ? pseudoTestDelegates
          : appLocalizationsDelegates,
    ),
  );
  final walk = _Walk(tester, services);
  walk.previousOnError = FlutterError.onError;
  FlutterError.onError = (d) => walk.errors.add(d);
  await walk.settle(20);
  return walk;
}

/// Invented data of the gallery that is shown as stored.
final _data = <RegExp>[
  RegExp(r'^(Sample Kitchen \(gallery\)|Asha Verma|Neha Shah|Ravi Kulkarni)$'),
  RegExp(r'^(Meera Joshi|Sanjay Rao|Priya Deshmukh|Arjun Patil|Kavya Nair)$'),
  RegExp(r'^(Rahul Patil|Priya Sharma|Anita Kale|Priya|Rahul|Anita)\b'),
  RegExp(r'(Chicken Biryani|Veg Thali|Sweet Lassi|Paneer Tikka|Crispy Corn)'),
  RegExp(r'(Chicken 65|Egg Masala Fry|Cold Drink|Mutton|Dal |Jeera|Gulab)'),
  RegExp(r'^(Starters|Biryani|Thalis|Drinks|Desserts|Breads|Mains)$'),
  RegExp(r'(@sample-kitchen\.example|you@|sample-kitchen)'),
  RegExp(
    r'^(Shivaji Nagar|Ganesh Nagar|Indoor|Rooftop|T\d|R\d|Swiggy|Zomato)$',
  ),
  RegExp(r'^(OL|ORD)-\d+'),
  RegExp(r'^(Sample Kitchen Pvt Ltd|12 Example Road, Sampletown)'),
  RegExp(r'^(27AAAAA0000A1Z5|\+91 98765 43210|Thank you! Visit again\.)$'),
  RegExp(r'^(Extra spicy|Less sugar|Chilled|Website|One Local)$'),
  RegExp(r'^[A-Z]{1,3}$'), // initials in an avatar
  RegExp(r'^v\d+\.\d+'), // version numbers
  // Words the Flutter framework itself supplies (its own delegates translate
  // them): the back button's tooltip.
  RegExp(r'^(Back|Close|Open navigation menu|Show menu)$'),
  // Restaurant data of the gallery and the font specimen of the template tile.
  RegExp(r'^(Veg Dum Biryani|Aa)$'),
  // Product names of the three storefront templates, and their example guest
  // copy (shown as a grey hint; guest content, not staff UI).
  RegExp(r'^(Bistro Night|Artisan Day|Fresh Minimal)$'),
  RegExp(r'^(Food Looks Better When You Explore It\.|Swipe through dishes,)'),
  // A language is named in its own script, with a sample line in it.
  RegExp(r'^(English|Orders, bills and tables in English)$'),
  // Identifiers and links.
  RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z]\d[A-Z]\d$'),
  RegExp(r'^vinii\.app/'),
];

/// "A RenderFlex overflowed by 33 pixels on the bottom [lib/…/x.dart:123]".
String _describe(FlutterErrorDetails d) {
  final text = d
      .toDiagnosticsNode()
      .toStringDeep(minLevel: DiagnosticLevel.debug)
      .replaceAll('%20', ' ');
  final what = d.exceptionAsString().split('\n').first.trim();
  final where = RegExp(r'(lib/[\w/]+\.dart:\d+)')
      .allMatches(text)
      .map((m) => m.group(1))
      .toSet()
      .take(3)
      .join(', ');
  return where.isEmpty ? what : '$what [$where]';
}

bool _isData(String s) => _data.any((r) => r.hasMatch(s));

/// Letters outside [ ] brackets: not read from the catalogue.
bool _leaks(String s) {
  if (s.contains('[')) return false;
  return RegExp(r'[A-Za-z]{2,}').hasMatch(s);
}

void main() {
  group('Hindi, phone width, large text: no layout exception anywhere', () {
    for (final (width, scale) in [(360.0, 1.0), (320.0, 1.3)]) {
      testWidgets('${width.toInt()}px, text x$scale', (tester) async {
        final walk = await _boot(
          tester,
          language: hindiLocale,
          size: Size(width, 780),
          scale: scale,
        );
        final problems = <String>[];
        await walk.visitAll(
          (where) =>
              problems.addAll(walk.takeErrors().map((e) => '$where: $e')),
        );
        await walk.finish();
        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }

    testWidgets(
      'a counter computer, 1280px wide',
      timeout: const Timeout(Duration(minutes: 4)),
      (tester) async {
        final walk = await _boot(
          tester,
          language: hindiLocale,
          size: const Size(1280, 800),
        );
        final problems = <String>[];
        await walk.visitAll(
          (where) =>
              problems.addAll(walk.takeErrors().map((e) => '$where: $e')),
        );
        await walk.finish();
        expect(problems, isEmpty, reason: problems.join('\n'));
      },
    );
  });

  group('Pseudo-language: nothing is hard-coded English', () {
    testWidgets('every screen reads its words from the catalogue', (
      tester,
    ) async {
      final walk = await _boot(
        tester,
        language: pseudoLocale,
        size: const Size(390, 844),
        pseudo: true,
      );
      expect(walk.services.locale.active, pseudoLocale);
      final leaks = <String>[];
      var screens = 0;
      await walk.visitAll((where) {
        leaks.addAll(walk.takeErrors().map((e) => '$where: EXCEPTION $e'));
        screens++;
        final texts = walk.texts();
        expect(
          texts.where((t) => t.startsWith('[')),
          isNotEmpty,
          reason: '$where shows no catalogue text at all',
        );
        for (final t in texts) {
          if (_leaks(t) && !_isData(t)) leaks.add('$where: "$t"');
        }
      });
      await walk.finish();
      expect(screens, greaterThan(_routes.length));
      expect(leaks.toSet().toList(), isEmpty, reason: leaks.toSet().join('\n'));
    });
  });
}
