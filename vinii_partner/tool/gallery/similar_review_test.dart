// Visual review of "tables like yours", without a browser.
//
// Renders the real guest runtime on the gallery's invented restaurants, with
// an invented feed of three tables (gallery_similar.dart), and writes PNG
// files: the strip on the categories screen, a mouse resting on a card (what
// is in it), the compact strip on the empty order, the open sheet, the sheet
// with some of it taken off and counts changed, one dish added on its own, the
// sheet with a dish that has left the menu, and the confirmation after "Add".
// The dark bistro and the cream bakery at phone width, then a 320 pixel phone
// and a wide screen. It is not part of the normal test run and writes nothing
// unless VISUAL_OUT names a folder:
//
//   VISUAL_OUT=/tmp/similar-shots flutter test tool/gallery/similar_review_test.dart
//
// Headings use Inter here (remote fonts are off in tests), so the type shows
// the layout and hierarchy but not the chosen display faces.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/application/guest_social.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/presentation/guest/guest_app.dart';
import 'package:vinii_partner/presentation/guest/guest_order.dart';
import 'package:vinii_partner/presentation/guest/guest_similar.dart';
import 'package:vinii_partner/presentation/guest/guest_widgets.dart';
import 'package:vinii_partner/presentation/theme/guest_theme.dart';

import 'gallery_kit.dart';
import 'gallery_similar.dart';

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

typedef _Basket = List<({String itemId, int qty})>;

/// What the three pretend tables ordered at the dark bistro. The second has a
/// dish that is no longer on the menu, to see the dimmed row.
const _bistro = <_Basket>[
  [
    (itemId: 'i-biryani', qty: 2),
    (itemId: 'i-tikka', qty: 1),
    (itemId: 'i-corn', qty: 1),
    (itemId: 'i-jamun', qty: 2),
  ],
  [
    (itemId: 'i-penne', qty: 1),
    (itemId: 'i-margherita', qty: 1),
    (itemId: 'i-tiramisu', qty: 2),
    (itemId: 'i-retired-special', qty: 1),
  ],
  [
    (itemId: 'i-c65', qty: 1),
    (itemId: 'i-tikka', qty: 2),
    (itemId: 'i-biryani', qty: 1),
  ],
];

/// And at the cream bakery.
const _bakery = <_Basket>[
  [
    (itemId: 'a-scroll', qty: 2),
    (itemId: 'a-pistachio', qty: 1),
    (itemId: 'a-latte', qty: 2),
  ],
  [
    (itemId: 'a-sourdough', qty: 1),
    (itemId: 'a-almond', qty: 2),
    (itemId: 'a-cake', qty: 1),
    (itemId: 'a-seasonal-loaf', qty: 1),
  ],
  [(itemId: 'a-danish', qty: 1), (itemId: 'a-raspberry', qty: 1)],
];

/// The gallery's gateway, with the invented tables.
class _ReviewGateway extends GalleryGateway {
  _ReviewGateway(this._tables);
  final GuestSimilarTables _tables;

  @override
  GuestSimilarTables? get similarTables => _tables;
}

/// Finite steps instead of pumpAndSettle: the stage's embers never rest.
Future<void> _settle(WidgetTester tester, [int ms = 1200]) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

late Size _size;

Future<void> _shot(WidgetTester tester, String name) async {
  await _settle(tester, 300);
  await tester.runAsync(() async {
    final boundary =
        _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ratio = _size.width > 600 ? 1.0 : 2.0;
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _boot(
  WidgetTester tester,
  Fixture fixture,
  List<_Basket> baskets, {
  Size size = _phone,
}) async {
  _size = size;
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
          gateway: _ReviewGateway(GallerySimilarTables(baskets)),
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

/// A tap where the card is, so the row stays where the guest would see it.
Future<void> _tapCard(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
}

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).last);

/// Welcome, past the budget screen, onto the categories.
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
  // The tables arrive a moment after the page does.
  await _settle(tester, 1600);
}

/// The strip as the categories screen carries it. If that screen does not
/// carry it yet, a page of its own shows it on the same lit stage.
Future<void> _ensureStrip(WidgetTester tester) async {
  if (find.byType(SimilarTablesStrip).evaluate().isNotEmpty) return;
  _nav(tester).push(guestRoute<void>(const _Host()));
  await _settle(tester, 1600);
}

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return GuestPage(
      maxWidth: wide ? 1040 : 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GuestTopBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Text('What are you in the mood for?', style: p.display(28)),
          ),
          const SimilarTablesStrip(),
        ],
      ),
    );
  }
}

