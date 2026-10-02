import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/failure.dart';
import '../domain/billing.dart';
import '../domain/guest_catalog.dart';
import '../domain/menu.dart';
import '../domain/pos_order.dart';
import '../domain/storefront.dart';
import 'guest_coupons.dart';
import 'guest_gateway.dart';
import 'guest_nearby.dart';
import 'guest_similar.dart';

/// How the guest browses the menu: swiping through dish cards, or the
/// traditional menu of blocks. The guest can switch at any time.
enum GuestBrowseView { swipe, menu }

/// One guest party's visit, from "Start exploring" to the bill: what they
/// chose, their budget, their cart and the orders they placed. Screens of the
/// guest runtime read and change only this; it reaches the outside world only
/// through [gateway], so the same session runs handed-over, in Studio's
/// preview and in tests.
class GuestSession extends ChangeNotifier {
  GuestSession({
    required this.definition,
    required MenuSnapshot menu,
    required this.gateway,
    this.table,
    DateTime? now,
  }) : catalog = GuestCatalog(menu: menu, definition: definition, now: now),
       mode = definition.serviceModes.isEmpty
           ? GuestServiceMode.dineIn
           : definition.serviceModes.first,
       language = definition.guestLanguage;

  /// Replaced by [reconfigure] while Studio's live preview is being edited.
  StorefrontDefinition definition;
  GuestCatalog catalog;
  final GuestOrderGateway gateway;

  /// Studio edits the storefront while its preview is open: the party keeps
  /// its place and cart, and only what the new settings forbid is undone.
  void reconfigure({
    required StorefrontDefinition definition,
    required MenuSnapshot menu,
  }) {
    final previous = this.definition;
    this.definition = definition;
    // A new default restarts the party there; a language whose text was
    // removed falls back to it.
    if (definition.guestLanguage != previous.guestLanguage ||
        (!languages.contains(language) &&
            language != definition.guestLanguage)) {
      language = definition.guestLanguage;
    }
    catalog = GuestCatalog(menu: menu, definition: definition);
    if (!definition.serviceModes.contains(mode) &&
        definition.serviceModes.isNotEmpty) {
      mode = definition.serviceModes.first;
    }
    if (!definition.features.budget.enabled) budget = null;
    if (!definition.features.likes) liked.clear();
    _notify();
  }

  GuestFeatures get features => definition.features;

  /// Alerts for what the tables around are ordering, when the restaurant's
  /// server shares it (otherwise null and nothing is ever shown).
  late final NearbyFeed? nearbyFeed = gateway.nearby == null
      ? null
      : NearbyFeed(
          source: gateway.nearby!,
          canShow: (o) =>
              catalog.item(o.itemId) != null && qtyOf(o.itemId) == 0,
        );

  /// "Tables like yours", when the server shares it.
  late final SimilarTables? similar = gateway.similarTables == null
      ? null
      : SimilarTables(source: gateway.similarTables!, catalog: () => catalog);

  // ── Choices ───────────────────────────────────────────────────────────
  GuestServiceMode mode;

  GuestBrowseView? _browseView;

  /// Whether the guest may choose how to browse: only when the restaurant
  /// has the swipe deck on. With it off the menu is the only view.
  bool get canSwitchView => features.swipeDeck;

  /// The view the guest is browsing in. Starts as the swipe deck (the
  /// restaurant's signature) and remembers the guest's last choice for the
  /// rest of the visit.
  GuestBrowseView get browseView => !features.swipeDeck
      ? GuestBrowseView.menu
      : (_browseView ?? GuestBrowseView.swipe);

  void setBrowseView(GuestBrowseView v) {
    if (browseView == v || !canSwitchView) return;
    _browseView = v;
    _notify();
  }

  /// The language the party reads the restaurant's guest text in. Starts
  /// at the storefront's default language; text missing in it falls back
  /// to the restaurant's English, then the registry's English.
  CopyLanguage language;

  /// The languages the party can switch between: English and every
  /// language the restaurant wrote guest text in.
  List<CopyLanguage> get languages => definition.copy.guestLanguages;

  void setLanguage(CopyLanguage l) {
    if (l == language) return;
    language = l;
    _notify();
  }

