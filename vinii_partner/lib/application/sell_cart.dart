import 'package:flutter/foundation.dart';

import '../core/failure.dart';
import '../data/backend.dart';
import '../data/local_prefs.dart';
import '../domain/billing.dart';
import '../domain/menu.dart';
import '../domain/pos_order.dart';
import 'sell_keys.dart';

/// Why the order cannot be sent yet. Screens show it in the reader's language
/// through `l10n.sellBlockerText`; [code] is the failure code if a send is
/// attempted anyway, [english] the fallback for logs and tests.
enum SellBlocker {
  empty('sell_blocker_empty', 'Add at least one item.'),
  noTable('sell_blocker_no_table', 'Choose a table for this dine-in order.'),
  noPhone(
    'sell_blocker_no_phone',
    // i18n-ignore: English fallback for logs/tests, screens use l10n
    "Add the customer's phone number for delivery.",
  );

  const SellBlocker(this.code, this.english);
  final String code;

  // i18n-ignore: English fallback for logs/tests, screens use l10n
  final String english;
}

/// What happened when the cashier sent the cart.
class PlaceResult {
  const PlaceResult(this.order, {this.earlierOrder = false});

  /// The order exactly as the server saved it.
  final PlacedOrder order;

  /// True when the server answered with an order this phone sent earlier
  /// (an unanswered attempt was retried with the same key, contract R3) and
  /// its lines differ from the current cart. The cart is then kept, so the
  /// cashier can send it as a new order.
  final bool earlierOrder;
}

/// The phone POS's working order, shared by the Sell and Checkout screens.
///
/// It holds the menu it sells from, the organization's bill settings (for
/// the *estimated* bill only — the server prices the order, contract R2),
/// and the lines, service type, table and customer the cashier picked.
/// It lives in the feature store, so it is thrown away on sign-out and on
/// organization switch: one restaurant's cart can never reach another's.
class SellCart extends ChangeNotifier {
  SellCart({
    required this.menuRepository,
    required this.pos,
    required this.prefs,
    required this.orgId,
  });

  final MenuRepository menuRepository;
  final PosRepository pos;
  final LocalPrefs prefs;
  final String orgId;

  late final _keys = PendingKeys(prefs);
  bool _disposed = false;

  // ── Menu ──────────────────────────────────────────────────────────────

  MenuSnapshot? menu;
  AppFailure? menuFailure;
  bool loadingMenu = false;

  /// `org_bill_settings`, or the OS defaults when they cannot be read. Only
  /// ever used for the estimate.
  BillCharges charges = BillCharges.defaults;

  /// Reads the organization's rates again, so a change made in Bill & GST
  /// shows on the next review without reloading the menu.
  Future<void> refreshCharges() async {
    try {
      charges = await pos.billCharges();
      _notify();
    } on AppFailure {
      // Keep the rates already on screen; the bill is labelled an estimate.
    }
  }

  /// Loads the menu and bill settings. Without [force] it does nothing once
  /// a menu is on screen, so switching tabs does not refetch.
  Future<void> load({bool force = false}) async {
    if (loadingMenu || (menu != null && !force)) return;
    loadingMenu = true;
    menuFailure = null;
    _notify();
    try {
      menu = await menuRepository.load();
      try {
        charges = await pos.billCharges();
      } on AppFailure {
        // The bill is labelled an estimate; the defaults are the OS's own.
        charges = BillCharges.defaults;
      }
    } on AppFailure catch (e) {
      menuFailure = e;
    } catch (e) {
      menuFailure = asFailure(e);
    } finally {
      loadingMenu = false;
      _notify();
    }
  }

  // ── The order being built ─────────────────────────────────────────────

  ServiceType serviceType = ServiceType.dineIn;
  DiningTable? table;
  int guestCount = 2;
  String customerName = '';
  String customerPhone = '';
  String notes = '';
  final _lines = <CartLine>[];

  /// A manager took the service charge off this bill. It goes to the server
  /// with the order, which checks the role and records who did it.
  bool waiveServiceCharge = false;
  String? waiveReason;

  /// True while the order is being sent, so both buttons wait.
  bool placing = false;

