import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/application/guest_coupons.dart';
import 'package:vinii_partner/application/guest_session.dart';
import 'package:vinii_partner/domain/pos_order.dart';

import 'guest_runtime_test.dart'
    show
        RecordingGateway,
        goToCheckout,
        menu,
        noBudget,
        openAllDishes,
        pumpGuest,
        settle,
        storefront,
        table12;

/// A stand-in for the server's coupon check. It records what it was asked.
class FakeCoupons extends GuestCoupons {
  final asked = <String>[];

  /// Orders below this much food are refused.
  double minimum = 0;

  /// When set, every answer waits for it (to let a test order the replies).
  Future<void>? hold;

  @override
  Future<CouponResult> check({
    required String code,
    required List<CartLine> lines,
    required ServiceType serviceType,
  }) async {
    asked.add(code);
    final wait = hold;
    if (wait != null) await wait;
    final food = lines.fold<double>(0, (s, l) => s + l.lineTotal);
    if (code == 'NOPE') {
      return const CouponResult.invalid(
        code: 'NOPE',
        message: "That code isn't valid.",
      );
    }
    if (food < minimum) {
      return CouponResult.invalid(
        code: code,
        message: 'Minimum order is ₹${minimum.toInt()}.',
      );
    }
    return CouponResult.valid(code: code, discount: 50, label: '₹50 off');
  }
}

class CouponGateway extends RecordingGateway {
  CouponGateway(this.service);
  final FakeCoupons? service;

  @override
  GuestCoupons? get coupons => service;
}

Future<void> reachOrder(WidgetTester tester, CouponGateway gateway) async {
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
}

Future<void> applyCode(WidgetTester tester, String code) async {
  await tester.ensureVisible(find.byKey(const ValueKey('coupon-open')));
  await tester.tap(find.byKey(const ValueKey('coupon-open')));
  await settle(tester, ms: 400);
  await tester.enterText(find.byKey(const ValueKey('coupon-field')), code);
  await tester.tap(find.byKey(const ValueKey('coupon-apply')));
  await settle(tester, ms: 900);
}

void main() {
  testWidgets('without a coupon service the order has no coupon row', (
    tester,
  ) async {
    await reachOrder(tester, CouponGateway(null));
    expect(find.byKey(const ValueKey('coupon-open')), findsNothing);
    expect(find.text('Have a coupon code?'), findsNothing);
  });

  testWidgets('a good code takes its discount off the bill and goes with the '
      'order', (tester) async {
    final service = FakeCoupons();
    final gateway = CouponGateway(service);
    await reachOrder(tester, gateway);
    expect(find.text('Have a coupon code?'), findsOneWidget);

    // Typed in lower case, sent in upper case.
    await applyCode(tester, 'save50');
    expect(service.asked, ['SAVE50']);
    expect(find.byKey(const ValueKey('coupon-applied')), findsOneWidget);
    expect(find.text('SAVE50 applied'), findsOneWidget);
    expect(find.text('₹50 off'), findsOneWidget);
    // The bill names the coupon and takes ₹50 off the ₹600 dish: ₹550 plus
    // 5% GST is ₹577.50, rounded to the rupee.
    expect(find.text('Coupon SAVE50'), findsOneWidget);
    expect(find.text('Place order · ₹578'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester, ms: 1500);
    final d = gateway.drafts.single;
    expect(d.couponCode, 'SAVE50');
    expect(d.couponDiscount, 50);
    expect(d.bill.discount, 50);
  });

  testWidgets('a code the server refuses says why and takes nothing off', (
    tester,
  ) async {
    final gateway = CouponGateway(FakeCoupons());
    await reachOrder(tester, gateway);
    await applyCode(tester, 'nope');
    expect(find.byKey(const ValueKey('coupon-applied')), findsNothing);
    expect(find.text("That code isn't valid."), findsOneWidget);
    expect(find.text('Place order · ₹630'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('place-order')));
    await settle(tester, ms: 1500);
    expect(gateway.drafts.single.couponCode, isNull);
  });

  testWidgets('Remove takes the coupon off again', (tester) async {
    await reachOrder(tester, CouponGateway(FakeCoupons()));
    await applyCode(tester, 'SAVE50');
    expect(find.byKey(const ValueKey('coupon-applied')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('coupon-remove')));
    await settle(tester, ms: 400);
    expect(find.byKey(const ValueKey('coupon-applied')), findsNothing);
    expect(find.text('Place order · ₹630'), findsOneWidget);
  });

  testWidgets('changing the order asks again and drops a coupon that no '
      'longer fits', (tester) async {
    final service = FakeCoupons();
    await reachOrder(tester, CouponGateway(service));
    await applyCode(tester, 'SAVE50');
    expect(find.byKey(const ValueKey('coupon-applied')), findsOneWidget);

    // The server now wants more food than the cart has.
    service.minimum = 5000;
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('i-paneer')),
        matching: find.byIcon(Icons.add_rounded),
      ),
    );
    await settle(tester, ms: 1200);

    expect(service.asked, ['SAVE50', 'SAVE50']);
    expect(find.byKey(const ValueKey('coupon-applied')), findsNothing);
    expect(
      find.textContaining('Coupon SAVE50 was taken off: Minimum order'),
      findsOneWidget,
    );
  });

  test('an older answer never replaces a newer one', () async {
    final service = FakeCoupons();
    final session = GuestSession(
      definition: storefront(features: noBudget),
      menu: menu,
      gateway: CouponGateway(service),
    );
    addTearDown(session.dispose);
    session.add(session.catalog.allItems.first);

    final slow = Completer<void>();
    service.hold = slow.future;
    final first = session.applyCoupon('SLOW');
    service.hold = null;
    await session.applyCoupon('NOPE');
    expect(session.coupon, isNull);
    expect(session.couponMessage, "That code isn't valid.");

    slow.complete();
    await first;
    // SLOW would have been valid; it arrived late and must be ignored.
    expect(session.coupon, isNull);
    expect(session.couponMessage, "That code isn't valid.");
    expect(session.couponChecking, isFalse);
  });

  test('the estimate carries the discount and never goes below zero', () {
    final session = GuestSession(
      definition: storefront(features: noBudget),
      menu: menu,
      gateway: CouponGateway(FakeCoupons()),
    );
    addTearDown(session.dispose);
    session.add(session.catalog.allItems.last); // Brownie, ₹150
    session.coupon = const CouponResult.valid(code: 'BIG', discount: 5000);
    expect(session.estimate.discount, 150);
    expect(session.estimate.payable, 0);
  });
}
