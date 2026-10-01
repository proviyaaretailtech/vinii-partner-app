// Visual review of the staff screens, without a browser.
//
// Renders the real app (ViniiPartnerApp on the test FakeBackend, filled with
// the gallery's invented fixtures) with the bundled Inter font and the
// Material icons, and writes each screen to a PNG file: phone and counter
// computer, light and dark, and each role's view. It is not part of the
// normal test run and writes nothing unless VISUAL_OUT names a folder:
//
//   VISUAL_OUT=/tmp/staff-shots flutter test tool/gallery/staff_review_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/app/app.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/application/sell_cart.dart';
import 'package:vinii_partner/domain/pos_order.dart';

import '../../test/support/harness.dart';
import 'staff_fixtures.dart';

final _out = Platform.environment['VISUAL_OUT'];

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  // The flutter tool names its own folder; the icon font ships inside it.
  final root = Platform.environment['FLUTTER_ROOT'];
  await load('Inter', 'assets/fonts/Inter.ttf');
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
  await tester.runAsync(() async {
    final boundary =
        _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<AppServices> _boot(
  WidgetTester tester, {
  required String role,
  Size size = const Size(390, 844),
  ThemeMode mode = ThemeMode.light,
  String? outlet,
  bool cart = false,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  final backend = staffGalleryBackend(role: role, outlet: outlet);
  final services = await testServices(backend);
  await services.prefs.setRingEnabled(false);
  services.themeMode.value = mode;
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
  await tester.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: ViniiPartnerApp(services: services),
    ),
  );
  await _settle(tester, 20);
  return services;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text).first;
  await tester.ensureVisible(f);
  await _settle(tester, 3);
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await _settle(tester, 3);
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _back(WidgetTester tester) async {
  await tester.pageBack();
  await _settle(tester);
}

Future<void> _scroll(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(Scrollable).first, Offset(0, -dy));
  await _settle(tester);
}

