// Visual review of the staff screens IN HINDI (or the pseudo-language),
// without a browser.
//
// Same idea as staff_review_test.dart: the real app on the gallery's invented
// fixtures, drawn to PNG files with the bundled Inter font, Noto Sans
// Devanagari and the Material icons. Look for clipped matras (marks above and
// below the line), text that collides, buttons that lost their label and
// anything that overflows. Writes nothing unless VISUAL_OUT names a folder:
//
//   VISUAL_OUT=/tmp/hindi-shots flutter test tool/gallery/hindi_review_test.dart
//   VISUAL_LOCALE=en_XA ...    (the pseudo-language instead of Hindi)
//   VISUAL_SCALE=1.3 ...       (system text size)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinii_partner/app/app.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/app/routes.dart';
import 'package:vinii_partner/application/sell_cart.dart';
import 'package:vinii_partner/domain/pos_order.dart';

import '../../test/support/harness.dart';
import 'staff_fixtures.dart';

final _out = Platform.environment['VISUAL_OUT'];
final _localeCode = Platform.environment['VISUAL_LOCALE'] ?? 'hi';
final _scale = double.tryParse(Platform.environment['VISUAL_SCALE'] ?? '') ?? 1;

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  final root = Platform.environment['FLUTTER_ROOT'];
  await load('Inter', 'assets/fonts/Inter.ttf');
  await load('NotoSansDevanagari', 'assets/fonts/NotoSansDevanagari.ttf');
  await load(
    'MaterialIcons',
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
}

final _key = GlobalKey();

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settle(tester, 4);
  final problem = tester.takeException();
  await tester.runAsync(() async {
    final boundary =
        _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$_localeCode-$name.png').writeAsBytesSync(
      data!.buffer.asUint8List(),
    );
  });
  if (problem != null) {
    File('$_out/$_localeCode-$name.problem.txt').writeAsStringSync('$problem');
  }
}

Future<AppServices> _boot(
  WidgetTester tester, {
  required String role,
  Size size = const Size(360, 780),
  bool cart = false,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = _scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  final backend = staffGalleryBackend(role: role);
  final services = await testServices(backend, prefsValues: {
    'locale': _localeCode,
  });
  await services.prefs.setRingEnabled(false);
  if (cart) {
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
      ..add(dish['i-lassi']!, qty: 2)
      ..setTable(const DiningTable(id: 'tb2', label: 'T2', seats: 4))
      ..setGuestCount(3);
  }
  // What main() does before the first frame.
  await services.locale.restore();
  expect(services.locale.active.code, _localeCode);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: ViniiPartnerApp(services: services),
    ),
  );
  await _settle(tester, 20);
  return services;
}

void _go(WidgetTester tester, String route) {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
}

Future<void> _tab(WidgetTester tester, int index) async {
  await tester.tap(find.byType(NavigationDestination).at(index));
  await _settle(tester);
}

Future<void> _scroll(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(Scrollable).first, Offset(0, -dy));
  await _settle(tester);
}

void main() {
  setUpAll(_loadFonts);
  final skip = _out == null ? 'set VISUAL_OUT to render' : null;

  testWidgets('inbox and the open-orders sheet', (tester) async {
    await _boot(tester, role: 'manager');
    await _shot(tester, 'orders');
  }, skip: skip != null);

  testWidgets('more, language, bill, team, tables', (tester) async {
    await _boot(tester, role: 'org_owner');
    await _tab(tester, 4);
    await _shot(tester, 'more');
    await _scroll(tester, 500);
    await _shot(tester, 'more-2');
    _go(tester, Routes.language);
    await _settle(tester);
    await _shot(tester, 'language');
    _go(tester, Routes.billSettings);
    await _settle(tester);
    await _shot(tester, 'bill-1');
    await _scroll(tester, 700);
    await _shot(tester, 'bill-2');
    _go(tester, Routes.team);
    await _settle(tester);
    await _shot(tester, 'team');
    _go(tester, Routes.tableCodes);
    await _settle(tester);
    await _shot(tester, 'tables');
  }, skip: skip != null);

  testWidgets('sell and checkout', (tester) async {
    await _boot(tester, role: 'org_owner', cart: true);
    await _tab(tester, 1);
    await _shot(tester, 'sell');
    await tester.tap(find.byKey(const Key('sell-review')));
    await _settle(tester);
    await _shot(tester, 'checkout-1');
    await _scroll(tester, 700);
    await _shot(tester, 'checkout-2');
  }, skip: skip != null);

  testWidgets('payment', (tester) async {
    final services = await _boot(tester, role: 'manager');
    final order = (await services.backend.pos.openOrders()).first;
    await _tab(tester, 1);
    await tester.tap(find.byTooltip(
      services.locale.active.code == 'hi' ? 'खुले ऑर्डर' : 'Open orders',
    ));
    await _settle(tester);
    await _shot(tester, 'open-orders');
    await tester.tap(find.text(order.displayNo));
    await _settle(tester);
    await _shot(tester, 'pay-1');
    await _scroll(tester, 900);
    await _shot(tester, 'pay-2');
  }, skip: skip != null);

  testWidgets('menu and studio', (tester) async {
    await _boot(tester, role: 'org_owner');
    await _tab(tester, 2);
    await _shot(tester, 'menu');
    await _tab(tester, 3);
    await _shot(tester, 'studio');
  }, skip: skip != null);

  testWidgets('wide counter screen', (tester) async {
    await _boot(tester, role: 'org_owner', size: const Size(1280, 800), cart: true);
    await _tab(tester, 1);
    await _shot(tester, 'wide-sell');
  }, skip: skip != null);
}