  /// The table, from the QR code on it (or the table a staff member handed
  /// the phone to). Never typed or picked by the guest.
  final DiningTable? table;

  /// "Table 12" (or "Room 12"): the storefront's own word for a table plus
  /// the table's number; unusual labels ("Patio 3") are shown as they are.
  String? get tableName {
    final t = table;
    if (t == null) return null;
    final m = RegExp(r'^[A-Za-z]{0,2}\s*(\d+[A-Za-z]?)$').firstMatch(t.label);
    return m == null ? t.label : '${definition.tableLabel} ${m.group(1)}';
  }

  /// Pre-order pickup slot.
  DateTime? scheduledFor;
  int partySize = 2;

  /// Null = no budget (skipped, or the feature is off): no rings anywhere.
  double? budget;

  /// The party & budget question was answered (saved or skipped): it is
  /// asked once per visit, not again on "Order more".
  bool budgetAsked = false;

  /// Delivery contact details, only asked for delivery.
  String customerName = '';
  String customerPhone = '';
  String addressNote = '';
  String notes = '';

  // ── Cart ──────────────────────────────────────────────────────────────
  final List<CartLine> lines = [];
  final Set<String> liked = {};

  /// Cards swiped away (either way) — the deck does not show them again.
  final Set<String> seen = {};
  final Set<String> skipped = {};

  // ── Placing & tracking ────────────────────────────────────────────────
  /// Created on the first "Place order" tap and reused on every retry until
  /// the server answers, so a retry never makes a second order (R3).
  String? pendingKey;
  bool placing = false;
  AppFailure? placeError;
  final List<PlacedOrder> placed = [];

  /// Preview only: the step the owner advanced to with "Next step".
  GuestTrackingStep previewStep = GuestTrackingStep.confirmed;
  final _watches = <String, StreamSubscription<PlacedOrder>>{};

  BillCharges? _charges;
  BillCharges? get charges => _charges;
  bool _disposed = false;

  Future<void> loadCharges() async {
    try {
      _charges = await gateway.charges();
      _notify();
    } catch (_) {
      // The estimate falls back to items only; the server bill is exact.
    }
  }

  // ── Cart maths ────────────────────────────────────────────────────────
  int qtyOf(String itemId) =>
      lines.where((l) => l.itemId == itemId).fold(0, (n, l) => n + l.qty);

  int get itemCount => lines.fold(0, (n, l) => n + l.qty);

  /// The pre-order bill, labelled "Estimated" everywhere. Without charges
  /// yet, only the food is counted (no invented GST). An applied coupon takes
  /// off what the server said it takes off.
  BillSummary get estimate => BillSummary.of(
    lines.map((l) => (unitPrice: l.unitPrice, qty: l.qty)),
    charges:
        _charges ??
        const BillCharges(sgstPercent: 0, cgstPercent: 0, roundOff: false),
    discount: coupon?.discount ?? 0,
  );

  // ── Coupon ────────────────────────────────────────────────────────────
  /// The coupon the server accepted for the cart as it stands, or null.
  CouponResult? coupon;

  /// Why the last code did not apply, in the guest's words.
  String? couponMessage;
  bool couponChecking = false;
  int _couponRun = 0;
  Timer? _couponTimer;

  /// Whether this restaurant takes coupon codes at all (the server offers a
  /// check). When not, the checkout shows no coupon row.
  bool get canUseCoupons => gateway.coupons != null;

  /// Asks the server whether [raw] applies to this cart. The answer replaces
  /// any coupon already applied; a newer question beats an older answer.
  Future<void> applyCoupon(String raw) async {
    final code = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final service = gateway.coupons;
    if (service == null) return;
    if (code.isEmpty) {
      couponMessage = 'Enter a coupon code.';
      _notify();
      return;
    }
    final run = ++_couponRun;
    couponChecking = true;
    couponMessage = null;
    _notify();
    try {
      final r = await service.check(
        code: code,
        lines: List.of(lines),
        serviceType: serviceType,
      );
      if (run != _couponRun) return;
      coupon = r.valid ? r : null;
      couponMessage = r.valid
          ? null
          : (r.message ?? "That code doesn't apply.");
    } catch (e) {
      if (run != _couponRun) return;
      couponMessage = asFailure(e).message;
    } finally {
      if (run == _couponRun) {
        couponChecking = false;
        _notify();
      }
    }
  }

