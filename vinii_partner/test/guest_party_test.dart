import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'guest_runtime_test.dart'
    show
        RecordingGateway,
        goToCheckout,
        noBudget,
        pumpGuest,
        settle,
        storefront,
        table12,
        tapText;

void main() {
  testWidgets('"For all 2" gives everyone at the table the same dish', (
    tester,
  ) async {
    await pumpGuest(
      tester,
      definition: storefront(),
      gateway: RecordingGateway(),
      table: table12,
    );
    await tapText(tester, 'Start exploring');
    // The party is two people by default.
    await tapText(tester, 'Save & continue');
    await tapText(tester, 'All dishes');
    await tester.tap(find.byKey(const ValueKey('deck-add')));
    await settle(tester);
    await tapText(tester, 'View order (1)');

    expect(find.text('For all 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('repeat-i-paneer')));
    await settle(tester);
    // Two portions of a ₹600 dish; the chip is gone because it is done.
    expect(find.text('₹1,200'), findsOneWidget);
    expect(find.text('For all 2'), findsNothing);
  });

  testWidgets('"Order the same again" refills the cart from the last order', (
    tester,
  ) async {
    await pumpGuest(
      tester,
      definition: storefront(features: noBudget.copyWith(liveTracking: false)),
      gateway: RecordingGateway(),
      table: table12,
    );
    await tapText(tester, 'Start exploring');
    await tapText(tester, 'All dishes');
    await tester.tap(find.byKey(const ValueKey('deck-add')));
    await settle(tester);
    await goToCheckout(tester);
    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester, ms: 2000);
    await tapText(tester, 'View order details');

    await tester.tap(find.byKey(const ValueKey('repeat-order')));
    await settle(tester);
    expect(find.text('Paneer Tikka'), findsWidgets);
    expect(find.text('Continue to review'), findsOneWidget);
  });
}
