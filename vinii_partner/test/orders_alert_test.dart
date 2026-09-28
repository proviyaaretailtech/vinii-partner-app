import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinii_partner/app/app.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/domain/delivery_order.dart';
import 'package:vinii_partner/domain/staff.dart';
import 'package:vinii_partner/presentation/orders/orders_routes.dart';
import 'package:vinii_partner/presentation/theme/staff_theme.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

DeliveryOrder _order({Duration left = const Duration(seconds: 50)}) =>
    DeliveryOrder(
      id: 'd-1',
      displayNo: 'OL-00031',
      status: DeliveryStatus.placed,
      version: 'v1',
      placedAt: DateTime.now().subtract(const Duration(seconds: 10)),
      deadline: DateTime.now().add(left),
      customerName: 'Rahul Patil',
      area: 'Shivaji Nagar',
      notes: 'Ring the bell twice',
      items: const [
        DeliveryLine(
          name: 'Paneer Tikka',
          qty: 1,
          price: 220,
          notes: 'Less spicy',
        ),
        DeliveryLine(name: 'Butter Naan', qty: 3, price: 40),
      ],
      subtotal: 340,
      gst: 17,
      deliveryFee: 30,
      total: 387,
    );

/// A manager's phone with one order waiting in the alert queue, and a tiny
/// router: a home page, and the alert route pushed on top as the shell does.
Future<(AppServices, GoRouter)> _open(
  WidgetTester tester,
  FakeBackend backend, {
  String role = 'manager',
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  final services = await testServices(backend);
  await services.prefs.setRingEnabled(false);
  services.session.membership = membershipAs(role);
  await services.inbox.refresh(InboxTab.fresh);
  expect(services.inbox.alertQueue.map((o) => o.id), ['d-1']);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
      ),
      ...ordersRootRoutes,
    ],
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
  // Like the home shell: push, and let the alert close itself.
  unawaited(router.push<void>('/alert/d-1'));
  await _pump(tester);
  return (services, router);
}

/// The countdown ring ticks forever: pump fixed steps, never settle.
Future<void> _pump(WidgetTester tester, [int steps = 8]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('accepting with a prep time tells the server and closes', (
    tester,
  ) async {
    final backend = FakeBackend()..deliveries.add(_order());
    final (services, _) = await _open(tester, backend);

    expect(find.text('NEW ORDER · One Local'), findsOneWidget);
    expect(find.text('OL-00031'), findsOneWidget);
    expect(find.textContaining('Rahul · Shivaji Nagar'), findsOneWidget);
    expect(find.text('Less spicy'), findsOneWidget);
    expect(find.text('Ring the bell twice'), findsOneWidget);
    expect(find.text('₹387'), findsOneWidget);
    expect(find.text('Accept · 20 min'), findsOneWidget);

    await tester.tap(find.text('30 min'));
    await tester.pump();
    await tester.tap(find.text('Accept · 30 min'));
    await _pump(tester);

    final saved = backend.deliveries.single;
    expect(saved.status, DeliveryStatus.accepted);
    expect(saved.prepMinutes, 30);
    expect(services.inbox.alertQueue, isEmpty);
    expect(find.text('NEW ORDER · One Local'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Accepted OL-00031. Ready in 30 min.'), findsOneWidget);
  });

  testWidgets('rejecting asks for a reason and sends it', (tester) async {
    final backend = FakeBackend()..deliveries.add(_order());
    await _open(tester, backend);

    await tester.tap(find.text('Reject'));
    await _pump(tester);
    expect(find.text('Reject this order?'), findsOneWidget);
    await tester.tap(find.text('Kitchen busy'));
    await tester.pump();
    await tester.tap(find.text('Reject order'));
    await _pump(tester);

    final saved = backend.deliveries.single;
    expect(saved.status, DeliveryStatus.cancelled);
    expect(saved.cancelReason, 'Restaurant: Kitchen busy');
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('NEW ORDER · One Local'), findsNothing);
  });

  testWidgets('answered on another phone: says so, then closes once', (
    tester,
  ) async {
    final backend = FakeBackend()..deliveries.add(_order());
    final (services, _) = await _open(tester, backend);

    // Another phone accepted it; the next poll drops it from New.
    backend.deliveries[0] = backend.deliveries[0].copyWith(
      status: DeliveryStatus.accepted,
      version: 'v2',
    );
    await services.inbox.refresh(InboxTab.fresh);
    await tester.pump();
    expect(find.text('Answered on another phone'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await _pump(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Answered on another phone'), findsNothing);
  });

  testWidgets("time's up: the customer is told, the alert closes", (
    tester,
  ) async {
    final backend = FakeBackend()
      ..deliveries.add(_order(left: const Duration(seconds: -1)));
    final (services, _) = await _open(tester, backend);

    expect(find.text("Time's up"), findsOneWidget);
    expect(
      find.text("The customer is told the restaurant didn't respond."),
      findsOneWidget,
    );
    expect(services.inbox.alertQueue, isEmpty);

    await tester.pump(const Duration(seconds: 2));
    await _pump(tester);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('silence stops the ring for this order and closes', (
    tester,
  ) async {
    final backend = FakeBackend()..deliveries.add(_order());
    final (services, _) = await _open(tester, backend);

    await tester.tap(find.byTooltip('Silence'));
    await _pump(tester);

    expect(services.inbox.alertQueue, isEmpty);
    expect(backend.deliveries.single.status, DeliveryStatus.placed);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a conflict (someone was faster) closes the alert', (
    tester,
  ) async {
    final backend = FakeBackend()..deliveries.add(_order());
    await _open(tester, backend);

    // The server's copy moved on without this phone's poll seeing it.
    backend.deliveries[0] = backend.deliveries[0].copyWith(version: 'v9');
    await tester.tap(find.text('Accept · 20 min'));
    await _pump(tester);

    expect(
      find.text('This order was already changed on another phone.'),
      findsOneWidget,
    );
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('in the real app: the poll rings, the shell opens the alert, '
      'accepting returns to Orders', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    final backend = FakeBackend(
      user: const StaffUser(id: 'u-1', email: 'owner@example.com'),
      memberships: [membershipAs('manager')],
    )..deliveries.add(_order());
    final services = await testServices(backend);
    await services.prefs.setRingEnabled(false);

    await tester.pumpWidget(ViniiPartnerApp(services: services));
    await _pump(tester, 12);

    expect(find.text('NEW ORDER · One Local'), findsOneWidget);
    await tester.tap(find.text('Accept · 20 min'));
    await _pump(tester, 12);

    expect(find.text('NEW ORDER · One Local'), findsNothing);
    expect(backend.deliveries.single.status, DeliveryStatus.accepted);
    expect(find.text('Test Kitchen'), findsOneWidget);
    expect(find.text('No new orders'), findsOneWidget);

    // Stops the poller and the ring, which outlive the widget tree.
    await services.session.signOut();
    await _pump(tester);
  });
}
