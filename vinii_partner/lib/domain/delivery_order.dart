/// A delivery order from a marketplace (One Local today), in the exact shape
/// the partner API returns (`GET /api/partner/orders`). See
/// docs/PLAN_VINII_PARTNER_FLUTTER.md §6 for the contract.
enum DeliveryStatus {
  placed('New'),
  accepted('Preparing'),
  packed('Ready'),
  out('Out for delivery'),
  delivered('Delivered'),
  cancelled('Cancelled');

  const DeliveryStatus(this.label);

  /// English fallback for logs and tests only. Screens use
  /// `context.l10n.deliveryStatusLabel(status)`.
  // i18n-ignore: English fallback for logs/tests
  final String label;

  static DeliveryStatus fromApi(String? v) =>
      DeliveryStatus.values.where((s) => s.name == v).firstOrNull ??
      DeliveryStatus.placed;
}

/// The four inbox tabs and the statuses each one holds (server `TAB_STATUSES`).
enum InboxTab {
  fresh('new', {DeliveryStatus.placed}),
  preparing('preparing', {DeliveryStatus.accepted}),
  ready('ready', {DeliveryStatus.packed, DeliveryStatus.out}),
  past('past', {DeliveryStatus.delivered, DeliveryStatus.cancelled});

  /// Tab titles are words, so they live in the language catalogues:
  /// `context.l10n.inboxTabLabel(tab)`.
  const InboxTab(this.apiName, this.statuses);
  final String apiName;
  final Set<DeliveryStatus> statuses;
}

/// What One Local sends when the customer has no name, and its default way
/// of paying. They are DATA values, not screen text: the screens show them
/// through `firstName()` / `customerDisplayName()` / `orderPaymentLabel()` in
/// order_widgets.dart, which map these known values to the reader's language
/// and show any other text exactly as stored.
// i18n-ignore: server data value, mapped to words in order_widgets.dart
const customerNameFallback = 'Customer';
// i18n-ignore: server data value, mapped to words in order_widgets.dart
const paymentCashOnDelivery = 'Cash on delivery';

/// The sentence the inbox gives when this build has no One Local address. The
/// Orders tab compares against it to show the translated sentence
/// (`failOrdersUnavailable`); any other reason is shown as written.
// i18n-ignore: English fallback, translated through failOrdersUnavailable
const partnerApiUnavailableReason =
    'Delivery orders come from One Local. This build does not have the One Local server address '
    '(PARTNER_API_BASE_URL), so it cannot show them.';

class DeliveryLine {
  const DeliveryLine({
    required this.name,
    required this.qty,
    required this.price,
    this.notes,
  });
  final String name;
  final int qty;
  final double price;
  final String? notes;

  factory DeliveryLine.fromJson(Map<String, dynamic> j) => DeliveryLine(
    name: '${j['name'] ?? ''}',
    qty: (j['qty'] as num?)?.toInt() ?? 1,
    price: (j['price'] as num?)?.toDouble() ?? 0,
    notes: j['notes'] as String?,
  );
}

class OrderEvent {
  const OrderEvent({required this.kind, required this.at, this.message});
  final String kind;
  final String? message;
  final DateTime at;

  factory OrderEvent.fromJson(Map<String, dynamic> j) => OrderEvent(
    kind: '${j['kind']}',
    message: j['message'] as String?,
    at: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
  );

  /// "Accepted", "Kitchen ticket sent"… for the order timeline. English
  /// fallback for logs and tests only: the timeline shows
  /// `orderEventLabel(l10n, event)` from order_widgets.dart.
  // i18n-ignore: English fallback for logs/tests
  String get label => switch (kind) {
    'placed' => 'Order placed',
    'accepted' => 'Accepted',
    'kot_fired' => 'Kitchen ticket sent',
    'kot_preparing' => 'Kitchen started',
    'kot_ready' => 'Ready',
    'out_for_delivery' => 'Out for delivery',
    'delivered' => 'Delivered',
    'paid' => 'Cash collected',
    'rejected' => 'Rejected',
    'timed_out' => 'Not answered in time',
    _ => kind.replaceAll('_', ' '),
  };
}

