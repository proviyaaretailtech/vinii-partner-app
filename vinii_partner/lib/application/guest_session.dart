import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/failure.dart';
import '../domain/billing.dart';
import '../domain/guest_catalog.dart';
import '../domain/menu.dart';
import '../domain/pos_order.dart';
import '../domain/storefront.dart';
import 'guest_gateway.dart';

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
           : definition.serviceModes.first;

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
    this.definition = definition;
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

  // ── Choices ───────────────────────────────────────────────────────────
  GuestServiceMode mode;

  /// The table the phone was handed to. Never chosen by the guest.
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
  /// yet, only the food is counted (no invented GST).
  BillSummary get estimate => BillSummary.of(
    lines.map((l) => (unitPrice: l.unitPrice, qty: l.qty)),
    charges:
        _charges ??
        const BillCharges(sgstPercent: 0, cgstPercent: 0, roundOff: false),
  );

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
  }

  void clearCart() {
    lines.clear();
    _notify();
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
      return 'Please call a staff member to confirm your '
          '${definition.tableLabel.toLowerCase()}.';
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
    );
    try {
      final order = await gateway.place(draft);
      placed.add(order);
      pendingKey = null;
      lines.clear();
      notes = '';
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

  /// Longest prep time of the latest order (fallback 15): "15–20 minutes".
  int estimatedMinutes(PlacedOrder order) {
    var m = 0;
    for (final l in order.lines) {
      final p = catalog.item(l.itemId)?.item.prepMinutes ?? 0;
      if (p > m) m = p;
    }
    return m == 0 ? 15 : m;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _watches.values) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
