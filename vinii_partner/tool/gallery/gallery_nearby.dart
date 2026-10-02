// An INVENTED feed of orders at "the tables around you", for the design
// gallery only. NOT part of the app and never built into it: a real
// restaurant shows these alerts only when its server shares them (see
// docs/GUEST_SERVER_CONTRACT.md). Nothing here is read from anywhere; the
// table labels and quantities are made up so the alert can be reviewed.
//
// Plain Dart with nothing browser-only in it, so the Dart VM can load it too
// (the offline picture renderer and the tests use it).
import 'dart:async';

import 'package:vinii_partner/application/guest_social.dart';

class GalleryNearby extends GuestNearby {
  /// [itemIds] are the dishes to rotate through (ids from the gallery menu).
  /// An order arrives [startAfter] after someone listens, then one every
  /// [every]. The guest runtime still decides what to show: it keeps to one
  /// alert at a time and skips a dish already in the order.
  GalleryNearby(
    this.itemIds, {
    this.every = const Duration(seconds: 14),
    this.startAfter = const Duration(seconds: 4),
  });

  final List<String> itemIds;
  final Duration every;
  final Duration startAfter;

  static const _tables = ['Table 7', 'Table 4', 'Table 9', 'Table 15'];

  @override
  Stream<NearbyOrder> orders() {
    late final StreamController<NearbyOrder> out;
    Timer? timer;
    var n = 0;

    void emit() {
      if (itemIds.isEmpty || out.isClosed) return;
      // Dishes and tables turn at different rates, and two portions are
      // ordered every third time, so the alert is seen with and without a
      // quantity.
      out.add(
        NearbyOrder(
          id: 'gallery-nearby-$n',
          itemId: itemIds[n % itemIds.length],
          qty: n % 3 == 0 ? 2 : 1,
          who: _tables[n % _tables.length],
          at: DateTime.now(),
        ),
      );
      n++;
    }

    out = StreamController<NearbyOrder>(
      onListen: () {
        timer = Timer(startAfter, () {
          emit();
          timer = Timer.periodic(every, (_) => emit());
        });
      },
      // Cancelling the timers (rather than awaiting Future.delayed) leaves
      // nothing running when the screen goes away.
      onCancel: () {
        timer?.cancel();
        timer = null;
      },
    );
    return out.stream;
  }
}
