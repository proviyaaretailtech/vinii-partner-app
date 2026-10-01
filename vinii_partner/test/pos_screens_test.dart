import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/presentation/pos/payment_card.dart';
import 'package:vinii_partner/presentation/pos/sell_routes.dart';
import 'package:vinii_partner/presentation/theme/staff_theme.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

const _menu = MenuSnapshot(
  categories: [
    MenuCategory(id: 'c1', name: 'Biriyani'),
    MenuCategory(id: 'c2', name: 'Thalis', sortOrder: 1),
  ],
  items: [
    MenuItem(
      id: 'i1',
      name: 'Chicken Biryani',
      price: 240,
      categoryId: 'c1',
      foodType: FoodType.nonVeg,
    ),
    MenuItem(
      id: 'i2',
      name: 'Veg Thali',
      price: 180,
      categoryId: 'c2',
      foodType: FoodType.veg,
    ),
    MenuItem(
      id: 'i3',
      name: 'Paneer Tikka',
      price: 220,
      categoryId: 'c2',
      foodType: FoodType.veg,
      sortOrder: 1,
    ),
  ],
);

/// ₹504 as the server stored it: two biryanis, 5% GST.
PlacedOrder _order({
  double paid = 0,
  PosStatus status = PosStatus.sentToKitchen,
}) => PlacedOrder(
  id: 'o-1',
  version: 'v1',
  displayNo: 'ORD-7',
  status: status,
  serviceType: ServiceType.dineIn,
  createdAt: DateTime(2026, 10, 2, 12, 14),
  lines: const [
    CartLine(itemId: 'i1', name: 'Chicken Biryani', unitPrice: 240, qty: 2),
  ],
  bill: BillSummary.stored(
    itemTotal: 480,
    gst: 24,
    payable: 504,
    gstPercent: 5,
  ),
  table: const DiningTable(id: 't-12', label: '12'),
  paidAmount: paid,
);

