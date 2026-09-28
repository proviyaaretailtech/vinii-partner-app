import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/presentation/pos/sell_routes.dart';
import 'package:vinii_partner/presentation/theme/staff_theme.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

/// A saved dine-in order: two biryanis, ₹504 as the server stored it.
final _order = PlacedOrder(
  id: 'o-1',
  version: 'v1',
  displayNo: 'ORD-7',
  status: PosStatus.sentToKitchen,
  serviceType: ServiceType.dineIn,
  createdAt: DateTime(2026, 9, 28, 12, 14),
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
);

Future<AppServices> _open(
  WidgetTester tester,
  FakeBackend backend, {
  String role = 'biller',
  Map<String, String> pendingKeys = const {},
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  final services = await testServices(backend);
  for (final e in pendingKeys.entries) {
    await services.prefs.setPendingKey(e.key, e.value);
  }
  services.session.membership = membershipAs(role);
  final router = GoRouter(
    initialLocation: '/sell/order/o-1',
    initialExtra: _order,
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

void main() {
  testWidgets('shows the stored bill, never a recomputation', (tester) async {
    await _open(tester, FakeBackend());

    expect(find.text('ORD-7'), findsWidgets);
    expect(find.text('In kitchen'), findsOneWidget);
    expect(find.textContaining('Table 12'), findsOneWidget);
    expect(find.text('SGST (2.5%)'), findsOneWidget);
    expect(find.text('₹504'), findsWidgets);
  });

  testWidgets('a UPI payment carries a saved key and ends "Paid"', (
    tester,
  ) async {
    final backend = FakeBackend();
    final services = await _open(tester, backend);

    await _tap(tester, find.text('UPI'));
    await tester.enterText(
      find.widgetWithText(TextField, 'UPI reference (optional)'),
      'UPI-4471',
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Charge ₹504'));

    final p = backend.payments.single;
    expect(p.orderId, 'o-1');
    expect(p.method, PaymentMethod.upi);
    expect(p.amount, 504);
    expect(p.key, isNotEmpty);
    // Answered: the key is released.
    expect(services.prefs.pendingKey('payment:o-1'), isNull);

    expect(find.text('Paid · ₹504 by UPI'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'New order'), findsOneWidget);
  });

  testWidgets('a payment key waiting from before is reused', (tester) async {
    final backend = FakeBackend();
    await _open(
      tester,
      backend,
      pendingKeys: {'payment:o-1': 'key-from-the-dropped-call'},
    );

    await _tap(tester, find.text('Charge ₹504'));

    expect(backend.payments.single.key, 'key-from-the-dropped-call');
    expect(backend.payments.single.method, PaymentMethod.cash);
  });

  testWidgets('cash shows the change to give back', (tester) async {
    await _open(tester, FakeBackend());

    final received = find.widgetWithText(TextField, 'Cash received (optional)');
    await tester.ensureVisible(received);
    await tester.enterText(received, '600');
    await tester.pumpAndSettle();

    expect(find.text('Change to return'), findsOneWidget);
    expect(find.text('₹96'), findsOneWidget);

    await tester.enterText(received, '500');
    await tester.pumpAndSettle();
    expect(find.text('Cash received is less than ₹504.'), findsOneWidget);
  });

  testWidgets('a part payment leaves the rest due', (tester) async {
    final backend = FakeBackend();
    await _open(tester, backend);

    final amount = find.widgetWithText(TextField, 'Amount');
    await tester.ensureVisible(amount);
    await tester.enterText(amount, '300');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Charge ₹300'));

    expect(backend.payments.single.amount, 300);
    expect(find.text('₹204'), findsWidgets);
    expect(find.textContaining('Paid ·'), findsNothing);
  });

  testWidgets('a role without payments sees no payment form', (tester) async {
    await _open(tester, FakeBackend(), role: 'captain');

    expect(find.text('Take payment'), findsNothing);
    expect(
      find.text('A biller or manager takes the payment for this order.'),
      findsOneWidget,
    );
  });
}
