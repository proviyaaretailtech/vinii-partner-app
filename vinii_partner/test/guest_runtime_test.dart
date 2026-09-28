import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/application/guest_gateway.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/domain/storefront.dart';
import 'package:vinii_partner/presentation/guest/guest_app.dart';
import 'package:vinii_partner/presentation/theme/guest_theme.dart';

/// Records every draft; can be told to fail the next place().
class RecordingGateway extends GuestOrderGateway {
  RecordingGateway({this.preview = false});

  final bool preview;
  final drafts = <PosOrderDraft>[];
  AppFailure? failNext;
  final _updates = StreamController<PlacedOrder>.broadcast();

  @override
  bool get isPreview => preview;

  @override
  Future<BillCharges> charges() async => BillCharges.defaults;

  @override
  Future<PlacedOrder> place(PosOrderDraft draft) async {
    drafts.add(draft);
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    return PlacedOrder(
      id: 'o-${drafts.length}',
      version: 'v1',
      displayNo: 'VB${1250 + drafts.length}',
      status: PosStatus.sentToKitchen,
      serviceType: draft.serviceType,
      createdAt: DateTime(2026, 9, 28, 12, 14),
      lines: draft.lines,
      bill: draft.bill,
      table: draft.table,
      scheduledFor: draft.scheduledFor,
      placedBy: draft.placedBy,
    );
  }

  @override
  Stream<PlacedOrder> watch(PlacedOrder order) => _updates.stream;
}

const menu = MenuSnapshot(
  categories: [
    MenuCategory(id: 'c-mains', name: 'Mains', sortOrder: 1),
    MenuCategory(id: 'c-dess', name: 'Desserts', sortOrder: 2),
  ],
  items: [
    MenuItem(
      id: 'i-paneer',
      name: 'Paneer Tikka',
      price: 600,
      categoryId: 'c-mains',
      foodType: FoodType.veg,
      isRecommended: true,
      prepMinutes: 20,
    ),
    MenuItem(
      id: 'i-biryani',
      name: 'Chicken Biryani',
      price: 400,
      categoryId: 'c-mains',
      foodType: FoodType.nonVeg,
      sortOrder: 1,
    ),
    MenuItem(
      id: 'i-brownie',
      name: 'Brownie',
      price: 150,
      categoryId: 'c-dess',
    ),
  ],
);

StorefrontDefinition storefront({
  GuestFeatures features = const GuestFeatures(),
  List<GuestServiceMode> modes = const [GuestServiceMode.dineIn],
  StorefrontBrand brand = const StorefrontBrand(displayName: 'Test Bistro'),
}) => StorefrontDefinition(
  template: StorefrontTemplate.bistroNight,
  accentHex: '#F5B82E',
  brand: brand,
  serviceModes: modes,
  features: features,
);

const noBudget = GuestFeatures(budget: BudgetSettings(enabled: false));
const table12 = DiningTable(id: 't-12', label: '12');

Future<void> pumpGuest(
  WidgetTester tester, {
  required StorefrontDefinition definition,
  required GuestOrderGateway gateway,
  MenuSnapshot snapshot = menu,
  DiningTable? table,
}) async {
  GuestPalette.remoteFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: GuestApp(
        definition: definition,
        menu: snapshot,
        gateway: gateway,
        table: table,
      ),
    ),
  );
  await settle(tester);
}

/// Finite steps instead of pumpAndSettle (confetti, countdowns).
Future<void> settle(WidgetTester tester, {int ms = 1200}) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await settle(tester);
}

/// Welcome → (budget skipped or off) → All dishes.
Future<void> openAllDishes(WidgetTester tester) async {
  await tapText(tester, 'Start exploring');
  if (find.text('Skip').evaluate().isNotEmpty) await tapText(tester, 'Skip');
  await tapText(tester, 'All dishes');
}

Future<void> goToCheckout(WidgetTester tester) async {
  await tapText(tester, 'View order (1)');
  await tapText(tester, 'Continue to review');
  await tapText(tester, 'Proceed to checkout');
}

