import 'dart:async';

import '../core/failure.dart';
import '../data/backend.dart';
import '../domain/billing.dart';
import '../domain/pos_order.dart';
import 'guest_coupons.dart';
import 'guest_payments.dart';
import 'guest_social.dart';

/// How the guest storefront runtime reaches the outside world. The runtime
/// itself (`presentation/guest/`) never touches a repository directly, so
/// the same screens run handed-over on a staff phone, inside Studio's
/// preview, and later as the public website.
abstract class GuestOrderGateway {
  const GuestOrderGateway();

  /// Inside Studio's preview: nothing is ever sent, and every screen after
  /// "Place order" says so.
  bool get isPreview;

  /// The organization's bill settings, for the guest's preview bill.
  Future<BillCharges> charges();

  /// Places the order through the POS front door with `placed_by: guest`.
  Future<PlacedOrder> place(PosOrderDraft draft);

  /// The order again each time the kitchen moves it (live tracking).
  Stream<PlacedOrder> watch(PlacedOrder order);

  /// Online payment of the bill (UPI, cards, netbanking), when the server
  /// can take it for this restaurant. Null means staff collect the payment,
  /// and the bill tells the guest to let staff know (there is no way yet to
  /// call them from the screen). Wired when the payment functions exist (see
  /// docs/PAYMENTS_CASHFREE.md).
  GuestPayments? get payments => null;

  /// Orders as they happen at the tables around this one, for the quick-add
  /// alerts. Null (nothing is shown) until the server function exists
  /// (docs/GUEST_SERVER_CONTRACT.md).
  GuestNearby? get nearby => null;

  /// Recent orders of tables with a similar party, to preview and copy. Null
  /// until the server function exists.
  GuestSimilarTables? get similarTables => null;

  /// Coupon codes at checkout. Null until the server function exists; the
  /// coupon row is then not shown.
  GuestCoupons? get coupons => null;

  /// Whether guest feedback can be stored. There is no feedback table or
  /// endpoint yet, so every gateway says no and the guest screens hide the
  /// feedback row rather than pretend to save it.
  bool get acceptsFeedback => false;
}

/// A staff phone handed to a guest party at their table. Orders are real and
/// go through `pos_place_order` under the staff member's session, marked as
/// placed by the guest (contract R10: guests never write tables themselves).
class PosGuestGateway extends GuestOrderGateway {
  PosGuestGateway(this.pos);
  final PosRepository pos;

  @override
  bool get isPreview => false;

  @override
  Future<BillCharges> charges() => pos.billCharges();

  @override
  Future<PlacedOrder> place(PosOrderDraft draft) {
    if (draft.placedBy != PlacedBy.guest) {
      throw const AppFailure(
        'Guest orders must be marked as placed by the guest.',
        kind: FailureKind.rejected,
      );
    }
    return pos.placeOrder(draft);
  }

  @override
  Stream<PlacedOrder> watch(PlacedOrder order) async* {
    yield order;
    var last = order;
    while (last.status.isOpen) {
      await Future<void>.delayed(const Duration(seconds: 5));
      try {
        last = await pos.refresh(order.id);
        yield last;
      } on AppFailure catch (e) {
        if (!e.isOffline) rethrow;
      }
    }
  }
}

/// Studio's live preview. Uses the organization's real menu and bill
/// settings, but "Place order" goes nowhere: the result is a local stand-in
/// numbered "PREVIEW" that is never stored and never listed anywhere.
class PreviewGuestGateway extends GuestOrderGateway {
  PreviewGuestGateway(this._charges);
  final Future<BillCharges> Function() _charges;

  @override
  bool get isPreview => true;

  @override
  Future<BillCharges> charges() => _charges();

  @override
  Future<PlacedOrder> place(PosOrderDraft draft) async => PlacedOrder(
    id: 'preview-${draft.idempotencyKey}',
    version: '',
    displayNo: 'PREVIEW',
    status: PosStatus.fresh,
    serviceType: draft.serviceType,
    createdAt: DateTime.now(),
    lines: draft.lines,
    bill: draft.bill,
    table: draft.table,
    scheduledFor: draft.scheduledFor,
    placedBy: PlacedBy.guest,
  );

  @override
  Stream<PlacedOrder> watch(PlacedOrder order) => Stream.value(order);
}
