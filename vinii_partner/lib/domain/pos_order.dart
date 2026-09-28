import 'billing.dart';

/// How the food reaches the guest. Maps to POS `orders.channel`.
enum ServiceType {
  dineIn('dine_in', 'Dine-in', 'Served at the table'),
  takeaway('pickup', 'Takeaway', 'Picked up at the counter'),
  delivery('delivery', 'Delivery', 'Delivered to an address');

  const ServiceType(this.channel, this.label, this.hint);
  final String channel;
  final String label;
  final String hint;
}

/// Who created the order (`orders.placed_by`).
enum PlacedBy { pos, captain, guest }

/// POS `orders.status` values (OS migration 0006/0010 check constraint).
enum PosStatus {
  fresh('new'),
  inBilling('in_billing'),
  sentToKitchen('sent_to_kitchen'),
  ready('ready'),
  awaitingPayment('awaiting_payment'),
  paid('paid'),
  delivered('delivered'),
  cancelled('cancelled');

  const PosStatus(this.dbValue);
  final String dbValue;

  static PosStatus fromDb(String? v) =>
      PosStatus.values.where((s) => s.dbValue == v).firstOrNull ??
      PosStatus.fresh;

  String get label => switch (this) {
    PosStatus.fresh => 'New',
    PosStatus.inBilling => 'In billing',
    PosStatus.sentToKitchen => 'In kitchen',
    PosStatus.ready => 'Ready',
    PosStatus.awaitingPayment => 'Awaiting payment',
    PosStatus.paid => 'Paid',
    PosStatus.delivered => 'Served',
    PosStatus.cancelled => 'Cancelled',
  };

  bool get isOpen => this != PosStatus.paid && this != PosStatus.cancelled;
}

/// `payments.method` values the phone offers.
enum PaymentMethod {
  cash('cash', 'Cash'),
  upi('upi', 'UPI'),
  card('card', 'Card');

  const PaymentMethod(this.dbValue, this.label);
  final String dbValue;
  final String label;
}

class DiningTable {
  const DiningTable({
    required this.id,
    required this.label,
    this.seats = 4,
    this.area,
    this.occupied = false,
  });
  final String id;

  /// "T12" or "12" — shown as "Table 12".
  final String label;
  final int seats;
  final String? area;

  /// Has an open (unpaid) order right now.
  final bool occupied;

  String get displayName =>
      RegExp(r'^\d+$').hasMatch(label) ? 'Table $label' : label;
}

class CartLine {
  const CartLine({
    required this.itemId,
    required this.name,
    required this.unitPrice,
    this.qty = 1,
    this.notes,
    this.variantName,
  });

  final String itemId;
  final String name;
  final double unitPrice;
  final int qty;
  final String? notes;
  final String? variantName;

  double get lineTotal => unitPrice * qty;

  CartLine copyWith({int? qty, String? notes}) => CartLine(
    itemId: itemId,
    name: name,
    unitPrice: unitPrice,
    qty: qty ?? this.qty,
    notes: notes ?? this.notes,
    variantName: variantName,
  );
}

/// Everything needed to create one POS order. Built by the Sell screen and
/// by the guest storefront; saved by [PosRepository.placeOrder].
///
/// This is intent, not fact (platform contract R2): the server prices each
/// line from `menu_items`, takes GST from the organization's bill settings
/// and numbers the order. [bill] is a preview for the screen only.
class PosOrderDraft {
  const PosOrderDraft({
    required this.idempotencyKey,
    required this.serviceType,
    required this.lines,
    this.placedBy = PlacedBy.pos,
    this.table,
    this.guestCount,
    this.customerName,
    this.customerPhone,
    this.notes,
    this.scheduledFor,
    this.fireKitchenTicket = true,
    this.charges = BillCharges.defaults,
  });

  /// False = "Save & hold": the order is saved without a kitchen ticket
  /// (`fire_kot: false`), to be sent to the kitchen later from the POS.
  final bool fireKitchenTicket;

  /// Created when the order is confirmed and kept until the server answers,
  /// across retries and restarts (contract R3). Sending the same key twice
  /// returns the first order instead of making a second one.
  final String idempotencyKey;
  final ServiceType serviceType;
  final List<CartLine> lines;
  final PlacedBy placedBy;
  final DiningTable? table;
  final int? guestCount;
  final String? customerName;
  final String? customerPhone;
  final String? notes;

  /// Pre-orders: when the guest will pick up.
  final DateTime? scheduledFor;

  /// The organization's `org_bill_settings`, for the preview bill.
  final BillCharges charges;

  /// Preview only — the server's total is the one that counts.
  BillSummary get bill => BillSummary.of(
    lines.map((l) => (unitPrice: l.unitPrice, qty: l.qty)),
    charges: charges,
  );

  int get itemCount => lines.fold(0, (n, l) => n + l.qty);
}

/// A saved POS order, as the phone needs it after placing and while tracking.
class PlacedOrder {
  const PlacedOrder({
    required this.id,
    required this.version,
    required this.displayNo,
    required this.status,
    required this.serviceType,
    required this.createdAt,
    required this.lines,
    required this.bill,
    this.table,
    this.paidAmount = 0,
    this.scheduledFor,
    this.customerName,
    this.placedBy = PlacedBy.pos,
  });

  final String id;

  /// `orders.updated_at`, sent back as `expected_updated_at` with every
  /// status change or payment, so a stale screen cannot overwrite a newer one.
  final String version;

  /// "ORD-65005553" — the number guests and the kitchen say out loud.
  final String displayNo;
  final PosStatus status;
  final ServiceType serviceType;
  final DateTime createdAt;
  final List<CartLine> lines;
  final BillSummary bill;
  final DiningTable? table;
  final double paidAmount;
  final DateTime? scheduledFor;
  final String? customerName;
  final PlacedBy placedBy;

  int get itemCount => lines.fold(0, (n, l) => n + l.qty);
  double get due =>
      (bill.payable - paidAmount).clamp(0, double.infinity).toDouble();
  bool get isPaid => status == PosStatus.paid || due <= 0.009;

  PlacedOrder copyWith({
    PosStatus? status,
    double? paidAmount,
    String? version,
  }) => PlacedOrder(
    id: id,
    version: version ?? this.version,
    displayNo: displayNo,
    status: status ?? this.status,
    serviceType: serviceType,
    createdAt: createdAt,
    lines: lines,
    bill: bill,
    table: table,
    paidAmount: paidAmount ?? this.paidAmount,
    scheduledFor: scheduledFor,
    customerName: customerName,
    placedBy: placedBy,
  );
}

/// The steps a guest sees on "Live order tracking", derived from the POS
/// status so the kitchen's taps move the guest's screen.
enum GuestTrackingStep {
  confirmed('Order confirmed', 'We have your order'),
  inKitchen('In the kitchen', 'Your food is being prepared'),
  ready('Ready', "We'll bring it over shortly"),
  onTheWay('On the way', 'Coming to your table'),
  served('Served', 'Enjoy your meal!');

  const GuestTrackingStep(this.title, this.subtitle);
  final String title;
  final String subtitle;

  static GuestTrackingStep fromStatus(PosStatus s) => switch (s) {
    PosStatus.fresh || PosStatus.inBilling => GuestTrackingStep.confirmed,
    PosStatus.sentToKitchen => GuestTrackingStep.inKitchen,
    PosStatus.ready => GuestTrackingStep.ready,
    PosStatus.awaitingPayment ||
    PosStatus.delivered ||
    PosStatus.paid => GuestTrackingStep.served,
    PosStatus.cancelled => GuestTrackingStep.confirmed,
  };
}