  List<CartLine> get lines => List.unmodifiable(_lines);
  bool get isEmpty => _lines.isEmpty;
  int get itemCount => _lines.fold(0, (n, l) => n + l.qty);

  int qtyOf(String itemId) =>
      _lines.where((l) => l.itemId == itemId).firstOrNull?.qty ?? 0;

  CartLine? lineFor(String itemId) =>
      _lines.where((l) => l.itemId == itemId).firstOrNull;

  /// Adds [qty] of [item]. Sold-out items cannot be added.
  void add(MenuItem item, {int qty = 1}) {
    if (!item.isAvailable || qty <= 0) return;
    final i = _lines.indexWhere((l) => l.itemId == item.id);
    if (i >= 0) {
      _lines[i] = _lines[i].copyWith(qty: _lines[i].qty + qty);
    } else {
      _lines.add(
        CartLine(
          itemId: item.id,
          name: item.name,
          unitPrice: item.price,
          qty: qty,
        ),
      );
    }
    _notify();
  }

  /// Sets a line's quantity and note in one go (the long-press sheet). A
  /// quantity of 0 removes the line.
  void setLine(MenuItem item, {required int qty, String? note}) {
    final i = _lines.indexWhere((l) => l.itemId == item.id);
    if (qty <= 0) {
      if (i >= 0) _lines.removeAt(i);
      _notify();
      return;
    }
    if (!item.isAvailable && i < 0) return;
    final line = CartLine(
      itemId: item.id,
      name: item.name,
      unitPrice: i >= 0 ? _lines[i].unitPrice : item.price,
      qty: qty,
      notes: _clean(note),
    );
    if (i >= 0) {
      _lines[i] = line;
    } else {
      _lines.add(line);
    }
    _notify();
  }

  /// The checkout steppers. 0 removes the line.
  void setQty(String itemId, int qty) {
    final i = _lines.indexWhere((l) => l.itemId == itemId);
    if (i < 0) return;
    if (qty <= 0) {
      _lines.removeAt(i);
    } else {
      _lines[i] = _lines[i].copyWith(qty: qty);
    }
    _notify();
  }

  /// [CartLine.copyWith] cannot clear a note, so the line is rebuilt.
  void setLineNote(String itemId, String? note) {
    final i = _lines.indexWhere((l) => l.itemId == itemId);
    if (i < 0) return;
    final l = _lines[i];
    _lines[i] = CartLine(
      itemId: l.itemId,
      name: l.name,
      unitPrice: l.unitPrice,
      qty: l.qty,
      notes: _clean(note),
      variantName: l.variantName,
    );
    _notify();
  }

  void setServiceType(ServiceType t) {
    if (t == serviceType) return;
    serviceType = t;
    _notify();
  }

  void setTable(DiningTable? t) {
    table = t;
    _notify();
  }

  void setGuestCount(int n) {
    guestCount = n.clamp(1, 99);
    _notify();
  }

  /// Text fields call these on every keystroke; they notify so the
  /// "phone needed" hint and the buttons update as the cashier types.
  void setCustomerName(String v) {
    customerName = v;
    _notify();
  }

  void setCustomerPhone(String v) {
    customerPhone = v;
    _notify();
  }

  void setNotes(String v) {
    notes = v;
  }

  /// Removes the service charge from this bill (or puts it back).
  void setServiceChargeWaived(bool waived, {String? reason}) {
    waiveServiceCharge = waived;
    waiveReason = waived ? _clean(reason) : null;
    _notify();
  }

  /// Empties the order after it was saved. The service type stays (a
  /// counter doing takeaways keeps doing takeaways); the table does not.
  void clear() {
    _lines.clear();
    table = null;
    guestCount = 2;
    customerName = '';
    customerPhone = '';
    notes = '';
    waiveServiceCharge = false;
    waiveReason = null;
    _notify();
  }

  // ── Sending ───────────────────────────────────────────────────────────

  /// Why the order cannot be sent yet, or null. Screens turn it into words
  /// with `l10n.sellBlockerText`.
  SellBlocker? get blockerKind {
    if (_lines.isEmpty) return SellBlocker.empty;
    if (serviceType == ServiceType.dineIn && table == null) {
      return SellBlocker.noTable;
    }
    if (serviceType == ServiceType.delivery &&
        _digits(customerPhone).length < 10) {
      return SellBlocker.noPhone;
    }
    return null;
  }

