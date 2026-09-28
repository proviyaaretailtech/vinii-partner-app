import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vinii_partner/application/sell_cart.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/data/backend.dart';
import 'package:vinii_partner/data/local_prefs.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/pos_order.dart';

import 'support/fake_backend.dart';

const _biryani = MenuItem(id: 'i1', name: 'Chicken Biryani', price: 240);
const _lassi = MenuItem(id: 'i2', name: 'Sweet Lassi', price: 60);
const _thali = MenuItem(
  id: 'i3',
  name: 'Veg Thali',
  price: 180,
  isAvailable: false,
);
const _table = DiningTable(id: 't-12', label: '12');
const _scope = 'order:org-1';

/// Records what the phone had saved at the moment the order left.
class _SpyPos extends Fake implements PosRepository {
  _SpyPos(this.prefs);
  final LocalPrefs prefs;
  final keyAtCall = <String?>[];
  final drafts = <PosOrderDraft>[];
  AppFailure? fail;
  List<CartLine>? answerLines;

  @override
  Future<BillCharges> billCharges() async => BillCharges.defaults;

  @override
  Future<PlacedOrder> placeOrder(PosOrderDraft draft) async {
    keyAtCall.add(prefs.pendingKey(_scope));
    drafts.add(draft);
    if (fail != null) throw fail!;
    return PlacedOrder(
      id: 'o-${drafts.length}',
      version: 'v1',
      displayNo: 'ORD-${drafts.length}',
      status: PosStatus.sentToKitchen,
      serviceType: draft.serviceType,
      createdAt: DateTime(2026, 9, 28, 12),
      lines: answerLines ?? draft.lines,
      bill: draft.bill,
    );
  }
}

