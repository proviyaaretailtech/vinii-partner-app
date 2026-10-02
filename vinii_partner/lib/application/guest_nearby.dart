import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'guest_social.dart';

/// Turns the stream of orders at the tables around this one into at most one
/// alert at a time for the screen to show ("Table 7 just ordered Chicken
/// Biryani — Add").
///
/// This is a nicety, never part of ordering, so it is built to stay quiet:
///
/// * One alert at a time ([current]). The rest wait, at most [maxWaiting] of
///   them; when more arrive the oldest waiting one is dropped.
/// * After an alert is shown the next one waits at least [cooldown]. If the
///   guest then closes it (or adds the dish) that wait starts again from that
///   moment, so someone who said "not now" is left alone for the full time.
/// * An order older than [maxAge] by the time its turn comes is dropped, and so
///   is one for a dish that was alerted less than [sameDishGap] ago.
/// * [canShow] is asked when an order arrives and again when its turn comes,
///   because the guest may have added the dish, or the dish may have gone off
///   the menu, in between.
/// * An order id is never shown twice.
/// * If the source fails or ends, the feed just stops listening. It never
///   throws and never shows an error.
///
/// Time comes from the `now` clock given to the constructor and from plain
/// [Timer]s only, so a test with fake async drives all of it.
class NearbyFeed extends ChangeNotifier {
  NearbyFeed({
    required this.source,
    required this.canShow,
    this.cooldown = const Duration(seconds: 20),
    this.showFor = const Duration(seconds: 7),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// How many orders may wait behind the one on screen.
  static const maxWaiting = 3;

  /// An order older than this when its turn comes is not worth showing.
  static const maxAge = Duration(seconds: 30);

  /// The same dish is not alerted again within this long.
  static const sameDishGap = Duration(minutes: 2);

  /// How many order ids are remembered (so a replayed order is not shown
  /// twice) before the oldest are forgotten.
  static const _idMemory = 256;

  final GuestNearby source;

  /// Whether this dish is worth an alert for this guest: still on the menu
  /// and not already in their order.
  final bool Function(NearbyOrder order) canShow;

  /// The quietest the feed may be: after an alert is shown, the next one waits
  /// at least this long; and again from the moment the guest closes it.
  final Duration cooldown;

  /// How long an alert stays up when nobody touches it.
  final Duration showFor;

  final DateTime Function() _now;

  NearbyOrder? _current;
  final _waiting = Queue<NearbyOrder>();
  final _seenIds = <String>{};
  final _dishAlertedAt = <String, DateTime>{};

  /// No alert may be shown before this moment.
  DateTime? _quietUntil;

  StreamSubscription<NearbyOrder>? _subscription;
  Timer? _closeTimer;
  Timer? _nextTimer;
  bool _started = false;
  bool _disposed = false;

  /// The alert to show right now, or null.
  NearbyOrder? get current => _current;

  /// Starts listening. Safe to call more than once: it subscribes only the
  /// first time, and never throws.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    try {
      _subscription = source.orders().listen(
        _onOrder,
        onError: (Object _, StackTrace _) => _sourceGone(),
        onDone: _sourceGone,
        cancelOnError: true,
      );
    } catch (_) {
      _subscription = null;
    }
  }

  /// The guest closed the alert.
  void dismiss() => _close(byGuest: true);

  /// The guest added the dish from the alert (closes it).
  void added() => _close(byGuest: true);

  @override
  void dispose() {
    _disposed = true;
    _closeTimer?.cancel();
    _nextTimer?.cancel();
    _closeTimer = _nextTimer = null;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _waiting.clear();
    _current = null;
    super.dispose();
  }

  // ── Coming in ─────────────────────────────────────────────────────────

  void _onOrder(NearbyOrder order) {
    if (_disposed || order.qty < 1) return;
    if (!_remember(order.id)) return;
    if (_isStale(order, _now()) || !_allowed(order)) return;
    _waiting.addLast(order);
    while (_waiting.length > maxWaiting) {
      _waiting.removeFirst();
    }
    _pump();
  }

  /// The source failed or ended: stop listening, quietly. Orders already
  /// waiting still get their turn.
  void _sourceGone() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  /// False when this id was seen before.
  bool _remember(String id) {
    if (!_seenIds.add(id)) return false;
    if (_seenIds.length > _idMemory) _seenIds.remove(_seenIds.first);
    return true;
  }

  // ── Going out ─────────────────────────────────────────────────────────

  /// Shows the next waiting order if nothing is on screen and the quiet time
  /// is over; otherwise arranges to try again when it is.
  void _pump() {
    if (_disposed || _current != null) return;
    _nextTimer?.cancel();
    _nextTimer = null;
    final t = _now();
    final quiet = _quietUntil;
    if (quiet != null && t.isBefore(quiet)) {
      var wait = quiet.difference(t);
      // A clock set backwards must not leave the feed silent for hours.
      if (wait > cooldown) wait = cooldown;
      if (_waiting.isNotEmpty) _nextTimer = Timer(wait, _pump);
      return;
    }
    while (_waiting.isNotEmpty) {
      final order = _waiting.removeFirst();
      if (_isStale(order, t) ||
          _alertedRecently(order.itemId, t) ||
          !_allowed(order)) {
        continue;
      }
      _show(order, t);
      return;
    }
  }

  void _show(NearbyOrder order, DateTime t) {
    _current = order;
    _dishAlertedAt.removeWhere((_, at) => t.difference(at) >= sameDishGap);
    _dishAlertedAt[order.itemId] = t;
    _quietUntil = t.add(cooldown);
    _closeTimer?.cancel();
    _closeTimer = Timer(showFor, _close);
    _notify();
  }

  /// Takes the alert down. When the guest did it, the quiet time starts
  /// again from now; when it simply timed out, it keeps running from when
  /// the alert was shown.
  void _close({bool byGuest = false}) {
    _closeTimer?.cancel();
    _closeTimer = null;
    if (_disposed || _current == null) return;
    _current = null;
    if (byGuest) _quietUntil = _now().add(cooldown);
    _notify();
    _pump();
  }

  // ── Rules ─────────────────────────────────────────────────────────────

  bool _isStale(NearbyOrder order, DateTime t) =>
      t.difference(order.at) > maxAge;

  bool _alertedRecently(String itemId, DateTime t) {
    final last = _dishAlertedAt[itemId];
    if (last == null) return false;
    final since = t.difference(last);
    return !since.isNegative && since < sameDishGap;
  }

  /// [canShow] is the session's; if it ever fails the dish is simply skipped.
  bool _allowed(NearbyOrder order) {
    try {
      return canShow(order);
    } catch (_) {
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
