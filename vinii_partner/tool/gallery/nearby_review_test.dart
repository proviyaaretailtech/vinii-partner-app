// Visual review of the "what the tables around you are ordering" alert,
// without a browser.
//
// Renders the real guest runtime on the gallery's invented restaurants, with
// a pretend feed of other tables' orders, the bundled Inter font and the
// Material icons, and writes PNG files of the alert over the categories page
// and over the deck: the dark bistro and the cream bakery, on a phone, plus a
// few awkward cases (a long name, a narrow phone, a wide screen). It is not
// part of the normal test run and writes nothing unless VISUAL_OUT names a
// folder:
//
//   VISUAL_OUT=/tmp/nearby-shots flutter test tool/gallery/nearby_review_test.dart
//
// Headings use Inter here (remote fonts are off in tests), so the type shows
// the layout and hierarchy but not the chosen display faces.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/application/guest_social.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/presentation/guest/guest_app.dart';
import 'package:vinii_partner/presentation/theme/guest_theme.dart';

import 'gallery_kit.dart';
import 'gallery_nearby.dart';

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
const _narrow = Size(320, 640);
const _wide = Size(1440, 900);

/// One invented order, a second after anyone starts listening.
class _OneOrder extends GuestNearby {
  _OneOrder(this.itemId, {this.qty = 1, this.who = 'Table 7'});
  final String itemId;
  final int qty;
  final String who;

  @override
  Stream<NearbyOrder> orders() {
    final out = StreamController<NearbyOrder>();
    Timer? timer;
    out.onListen = () {
      timer = Timer(const Duration(seconds: 1), () {
        out.add(
          NearbyOrder(
            id: 'review-1',
            itemId: itemId,
            qty: qty,
            who: who,
            at: DateTime.now(),
          ),
        );
      });
    };
    out.onCancel = () => timer?.cancel();
    return out.stream;
  }
}

/// The gallery's gateway with a feed of the tables around of our choosing.
class _Gateway extends GalleryGateway {
  _Gateway(this._nearby);
  final GuestNearby _nearby;

  @override
  GuestNearby? get nearby => _nearby;
}

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
  Fixture fixture,
  GuestNearby nearby, {
  Size size = _phone,
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
          gateway: _Gateway(nearby),
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

/// Welcome, past the budget screen, onto the categories page, which is the
/// first page that shows alerts.
Future<void> _toCategories(WidgetTester tester) async {
  final cta = find.byKey(const ValueKey('welcome-cta'));
  await tester.tap(
    cta.evaluate().isNotEmpty
        ? cta
        : find.byKey(const ValueKey('welcome-mode-dineIn')),
  );
  await _settle(tester);
  if (find.text('Save & continue').evaluate().isNotEmpty) {
    await _tapText(tester, 'Save & continue');
  } else if (find.text('Skip').evaluate().isNotEmpty) {
    await _tapText(tester, 'Skip');
  }
}

/// Waits (in pretend time) for the alert to arrive and finish sliding in.
Future<void> _waitForAlert(WidgetTester tester) async {
  final alert = find.byKey(const ValueKey('nearby-alert'));
  for (var t = 0; t < 12000 && alert.evaluate().isEmpty; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(alert, findsWidgets, reason: 'the alert never arrived');
  await _settle(tester, 500);
}

void main() {
  setUpAll(_loadFonts);
  final skip = _out == null;

  testWidgets('bistro on a phone: over the categories, the deck, and Added', (
    tester,
  ) async {
    await _boot(
      tester,
      Fixture.bistro(),
      _OneOrder('i-biryani', qty: 2, who: 'Table 7'),
    );
    await _toCategories(tester);
    await _waitForAlert(tester);
    await _shot(tester, 'n-bistro-categories');

    // The alert goes along to the deck.
    await _tapText(tester, 'All dishes');
    await _shot(tester, 'n-bistro-deck');

    // Add: the button says Added for a moment.
    await tester.tap(find.byKey(const ValueKey('nearby-add')).last);
    await _settle(tester, 300);
    await _shot(tester, 'n-bistro-added');
    await _settle(tester, 9000);
  }, skip: skip);

  testWidgets('bakery (cream) on a phone: over the categories and the deck', (
    tester,
  ) async {
    await _boot(
      tester,
      Fixture.artisan(),
      _OneOrder('a-scroll', qty: 2, who: 'Table 7'),
    );
    await _toCategories(tester);
    await _waitForAlert(tester);
    await _shot(tester, 'n-bakery-categories');

    await _tapText(tester, 'Explore all dishes');
    await _shot(tester, 'n-bakery-deck');

    await tester.tap(find.byKey(const ValueKey('nearby-add')).last);
    await _settle(tester, 300);
    await _shot(tester, 'n-bakery-added');
    await _settle(tester, 9000);
  }, skip: skip);

  testWidgets('a single portion and a long name', (tester) async {
    await _boot(
      tester,
      Fixture.bistro(),
      _OneOrder('i-penne', who: 'Table 15'),
    );
    await _toCategories(tester);
    await _waitForAlert(tester);
    await _shot(tester, 'n-single');
    await _settle(tester, 9000);
  }, skip: skip);

  testWidgets('a narrow phone with larger text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _boot(
      tester,
      Fixture.bistro(),
      _OneOrder('i-margherita', qty: 12, who: 'Table 15'),
      size: _narrow,
    );
    await _toCategories(tester);
    await _waitForAlert(tester);
    await _shot(tester, 'n-narrow', size: _narrow);
    await _settle(tester, 9000);
  }, skip: skip);

  testWidgets('the gallery\'s own pretend feed, bistro, wide screen', (
    tester,
  ) async {
    final bistro = Fixture.bistro();
    await _boot(
      tester,
      bistro,
      GalleryNearby([
        'i-biryani',
        'i-tikka',
        'i-butter',
        'i-dal',
      ], startAfter: const Duration(seconds: 1)),
      size: _wide,
    );
    await _toCategories(tester);
    await _waitForAlert(tester);
    await _shot(tester, 'n-wide-categories', size: _wide);

    await _tapText(tester, 'All dishes');
    await _shot(tester, 'n-wide-deck', size: _wide);
    await _settle(tester, 9000);
  }, skip: skip);
}