  /// Takes the coupon off (the guest closed it).
  void removeCoupon() {
    _couponRun++;
    _couponTimer?.cancel();
    coupon = null;
    couponMessage = null;
    couponChecking = false;
    _notify();
  }

  /// The cart changed: a coupon that was applied is asked about again a
  /// moment later (a minimum order or a dish may no longer fit), so the
  /// discount on screen never outlives the cart it was worked out for.
  void _cartChanged() {
    final applied = coupon;
    if (applied == null) return;
    _couponTimer?.cancel();
    if (lines.isEmpty) {
      removeCoupon();
      return;
    }
    _couponTimer = Timer(const Duration(milliseconds: 350), () async {
      final before = applied.code;
      await applyCoupon(before);
      if (coupon == null && couponMessage != null) {
        couponMessage = 'Coupon $before was taken off: $couponMessage';
        _notify();
      }
    });
  }

  /// Everything this party has committed to: placed bills (server figures)
  /// plus the current cart's estimate.
  double get spent =>
      placed.fold<double>(0, (s, o) => s + o.bill.payable) + estimate.payable;

  BudgetStatus? get budgetStatus =>
      budget == null ? null : BudgetStatus(budget: budget!, spent: spent);

  /// Adds [qty] of [item]. Returns the new quantity.
  int add(GuestItem item, {int qty = 1}) {
    final i = lines.indexWhere((l) => l.itemId == item.item.id);
    if (i < 0) {
      lines.add(
        CartLine(
          itemId: item.item.id,
          name: item.item.name,
          unitPrice: item.item.price,
          qty: qty,
        ),
      );
    } else {
      lines[i] = lines[i].copyWith(qty: lines[i].qty + qty);
    }
    _notify();
    _cartChanged();
    return qtyOf(item.item.id);
  }

  void setQty(String itemId, int qty) {
    final i = lines.indexWhere((l) => l.itemId == itemId);
    if (i < 0) return;
    if (qty <= 0) {
      lines.removeAt(i);
    } else {
      lines[i] = lines[i].copyWith(qty: qty);
    }
    _notify();
    _cartChanged();
  }

  void clearCart() {
    lines.clear();
    _notify();
    _cartChanged();
  }

  void toggleLike(String itemId) {
    if (!liked.remove(itemId)) liked.add(itemId);
    _notify();
  }

  void markSeen(String itemId, {required bool skippedIt}) {
    seen.add(itemId);
    if (skippedIt) skipped.add(itemId);
    _notify();
  }

  /// "Start over" at the end of a deck.
  void resetSeen(Iterable<String> itemIds) {
    seen.removeAll(itemIds);
    skipped.removeAll(itemIds);
    _notify();
  }

  void update(VoidCallback change) {
    change();
    _notify();
  }

  // ── Placing ───────────────────────────────────────────────────────────
  ServiceType get serviceType => switch (mode) {
    GuestServiceMode.dineIn => ServiceType.dineIn,
    GuestServiceMode.takeaway ||
    GuestServiceMode.preOrder => ServiceType.takeaway,
    GuestServiceMode.delivery => ServiceType.delivery,
  };

  /// Why "Place order" cannot be pressed yet, in the guest's words; null
  /// when it can.
  String? get blocker {
    if (lines.isEmpty) return 'Add something to your order first.';
    if (mode == GuestServiceMode.dineIn &&
        table == null &&
        !gateway.isPreview) {
      return 'Scan the QR code on your '
          '${definition.tableLabel.toLowerCase()} to order from it.';
    }
    if (mode == GuestServiceMode.preOrder && scheduledFor == null) {
      return 'Choose a pickup time first.';
    }
    if (mode == GuestServiceMode.delivery &&
        (customerName.trim().isEmpty ||
            customerPhone.trim().length < 10 ||
            addressNote.trim().isEmpty)) {
      return 'Add your name, phone and address for delivery.';
    }
    return null;
  }

