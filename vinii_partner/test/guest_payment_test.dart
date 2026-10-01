import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/application/guest_payments.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/presentation/guest/guest_payment.dart';

import 'guest_runtime_test.dart'
    show
        RecordingGateway,
        goToCheckout,
        noBudget,
        pumpGuest,
        settle,
        storefront,
        table12,
        tapText;

/// A stand-in for the payment service: records what the app asks for and
/// answers with whatever the test chose. It never touches a network.
class FakePayments extends GuestPayments {
  FakePayments({this.window = CheckoutResult.completed});

  CheckoutResult window;
  final outcomes = <PaymentOutcome>[];
  final started = <({double amount, String key, String? phone})>[];
  int opened = 0;

  @override
  bool get available => true;

  @override
  bool get needsPayerPhone => true;

  @override
  Future<OnlinePayment> start({
    required List<PlacedOrder> orders,
    required double amount,
    required String idempotencyKey,
    String? payerPhone,
  }) async {
    started.add((amount: amount, key: idempotencyKey, phone: payerPhone));
    return OnlinePayment(
      attemptId: 'a-${started.length}',
      sessionId: 'session-${started.length}',
      amount: amount,
    );
  }

  @override
  Future<CheckoutResult> openCheckout(
    BuildContext context,
    OnlinePayment payment,
  ) async {
    opened++;
    return window;
  }

  @override
  Future<PaymentOutcome> outcome(OnlinePayment payment) async =>
      outcomes.isEmpty ? PaymentOutcome.pending : outcomes.removeAt(0);
}

class PayingGateway extends RecordingGateway {
  PayingGateway(this.service);
  final FakePayments? service;

  @override
  GuestPayments? get payments => service;
}

/// Welcome to the bill with one dish ordered.
Future<void> reachBill(WidgetTester tester, PayingGateway gateway) async {
  await pumpGuest(
    tester,
    definition: storefront(
      features: noBudget.copyWith(liveTracking: false, splitBill: true),
    ),
    gateway: gateway,
    table: table12,
  );
  await tapText(tester, 'Start exploring');
  await tapText(tester, 'All dishes');
  await tester.tap(find.byKey(const ValueKey('deck-add')));
  await settle(tester);
  await goToCheckout(tester);
  await tester.tap(find.byKey(const ValueKey('place-order')));
  await settle(tester, ms: 2000);
  await tapText(tester, 'View order details');
}

void main() {
  setUp(() => GuestPaymentScreen.pollEvery = Duration.zero);

  testWidgets('without online payment the bill only offers the staff route', (
    tester,
  ) async {
    await reachBill(tester, PayingGateway(null));
    // No button that does nothing: a plain line says what to do instead.
    expect(find.byKey(const ValueKey('pay-at-table')), findsOneWidget);
    expect(
      find.text(
        "To pay at the table, let a member of staff know you're ready for "
        "the bill. Calling staff from this screen isn't available yet.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('ask-bill')), findsNothing);
    expect(find.byKey(const ValueKey('pay-online')), findsNothing);
  });

  testWidgets('a paid payment waits for the server, then shows the receipt', (
    tester,
  ) async {
    final service = FakePayments()
      ..outcomes.addAll([PaymentOutcome.pending, PaymentOutcome.paid]);
    await reachBill(tester, PayingGateway(service));
    expect(find.byKey(const ValueKey('pay-online')), findsOneWidget);
    // Paying at the table stays possible, said as a plain line.
    expect(find.byKey(const ValueKey('pay-at-table')), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-bill')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('pay-online')));
    await settle(tester);
    expect(find.byKey(const ValueKey('pay-now')), findsOneWidget);

    // The payment service needs a mobile number before anything starts.
    await tester.tap(find.byKey(const ValueKey('pay-now')));
    await settle(tester);
    expect(service.started, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('pay-phone')),
      '9876543210',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pay-now')));
    await settle(tester, ms: 2000);

    expect(service.started.single.phone, '9876543210');
    expect(service.opened, 1);
    // The server said "pending" first and "paid" second.
    expect(find.text('Payment received'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a mobile number that cannot be right says what to change', (
    tester,
  ) async {
    final service = FakePayments();
    await reachBill(tester, PayingGateway(service));
    await tester.tap(find.byKey(const ValueKey('pay-online')));
    await settle(tester);
    final phone = find.byKey(const ValueKey('pay-phone'));

    // Too few digits: nothing is said yet, the Pay button just waits.
    await tester.enterText(phone, '98765');
    await tester.pump();
    expect(find.text('Enter your mobile number to pay'), findsOneWidget);
    expect(find.textContaining('starts with'), findsNothing);

    await tester.enterText(phone, '1234567890');
    await tester.pump();
    expect(
      find.text('A mobile number starts with 6, 7, 8 or 9'),
      findsOneWidget,
    );

    await tester.enterText(phone, '919876543210');
    await tester.pump();
    expect(
      find.text('Enter just the 10 digits, without 0 or +91'),
      findsOneWidget,
    );

    // None of them starts a payment.
    await tester.tap(find.byKey(const ValueKey('pay-now')));
    await settle(tester);
    expect(service.started, isEmpty);
  });

  testWidgets('a failed payment says nothing was paid and allows a retry', (
    tester,
  ) async {
    final service = FakePayments(window: CheckoutResult.failed)
      ..outcomes.add(PaymentOutcome.failed);
    await reachBill(tester, PayingGateway(service));
    await tester.tap(find.byKey(const ValueKey('pay-online')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pay-phone')),
      '9876543210',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pay-now')));
    await settle(tester, ms: 2000);

    expect(find.text("The payment didn't go through"), findsOneWidget);
    expect(find.text('Payment received'), findsNothing);

    // Trying again is a new attempt: a different key.
    service.outcomes.add(PaymentOutcome.paid);
    await tester.tap(find.byKey(const ValueKey('pay-now')));
    await settle(tester, ms: 2000);
    expect(service.started.length, 2);
    expect(service.started[0].key, isNot(service.started[1].key));
    expect(find.text('Payment received'), findsOneWidget);
  });

  testWidgets('closing the window is not a failure and reuses the attempt', (
    tester,
  ) async {
    final service = FakePayments(window: CheckoutResult.dropped)
      ..outcomes.addAll([PaymentOutcome.dropped, PaymentOutcome.paid]);
    await reachBill(tester, PayingGateway(service));
    await tester.tap(find.byKey(const ValueKey('pay-online')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pay-phone')),
      '9876543210',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pay-now')));
    await settle(tester, ms: 2000);

    expect(find.text('Payment window closed'), findsOneWidget);
    expect(find.text("The payment didn't go through"), findsNothing);

    service.window = CheckoutResult.completed;
    await tester.tap(find.byKey(const ValueKey('pay-now')));
    await settle(tester, ms: 2000);
    // The same session was reopened: no second payment was started.
    expect(service.started.length, 1);
    expect(service.opened, 2);
    expect(find.text('Payment received'), findsOneWidget);
  });

  testWidgets('choosing "my share" pays only that share', (tester) async {
    final service = FakePayments()..outcomes.add(PaymentOutcome.paid);
    await reachBill(tester, PayingGateway(service));
    await tester.tap(find.byKey(const ValueKey('pay-online')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('pay-phone')),
      '9876543210',
    );
    await tester.pump();

    await tester.tap(find.text('My share'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('pay-now')));
    await settle(tester, ms: 2000);

    // One ₹600 dish plus 5% GST is ₹630; two people each pay half.
    expect(service.started.single.amount, 315);
    expect(find.text('Your share is paid'), findsOneWidget);
  });
}