void main() {
  testWidgets('welcome shows only the real display name when hero is empty', (
    tester,
  ) async {
    await pumpGuest(
      tester,
      definition: storefront(),
      gateway: RecordingGateway(),
    );
    const t = StorefrontTemplate.bistroNight;
    expect(find.text('Test Bistro'), findsOneWidget);
    expect(find.text(t.defaultHeroTitle), findsNothing);
    expect(find.text(t.defaultHeroSubtitle), findsNothing);
    expect(find.text(t.defaultTagline), findsNothing);
    expect(find.text('Start exploring'), findsOneWidget);
  });

  testWidgets('an empty catalog shows "The menu is being prepared"', (
    tester,
  ) async {
    await pumpGuest(
      tester,
      definition: storefront(),
      gateway: RecordingGateway(),
      snapshot: MenuSnapshot.empty,
    );
    expect(find.text('The menu is being prepared'), findsOneWidget);
    expect(find.text('Start exploring'), findsNothing);
  });

  testWidgets('budget screen appears only when the budget is enabled', (
    tester,
  ) async {
    await pumpGuest(
      tester,
      definition: storefront(),
      gateway: RecordingGateway(),
    );
    await tapText(tester, 'Start exploring');
    expect(find.text('Dining with friends?'), findsOneWidget);

    await pumpGuest(
      tester,
      definition: storefront(features: noBudget),
      gateway: RecordingGateway(),
    );
    await tapText(tester, 'Start exploring');
    expect(find.text('Dining with friends?'), findsNothing);
    expect(find.text('What are you in the mood for?'), findsOneWidget);
  });

  testWidgets('adding from the deck updates the budget ring', (tester) async {
    await pumpGuest(
      tester,
      definition: storefront(),
      gateway: RecordingGateway(),
    );
    await tapText(tester, 'Start exploring');
    await tapText(tester, 'Save & continue');
    await tapText(tester, 'All dishes');
    expect(find.text('₹0 / ₹3,000'), findsOneWidget);
    expect(find.text('0% used'), findsOneWidget);

    // The green ♥ adds the top card (Paneer Tikka, ₹600 + 5% GST).
    await tester.tap(find.byKey(const ValueKey('deck-add')));
    await settle(tester, ms: 1600);
    expect(find.text('₹630 / ₹3,000'), findsOneWidget);
    expect(find.text('21% used'), findsOneWidget);

    // A right swipe adds the next card (Chicken Biryani, ₹400 + GST).
    await tester.fling(
      find.byKey(const ValueKey('deck-card-i-biryani')),
      const Offset(500, 0),
      2000,
    );
    await settle(tester, ms: 1600);
    expect(find.text('₹1,050 / ₹3,000'), findsOneWidget);
    expect(find.text('35% used'), findsOneWidget);
  });

  testWidgets('swipeDeck off shows the list with Add buttons', (tester) async {
    await pumpGuest(
      tester,
      definition: storefront(features: noBudget.copyWith(swipeDeck: false)),
      gateway: RecordingGateway(),
    );
    await openAllDishes(tester);
    expect(find.byKey(const ValueKey('dish-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('deck-add')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('list-add-i-paneer')));
    await settle(tester);
    expect(find.byKey(const ValueKey('list-qty-i-paneer')), findsOneWidget);
    expect(find.text('View order (1)'), findsOneWidget);
  });

  testWidgets('placing sends guest, table and key; a retry reuses the key', (
    tester,
  ) async {
    final gateway = RecordingGateway();
    await pumpGuest(
      tester,
      definition: storefront(features: noBudget),
      gateway: gateway,
      table: table12,
    );
    await openAllDishes(tester);
    await tester.tap(find.byKey(const ValueKey('deck-add')));
    await settle(tester, ms: 1600);
    await goToCheckout(tester);
    expect(find.text('Table 12'), findsOneWidget);

    gateway.failNext = const AppFailure(
      'You are offline. Check the connection and try again.',
      kind: FailureKind.offline,
    );
    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester);
    expect(find.byKey(const ValueKey('place-error')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester, ms: 1500);

    expect(gateway.drafts, hasLength(2));
    final first = gateway.drafts[0], second = gateway.drafts[1];
    expect(first.idempotencyKey, isNotEmpty);
    expect(second.idempotencyKey, first.idempotencyKey);
    expect(second.placedBy, PlacedBy.guest);
    expect(second.table?.id, 't-12');
    expect(second.serviceType, ServiceType.dineIn);
    expect(second.lines.single.itemId, 'i-paneer');

    expect(find.text('Order placed!'), findsOneWidget);
    expect(find.text('#VB1252'), findsOneWidget);
    expect(find.text('20–25 minutes'), findsOneWidget);
    expect(
      find.text('Preview — nothing was sent to the kitchen'),
      findsNothing,
    );
    await settle(tester, ms: 3000);
  });

  testWidgets('a real dine-in order without a table asks for staff', (
    tester,
  ) async {
    final gateway = RecordingGateway();
    await pumpGuest(
      tester,
      definition: storefront(features: noBudget),
      gateway: gateway,
    );
    await openAllDishes(tester);
    await tester.tap(find.byKey(const ValueKey('deck-add')));
    await settle(tester, ms: 1600);
    await goToCheckout(tester);
    expect(find.textContaining('Please call a staff member'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester);
    expect(gateway.drafts, isEmpty);
  });

  testWidgets('the preview gateway shows the preview banner and next step', (
    tester,
  ) async {
    await pumpGuest(
      tester,
      definition: storefront(features: noBudget),
      gateway: PreviewGuestGateway(() async => BillCharges.defaults),
    );
    await openAllDishes(tester);
    await tester.tap(find.byKey(const ValueKey('deck-add')));
    await settle(tester, ms: 1600);
    await goToCheckout(tester);
    expect(find.text('Table will be confirmed by our staff.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester, ms: 1500);

    expect(find.text('Order placed!'), findsOneWidget);
    expect(
      find.text('Preview — nothing was sent to the kitchen'),
      findsOneWidget,
    );
    await tapText(tester, 'Track order');
    expect(
      find.text('Preview — nothing was sent to the kitchen'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('preview-next')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preview-next')));
    await settle(tester);
    expect(find.text('Your food is being prepared'), findsOneWidget);
    await settle(tester, ms: 3000);
  });
}