String _firstCard() => 'similar-card-gallery-similar-0';
String _secondCard() => 'similar-card-gallery-similar-1';

/// The pictures of one restaurant: the strip, two sheets
/// and the confirmation.
Future<void> _tour(
  WidgetTester tester,
  Fixture fixture,
  List<_Basket> baskets,
  String prefix, {
  Size size = _phone,
  bool everything = true,
}) async {
  await _boot(tester, fixture, baskets, size: size);
  await _toCategories(tester);
  await _ensureStrip(tester);
  await _shot(tester, '$prefix-strip');

  if (everything) {
    // A mouse resting on a card shows what is in it, a line to a dish.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(ValueKey(_firstCard()))));
    await _settle(tester, 700);
    await _shot(tester, '$prefix-peek');
    await mouse.moveTo(Offset.zero);
    await _settle(tester, 400);
    await mouse.removePointer();
  }

  await _tapCard(tester, _firstCard());
  await _shot(tester, '$prefix-sheet');

  // Take only some of it: drop the second dish, ask for one more of the first.
  final dishes = [for (final l in baskets.first) l.itemId];
  await _tapCard(tester, 'similar-tick-${dishes[1]}');
  await tester.tap(
    find.descendant(
      of: find.byKey(ValueKey('similar-qty-${dishes[0]}')),
      matching: find.byIcon(Icons.add_rounded),
    ),
  );
  await _settle(tester);
  await _shot(tester, '$prefix-sheet-picked');

  // And add the last dish on its own, with the sheet staying open.
  await tester.tap(find.byKey(ValueKey('similar-add-${dishes.last}')));
  await _shot(tester, '$prefix-sheet-added-one');
  // "Added" goes back to "Add" by itself after a moment.
  await _settle(tester, 2000);
  if (!everything) return;
  await _tapText(tester, 'Done');

  await _tapCard(tester, _secondCard());
  await _shot(tester, '$prefix-sheet-gone');
  await tester.tap(find.byKey(const ValueKey('similar-add-all')));
  await _settle(tester, 800);
  await _shot(tester, '$prefix-added');
  // Let the confirmation go, so no timer is left running.
  await _settle(tester, 4000);
}

/// The empty order, with the compact strip under "Browse dishes". On its own
/// so that whatever the order page does on its way out cannot spoil the rest.
Future<void> _emptyOrder(
  WidgetTester tester,
  Fixture fixture,
  List<_Basket> baskets,
  String prefix,
) async {
  await _boot(tester, fixture, baskets);
  await _toCategories(tester);
  _nav(tester).push(guestRoute<void>(const GuestOrderScreen()));
  await _settle(tester, 1600);
  await _shot(tester, '$prefix-order-empty');
  // Leave the page now, and say what it did on the way out rather than let
  // the end of the test trip over it.
  _nav(tester).pop();
  await _settle(tester);
  final onTheWayOut = tester.takeException();
  if (onTheWayOut != null) {
    debugPrint('The order page threw as it closed: $onTheWayOut');
  }
}

void main() {
  setUpAll(_loadFonts);
  final skip = _out == null;

  testWidgets('bistro (dark) on a phone', (tester) async {
    await _tour(tester, Fixture.bistro(), _bistro, 'bistro');
  }, skip: skip);

  testWidgets('bakery (cream) on a phone', (tester) async {
    await _tour(tester, Fixture.artisan(), _bakery, 'bakery');
  }, skip: skip);

  testWidgets('bistro on a 320 pixel phone', (tester) async {
    await _tour(
      tester,
      Fixture.bistro(),
      _bistro,
      'bistro-320',
      size: _narrow,
      everything: false,
    );
  }, skip: skip);

  testWidgets('bakery on a 320 pixel phone', (tester) async {
    await _tour(
      tester,
      Fixture.artisan(),
      _bakery,
      'bakery-320',
      size: _narrow,
      everything: false,
    );
  }, skip: skip);

  testWidgets('bistro on a wide screen', (tester) async {
    await _tour(
      tester,
      Fixture.bistro(),
      _bistro,
      'bistro-wide',
      size: _wide,
      everything: false,
    );
  }, skip: skip);

  testWidgets('bistro: the empty order', (tester) async {
    await _emptyOrder(tester, Fixture.bistro(), _bistro, 'bistro');
  }, skip: skip);

  testWidgets('bakery: the empty order', (tester) async {
    await _emptyOrder(tester, Fixture.artisan(), _bakery, 'bakery');
  }, skip: skip);
}
