import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'guest_runtime_test.dart'
    show
        RecordingGateway,
        noBudget,
        openAllDishes,
        pumpGuest,
        settle,
        storefront,
        table12;

/// The swipe is a gesture a screen reader cannot make, so the front card has
/// to say what it is and offer the same choices as actions.
void main() {
  // The front card is the only node that carries this hint.
  final frontCard = find.semantics.byHint('Double tap for details');

  /// What a screen reader does when the person picks an action by name.
  void act(WidgetTester tester, String label) => tester.semantics.performAction(
    frontCard,
    SemanticsAction.customAction,
    args: CustomSemanticsAction.getIdentifier(
      CustomSemanticsAction(label: label),
    ),
  );

  Future<SemanticsHandle> openDeck(WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await pumpGuest(
      tester,
      definition: storefront(features: noBudget),
      gateway: RecordingGateway(),
      table: table12,
    );
    await openAllDishes(tester);
    return handle;
  }

  testWidgets('the front card is named and can be added or skipped by action', (
    tester,
  ) async {
    final handle = await openDeck(tester);

    final node = frontCard.evaluate().single;
    expect(node.label, 'Paneer Tikka, ₹600, Veg, Bestseller');

    final labels = {
      for (final id in node.getSemanticsData().customSemanticsActionIds ?? [])
        CustomSemanticsAction.getAction(id as int)!.label,
    };
    expect(labels, {'Add to order', 'Skip this dish'});

    // Adding by action does what the right swipe does.
    expect(find.text('View order (1)'), findsNothing);
    act(tester, 'Add to order');
    await settle(tester, ms: 1800);
    expect(find.text('View order (1)'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('skipping by action moves on to the next dish', (tester) async {
    final handle = await openDeck(tester);
    expect(frontCard.evaluate().single.label, startsWith('Paneer Tikka'));

    act(tester, 'Skip this dish');
    await settle(tester, ms: 1800);

    expect(frontCard.evaluate().single.label, startsWith('Chicken Biryani'));
    expect(find.text('View order (1)'), findsNothing);
    handle.dispose();
  });

  testWidgets('a double tap opens the dish', (tester) async {
    final handle = await openDeck(tester);
    tester.semantics.tap(frontCard);
    await settle(tester, ms: 1800);
    expect(find.text('Add to order · ₹600'), findsOneWidget);
    handle.dispose();
  });
}
