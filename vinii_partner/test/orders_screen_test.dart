import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/domain/delivery_order.dart';
import 'package:vinii_partner/presentation/orders/orders_routes.dart';
import 'package:vinii_partner/presentation/orders/orders_screen.dart';
import 'package:vinii_partner/presentation/theme/staff_theme.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

DeliveryOrder _order({
  String id = 'd-1',
  String displayNo = 'OL-00024',
  DeliveryStatus status = DeliveryStatus.placed,
}) => DeliveryOrder(
  id: id,
  displayNo: displayNo,
  status: status,
  version: 'v1',
  placedAt: DateTime.now().subtract(const Duration(minutes: 4)),
  deadline: DateTime.now().add(const Duration(seconds: 50)),
  customerName: 'Priya Deshmukh',
  customerPhone: status == DeliveryStatus.placed ? null : '98220 12345',
  area: 'Ganesh Nagar',
  items: const [
    DeliveryLine(name: 'Chicken Biryani', qty: 2, price: 240),
    DeliveryLine(name: 'Coke', qty: 1, price: 40, notes: 'Chilled'),
  ],
  subtotal: 520,
  gst: 26,
  deliveryFee: 30,
  total: 576,
);

Future<AppServices> _services(
  WidgetTester tester,
  FakeBackend backend, {
  String role = 'manager',
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Haptics are a platform call that never answers inside a widget test.
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  final services = await testServices(backend);
  await services.prefs.setRingEnabled(false);
  services.session.membership = membershipAs(role);
  return services;
}

/// The Countdown rings tick forever, so tests pump fixed durations.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('the New tab shows an order from the inbox', (tester) async {
    final backend = FakeBackend()..deliveries.add(_order());
    final services = await _services(tester, backend);

    await tester.pumpWidget(wrapScreen(services, const OrdersScreen()));
    await _settle(tester);

    expect(find.text('Test Kitchen'), findsOneWidget);
    expect(find.text('Accepting orders'), findsOneWidget);
    expect(find.text('OL-00024'), findsOneWidget);
    expect(find.textContaining('Priya · Ganesh Nagar'), findsOneWidget);
    expect(find.text('2 × Chicken Biryani, 1 × Coke'), findsOneWidget);
    expect(find.text('₹576'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);

    // The poll put it in the alert queue (a manager may accept).
    expect(services.inbox.alertQueue.single.id, 'd-1');
    await services.ring.stop();
  });

  testWidgets('each tab says plainly when it is empty', (tester) async {
    final services = await _services(tester, FakeBackend());

    await tester.pumpWidget(wrapScreen(services, const OrdersScreen()));
    await _settle(tester);

    expect(find.text('No new orders'), findsOneWidget);
    expect(
      find.text('When a customer orders, this phone rings.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Preparing'));
    await _settle(tester);
    expect(find.text('Nothing cooking right now'), findsOneWidget);

    await tester.tap(find.text('Past'));
    await _settle(tester);
    expect(find.text('Orders from the last 3 days show here.'), findsOneWidget);
  });

  testWidgets('without a One Local server the tab explains why', (
    tester,
  ) async {
    final backend = FakeBackend()..inboxAvailable = false;
    final services = await _services(tester, backend);

    await tester.pumpWidget(wrapScreen(services, const OrdersScreen()));
    await _settle(tester);

    expect(find.text('Delivery orders are not connected'), findsOneWidget);
    expect(find.text('No One Local server in this build.'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('missed orders and a paused outlet are shown', (tester) async {
    final backend = FakeBackend()
      ..outletStatus = const OutletStatus(accepting: false, missedInARow: 2);
    final services = await _services(tester, backend);

    await tester.pumpWidget(wrapScreen(services, const OrdersScreen()));
    await _settle(tester);

    expect(find.text('Paused'), findsOneWidget);
    expect(
      find.text(
        '2 orders missed in a row. After 3, One Local pauses the restaurant.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pausing asks for how long and tells One Local', (tester) async {
    final backend = FakeBackend();
    final services = await _services(tester, backend);

    await tester.pumpWidget(wrapScreen(services, const OrdersScreen()));
    await _settle(tester);

    await tester.tap(find.byType(Switch));
    await _settle(tester);
    expect(find.text('Pause new orders'), findsOneWidget);

    await tester.tap(find.text('1 hour'));
    await _settle(tester);

    expect(backend.outletStatus.accepting, isFalse);
    expect(backend.outletStatus.backAt, isNotNull);
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('a kitchen login sees the state but cannot switch it', (
    tester,
  ) async {
    final services = await _services(tester, FakeBackend(), role: 'kitchen');

    await tester.pumpWidget(wrapScreen(services, const OrdersScreen()));
    await _settle(tester);

    expect(find.text('Accepting orders'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('an order card opens the order, which moves it on', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..deliveries.add(_order(status: DeliveryStatus.accepted));
    final services = await _services(tester, backend);
    final router = GoRouter(
      initialLocation: '/orders',
      routes: ordersBranchRoutes,
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
    await _settle(tester);

    await tester.tap(find.text('Preparing'));
    await _settle(tester);
    await tester.tap(find.text('OL-00024'));
    await _settle(tester);

    // Detail: phone, note and the slide for the next step.
    expect(find.text('98220 12345'), findsOneWidget);
    expect(find.text('Chilled'), findsOneWidget);
    expect(find.text('Mark ready'), findsOneWidget);

    await tester.drag(
      find.byIcon(Icons.arrow_forward_rounded),
      const Offset(400, 0),
    );
    await _settle(tester);

    expect(backend.deliveries.single.status, DeliveryStatus.packed);
    expect(find.text('Out for delivery'), findsOneWidget);
  });
}
