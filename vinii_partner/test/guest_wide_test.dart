import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/domain/storefront.dart';
import 'package:vinii_partner/presentation/guest/guest_app.dart';
import 'package:vinii_partner/presentation/guest/guest_order_panel.dart';
import 'package:vinii_partner/presentation/theme/guest_theme.dart';

import 'guest_runtime_test.dart'
    show RecordingGateway, menu, noBudget, settle, storefront, tapText;

/// The guest runtime on a counter screen and a tablet: no overflow, and the
/// order stays in view beside the deck when there is room for it.
Future<void> pumpAt(
  WidgetTester tester,
  Size logical, {
  StorefrontDefinition? definition,
}) async {
  GuestPalette.remoteFonts = false;
  tester.view.physicalSize = logical * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: GuestApp(
        definition: definition ?? storefront(features: noBudget),
        menu: menu,
        gateway: RecordingGateway(),
      ),
    ),
  );
  await settle(tester);
}

void main() {
  for (final size in const [
    Size(1440, 900),
    Size(1024, 768),
    Size(768, 1024),
  ]) {
    testWidgets(
      'the welcome fits ${size.width.toInt()} x ${size.height.toInt()}',
      (tester) async {
        await pumpAt(tester, size);
        expect(find.text('Start exploring'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a wide screen keeps the order beside the deck', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    await tapText(tester, 'Start exploring');
    await tapText(tester, 'All dishes');
    expect(find.byType(GuestOrderPanel), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('deck-add')));
    await settle(tester);
    expect(find.text('Nothing here yet'), findsNothing);
    expect(find.text('Paneer Tikka'), findsWidgets);
    expect(find.text('Review and place order'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the arrow keys drive the deck', (tester) async {
    await pumpAt(tester, const Size(1440, 900));
    await tapText(tester, 'Start exploring');
    await tapText(tester, 'All dishes');
    expect(find.text('Nothing here yet'), findsOneWidget);

    // Right adds the dish on top; left skips the next one without adding.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    expect(find.text('Nothing here yet'), findsNothing);
    expect(find.text('1 item'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(tester);
    expect(find.text('1 item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tablet in portrait keeps the phone layout', (tester) async {
    await pumpAt(tester, const Size(768, 1024));
    await tapText(tester, 'Start exploring');
    await tapText(tester, 'All dishes');
    expect(find.byType(GuestOrderPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
