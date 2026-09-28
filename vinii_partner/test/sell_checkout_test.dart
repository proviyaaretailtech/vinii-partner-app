import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/pos_order.dart';
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
      isAvailable: false,
    ),
  ],
);

const _notReady = AppFailure(
  'Taking orders from the phone needs the POS order functions, a database '
  'update waiting for approval. Until then, take this order at the POS counter.',
  kind: FailureKind.notReady,
);

Future<AppServices> _open(
  WidgetTester tester,
  FakeBackend backend, {
  String role = 'biller',
  String location = '/sell',
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  final services = await testServices(backend);
  services.session.membership = membershipAs(role);
  final router = GoRouter(initialLocation: location, routes: sellBranchRoutes);
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

void main() {
  testWidgets('the menu comes from the repository; taps build the cart', (
    tester,
  ) async {
    final backend = FakeBackend(menu: _menu);
    await _open(tester, backend);

    expect(find.text('Chicken Biryani'), findsOneWidget);
    expect(find.text('Veg Thali'), findsOneWidget);
    expect(find.text('Sold out'), findsOneWidget);
    expect(find.text('Biriyani'), findsOneWidget);

    await tester.tap(find.text('Chicken Biryani'));
    await tester.tap(find.text('Chicken Biryani'));
    await tester.tap(find.text('Veg Thali')); // sold out: not added
    await tester.pumpAndSettle();

    expect(find.text('2 items · ₹504'), findsOneWidget);
    expect(find.text('(estimated)'), findsOneWidget);

    // Category chips filter the grid.
    await tester.tap(find.text('Thalis'));
    await tester.pumpAndSettle();
    expect(find.text('Chicken Biryani'), findsNothing);
    expect(find.text('Veg Thali'), findsOneWidget);
  });

  testWidgets('an empty menu says where to add dishes', (tester) async {
    await _open(tester, FakeBackend());
    expect(find.text('No menu items yet'), findsOneWidget);
    expect(
      find.text('No menu items yet. Add dishes in the Menu tab.'),
      findsOneWidget,
    );
  });

  testWidgets('dine-in needs a table, picked from the restaurant\'s tables', (
    tester,
  ) async {
    final backend = FakeBackend(
      menu: _menu,
      tables: const [
        DiningTable(id: 't-11', label: '11', occupied: true),
        DiningTable(id: 't-12', label: '12', seats: 6),
      ],
    );
    final services = await _open(tester, backend, role: 'captain');

    await tester.tap(find.text('Chicken Biryani'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a table for this dine-in order.'), findsOneWidget);
    final send = find.ancestor(
      of: find.textContaining('Send to kitchen'),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.tap(find.text('Choose table'));
    await tester.pumpAndSettle();
    expect(find.text('Occupied'), findsOneWidget);
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    expect(find.text('Table 12'), findsOneWidget);
    await tester.tap(find.textContaining('Send to kitchen'));
    await tester.pumpAndSettle();

    final draft = backend.placed.single;
    expect(draft.table?.id, 't-12');
    expect(draft.guestCount, 2);
    expect(draft.placedBy, PlacedBy.captain);
    expect(draft.fireKitchenTicket, isTrue);
    expect(find.text('ORD-1'), findsWidgets);
    expect(services.prefs.pendingKey('order:org-1'), isNull);
  });

  testWidgets('"not ready" is shown honestly; the cart and key are kept, '
      'and the retry reuses the key', (tester) async {
    final backend = FakeBackend(menu: _menu)..failPlaceOrder = _notReady;
    final services = await _open(tester, backend);

    // Takeaway, two biryanis, a customer name.
    await tester.tap(find.text('Takeaway'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chicken Biryani'));
    await tester.tap(find.text('Chicken Biryani'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(
      find.text('Estimated. The POS confirms the final bill.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Customer name (optional)'),
      'Asha',
    );
    await tester.tap(find.text('Save & hold'));
    await tester.pumpAndSettle();

    expect(find.text('Not available yet'), findsOneWidget);
    expect(find.text(_notReady.message), findsOneWidget);
    final key = services.prefs.pendingKey('order:org-1');
    expect(key, isNotNull);
    expect(backend.placed, isEmpty);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // Still on checkout, nothing lost.
    expect(find.text('Review order'), findsOneWidget);
    expect(find.text('Chicken Biryani'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);

    // The database is ready now: the retry carries the same key.
    backend.failPlaceOrder = null;
    await tester.tap(find.text('Save & hold'));
    await tester.pumpAndSettle();

    final draft = backend.placed.single;
    expect(draft.idempotencyKey, key);
    expect(draft.serviceType, ServiceType.takeaway);
    expect(draft.fireKitchenTicket, isFalse);
    expect(draft.customerName, 'Asha');
    expect(draft.lines.single.qty, 2);
    expect(draft.placedBy, PlacedBy.pos);
    expect(services.prefs.pendingKey('order:org-1'), isNull);

    // The saved order shows the server's figures.
    expect(find.text('ORD-1'), findsWidgets);
    expect(find.text('₹504'), findsWidgets);
  });
}
