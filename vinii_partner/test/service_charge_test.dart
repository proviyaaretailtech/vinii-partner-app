import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/application/sell_cart.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/data/local_prefs.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/presentation/pos/sell_routes.dart';
import 'package:vinii_partner/presentation/theme/staff_theme.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

const _tenPercent = BillCharges(serviceChargePercent: 10);

const _menu = MenuSnapshot(
  categories: [MenuCategory(id: 'c1', name: 'Biriyani')],
  items: [
    MenuItem(
      id: 'i1',
      name: 'Chicken Biryani',
      price: 240,
      categoryId: 'c1',
      foodType: FoodType.nonVeg,
    ),
  ],
);

/// A dine-in order for ₹1,000 of food with a 10% service charge, as the
/// server stored it: ₹1,000 + ₹100 service + ₹55 GST = ₹1,155.
PlacedOrder _orderWithService({double paid = 0, bool waived = false}) =>
    PlacedOrder(
      id: 'o-1',
      version: 'v1',
      displayNo: 'ORD-7',
      status: PosStatus.sentToKitchen,
      serviceType: ServiceType.dineIn,
      createdAt: DateTime(2026, 10, 2, 12, 14),
      lines: const [
        CartLine(itemId: 'i1', name: 'Chicken Biryani', unitPrice: 1000),
      ],
      bill: waived
          ? BillSummary.stored(
              itemTotal: 1000,
              gst: 50,
              payable: 1050,
              gstPercent: 5,
              waivedServiceCharge: 100,
            )
          : BillSummary.stored(
              itemTotal: 1000,
              serviceCharge: 100,
              gst: 55,
              payable: 1155,
              gstPercent: 5,
            ),
      table: const DiningTable(id: 't-12', label: '12'),
      paidAmount: paid,
    );

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 4000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
}