  /// [blockerKind] in English, for logs and tests only.
  // i18n-ignore: English fallback for logs/tests, screens use blockerKind
  String? get blocker => blockerKind?.english;

  /// The order as it would be sent. Only the fields that belong to the
  /// chosen service type go out, so a table picked before switching to
  /// takeaway never reaches the server.
  PosOrderDraft draft({
    required String idempotencyKey,
    bool fireKitchenTicket = true,
    PlacedBy placedBy = PlacedBy.pos,
  }) {
    final dineIn = serviceType == ServiceType.dineIn;
    return PosOrderDraft(
      idempotencyKey: idempotencyKey,
      serviceType: serviceType,
      lines: List.of(_lines),
      placedBy: placedBy,
      table: dineIn ? table : null,
      guestCount: dineIn ? guestCount : null,
      customerName: dineIn ? null : _clean(customerName),
      customerPhone: dineIn ? null : _clean(customerPhone),
      notes: _clean(notes),
      fireKitchenTicket: fireKitchenTicket,
      charges: charges,
      // Only meaningful while the restaurant charges a service charge.
      waiveServiceCharge:
          waiveServiceCharge && charges.serviceChargePercent > 0,
      waiveReason: waiveServiceCharge ? waiveReason : null,
    );
  }

  /// The estimated bill. The POS confirms the final one.
  BillSummary get estimate => draft(idempotencyKey: '').bill;

  BillSummary _estimateWith({required bool waive}) => BillSummary.of(
    _lines.map((l) => (unitPrice: l.unitPrice, qty: l.qty)),
    charges: charges,
    waiveServiceCharge: waive,
  );

  /// The bill with the service charge on it, whether or not it was removed:
  /// what the row shows struck through.
  BillSummary get estimateWithService => _estimateWith(waive: false);

  /// How much less the guest pays if the service charge is removed: the
  /// charge and the GST on it.
  double get serviceChargeSaving =>
      money(estimateWithService.payable - _estimateWith(waive: true).payable);

  /// True when an earlier send from this phone never got an answer; the
  /// next send reuses its key.
  bool get hasPendingSend =>
      _keys.pending(PendingKeys.orderScope(orgId)) != null;

  /// Sends the cart through the POS front door (contract R1) with this
  /// organization's pending key. On success the cart is cleared — unless
  /// the server returned an earlier order for that key (see [PlaceResult]).
  /// Failures are rethrown unchanged and the cart is kept.
  Future<PlaceResult> place({
    required bool fireKitchenTicket,
    required PlacedBy placedBy,
  }) async {
    if (placing) {
      throw const AppFailure(
        'Already sending…',
        kind: FailureKind.rejected,
        code: 'sell_already_sending',
      );
    }
    final why = blockerKind;
    if (why != null) {
      throw AppFailure(why.english, kind: FailureKind.rejected, code: why.code);
    }
    placing = true;
    _notify();
    try {
      late PosOrderDraft sent;
      final order = await _keys.run(PendingKeys.orderScope(orgId), (key) {
        sent = draft(
          idempotencyKey: key,
          fireKitchenTicket: fireKitchenTicket,
          placedBy: placedBy,
        );
        return pos.placeOrder(sent);
      });
      final same = _sameLines(sent.lines, order.lines);
      if (same) clear();
      return PlaceResult(order, earlierOrder: !same);
    } finally {
      placing = false;
      _notify();
    }
  }

  /// Same items in the same quantities. The server re-prices lines, so
  /// prices are not compared.
  static bool _sameLines(List<CartLine> a, List<CartLine> b) {
    Map<String, int> count(List<CartLine> ls) {
      final m = <String, int>{};
      for (final l in ls) {
        m[l.itemId] = (m[l.itemId] ?? 0) + l.qty;
      }
      return m;
    }

    return mapEquals(count(a), count(b));
  }

  static String _digits(String v) => v.replaceAll(RegExp(r'\D'), '');

  static String? _clean(String? v) {
    final s = v?.trim();
    return s == null || s.isEmpty ? null : s;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
