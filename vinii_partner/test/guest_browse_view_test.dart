import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/application/guest_session.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/storefront.dart';

import 'guest_runtime_test.dart'
    show
        RecordingGateway,
        menu,
        noBudget,
        openAllDishes,
        pumpGuest,
        settle,
        storefront,
        table12,
        tapText;

/// The guest can flip, any time, between swiping through dishes and the
/// traditional menu of blocks.
void main() {
  final deck = find.byKey(const ValueKey('deck-add'));
  final list = find.byKey(const ValueKey('dish-list'));
  final swipeSwitch = find.byKey(const ValueKey('view-swipe'));
  final menuSwitch = find.byKey(const ValueKey('view-menu'));

  testWidgets('the switch flips between the swipe deck and the menu', (
    tester,
  ) async {
    await pumpGuest(
      tester,
      definition: storefront(features: noBudget),
      gateway: RecordingGateway(),
      table: table12,
    );
    await openAllDishes(tester);

    // The deck is where a visit starts.
    expect(deck, findsOneWidget);
    expect(list, findsNothing);
    expect(swipeSwitch, findsOneWidget);
    expect(menuSwitch, findsOneWidget);

    await tester.tap(menuSwitch);
    await settle(tester);
    expect(list, findsOneWidget);
    expect(deck, findsNothing);
    // The traditional menu adds with a pill, no swiping needed.
    await tester.tap(find.byKey(const ValueKey('list-add-i-paneer')));
    await settle(tester);
    expect(find.text('View order (1)'), findsOneWidget);

    await tester.tap(swipeSwitch);
    await settle(tester);
    expect(deck, findsOneWidget);
    expect(list, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the choice stays for the rest of the visit', (tester) async {
    await pumpGuest(
      tester,
      definition: storefront(features: noBudget),
      gateway: RecordingGateway(),
      table: table12,
    );
    await openAllDishes(tester);
    await tester.tap(menuSwitch);
    await settle(tester);

    // Another category, from the strip: still the menu.
    await tapText(tester, 'Desserts');
    expect(list, findsOneWidget);
    expect(find.text('Brownie'), findsWidgets);

    // Back to the categories and into one again: still the menu.
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await settle(tester);
    await tapText(tester, 'Mains');
    expect(list, findsOneWidget);
    expect(deck, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the restaurant can turn the deck off: the menu is all there '
      'is and there is no switch', (tester) async {
    await pumpGuest(
      tester,
      definition: storefront(features: noBudget.copyWith(swipeDeck: false)),
      gateway: RecordingGateway(),
      table: table12,
    );
    await openAllDishes(tester);
    expect(list, findsOneWidget);
    expect(deck, findsNothing);
    expect(swipeSwitch, findsNothing);
    expect(menuSwitch, findsNothing);
  });

  testWidgets('a long description and tags never overflow a menu row', (
    tester,
  ) async {
    const dish = MenuItem(
      id: 'i-long',
      name: 'Slow-cooked Mutton Biryani With Saffron',
      price: 420,
      categoryId: 'c-mains',
      foodType: FoodType.nonVeg,
      isRecommended: true,
      description:
          'Mutton on the bone, dum-sealed with saffron, fried onions and '
          'a little mint, served with a cooling raita on the side.',
    );
    const snapshot = MenuSnapshot(
      categories: [MenuCategory(id: 'c-mains', name: 'Mains', sortOrder: 1)],
      items: [dish],
    );
    final def = storefront(features: noBudget.copyWith(swipeDeck: false))
        .copyWith(
          items: const {
            'i-long': ItemPresentation(
              itemId: 'i-long',
              tags: ['Chef Special', 'Spicy', 'Weekend'],
            ),
          },
        );
    // A 320 px phone, the narrowest we promise to fit.
    await pumpGuest(
      tester,
      definition: def,
      gateway: RecordingGateway(),
      snapshot: snapshot,
      table: table12,
    );
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.devicePixelRatio = 3;
    await settle(tester, ms: 300);
    await openAllDishes(tester);
    expect(list, findsOneWidget);
    expect(
      find.text('Slow-cooked Mutton Biryani With Saffron'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('the view is the menu when the deck is off, whatever was asked', () {
    final session = GuestSession(
      definition: storefront(features: noBudget.copyWith(swipeDeck: false)),
      menu: menu,
      gateway: RecordingGateway(),
    );
    addTearDown(session.dispose);
    expect(session.canSwitchView, isFalse);
    session.setBrowseView(GuestBrowseView.swipe);
    expect(session.browseView, GuestBrowseView.menu);
  });
}