Future<AppServices> _open(
  WidgetTester tester,
  FakeBackend backend, {
  required String role,
  required String location,
  Object? extra,
  Future<void> Function(AppServices services)? before,
}) async {
  await _phone(tester);
  final services = await testServices(backend);
  services.session.membership = membershipAs(role);
  await before?.call(services);
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

/// Takeaway, one chicken biryani ×2, then Review.
Future<void> _toCheckout(WidgetTester tester) async {
  await tester.tap(find.text('Takeaway'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Chicken Biryani'));
  await tester.tap(find.text('Chicken Biryani'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Review'));
  await tester.pumpAndSettle();
}

void main() {
  group('the cart', () {
    Future<SellCart> cart({BillCharges charges = _tenPercent}) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend(menu: _menu);
      final c = SellCart(
        menuRepository: backend.menu,
        pos: backend.pos,
        prefs: await LocalPrefs.open(),
        orgId: 'org-1',
      )..charges = charges;
      c
        ..add(_menu.items.single)
        ..add(_menu.items.single);
      return c;
    }

    test(
      'removing the charge lowers the estimate and goes in the order',
      () async {
        final c = await cart();
        expect(c.estimate.serviceCharge, 48);
        expect(c.estimate.payable, 554);

        c.setServiceChargeWaived(true, reason: '  Regular guest ');
        expect(c.estimate.serviceCharge, 0);
        expect(c.estimate.payable, 504);
        expect(c.estimateWithService.serviceCharge, 48);
        expect(c.serviceChargeSaving, 50);

        final draft = c.draft(idempotencyKey: 'k');
        expect(draft.waiveServiceCharge, isTrue);
        expect(draft.waiveReason, 'Regular guest');

        c.setServiceChargeWaived(false);
        expect(c.estimate.payable, 554);
        expect(c.draft(idempotencyKey: 'k').waiveServiceCharge, isFalse);
        expect(c.draft(idempotencyKey: 'k').waiveReason, isNull);
      },
    );

    test(
      'a removal is meaningless without a service charge, so it is not sent',
      () async {
        final c = await cart(charges: BillCharges.defaults);
        c.setServiceChargeWaived(true, reason: 'x');
        expect(c.draft(idempotencyKey: 'k').waiveServiceCharge, isFalse);
        expect(c.estimate.payable, 504);
      },
    );

    test('a saved order starts the next one with the charge back on', () async {
      final c = await cart();
      c.setServiceChargeWaived(true);
      c.clear();
      expect(c.waiveServiceCharge, isFalse);
    });
  });

  group('the review screen', () {
    testWidgets(
      'a manager removes the charge, with a reason, and sends the order',
      (tester) async {
        final backend = FakeBackend(menu: _menu)..billCharges = _tenPercent;
        await _open(tester, backend, role: 'manager', location: '/sell');
        await _toCheckout(tester);

        expect(find.text('Service charge (10%)'), findsOneWidget);
        expect(find.text('₹48'), findsOneWidget);
        expect(find.text('₹554'), findsWidgets);

        await tester.tap(find.byKey(const Key('service-charge-remove')));
        await tester.pumpAndSettle();
        expect(
          find.text('Remove the service charge from this bill?'),
          findsOneWidget,
        );
        expect(
          find.text(
            'The guest will pay ₹50 less. This is recorded with your name.',
          ),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('service-charge-reason')),
          'Regular guest',
        );
        await tester.tap(
          find.byKey(const Key('service-charge-confirm-remove')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Removed'), findsOneWidget);
        expect(
          find.byKey(const Key('service-charge-add-back')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('service-charge-remove')), findsNothing);
        expect(find.text('₹554'), findsNothing);
        expect(find.text('₹504'), findsWidgets);

        await tester.tap(find.text('Save & hold'));
        await tester.pumpAndSettle();
        final draft = backend.placed.single;
        expect(draft.waiveServiceCharge, isTrue);
        expect(draft.waiveReason, 'Regular guest');
      },
    );

    testWidgets('keeping it closes the sheet and changes nothing', (
      tester,
    ) async {
      final backend = FakeBackend(menu: _menu)..billCharges = _tenPercent;
      await _open(tester, backend, role: 'org_owner', location: '/sell');
      await _toCheckout(tester);

      await tester.tap(find.byKey(const Key('service-charge-remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(find.text('Removed'), findsNothing);
      expect(find.byKey(const Key('service-charge-remove')), findsOneWidget);
    });

    testWidgets('Add back puts the charge on again', (tester) async {
      final backend = FakeBackend(menu: _menu)..billCharges = _tenPercent;
      await _open(tester, backend, role: 'manager', location: '/sell');
      await _toCheckout(tester);

      await tester.tap(find.byKey(const Key('service-charge-remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('service-charge-confirm-remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('service-charge-add-back')));
      await tester.pumpAndSettle();

      expect(find.text('Removed'), findsNothing);
      expect(find.byKey(const Key('service-charge-remove')), findsOneWidget);
      expect(find.text('₹554'), findsWidgets);

      await tester.tap(find.text('Save & hold'));
      await tester.pumpAndSettle();
      expect(backend.placed.single.waiveServiceCharge, isFalse);
    });

    testWidgets('a biller sees the charge but cannot remove it', (
      tester,
    ) async {
      final backend = FakeBackend(menu: _menu)..billCharges = _tenPercent;
      await _open(tester, backend, role: 'biller', location: '/sell');
      await _toCheckout(tester);

      expect(find.text('Service charge (10%)'), findsOneWidget);
      expect(find.byKey(const Key('service-charge-remove')), findsNothing);
    });

    testWidgets('no service charge, no row', (tester) async {
      final backend = FakeBackend(menu: _menu);
      await _open(tester, backend, role: 'manager', location: '/sell');
      await _toCheckout(tester);

      expect(find.textContaining('Service charge'), findsNothing);
    });
  });

  group('the payment step', () {
    testWidgets('a manager is asked once; Keep is remembered for that order', (
      tester,
    ) async {
      final backend = FakeBackend()..billCharges = _tenPercent;
      final services = await _open(
        tester,
        backend,
        role: 'manager',
        location: '/sell/order/o-1',
        extra: _orderWithService(),
      );

      expect(
        find.text('Service charge ₹100 is on this bill. Remove it?'),
        findsOneWidget,
      );
      expect(find.text('Service charge (10%)'), findsOneWidget);
      expect(
        find.byKey(const Key('payment-card')),
        findsOneWidget,
        reason: 'never blocks',
      );

      await tester.tap(find.byKey(const Key('service-charge-prompt-keep')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('service-charge-prompt')), findsNothing);
      expect(services.prefs.serviceChargeChoice('o-1'), 'keep');
      expect(find.byKey(const Key('service-charge-remove')), findsOneWidget);
      expect(backend.adjustments, isEmpty);
    });

    testWidgets('the answer is remembered after the app restarts', (
      tester,
    ) async {
      final backend = FakeBackend()..billCharges = _tenPercent;
      await _open(
        tester,
        backend,
        role: 'manager',
        location: '/sell/order/o-1',
        extra: _orderWithService(),
        before: (s) => s.prefs.setServiceChargeChoice('o-1', 'keep'),
      );
      expect(find.byKey(const Key('payment-card')), findsOneWidget);
      expect(find.byKey(const Key('service-charge-prompt')), findsNothing);
    });

    testWidgets(
      'Remove on the prompt asks, then tells the server who and why',
      (tester) async {
        final backend = FakeBackend()..billCharges = _tenPercent;
        final services = await _open(
          tester,
          backend,
          role: 'manager',
          location: '/sell/order/o-1',
          extra: _orderWithService(),
        );

        await tester.tap(find.byKey(const Key('service-charge-prompt-remove')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'The guest will pay ₹105 less. This is recorded with your name.',
          ),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('service-charge-reason')),
          'Birthday',
        );
        await tester.tap(
          find.byKey(const Key('service-charge-confirm-remove')),
        );
        await tester.pumpAndSettle();

        final call = backend.adjustments.single;
        expect(call.orderId, 'o-1');
        expect(call.waive, isTrue);
        expect(call.reason, 'Birthday');
        expect(call.version, 'v1');

        expect(find.text('Removed'), findsOneWidget);
        expect(find.text('Charge ₹1,050'), findsOneWidget);
        expect(find.byKey(const Key('service-charge-prompt')), findsNothing);
        expect(services.prefs.serviceChargeChoice('o-1'), 'remove');
      },
    );

    testWidgets('Add back on a removed charge asks the server to put it on', (
      tester,
    ) async {
      final backend = FakeBackend()..billCharges = _tenPercent;
      await _open(
        tester,
        backend,
        role: 'org_admin',
        location: '/sell/order/o-1',
        extra: _orderWithService(waived: true),
      );

      expect(find.text('Removed'), findsOneWidget);
      expect(
        find.text('Service charge ₹100 is on this bill. Remove it?'),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('service-charge-add-back')));
      await tester.pumpAndSettle();

      expect(backend.adjustments.single.waive, isFalse);
      expect(find.text('Removed'), findsNothing);
      expect(find.text('Charge ₹1,155'), findsOneWidget);
    });

    testWidgets(
      'until the database function exists, the dialog says so and nothing changes',
      (tester) async {
        final backend = FakeBackend()
          ..billCharges = _tenPercent
          ..failAdjustBill = const AppFailure(
            'Changing the service charge on a saved order needs a database update '
            'that is waiting for approval.',
            kind: FailureKind.notReady,
          );
        await _open(
          tester,
          backend,
          role: 'manager',
          location: '/sell/order/o-1',
          extra: _orderWithService(),
        );

        await tester.tap(find.byKey(const Key('service-charge-remove')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('service-charge-confirm-remove')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Not available yet'), findsOneWidget);
        expect(find.textContaining('waiting for approval'), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.text('Removed'), findsNothing);
        expect(find.text('Charge ₹1,155'), findsOneWidget);
      },
    );

    testWidgets('a biller sees the row, no prompt and no Remove', (
      tester,
    ) async {
      final backend = FakeBackend()..billCharges = _tenPercent;
      await _open(
        tester,
        backend,
        role: 'biller',
        location: '/sell/order/o-1',
        extra: _orderWithService(),
      );

      expect(find.text('Service charge (10%)'), findsOneWidget);
      expect(find.byKey(const Key('service-charge-prompt')), findsNothing);
      expect(find.byKey(const Key('service-charge-remove')), findsNothing);
      expect(find.byKey(const Key('payment-card')), findsOneWidget);
    });

    testWidgets('once money has been taken the charge stays', (tester) async {
      final backend = FakeBackend()..billCharges = _tenPercent;
      await _open(
        tester,
        backend,
        role: 'manager',
        location: '/sell/order/o-1',
        extra: _orderWithService(paid: 500),
      );

      expect(find.text('Service charge (10%)'), findsOneWidget);
      expect(find.byKey(const Key('service-charge-prompt')), findsNothing);
      expect(find.byKey(const Key('service-charge-remove')), findsNothing);
    });
  });
}