Future<(SellCart, _SpyPos, LocalPrefs)> _cart({
  Map<String, Object> saved = const {},
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await LocalPrefs.open();
  final pos = _SpyPos(prefs);
  final cart = SellCart(
    menuRepository: FakeBackend().menu,
    pos: pos,
    prefs: prefs,
    orgId: 'org-1',
  );
  return (cart, pos, prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('adding, changing and removing lines', () async {
    final (cart, _, _) = await _cart();
    cart
      ..add(_biryani)
      ..add(_biryani)
      ..add(_lassi)
      ..add(_thali); // sold out: ignored

    expect(cart.itemCount, 3);
    expect(cart.qtyOf('i1'), 2);
    expect(cart.qtyOf('i3'), 0);

    cart.setLineNote('i1', 'Less spicy');
    expect(cart.lineFor('i1')!.notes, 'Less spicy');
    cart.setLineNote('i1', '  ');
    expect(cart.lineFor('i1')!.notes, isNull);

    cart.setLine(_lassi, qty: 3, note: 'No sugar');
    expect(cart.lineFor('i2')!.qty, 3);
    expect(cart.lineFor('i2')!.notes, 'No sugar');

    cart.setQty('i2', 0);
    expect(cart.qtyOf('i2'), 0);
    expect(cart.lines.single.itemId, 'i1');
  });

  test('the estimate uses the OS bill maths', () async {
    final (cart, _, _) = await _cart();
    cart
      ..add(_biryani)
      ..add(_biryani);
    final bill = cart.estimate;
    expect(bill.itemTotal, 480);
    expect(bill.sgst, 12);
    expect(bill.cgst, 12);
    expect(bill.payable, 504);
  });

  test('what blocks sending, per service type', () async {
    final (cart, _, _) = await _cart();
    expect(cart.blocker, 'Add at least one item.');
    cart.add(_biryani);
    expect(cart.blocker, 'Choose a table for this dine-in order.');
    cart.setTable(_table);
    expect(cart.blocker, isNull);

    cart.setServiceType(ServiceType.delivery);
    expect(cart.blocker, "Add the customer's phone number for delivery.");
    cart.setCustomerPhone('98220 12345');
    expect(cart.blocker, isNull);
  });

  test('only the chosen service type\'s fields are sent', () async {
    final (cart, _, _) = await _cart();
    cart
      ..add(_biryani)
      ..setTable(_table)
      ..setGuestCount(4)
      ..setCustomerName('Asha');

    final dineIn = cart.draft(idempotencyKey: 'k');
    expect(dineIn.table?.id, 't-12');
    expect(dineIn.guestCount, 4);
    expect(dineIn.customerName, isNull);

    cart.setServiceType(ServiceType.takeaway);
    final takeaway = cart.draft(idempotencyKey: 'k');
    expect(takeaway.table, isNull);
    expect(takeaway.guestCount, isNull);
    expect(takeaway.customerName, 'Asha');
  });

  test('the key is saved before sending, kept after "not ready", reused, '
      'then cleared on success', () async {
    final (cart, pos, prefs) = await _cart();
    cart
      ..setServiceType(ServiceType.takeaway)
      ..add(_biryani);
    pos.fail = const AppFailure(
      'Needs the database update.',
      kind: FailureKind.notReady,
    );

    await expectLater(
      cart.place(fireKitchenTicket: true, placedBy: PlacedBy.pos),
      throwsA(isA<AppFailure>()),
    );
    final key = prefs.pendingKey(_scope);
    expect(key, isNotNull);
    expect(pos.keyAtCall.single, key, reason: 'saved before the call');
    expect(pos.drafts.single.idempotencyKey, key);
    expect(cart.itemCount, 1, reason: 'the cart is kept');
    expect(cart.hasPendingSend, isTrue);

    pos.fail = null;
    final result = await cart.place(
      fireKitchenTicket: false,
      placedBy: PlacedBy.captain,
    );
    expect(pos.drafts.last.idempotencyKey, key, reason: 'same key on retry');
    expect(pos.drafts.last.fireKitchenTicket, isFalse);
    expect(pos.drafts.last.placedBy, PlacedBy.captain);
    expect(result.earlierOrder, isFalse);
    expect(prefs.pendingKey(_scope), isNull);
    expect(cart.isEmpty, isTrue);
  });

  test('offline keeps the key; a refusal clears it', () async {
    final (cart, pos, prefs) = await _cart();
    cart
      ..setServiceType(ServiceType.takeaway)
      ..add(_biryani);

    pos.fail = const AppFailure('Offline.', kind: FailureKind.offline);
    await expectLater(
      cart.place(fireKitchenTicket: true, placedBy: PlacedBy.pos),
      throwsA(isA<AppFailure>()),
    );
    expect(prefs.pendingKey(_scope), isNotNull);

    pos.fail = const AppFailure(
      'Chicken Biryani is sold out.',
      kind: FailureKind.rejected,
    );
    await expectLater(
      cart.place(fireKitchenTicket: true, placedBy: PlacedBy.pos),
      throwsA(isA<AppFailure>()),
    );
    expect(prefs.pendingKey(_scope), isNull);
    expect(cart.itemCount, 1);
  });

  test('a key left from before a restart is reused', () async {
    final (cart, pos, prefs) = await _cart(
      saved: {'pending_key:$_scope': 'key-from-yesterday'},
    );
    cart
      ..setServiceType(ServiceType.takeaway)
      ..add(_biryani);
    await cart.place(fireKitchenTicket: true, placedBy: PlacedBy.pos);
    expect(pos.drafts.single.idempotencyKey, 'key-from-yesterday');
    expect(prefs.pendingKey(_scope), isNull);
  });

  test('an earlier order returned for that key keeps the new cart', () async {
    final (cart, pos, prefs) = await _cart(
      saved: {'pending_key:$_scope': 'key-from-before'},
    );
    cart
      ..setServiceType(ServiceType.takeaway)
      ..add(_biryani);
    pos.answerLines = const [
      CartLine(itemId: 'i2', name: 'Sweet Lassi', unitPrice: 60, qty: 2),
    ];

    final result = await cart.place(
      fireKitchenTicket: true,
      placedBy: PlacedBy.pos,
    );
    expect(result.earlierOrder, isTrue);
    expect(cart.qtyOf('i1'), 1, reason: 'the current cart is kept');
    expect(prefs.pendingKey(_scope), isNull);
  });
}
