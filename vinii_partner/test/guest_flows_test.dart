import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vinii_partner/application/guest_gateway.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/domain/staff.dart';
import 'package:vinii_partner/domain/storefront.dart';
import 'package:vinii_partner/presentation/guest/guest_routes.dart';

import 'guest_runtime_test.dart'
    show
        RecordingGateway,
        menu,
        noBudget,
        pumpGuest,
        settle,
        storefront,
        table12,
        tapText;
import 'support/fake_backend.dart';
import 'support/harness.dart';

/// A storefront with every guest detail filled in, like Studio would save.
StorefrontDefinition richStorefront({
  GuestFeatures features = const GuestFeatures(),
  StorefrontTemplate template = StorefrontTemplate.bistroNight,
  List<GuestServiceMode> modes = const [GuestServiceMode.dineIn],
  CategoryStyle style = CategoryStyle.grid,
}) {
  final now = DateTime.now();
  final ends = now.hour >= 22 ? '23:59' : '${now.hour + 2}'.padLeft(2, '0');
  return StorefrontDefinition(
    template: template,
    accentHex: template.defaultAccent,
    brand: const StorefrontBrand(
      displayName: 'Test Bistro',
      locationLine: 'Indiranagar, Bengaluru',
      heroTitle: 'Dinner at our place',
    ),
    serviceModes: modes,
    features: features,
    categoryStyle: style,
    items: const {
      'i-paneer': ItemPresentation(
        itemId: 'i-paneer',
        tags: ['Spicy'],
        ingredients: ['Paneer', 'Chilli', 'Onion'],
        allergens: ['Dairy'],
        kcal: 420,
      ),
    },
    chefsPicks: const ['i-brownie'],
    limitedToday: [
      LimitedOffer(
        itemId: 'i-biryani',
        endsAt: ends.length == 2 ? '$ends:00' : ends,
      ),
    ],
  );
}

