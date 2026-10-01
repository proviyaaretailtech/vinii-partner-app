// Visual review of the guest screens, without a browser.
//
// Renders the real guest runtime on the gallery's invented restaurants (see
// gallery_kit.dart), with the bundled Inter font and the Material icons, and
// writes each screen to a PNG file: the dark bistro, the cream bakery, a
// phone and a wide screen. It is not part of the normal test run and writes
// nothing unless VISUAL_OUT names a folder:
//
//   VISUAL_OUT=/tmp/guest-shots flutter test tool/gallery/guest_review_test.dart
//
// Headings use Inter here (remote fonts are off in tests), so the type shows
// the layout and hierarchy but not the chosen display faces.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/presentation/guest/guest_app.dart';
import 'package:vinii_partner/presentation/theme/guest_theme.dart';

import 'gallery_kit.dart';

final _out = Platform.environment['VISUAL_OUT'];

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final bytes = File(path).readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  final root = Platform.environment['FLUTTER_ROOT'];
  await load('Inter', 'assets/fonts/Inter.ttf');
  await load(
    'MaterialIcons',
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
}

final _key = GlobalKey();
const _phone = Size(390, 844);
const _wide = Size(1440, 900);

/// Finite steps instead of pumpAndSettle: the stage's embers never rest.
Future<void> _settle(WidgetTester tester, [int ms = 1200]) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name, {Size? size}) async {
  await _settle(tester, 300);
  await tester.runAsync(() async {
    final boundary =
        _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ratio = (size ?? _phone).width > 600 ? 1.0 : 2.0;
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _boot(
  WidgetTester tester,
  Fixture fixture, {
  Size size = _phone,
  bool online = true,
}) async {
  GuestPalette.remoteFonts = false;
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: _key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: GuestApp(
          definition: fixture.definition,
          menu: fixture.menu,
          gateway: GalleryGateway(online: online),
          table: const DiningTable(id: 'gallery-t12', label: '12'),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text).first;
  await tester.ensureVisible(f);
  await _settle(tester, 200);
  await tester.tap(f);
  await _settle(tester);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await _settle(tester, 200);
  await tester.tap(f);
  await _settle(tester);
}

/// The welcome screen's way in: one button, or a pill per way of ordering.
Future<void> _start(WidgetTester tester) async {
  final cta = find.byKey(const ValueKey('welcome-cta'));
  await tester.tap(
    cta.evaluate().isNotEmpty
        ? cta
        : find.byKey(const ValueKey('welcome-mode-dineIn')),
  );
  await _settle(tester);
}

/// Back one page, the way the guest's own back arrow does.
Future<void> _back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).last).pop();
  await _settle(tester);
}

/// Welcome, past the budget screen, into the deck of every dish.
Future<void> _intoDeck(WidgetTester tester) async {
  await _start(tester);
  if (find.text('Save & continue').evaluate().isNotEmpty) {
    await _tapText(tester, 'Save & continue');
  } else if (find.text('Skip').evaluate().isNotEmpty) {
    await _tapText(tester, 'Skip');
  }
}

/// Let the pretend kitchen finish (8 s a step), then open the bill.
Future<void> _toBill(WidgetTester tester) async {
  await _tapText(tester, 'Track order');
  await _settle(tester, 17000);
  await _tapText(tester, 'View bill');
}

/// Leaves time for the gallery's pretend kitchen to finish so no timer is
/// left running when the test ends.
Future<void> _drain(WidgetTester tester) async {
  await _settle(tester, 30000);
}