class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.displayNo,
    required this.status,
    required this.version,
    required this.placedAt,
    required this.customerName,
    required this.items,
    required this.subtotal,
    required this.gst,
    required this.deliveryFee,
    required this.total,
    this.oneLocalId,
    this.posStatus,
    this.deadline,
    this.customerPhone,
    this.address,
    this.area,
    this.notes,
    this.payment = paymentCashOnDelivery,
    this.prepMinutes,
    this.cancelReason,
    this.events = const [],
    this.channel = 'One Local',
  });

  /// POS `orders.id` — every action path uses this.
  final String id;
  final String? oneLocalId;

  /// OL-00024
  final String displayNo;
  final DeliveryStatus status;
  final String? posStatus;

  /// POS `orders.updated_at`, sent back unchanged with every action. A stale
  /// version is refused with 409 ("already changed on another phone").
  final String version;
  final DateTime placedAt;

  /// Accept-by time. After it passes, the server cancels the order.
  final DateTime? deadline;
  final String customerName;

  /// Only present while the order is live (accepted / ready / out).
  final String? customerPhone;
  final String? address;
  final String? area;
  final String? notes;
  final List<DeliveryLine> items;
  final double subtotal;
  final double gst;
  final double deliveryFee;
  final double total;
  final String payment;
  final int? prepMinutes;
  final String? cancelReason;
  final List<OrderEvent> events;

  /// Which marketplace sent it. One Local only, for now.
  final String channel;

  int get itemCount => items.fold(0, (n, l) => n + l.qty);

  Duration timeLeft([DateTime? now]) {
    if (deadline == null) return Duration.zero;
    final left = deadline!.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  factory DeliveryOrder.fromJson(Map<String, dynamic> j) {
    final address = j['address'];
    String? addressText, area;
    if (address is Map) {
      area = (address['area'] ?? address['locality']) as String?;
      addressText = [address['label'], address['line'] ?? address['text'], area]
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toSet()
          .join(', ');
      if (addressText.isEmpty) addressText = null;
    }
    double n(Object? v) => (v as num?)?.toDouble() ?? 0;
    return DeliveryOrder(
      id: '${j['id']}',
      oneLocalId: j['one_local_id'] as String?,
      displayNo: '${j['display_no'] ?? ''}',
      status: DeliveryStatus.fromApi(j['status'] as String?),
      posStatus: j['pos_status'] as String?,
      version: '${j['version']}',
      placedAt: DateTime.tryParse('${j['placed_at']}') ?? DateTime.now(),
      deadline: j['deadline'] == null
          ? null
          : DateTime.tryParse('${j['deadline']}'),
      customerName: '${j['customer_name'] ?? customerNameFallback}',
      customerPhone: j['customer_phone'] as String?,
      address: addressText,
      area: area,
      notes: j['notes'] as String?,
      items: [
        for (final l in (j['items'] as List? ?? const []))
          if (l is Map<String, dynamic>) DeliveryLine.fromJson(l),
      ],
      subtotal: n(j['subtotal']),
      gst: n(j['gst']),
      deliveryFee: n(j['delivery_fee']),
      total: n(j['total']),
      payment: '${j['payment'] ?? paymentCashOnDelivery}',
      prepMinutes: (j['prep_minutes'] as num?)?.toInt(),
      cancelReason: j['cancel_reason'] as String?,
      events: [
        for (final e in (j['events'] as List? ?? const []))
          if (e is Map<String, dynamic>) OrderEvent.fromJson(e),
      ],
    );
  }

  DeliveryOrder copyWith({
    DeliveryStatus? status,
    String? version,
    int? prepMinutes,
    String? cancelReason,
    List<OrderEvent>? events,
    String? customerPhone,
  }) => DeliveryOrder(
    id: id,
    oneLocalId: oneLocalId,
    displayNo: displayNo,
    status: status ?? this.status,
    posStatus: posStatus,
    version: version ?? this.version,
    placedAt: placedAt,
    deadline: deadline,
    customerName: customerName,
    customerPhone: customerPhone ?? this.customerPhone,
    address: address,
    area: area,
    notes: notes,
    items: items,
    subtotal: subtotal,
    gst: gst,
    deliveryFee: deliveryFee,
    total: total,
    payment: payment,
    prepMinutes: prepMinutes ?? this.prepMinutes,
    cancelReason: cancelReason ?? this.cancelReason,
    events: events ?? this.events,
    channel: channel,
  );
}

/// Whether the restaurant is taking marketplace orders (`GET /me` →
/// `restaurant`, `PATCH /outlet`).
class OutletStatus {
  const OutletStatus({
    required this.accepting,
    this.backAt,
    this.defaultPrepMinutes = 20,
    this.acceptWindowSeconds = 60,
    this.missedInARow = 0,
    this.address,
    this.setUp = true,
  });

  final bool accepting;
  final DateTime? backAt;
  final int defaultPrepMinutes;
  final int acceptWindowSeconds;

  /// Three misses in a row switch accepting off (PRD PD2).
  final int missedInARow;
  final String? address;

  /// False when the restaurant has no One Local channel yet.
  final bool setUp;

  factory OutletStatus.fromJson(Map<String, dynamic> j) => OutletStatus(
    accepting: j['accepting'] == true,
    backAt: j['back_at'] == null ? null : DateTime.tryParse('${j['back_at']}'),
    defaultPrepMinutes: (j['default_prep_minutes'] as num?)?.toInt() ?? 20,
    acceptWindowSeconds: (j['accept_window_seconds'] as num?)?.toInt() ?? 60,
    missedInARow: (j['missed_in_a_row'] as num?)?.toInt() ?? 0,
    address: j['address'] as String?,
    setUp: j['set_up'] != false,
  );
}

/// Prep-time chips on accept (PRD PD3) and reject reasons (partner app).
/// The reasons are what One Local receives and shows the customer, so they
/// are sent in English whatever the app language; the sheet shows each in the
/// reader's language through `rejectReasonLabel()` in order_widgets.dart.
const prepTimeChoices = [10, 15, 20, 30, 45];
// i18n-ignore: values sent to One Local, labelled through rejectReasonLabel()
const rejectReasons = [
  'Item out of stock',
  'Kitchen busy',
  'Closing soon',
  'Other',
];