  String? get _composedNotes {
    final parts = [
      if (mode == GuestServiceMode.delivery && addressNote.trim().isNotEmpty)
        'Deliver to: ${addressNote.trim()}',
      if (notes.trim().isNotEmpty) notes.trim(),
    ];
    return parts.isEmpty ? null : parts.join('\n');
  }

  /// Sends the cart through the gateway. Throws [AppFailure]; the key stays
  /// in [pendingKey] so the next tap retries the same order.
  Future<PlacedOrder> place() async {
    if (placing) throw const AppFailure('Already placing your order.');
    pendingKey ??= const Uuid().v4();
    placing = true;
    placeError = null;
    _notify();
    final delivery = mode == GuestServiceMode.delivery;
    final draft = PosOrderDraft(
      idempotencyKey: pendingKey!,
      serviceType: serviceType,
      lines: List.of(lines),
      placedBy: PlacedBy.guest,
      table: mode == GuestServiceMode.dineIn ? table : null,
      guestCount: mode == GuestServiceMode.dineIn ? partySize : null,
      customerName: delivery ? customerName.trim() : null,
      customerPhone: delivery ? customerPhone.trim() : null,
      notes: _composedNotes,
      scheduledFor: mode == GuestServiceMode.preOrder ? scheduledFor : null,
      charges: _charges ?? BillCharges.defaults,
      couponCode: coupon?.code,
      couponDiscount: coupon?.discount ?? 0,
    );
    try {
      final order = await gateway.place(draft);
      placed.add(order);
      pendingKey = null;
      lines.clear();
      notes = '';
      removeCoupon();
      previewStep = GuestTrackingStep.confirmed;
      _watch(order);
      return order;
    } catch (e) {
      placeError = asFailure(e);
      throw placeError!;
    } finally {
      placing = false;
      _notify();
    }
  }

  PlacedOrder? get latest => placed.isEmpty ? null : placed.last;

  /// "Order the same again": puts the last order's dishes back in the cart,
  /// skipping any that are no longer on sale. Returns how many portions went
  /// in (0 when there is nothing to repeat).
  int repeatLatest() {
    final order = latest;
    if (order == null) return 0;
    var portions = 0;
    for (final l in order.lines) {
      final dish = catalog.item(l.itemId);
      if (dish == null) continue;
      add(dish, qty: l.qty);
      portions += l.qty;
    }
    return portions;
  }

  /// Whether the party was told apart: more than one person to feed, with
  /// splitting turned on, so "for everyone" means something.
  bool get hasParty => features.splitParty && partySize >= 2;

  GuestTrackingStep get step {
    final o = latest;
    if (o == null) return GuestTrackingStep.confirmed;
    return gateway.isPreview
        ? previewStep
        : GuestTrackingStep.fromStatus(o.status);
  }

  /// Preview: shows owners every tracking screen without a kitchen.
  /// [path] is the steps this kind of order shows (takeaway has no "on the
  /// way"), so every tap visibly moves on.
  void advancePreview([List<GuestTrackingStep>? path]) {
    final all = path ?? GuestTrackingStep.values;
    final next = all.where((s) => s.index > previewStep.index).firstOrNull;
    if (next != null) previewStep = next;
    _notify();
  }

  void _watch(PlacedOrder order) {
    if (!features.liveTracking || gateway.isPreview) return;
    _watches[order.id] = gateway
        .watch(order)
        .listen(
          (o) {
            final i = placed.indexWhere((p) => p.id == o.id);
            if (i >= 0) placed[i] = o;
            _notify();
          },
          onError: (Object _) {},
          cancelOnError: false,
        );
  }

  /// The longest prep time among the order's dishes, as the restaurant set
  /// it, or null when none of them has one. The screens then say nothing
  /// about time: a number the restaurant never gave would be a promise the
  /// kitchen did not make.
  int? estimatedMinutes(PlacedOrder order) {
    var m = 0;
    for (final l in order.lines) {
      final p = catalog.item(l.itemId)?.item.prepMinutes ?? 0;
      if (p > m) m = p;
    }
    return m == 0 ? null : m;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _couponTimer?.cancel();
    nearbyFeed?.dispose();
    similar?.dispose();
    for (final s in _watches.values) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