void main() {
  setUpAll(_loadFonts);
  final skip = _out == null;

  testWidgets('bistro on a phone: welcome to the order', (tester) async {
    await _boot(tester, Fixture.bistro());
    await _shot(tester, 'g-welcome');
    await _start(tester);
    await _shot(tester, 'g-budget');
    await _tapText(tester, 'Save & continue');
    await _shot(tester, 'g-categories');
    await _tapText(tester, 'All dishes');
    await _shot(tester, 'g-deck');

    // The top card opens the dish: ingredients are plain words now.
    final card = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key! as ValueKey).value}'.startsWith('deck-card-'),
    );
    await tester.tap(card.last);
    await _settle(tester, 1800);
    await _shot(tester, 'g-detail');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
    await _settle(tester, 800);
    await _shot(tester, 'g-detail-2');
    await _back(tester);

    await _tapKey(tester, 'deck-add');
    await _settle(tester, 1600);
    await _tapText(tester, 'View order (1)');
    await _shot(tester, 'g-order');
    await _tapText(tester, 'Continue to review');
    await _tapText(tester, 'Proceed to checkout');
    await _shot(tester, 'g-checkout');
    await _drain(tester);
  }, skip: skip);

  testWidgets('bistro on a phone: placed, tracking, bill, pay', (tester) async {
    await _boot(tester, Fixture.bistro());
    await _intoDeck(tester);
    await _tapText(tester, 'All dishes');
    await _tapKey(tester, 'deck-add');
    await _settle(tester, 1600);
    await _tapText(tester, 'View order (1)');
    await _tapText(tester, 'Continue to review');
    await _tapText(tester, 'Proceed to checkout');
    await _tapKey(tester, 'place-order');
    await _settle(tester, 900);
    await _shot(tester, 'g-placed');
    await _settle(tester, 1500);
    await _tapText(tester, 'Track order');
    await _shot(tester, 'g-tracking');
    await _settle(tester, 17000);
    await _tapText(tester, 'View bill');
    await _shot(tester, 'g-bill');

    // Online payment: the hint sits right above the button, then the number
    // is typed and the button is ready.
    await _tapKey(tester, 'pay-online');
    await _shot(tester, 'g-pay-hint');
    await tester.enterText(
      find.byKey(const ValueKey('pay-phone')),
      '1234567890',
    );
    await _settle(tester, 300);
    await _shot(tester, 'g-pay-invalid');
    await tester.enterText(
      find.byKey(const ValueKey('pay-phone')),
      '9876543210',
    );
    await _settle(tester, 300);
    await _shot(tester, 'g-pay-ready');
    if (find.text('My share').evaluate().isNotEmpty) {
      await _tapText(tester, 'My share');
      await _shot(tester, 'g-pay-share');
      await _tapText(tester, 'Whole bill');
    }
    await _tapKey(tester, 'pay-now');
    await _settle(tester, 1200);
    await _shot(tester, 'g-pay-window');
    await _tapText(tester, 'Pay successfully');
    await _settle(tester, 3000);
    await _shot(tester, 'g-receipt');
    await _drain(tester);
  }, skip: skip);

  testWidgets('bistro on a phone without online payment', (tester) async {
    await _boot(tester, Fixture.bistro(), online: false);
    await _intoDeck(tester);
    await _tapText(tester, 'All dishes');
    await _tapKey(tester, 'deck-add');
    await _settle(tester, 1600);
    await _tapText(tester, 'View order (1)');
    await _tapText(tester, 'Continue to review');
    await _tapText(tester, 'Proceed to checkout');
    await _tapKey(tester, 'place-order');
    await _settle(tester, 2400);
    await _toBill(tester);
    await _shot(tester, 'g-bill-offline');
    await _drain(tester);
  }, skip: skip);

  testWidgets('bakery (cream) on a phone', (tester) async {
    await _boot(tester, Fixture.artisan());
    await _shot(tester, 'c-welcome');
    await _intoDeck(tester);
    await _shot(tester, 'c-categories');
    await _tapText(tester, 'All dishes');
    await _shot(tester, 'c-deck');
    final card = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey &&
          '${(w.key! as ValueKey).value}'.startsWith('deck-card-'),
    );
    await tester.tap(card.last);
    await _settle(tester, 1800);
    await _shot(tester, 'c-detail');
    await _back(tester);
    await _tapKey(tester, 'deck-add');
    await _settle(tester, 1600);
    await _tapText(tester, 'View order (1)');
    await _tapText(tester, 'Continue to review');
    await _tapText(tester, 'Proceed to checkout');
    await _tapKey(tester, 'place-order');
    await _settle(tester, 2400);
    await _shot(tester, 'c-placed');
    await _tapText(tester, 'Track order');
    await _shot(tester, 'c-tracking');
    await _settle(tester, 17000);
    await _tapText(tester, 'View bill');
    await _shot(tester, 'c-bill');
    await _tapKey(tester, 'pay-online');
    await _shot(tester, 'c-pay');
    await _drain(tester);
  }, skip: skip);

  testWidgets('bistro on a wide screen', (tester) async {
    await _boot(tester, Fixture.bistro(), size: _wide);
    await _shot(tester, 'w-welcome', size: _wide);
    await _intoDeck(tester);
    await _shot(tester, 'w-categories', size: _wide);
    await _tapText(tester, 'All dishes');
    await _tapKey(tester, 'deck-add');
    await _settle(tester, 1600);
    await _shot(tester, 'w-deck', size: _wide);
    await _drain(tester);
  }, skip: skip);
}
