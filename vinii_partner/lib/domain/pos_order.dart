import '../l10n/app_localizations.dart';
import 'billing.dart';

/// How the food reaches the guest. Maps to POS `orders.channel`.
///
/// [label] and [hint] are the English fallback for logs and tests; screens
/// show `l10n.serviceTypeLabel(type)` / `serviceTypeHint(type)` instead.
enum ServiceType {
  // i18n-ignore: English fallback for logs/tests, screens use l10n labels
  dineIn('dine_in', 'Dine-in', 'Served at the table'),
  // i18n-ignore: English fallback for logs/tests, screens use l10n labels
  takeaway('pickup', 'Takeaway', 'Picked up at the counter'),
  // i18n-ignore: English fallback for logs/tests, screens use l10n labels
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

  // i18n-ignore: English fallback for logs/tests, screens use posStatusLabel
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
///
/// [label] is the English fallback for logs and tests; screens show
/// `l10n.paymentMethodLabel(method)`.
enum PaymentMethod {
  // i18n-ignore: English fallback for logs/tests, screens use l10n labels
  cash('cash', 'Cash'),
  // i18n-ignore: English fallback for logs/tests, screens use l10n labels
  upi('upi', 'UPI'),
  // i18n-ignore: English fallback for logs/tests, screens use l10n labels
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

  /// "Table 12" in the reader's language; a name that is not a number
  /// ("Counter", "T12") is shown as the restaurant typed it.
  String nameIn(AppLocalizations l) => RegExp(r'^\d+$').hasMatch(label)
      ? l.posTableNumber(number: label)
      : label;

  // i18n-ignore: English fallback for logs/tests, screens use nameIn(l)
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
    this.waiveServiceCharge = false,
    this.waiveReason,
    this.couponCode,
    this.couponDiscount = 0,
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

  /// A manager removed the service charge from this bill before it was sent.
  /// Goes to the server as `waive_service_charge` (only when true); the
  /// server checks the role and records who did it.
  final bool waiveServiceCharge;

  /// Why, in the manager's words. Optional; sent only with a waiver.
  final String? waiveReason;

  /// A coupon code the guest asked to use. Intent only: the server checks it
  /// again when it prices the order (it goes as `coupon_code`, only when set).
  final String? couponCode;

  /// What the server said that code takes off when the guest applied it, so
  /// the preview bill matches. The server's own figure on the order wins.
  final num couponDiscount;

  /// Preview only — the server's total is the one that counts.
  BillSummary get bill => BillSummary.of(
    lines.map((l) => (unitPrice: l.unitPrice, qty: l.qty)),
    charges: charges,
    discount: couponDiscount,
    waiveServiceCharge: waiveServiceCharge,
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
    BillSummary? bill,
  }) => PlacedOrder(
    id: id,
    version: version ?? this.version,
    displayNo: displayNo,
    status: status ?? this.status,
    serviceType: serviceType,
    createdAt: createdAt,
    lines: lines,
    bill: bill ?? this.bill,
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

/// A table as the QR code screen sees it: `dining_tables` with its floor
/// section and its guest code (`qr_token`). Inactive tables are included,
/// because a table taken out of service still has a sticker on it.
class TableCode {
  const TableCode({
    required this.id,
    required this.label,
    this.seats = 4,
    this.areaId,
    this.areaName,
    this.isActive = true,
    this.qrToken,
    this.sortOrder = 0,
  });

  final String id;

  /// "12" or "T12" — shown as "Table 12".
  final String label;
  final int seats;
  final String? areaId;
  final String? areaName;
  final bool isActive;

  /// Ten characters, a–z and 0–9, unique across every restaurant. Null until
  /// a code has been issued for this table.
  final String? qrToken;
  final int sortOrder;

  bool get hasCode => qrToken != null && qrToken!.isNotEmpty;

  /// "Table 12" in the reader's language; a name that is not a number
  /// ("Counter", "T12") is shown as the restaurant typed it.
  String nameIn(AppLocalizations l) => RegExp(r'^\d+$').hasMatch(label)
      ? l.posTableNumber(number: label)
      : label;

  // i18n-ignore: English fallback for logs/tests, screens use nameIn(l)
  String get displayName =>
      RegExp(r'^\d+$').hasMatch(label) ? 'Table $label' : label;

  /// What the sticker holds: `<storefront address>/t/<code>`.
  String? link(String storefrontBaseUrl) {
    if (!hasCode) return null;
    final base = storefrontBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/t/$qrToken';
  }

  DiningTable toDiningTable() =>
      DiningTable(id: id, label: label, seats: seats, area: areaName);
}

/// One row of `channel_integrations`: Swiggy, Zomato and the other places
/// orders come from, each with its own ON/OFF.
class SalesChannel {
  const SalesChannel({
    required this.id,
    required this.key,
    required this.name,
    required this.connected,
    required this.accepting,
  });

  final String id;

  /// `swiggy`, `zomato`, `ondc`, `website`, `whatsapp`, `qr`.
  final String key;

  /// "Swiggy" (the row's `display_name`).
  final String name;

  /// `is_connected`: the channel has been set up. Switching an unconnected
  /// channel does nothing, so the screen does not offer it.
  final bool connected;

  /// `is_accepting`: this channel is ON.
  final bool accepting;

  SalesChannel copyWith({bool? accepting}) => SalesChannel(
    id: id,
    key: key,
    name: name,
    connected: connected,
    accepting: accepting ?? this.accepting,
  );
}
