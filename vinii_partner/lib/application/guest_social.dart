import 'dart:async';

import 'package:flutter/foundation.dart';

/// What the guest can learn about the other tables, behind two small seams so
/// the screens never know where it comes from and never see anything about a
/// person. Both are `null` on every real gateway until the server functions
/// exist (docs/GUEST_SERVER_CONTRACT.md); the screens then show nothing, they
/// never invent activity.
///
/// What the server shares is anonymous by design: a dish, a quantity, a time,
/// and a label the SERVER chose for the table ("Table 7", or "A table near
/// you" if the restaurant prefers not to show numbers). The app shows that
/// label as it is given.

/// One dish another table around this one has just ordered.
@immutable
class NearbyOrder {
  const NearbyOrder({
    required this.id,
    required this.itemId,
    required this.qty,
    required this.who,
    required this.at,
  });

  /// Unique per event, so the same one is never shown twice.
  final String id;
  final String itemId;
  final int qty;

  /// How the server names that table to this guest ("Table 7").
  final String who;
  final DateTime at;
}

/// "Orders as they happen at the tables around this one."
abstract class GuestNearby {
  const GuestNearby();

  /// A stream of orders placed at other tables near this one. It may end or
  /// fail at any time (the screen just stops showing alerts).
  Stream<NearbyOrder> orders();
}

/// One line of another table's order.
@immutable
class TableOrderLine {
  const TableOrderLine({required this.itemId, required this.qty});
  final String itemId;
  final int qty;
}

/// A recent order of a table with a similar party, for the guest to look at
/// and copy ("what did they have?").
@immutable
class TableOrderPreview {
  const TableOrderPreview({
    required this.id,
    required this.who,
    required this.lines,
    required this.orderedAt,
    this.partySize,
  });

  final String id;

  /// How the server names that table ("Table 5" or "A table of 4").
  final String who;

  /// How many people sat at that table, when the server shares it.
  final int? partySize;
  final List<TableOrderLine> lines;
  final DateTime orderedAt;
}

/// "Tables like yours."
abstract class GuestSimilarTables {
  const GuestSimilarTables();

  /// Recent orders of tables with a party near [partySize], newest first,
  /// at most a handful. May be empty.
  Future<List<TableOrderPreview>> forParty({required int partySize});
}