void main() {
  setUpAll(_loadFonts);
  final skip = _out == null ? 'set VISUAL_OUT to render' : null;
  const desk = Size(1280, 800);

  testWidgets('orders: open, paused, closed, kitchen', (tester) async {
    await _boot(tester, role: 'manager');
    await _shot(tester, 'p-orders-open');
    await _tapKey(tester, 'outlet-closed');
    await _shot(tester, 'p-orders-close-sheet');
  }, skip: skip != null);

  testWidgets('orders paused', (tester) async {
    await _boot(tester, role: 'manager', outlet: 'paused');
    await _shot(tester, 'p-orders-paused');
  }, skip: skip != null);

  testWidgets('orders closed', (tester) async {
    await _boot(tester, role: 'manager', outlet: 'closed');
    await _shot(tester, 'p-orders-closed');
  }, skip: skip != null);

  testWidgets('orders kitchen', (tester) async {
    await _boot(tester, role: 'kitchen');
    await _shot(tester, 'p-orders-kitchen');
  }, skip: skip != null);

  testWidgets('more, bill, phone', (tester) async {
    await _boot(tester, role: 'org_owner');
    await _tapText(tester, 'More');
    await _shot(tester, 'p-more');
    await _scroll(tester, 500);
    await _shot(tester, 'p-more-2');
    await _tapText(tester, 'Bill & GST');
    await _shot(tester, 'p-bill-1');
    await _scroll(tester, 700);
    await _shot(tester, 'p-bill-2');
  }, skip: skip != null);

  testWidgets('team as owner and as admin', (tester) async {
    await _boot(tester, role: 'org_owner');
    await _tapText(tester, 'More');
    await _tapText(tester, 'Team');
    await _shot(tester, 'p-team-owner-1');
    await _scroll(tester, 900);
    await _shot(tester, 'p-team-owner-2');
  }, skip: skip != null);

  testWidgets('team admin sheets', (tester) async {
    await _boot(tester, role: 'org_admin');
    await _tapText(tester, 'More');
    await _tapText(tester, 'Team');
    await _shot(tester, 'p-team-admin');
    await tester.ensureVisible(find.text('Ravi Kulkarni'));
    await _settle(tester, 3);
    await tester.tap(find.text('Ravi Kulkarni'));
    await _settle(tester);
    await _shot(tester, 'p-team-sheet');
    await _tapKey(tester, 'team-change-role');
    await _shot(tester, 'p-team-roles');
  }, skip: skip != null);

  testWidgets('tables phone', (tester) async {
    await _boot(tester, role: 'manager');
    await _tapText(tester, 'More');
    await _tapText(tester, 'Table QR codes');
    await _shot(tester, 'p-tables-1');
    await _scroll(tester, 500);
    await _shot(tester, 'p-tables-2');
  }, skip: skip != null);

  testWidgets('sell, checkout phone', (tester) async {
    await _boot(tester, role: 'org_owner', cart: true);
    await _tapText(tester, 'Sell');
    await _shot(tester, 'p-sell');
    await tester.tap(find.byKey(const Key('sell-review')));
    await _settle(tester);
    await _shot(tester, 'p-checkout-1');
    await _scroll(tester, 700);
    await _shot(tester, 'p-checkout-2');
    await tester.tap(find.byKey(const Key('service-charge-remove')));
    await _settle(tester);
    await _shot(tester, 'p-remove-sheet');
    await tester.tap(find.byKey(const Key('service-charge-confirm-remove')));
    await _settle(tester);
    await _shot(tester, 'p-checkout-removed');
  }, skip: skip != null);

  testWidgets('sell pickers', (tester) async {
    await _boot(tester, role: 'captain');
    await _tapText(tester, 'Sell');
    await _shot(tester, 'p-sell-empty');
    await _tapText(tester, 'Choose table');
    await _shot(tester, 'p-table-picker');
    await tester.tapAt(const Offset(195, 60));
    await _settle(tester);
    await tester.longPress(find.text('Chicken Biryani').first);
    await _settle(tester);
    await _shot(tester, 'p-line-sheet');
  }, skip: skip != null);

  testWidgets('payment phone', (tester) async {
    final services = await _boot(tester, role: 'manager');
    final order = (await services.backend.pos.openOrders()).first;
    await _tapText(tester, 'Sell');
    await tester.tap(find.byTooltip('Open orders'));
    await _settle(tester);
    await _shot(tester, 'p-open-orders');
    await tester.tap(find.text(order.displayNo));
    await _settle(tester);
    await _shot(tester, 'p-pay-1');
    await _scroll(tester, 900);
    await _shot(tester, 'p-pay-2');
    await _tapKey(tester, 'cash-500');
    await _shot(tester, 'p-pay-cash');
    await _tapKey(tester, 'pay-split');
    await tester.enterText(find.byKey(const Key('split-amount-1')), '300');
    await _settle(tester);
    await _tapKey(tester, 'split-rest');
    await _shot(tester, 'p-pay-split-covered');
    await _tapKey(tester, 'pay-charge');
    await _shot(tester, 'p-pay-success');
  }, skip: skip != null);

  testWidgets('dark', (tester) async {
    await _boot(tester, role: 'org_owner', mode: ThemeMode.dark, cart: true);
    await _shot(tester, 'k-orders');
    await _tapText(tester, 'More');
    await _shot(tester, 'k-more');
    await _tapText(tester, 'Sell');
    await _shot(tester, 'k-sell');
  }, skip: skip != null);

  testWidgets('desktop sell and payment', (tester) async {
    final services = await _boot(
      tester,
      role: 'org_owner',
      size: desk,
      cart: true,
    );
    await _shot(tester, 'w-orders');
    await _tapText(tester, 'Sell');
    await _shot(tester, 'w-sell');
    final order = (await services.backend.pos.openOrders()).first;
    await tester.tap(find.byTooltip('Open orders'));
    await _settle(tester);
    await tester.tap(find.text(order.displayNo));
    await _settle(tester);
    await _shot(tester, 'w-pay');
    await _tapKey(tester, 'pay-split');
    await _shot(tester, 'w-pay-split');
  }, skip: skip != null);

  testWidgets('desktop settings', (tester) async {
    await _boot(tester, role: 'org_admin', size: desk);
    await _tapText(tester, 'More');
    await _shot(tester, 'w-more');
    await _tapText(tester, 'Bill & GST');
    await _shot(tester, 'w-bill');
    await _back(tester);
    await _tapText(tester, 'Team');
    await _shot(tester, 'w-team');
    await _back(tester);
    await _tapText(tester, 'Table QR codes');
    await _shot(tester, 'w-tables');
  }, skip: skip != null);

  for (final role in ['manager', 'biller', 'captain', 'kitchen']) {
    testWidgets('more as $role', (tester) async {
      await _boot(tester, role: role);
      await _tapText(tester, 'More');
      await _shot(tester, 'r-more-$role');
    }, skip: skip != null);
  }

  testWidgets('bill as manager (view only)', (tester) async {
    await _boot(tester, role: 'manager');
    await _tapText(tester, 'More');
    await _tapText(tester, 'Bill & GST');
    await _shot(tester, 'r-bill-manager');
  }, skip: skip != null);
}
