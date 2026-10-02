import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/domain/storefront.dart';

import 'guest_runtime_test.dart'
    show
        RecordingGateway,
        noBudget,
        pumpGuest,
        settle,
        storefront,
        table12,
        tapText;

/// "Your order" is one screen: it used to be an order page, a review page and
/// a checkout page that said the same things three times.
void main() {
  Future<RecordingGateway> reachOrder(
    WidgetTester tester, {
    List<GuestServiceMode> modes = const [GuestServiceMode.dineIn],
    bool withTable = true,
  }) async {
    final gateway = RecordingGateway();
    await pumpGuest(
      tester,
      definition: storefront(features: noBudget, modes: modes),
      gateway: gateway,
      table: withTable ? table12 : null,
    );
    if (modes.length > 1) {
      await tester.tap(
        find.byKey(ValueKey('welcome-mode-${modes.first.name}')),
      );
      await settle(tester);
    } else {
      await tapText(tester, 'Start exploring');
    }
    await tapText(tester, 'All dishes');
    await tester.tap(find.byKey(const ValueKey('deck-add')));
    await settle(tester, ms: 1600);
    await tapText(tester, 'View order (1)');
    return gateway;
  }

  testWidgets('one screen holds the dishes, the note, the bill and Place '
      'order', (tester) async {
    await reachOrder(tester);
    expect(find.text('Your order'), findsOneWidget);
    expect(find.text('Paneer Tikka'), findsWidgets);
    expect(find.text('Special instructions (optional)'), findsOneWidget);
    expect(find.text('Estimated total'), findsOneWidget);
    expect(find.byKey(const ValueKey('place-order')), findsOneWidget);
    // The extra steps are gone.
    expect(find.text('Continue to review'), findsNothing);
    expect(find.text('Proceed to checkout'), findsNothing);
    expect(find.text('Review your order'), findsNothing);
  });

  testWidgets('the table is said once and never asked', (tester) async {
    await reachOrder(tester);
    expect(find.text('Table 12 • Dine-in'), findsOneWidget);
    expect(find.text('Table number'), findsNothing);
    expect(find.byKey(const ValueKey('qr-hint')), findsNothing);
  });

  testWidgets('without a table the guest is told to scan the QR code', (
    tester,
  ) async {
    final gateway = await reachOrder(tester, withTable: false);
    expect(find.byKey(const ValueKey('qr-hint')), findsOneWidget);
    expect(
      find.text('Scan the QR code on your table to order from it.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester);
    expect(gateway.drafts, isEmpty);
  });

  testWidgets('only the ways of ordering the restaurant offers are a switch '
      'at the top', (tester) async {
    final gateway = await reachOrder(
      tester,
      modes: const [GuestServiceMode.dineIn, GuestServiceMode.takeaway],
    );
    expect(find.byKey(const ValueKey('mode-dineIn')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-takeaway')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-delivery')), findsNothing);
    expect(find.text('Table 12'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mode-takeaway')));
    await settle(tester);
    expect(
      find.text("We'll call your order number at the counter."),
      findsOneWidget,
    );
    // A takeaway order has no table.
    expect(find.textContaining('Table 12'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester, ms: 1500);
    final d = gateway.drafts.single;
    expect(d.serviceType, ServiceType.takeaway);
    expect(d.table, isNull);
  });

  testWidgets('a pre-order cannot be placed until a pickup time is chosen', (
    tester,
  ) async {
    final gateway = await reachOrder(
      tester,
      modes: const [GuestServiceMode.dineIn, GuestServiceMode.preOrder],
    );
    await tester.tap(find.byKey(const ValueKey('mode-preOrder')));
    await settle(tester);
    expect(find.text('Choose a pickup time'), findsOneWidget);
    expect(find.text('Choose a pickup time first.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester);
    expect(gateway.drafts, isEmpty);
  });
}