void main() {
  testWidgets('detail, added sheet, budget overview and specials', (
    tester,
  ) async {
    await pumpGuest(
      tester,
      definition: richStorefront(),
      gateway: RecordingGateway(),
    );
    expect(find.text('Indiranagar, Bengaluru'), findsOneWidget);
    await tapText(tester, 'Start exploring');
    await tapText(tester, 'Save & continue');
    await tapText(tester, 'All dishes');

    await tester.tap(find.byKey(const ValueKey('budget-strip')));
    await settle(tester);
    expect(find.text('Your budget'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);

    await tester.tap(find.byTooltip('Details'));
    await settle(tester);
    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.text('Chilli'), findsOneWidget);
    await tester.ensureVisible(find.text('Allergen information'));
    await tester.tap(find.text('Allergen information'));
    await settle(tester);
    expect(find.text('Contains: Dairy'), findsOneWidget);
    await tester.ensureVisible(find.text('Nutritional info'));
    await settle(tester, ms: 300);
    await tester.tap(find.text('Nutritional info'));
    await settle(tester);
    expect(find.text('420 kcal per serving'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('detail-add')));
    await settle(tester);
    expect(find.text('Added to your order!'), findsOneWidget);
    await tapText(tester, 'Keep exploring');

    await tester.tap(find.byTooltip('Specials').first);
    await settle(tester);
    expect(
      find.textContaining("Chef's picks", findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Limited today'), findsOneWidget);
    expect(find.textContaining('Ends in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('feature switches hide ingredients, likes and specials', (
    tester,
  ) async {
    await pumpGuest(
      tester,
      definition: richStorefront(
        features: noBudget.copyWith(
          showIngredients: false,
          showAllergens: false,
          showNutrition: false,
          likes: false,
          chefsPicks: false,
          limitedToday: false,
        ),
      ),
      gateway: RecordingGateway(),
    );
    await tapText(tester, 'Start exploring');
    await tapText(tester, 'All dishes');
    expect(find.byTooltip('Specials'), findsNothing);
    expect(find.byTooltip('Save for later'), findsNothing);
    expect(find.byKey(const ValueKey('budget-strip')), findsNothing);
    await tester.tap(find.byTooltip('Details'));
    await settle(tester);
    expect(find.text('Ingredients'), findsNothing);
    expect(find.text('Allergen information'), findsNothing);
    expect(find.text('Nutritional info'), findsNothing);
  });

  testWidgets('artisan wheel and a pre-order with a pickup slot', (
    tester,
  ) async {
    final gateway = RecordingGateway();
    final def = richStorefront(
      template: StorefrontTemplate.artisanDay,
      modes: const [GuestServiceMode.dineIn, GuestServiceMode.preOrder],
      style: CategoryStyle.wheel,
      features: noBudget,
    );
    await pumpGuest(tester, definition: def, gateway: gateway, table: table12);
    expect(find.text('Order now'), findsOneWidget);
    await tapText(tester, 'Pre-order');
    expect(find.text('Select date & time'), findsOneWidget);

    final now = DateTime.now();
    final days = [
      for (var i = 0; i < def.preOrder.daysAhead; i++)
        DateTime(now.year, now.month, now.day + i),
    ];
    final day = days.firstWhere((d) => def.preOrder.slotsFor(d).isNotEmpty);
    final slot = def.preOrder.slotsFor(day).first;
    await tapText(tester, DateFormat('h:mm a').format(slot));
    await tapText(tester, 'Continue');

    expect(find.text('Swipe to explore categories'), findsOneWidget);
    await tapText(tester, 'Explore all dishes');
    await tester.tap(find.byKey(const ValueKey('deck-add')));
    await settle(tester, ms: 1600);
    await tapText(tester, 'View order (1)');
    // One screen: the ways of ordering sit at the top, Place order at the bottom.
    expect(find.byKey(const ValueKey('mode-preOrder')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-dineIn')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester, ms: 1500);

    expect(find.text('Pre-order confirmed!'), findsOneWidget);
    final d = gateway.drafts.single;
    expect(d.serviceType, ServiceType.takeaway);
    expect(d.scheduledFor, slot);
    expect(d.table, isNull);
    await settle(tester, ms: 3000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview: tracking to served, then the bill', (tester) async {
    await pumpGuest(
      tester,
      definition: richStorefront(),
      gateway: PreviewGuestGateway(() async => BillCharges.defaults),
      table: table12,
    );
    await tapText(tester, 'Start exploring');
    await tapText(tester, 'Save & continue');
    await tapText(tester, 'All dishes');
    await tester.tap(find.byKey(const ValueKey('deck-add')));
    await settle(tester, ms: 1600);
    await tapText(tester, 'View order (1)');
    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester, ms: 1500);
    await tapText(tester, 'Track order');
    // The status ring leads the screen, so the discover strip sits below it.
    await tester.scrollUntilVisible(
      find.text('Discover more'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Discover more'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('preview-next')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('preview-next')));
      await settle(tester, ms: 600);
    }
    await settle(tester, ms: 1000);
    expect(find.text('Your order is served!'), findsOneWidget);
    await tapText(tester, 'View bill');
    expect(find.text('Your bill'), findsOneWidget);
    expect(find.text('Great! You stayed within your budget.'), findsOneWidget);
    expect(
      find.text('Preview — nothing was sent to the kitchen'),
      findsOneWidget,
    );
    await tapText(tester, 'Split bill');
    expect(find.text('Split the bill'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);
    expect(
      find.text(
        "To pay at the table, let a member of staff know you're ready for "
        "the bill. Calling staff from this screen isn't available yet.",
      ),
      findsOneWidget,
    );
    expect(find.text('How was your experience?'), findsNothing);
    await settle(tester, ms: 3000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delivery asks for contact details and sends them', (
    tester,
  ) async {
    final gateway = RecordingGateway();
    await pumpGuest(
      tester,
      definition: storefront(
        features: noBudget,
        modes: const [GuestServiceMode.delivery],
      ),
      gateway: gateway,
    );
    await tapText(tester, 'Start exploring');
    await tapText(tester, 'All dishes');
    await tester.tap(find.byKey(const ValueKey('deck-add')));
    await settle(tester, ms: 1600);
    await tapText(tester, 'View order (1)');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your name'),
      'Asha',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone number'),
      '9876543210',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address or room number'),
      'Room 204',
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester, ms: 1500);
    final d = gateway.drafts.single;
    expect(d.serviceType, ServiceType.delivery);
    expect(d.customerName, 'Asha');
    expect(d.customerPhone, '9876543210');
    expect(d.notes, contains('Room 204'));
    expect(d.placedBy, PlacedBy.guest);
    await settle(tester, ms: 3000);
  });

  testWidgets('three service modes ask how the guest will order', (
    tester,
  ) async {
    await pumpGuest(
      tester,
      definition: storefront(
        features: noBudget,
        modes: const [
          GuestServiceMode.dineIn,
          GuestServiceMode.takeaway,
          GuestServiceMode.delivery,
        ],
      ),
      gateway: RecordingGateway(),
    );
    await tapText(tester, 'Start exploring');
    expect(
      find.text('How would you like to enjoy Test Bistro?'),
      findsOneWidget,
    );
    await tapText(tester, 'Takeaway');
    expect(find.text('What are you in the mood for?'), findsOneWidget);
  });

  for (final template in [
    StorefrontTemplate.bistroNight,
    StorefrontTemplate.artisanDay,
  ]) {
    testWidgets('a 320 px phone renders ${template.label} without overflow', (
      tester,
    ) async {
      await pumpGuest(
        tester,
        definition: richStorefront(template: template),
        gateway: PreviewGuestGateway(() async => BillCharges.defaults),
        table: table12,
      );
      tester.view.physicalSize = const Size(960, 1800);
      await settle(tester);
      Future<void> step(Future<void> Function() action) async {
        await action();
        expect(tester.takeException(), isNull);
      }

      await step(() => tapText(tester, 'Start exploring'));
      await step(() => tapText(tester, 'Save & continue'));
      await step(() => tapText(tester, 'All dishes'));
      await step(() async {
        await tester.tap(find.byTooltip('Details'));
        await settle(tester);
      });
      await step(() async {
        await tester.tap(find.byKey(const ValueKey('detail-add')));
        await settle(tester);
      });
      await step(() => tapText(tester, 'Keep exploring'));
      await step(() => tapText(tester, 'View order (1)'));
      await step(() async {
        await tester.tap(find.byKey(const ValueKey('place-order')));
        await settle(tester, ms: 1500);
      });
      await step(() => tapText(tester, 'Track order'));
      await step(() async {
        await tester.scrollUntilVisible(
          find.text('View bill'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tapText(tester, 'View bill');
      });
      expect(find.text('Your bill'), findsOneWidget);
      await settle(tester, ms: 3000);
    });
  }

  testWidgets('a 320 px phone renders modes, wheel and specials', (
    tester,
  ) async {
    await pumpGuest(
      tester,
      definition: richStorefront(
        template: StorefrontTemplate.artisanDay,
        style: CategoryStyle.wheel,
        modes: const [
          GuestServiceMode.dineIn,
          GuestServiceMode.takeaway,
          GuestServiceMode.delivery,
        ],
      ),
      gateway: RecordingGateway(),
      table: table12,
    );
    tester.view.physicalSize = const Size(960, 1800);
    await settle(tester);
    await tapText(tester, 'Start exploring');
    expect(tester.takeException(), isNull);
    await tapText(tester, 'Dine-in');
    await tapText(tester, 'Save & continue');
    expect(find.text('Swipe to explore categories'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Specials'));
    await settle(tester);
    expect(find.text('Limited today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hand to guest needs a published storefront', (tester) async {
    final backend = FakeBackend(
      user: const StaffUser(id: 'u-1', email: 'captain@example.com'),
      memberships: [membershipAs('captain')],
      menu: menu,
      tables: const [table12],
    );
    final services = await testServices(backend);
    await services.session.boot();
    await tester.pumpWidget(
      wrapScreen(services, const GuestHostScreen(tableId: 't-12')),
    );
    await settle(tester);
    expect(
      find.text('Publish your storefront in Studio first'),
      findsOneWidget,
    );

    await backend.storefront.publish(testOrg, storefront(), publishedBy: 'u-1');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      wrapScreen(services, const GuestHostScreen(tableId: 't-12')),
    );
    await settle(tester);
    expect(find.text('Test Bistro'), findsOneWidget);
    expect(find.text('Start exploring'), findsOneWidget);
    expect(find.byKey(const ValueKey('guest-exit')), findsOneWidget);
  });
}
