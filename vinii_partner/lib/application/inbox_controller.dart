import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/failure.dart';
import '../data/backend.dart';
import '../domain/delivery_order.dart';
import '../domain/staff.dart';
import 'ring_player.dart';
import 'session_controller.dart';

/// Marketplace delivery orders for the active organization: the four inbox
/// lists, the outlet switch, and the new-order alert queue that rings over
/// whatever screen is open.
///
/// New orders are found by polling `GET /orders?tab=new` every 5 seconds
/// while the restaurant is accepting (every 30 s otherwise), exactly as the
/// partner app does. That poll is also what makes the server expire
/// unanswered orders. Push notifications for a locked phone are a later
/// step (see the plan, §7).
class InboxController extends ChangeNotifier {
  InboxController({required this.session, required this.ring}) {
    session
      ..addListener(_onSession)
      ..onReset(_reset);
  }

  final SessionController session;
  final RingPlayer ring;

  DeliveryInbox get _inbox => session.backend.inbox;

  bool get available => _inbox.available;
  String? get unavailableReason => _inbox.unavailableReason;

  OutletStatus? outlet;
  AppFailure? outletFailure;

  final lists = <InboxTab, List<DeliveryOrder>>{};
  final failures = <InboxTab, AppFailure?>{};
  final loading = <InboxTab>{};

  /// New orders this phone has not answered yet, oldest first. The alert
  /// screen shows the first one.
  final alertQueue = <DeliveryOrder>[];
  final _alerted = <String>{};

  DeliveryOrder? get currentAlert => alertQueue.firstOrNull;

  /// Orders being acted on, so buttons can show progress and not double-send.
  final busy = <String>{};

  Timer? _poller;
  bool _running = false;
  String? _orgId;

  void _onSession() {
    final ready =
        session.stage == SessionStage.ready &&
        session.can(Capability.viewOrders) &&
        available;
    if (ready && (!_running || _orgId != session.membership?.organization.id)) {
      _start();
    } else if (!ready && _running) {
      _reset();
    }
  }

  void _start() {
    _reset();
    _running = true;
    _orgId = session.membership?.organization.id;
    unawaited(refreshOutlet());
    unawaited(_pollNew());
  }

  void _schedule() {
    _poller?.cancel();
    if (!_running) return;
    final accepting = outlet?.accepting ?? true;
    _poller = Timer(Duration(seconds: accepting ? 5 : 30), _pollNew);
  }

  Future<void> _pollNew() async {
    if (!_running) return;
    await refresh(InboxTab.fresh, quiet: true);
    _schedule();
  }

  Future<void> refreshOutlet() async {
    try {
      outlet = await _inbox.outlet();
      outletFailure = null;
    } on AppFailure catch (e) {
      outletFailure = e;
    }
    notifyListeners();
  }

  /// Loads one tab. [quiet] keeps the current list on screen while polling.
  Future<void> refresh(InboxTab tab, {bool quiet = false}) async {
    if (!available) return;
    if (!quiet) {
      loading.add(tab);
      notifyListeners();
    }
    try {
      final rows = await _inbox.list(tab);
      if (!_running && tab == InboxTab.fresh && quiet) return;
      lists[tab] = rows;
      failures[tab] = null;
      if (tab == InboxTab.fresh) _updateAlerts(rows);
    } on AppFailure catch (e) {
      failures[tab] = e;
    } finally {
      loading.remove(tab);
      notifyListeners();
    }
  }

  void _updateAlerts(List<DeliveryOrder> fresh) {
    final ids = {for (final o in fresh) o.id};
    // Answered on another phone, or expired: stop showing it here.
    alertQueue.removeWhere((o) => !ids.contains(o.id));
    for (final o in fresh) {
      final i = alertQueue.indexWhere((a) => a.id == o.id);
      if (i >= 0) {
        alertQueue[i] = o;
      } else if (!_alerted.contains(o.id) &&
          session.can(Capability.acceptOrders)) {
        _alerted.add(o.id);
        alertQueue.add(o);
      }
    }
    if (alertQueue.isNotEmpty) {
      unawaited(ring.start());
    } else {
      unawaited(ring.stop());
    }
  }

  /// Silences the ring without answering (the order stays in New).
  void snooze(String orderId) {
    alertQueue.removeWhere((o) => o.id == orderId);
    if (alertQueue.isEmpty) unawaited(ring.stop());
    notifyListeners();
  }

  Future<void> setAccepting(bool accepting, {DateTime? backAt}) async {
    outlet = await _inbox.setAccepting(accepting, backAt: backAt);
    outletFailure = null;
    notifyListeners();
    _schedule();
  }

  Future<DeliveryOrder> accept(DeliveryOrder o, int prepMinutes) =>
      _act(o, () => _inbox.accept(o, prepMinutes: prepMinutes));
  Future<DeliveryOrder> reject(DeliveryOrder o, String reason) =>
      _act(o, () => _inbox.reject(o, reason: reason));
  Future<DeliveryOrder> markReady(DeliveryOrder o) =>
      _act(o, () => _inbox.markReady(o));
  Future<DeliveryOrder> markOut(DeliveryOrder o) =>
      _act(o, () => _inbox.markOut(o));
  Future<DeliveryOrder> markDelivered(DeliveryOrder o) =>
      _act(o, () => _inbox.markDelivered(o));

  Future<DeliveryOrder> detail(String id) => _inbox.detail(id);

  Future<DeliveryOrder> _act(
    DeliveryOrder o,
    Future<DeliveryOrder> Function() call,
  ) async {
    if (busy.contains(o.id)) {
      throw const AppFailure(
        'Already sending…',
        kind: FailureKind.rejected,
        code: 'orders_already_sending',
      );
    }
    busy.add(o.id);
    notifyListeners();
    try {
      final updated = await call();
      _replace(updated);
      alertQueue.removeWhere((a) => a.id == o.id);
      if (alertQueue.isEmpty) unawaited(ring.stop());
      return updated;
    } on AppFailure catch (e) {
      // Someone else answered first: drop the alert and show the truth.
      if (e.isConflict) {
        alertQueue.removeWhere((a) => a.id == o.id);
        if (alertQueue.isEmpty) unawaited(ring.stop());
        unawaited(refresh(InboxTab.fresh, quiet: true));
      }
      rethrow;
    } finally {
      busy.remove(o.id);
      notifyListeners();
    }
  }

  void _replace(DeliveryOrder updated) {
    for (final tab in InboxTab.values) {
      final list = lists[tab];
      if (list == null) continue;
      list.removeWhere((o) => o.id == updated.id);
      if (tab.statuses.contains(updated.status)) list.insert(0, updated);
    }
  }

  /// Settings → "Send test order": creates a fake order for this restaurant
  /// on One Local's side and lets the poll pick it up.
  Future<void> sendTestOrder() async {
    await _inbox.sendTestOrder();
    await refresh(InboxTab.fresh, quiet: true);
  }

  void _reset() {
    _running = false;
    _orgId = null;
    _poller?.cancel();
    _poller = null;
    lists.clear();
    failures.clear();
    loading.clear();
    alertQueue.clear();
    _alerted.clear();
    busy.clear();
    outlet = null;
    outletFailure = null;
    unawaited(ring.stop());
    notifyListeners();
  }

  @override
  void dispose() {
    _poller?.cancel();
    session.removeListener(_onSession);
    unawaited(ring.dispose());
    super.dispose();
  }
}