Future<AppServices> _open(
  WidgetTester tester,
  FakeBackend backend, {
  String role = 'biller',
  String location = '/sell',
  Object? extra,
  Size size = const Size(1170, 4000),
  double ratio = 3,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  final services = await testServices(backend);
  services.session.membership = membershipAs(role);
  final router = GoRouter(
    initialLocation: location,
    initialExtra: extra,
    routes: sellBranchRoutes,
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
  return services;
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Finder f, String text) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.enterText(f, text);
  await tester.pumpAndSettle();
}

void main() {
  group('the menu on a phone', () {
    testWidgets('a dish on the order shows − 2 + on its picture', (
      tester,
    ) async {
      await _open(
        tester,
        FakeBackend(menu: _menu),
        size: const Size(1170, 2532),
      );

      await tester.tap(find.text('Chicken Biryani'));
      await tester.pumpAndSettle();
      expect(find.text('1 item · ₹252'), findsOneWidget);
      expect(find.bySemanticsLabel('Less'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('More'));
      await tester.pumpAndSettle();
      expect(find.text('2 items · ₹504'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Less'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Less'));
      await tester.pumpAndSettle();
      expect(find.text('(estimated)'), findsNothing, reason: 'order is empty');
      expect(find.bySemanticsLabel('Less'), findsNothing);
    });

    testWidgets('search narrows the dishes, and says when nothing matches', (
      tester,
    ) async {
      await _open(
        tester,
        FakeBackend(menu: _menu),
        size: const Size(1170, 2532),
      );

      await tester.enterText(find.byKey(const Key('sell-search')), 'paneer');
      await tester.pumpAndSettle();
      expect(find.text('Paneer Tikka'), findsOneWidget);
      expect(find.text('Chicken Biryani'), findsNothing);

      await tester.enterText(find.byKey(const Key('sell-search')), 'sushi');
      await tester.pumpAndSettle();
      expect(find.text('No dishes match'), findsOneWidget);
    });
  });

  group('the POS on a wide screen', () {
    Future<(AppServices, FakeBackend)> wide(WidgetTester tester) async {
      final backend = FakeBackend(
        menu: _menu,
        tables: const [DiningTable(id: 't-12', label: '12', seats: 6)],
      );
      final services = await _open(
        tester,
        backend,
        size: const Size(1280, 800),
        ratio: 1,
      );
      return (services, backend);
    }

    testWidgets('the menu and the order sit side by side; no Review step', (
      tester,
    ) async {
      await wide(tester);

      expect(
        find.text('Current order'),
        findsNothing,
        reason: 'nothing on the order yet',
      );
      expect(find.text('The order is empty'), findsOneWidget);
      expect(find.byKey(const Key('sell-review')), findsNothing);

      await tester.tap(find.text('Chicken Biryani'));
      await tester.tap(find.text('Veg Thali'));
      await tester.pumpAndSettle();

      expect(find.text('Current order'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
      expect(find.byKey(const Key('sell-review')), findsNothing);
      // The menu is on the left, the order on the right.
      final menu = tester.getTopLeft(find.text('Chicken Biryani').first);
      final ticket = tester.getTopLeft(find.text('Current order'));
      expect(menu.dx, lessThan(880), reason: 'the menu is on the left');
      expect(
        ticket.dx,
        greaterThanOrEqualTo(880),
        reason: 'the order is on the right',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sending from the order pane places it and opens the payment', (
      tester,
    ) async {
      final (_, backend) = await wide(tester);

      await tester.tap(find.text('Chicken Biryani'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Send to kitchen'));
      await tester.pumpAndSettle();

      expect(backend.placed.single.table?.id, 't-12');
      expect(find.text('ORD-1'), findsWidgets);
      expect(find.byKey(const Key('payment-card')), findsOneWidget);
      // Payment is the right-hand pane, the order the left.
      final left = tester.getTopLeft(find.text('Chicken Biryani').first);
      final right = tester.getTopLeft(find.byKey(const Key('payment-card')));
      expect(right.dx, greaterThan(left.dx + 400));
    });

    testWidgets('Clear asks first, then empties the order', (tester) async {
      await wide(tester);
      await tester.tap(find.text('Chicken Biryani'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ticket-clear')));
      await tester.pumpAndSettle();
      expect(find.text('Clear this order?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(find.text('Current order'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ticket-clear')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear order'));
      await tester.pumpAndSettle();
      expect(find.text('The order is empty'), findsOneWidget);
    });
  });

  group('taking payment', () {
    testWidgets(
      'cash: note shortcuts add up, Exact fills it, change is shown',
      (tester) async {
        await _open(
          tester,
          FakeBackend(),
          location: '/sell/order/o-1',
          extra: _order(),
        );

        await _tap(tester, find.byKey(const Key('cash-500')));
        expect(find.text('Cash received is less than ₹504.'), findsOneWidget);
        expect(find.text('Change to return'), findsNothing);
        await _tap(tester, find.byKey(const Key('cash-100')));
        expect(find.text('Change to return'), findsOneWidget);
        expect(find.text('₹96'), findsOneWidget);
        await _tap(tester, find.byKey(const Key('cash-50')));
        final received = tester.widget<TextField>(
          find.byKey(const Key('pay-received')),
        );
        expect(received.controller!.text, '650');
        expect(find.text('₹146'), findsOneWidget);

        await _tap(tester, find.byKey(const Key('cash-exact')));
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('pay-received')))
              .controller!
              .text,
          '504',
        );
        expect(find.text('Change to return'), findsOneWidget);
        // Exactly enough: nothing to give back.
      },
    );

    testWidgets(
      'after cash, the change to give back stays on the confirmation',
      (tester) async {
        final backend = FakeBackend();
        await _open(
          tester,
          backend,
          location: '/sell/order/o-1',
          extra: _order(),
        );

        await _enter(tester, find.byKey(const Key('pay-received')), '600');
        await _tap(tester, find.byKey(const Key('pay-charge')));

        expect(find.byKey(const Key('payment-success')), findsOneWidget);
        expect(find.text('Paid · ₹504 by Cash'), findsOneWidget);
        expect(find.text('Give back change'), findsOneWidget);
        expect(find.byKey(const Key('success-change')), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('success-change'))).data,
          '₹96',
        );
        expect(
          find.byKey(const Key('payment-card')),
          findsNothing,
          reason: 'a paid bill cannot be paid twice',
        );
      },
    );

    testWidgets('the confirmation does not animate when motion is reduced', (
      tester,
    ) async {
      await _open(
        tester,
        FakeBackend(),
        location: '/sell/order/o-1',
        extra: _order(),
      );
      await _tap(tester, find.byKey(const Key('pay-charge')));
      expect(find.byKey(const Key('payment-success')), findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byKey(const Key('payment-success')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
    });

    testWidgets('split: two parts that must cover what is due', (tester) async {
      final backend = FakeBackend();
      final services = await _open(
        tester,
        backend,
        location: '/sell/order/o-1',
        extra: _order(),
      );

      await _tap(tester, find.byKey(const Key('pay-split')));
      expect(find.byKey(const Key('split-part-1')), findsOneWidget);
      expect(find.byKey(const Key('split-part-2')), findsOneWidget);
      expect(find.text('Short by'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('pay-charge')))
            .onPressed,
        isNull,
      );

      await _enter(tester, find.byKey(const Key('split-amount-1')), '300');
      await _enter(tester, find.byKey(const Key('split-amount-2')), '100');
      expect(find.text('Short by'), findsOneWidget);
      expect(find.text('₹104'), findsWidgets);

      await _enter(tester, find.byKey(const Key('split-amount-2')), '300');
      expect(find.text('Over by'), findsOneWidget);
      expect(find.text('₹96'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('pay-charge')))
            .onPressed,
        isNull,
        reason: 'over is refused, not absorbed',
      );

      await _tap(tester, find.byKey(const Key('split-rest')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('split-amount-2')))
            .controller!
            .text,
        '204',
      );
      expect(find.text('Covered'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('pay-charge')));

      expect(backend.payments.map((p) => (p.method, p.amount)), [
        (PaymentMethod.cash, 300.0),
        (PaymentMethod.upi, 204.0),
      ]);
      expect(backend.payments[0].key, isNot(backend.payments[1].key));
      expect(find.text('Paid · ₹504 by Cash + UPI'), findsOneWidget);
      expect(services.prefs.pendingKey('payment:o-1'), isNull);
      expect(services.prefs.pendingKey('payment:o-1:2'), isNull);
    });

    testWidgets(
      'split: if part 2 does not go through, part 1 stays and part 2 can be retried',
      (tester) async {
        final backend = FakeBackend()
          ..failPaymentOnCall[2] = const AppFailure(
            'You are offline. Check the connection and try again.',
            kind: FailureKind.offline,
          );
        final services = await _open(
          tester,
          backend,
          location: '/sell/order/o-1',
          extra: _order(),
        );

        await _tap(tester, find.byKey(const Key('pay-split')));
        await _enter(tester, find.byKey(const Key('split-amount-1')), '300');
        await _tap(tester, find.byKey(const Key('split-rest')));
        await _tap(tester, find.byKey(const Key('pay-charge')));

        expect(backend.payments.single.amount, 300);
        expect(find.byKey(const Key('split-retry')), findsOneWidget);
        expect(
          find.textContaining('The first part is recorded'),
          findsOneWidget,
        );
        expect(find.textContaining('UPI ₹204'), findsOneWidget);
        expect(find.textContaining('₹204'), findsWidgets);
        final kept = services.prefs.pendingKey('payment:o-1:2');
        expect(kept, isNotNull, reason: 'an offline answer keeps the key');

        await _tap(tester, find.byKey(const Key('split-retry')));

        expect(backend.payments.length, 2);
        expect(backend.payments.last.amount, 204);
        expect(backend.payments.last.key, kept, reason: 'the same key again');
        expect(find.text('Paid · ₹504 by Cash + UPI'), findsOneWidget);
        expect(services.prefs.pendingKey('payment:o-1:2'), isNull);
      },
    );

    testWidgets(
      'split: "take it another way" goes back to a normal payment of what is left',
      (tester) async {
        final backend = FakeBackend()
          ..failPaymentOnCall[2] = const AppFailure(
            'You are offline.',
            kind: FailureKind.offline,
          );
        await _open(
          tester,
          backend,
          location: '/sell/order/o-1',
          extra: _order(),
        );

        await _tap(tester, find.byKey(const Key('pay-split')));
        await _enter(tester, find.byKey(const Key('split-amount-1')), '300');
        await _tap(tester, find.byKey(const Key('split-rest')));
        await _tap(tester, find.byKey(const Key('pay-charge')));
        await _tap(tester, find.byKey(const Key('split-forget')));

        expect(find.byKey(const Key('split-retry')), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('pay-amount')))
              .controller!
              .text,
          '204',
        );
        expect(find.text('Charge ₹204'), findsOneWidget);
      },
    );

    testWidgets('methods are named once each, in the order taken', (
      tester,
    ) async {
      expect(
        methodsLabel(const [
          PaymentPart(PaymentMethod.cash, 100),
          PaymentPart(PaymentMethod.upi, 100),
          PaymentPart(PaymentMethod.cash, 50),
        ]),
        'Cash + UPI',
      );
    });

    testWidgets(
      'on a wide screen the order is on the left and the payment on the right',
      (tester) async {
        await _open(
          tester,
          FakeBackend(),
          location: '/sell/order/o-1',
          extra: _order(),
          size: const Size(1280, 800),
          ratio: 1,
        );
        final summary = tester.getTopLeft(find.text('Chicken Biryani'));
        final pay = tester.getTopLeft(find.byKey(const Key('payment-card')));
        expect(pay.dx, greaterThan(summary.dx + 500));
        expect(
          pay.dy,
          lessThan(300),
          reason: 'no scrolling to find the button',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('open orders', () {
    testWidgets('a part-paid order shows what is still due', (tester) async {
      final backend = FakeBackend(menu: _menu)
        ..openOrderRows = [_order(paid: 300)];
      await _open(tester, backend, size: const Size(1170, 2532));

      await tester.tap(find.byTooltip('Open orders'));
      await tester.pumpAndSettle();

      expect(find.text('ORD-7'), findsOneWidget);
      expect(find.text('Due ₹204'), findsOneWidget);
      expect(find.textContaining('Table 12'), findsOneWidget);
    });
  });
}
