import 'package:flutter/foundation.dart';

import '../core/money.dart';
import '../domain/guest_catalog.dart';
import 'guest_social.dart';

/// "Tables like yours": what other tables with a similar party recently
/// ordered, matched to this restaurant's menu as it is now, ready to preview
/// and copy into the cart. The server shares only a dish, a quantity, a time
/// and a label for the table (see guest_social.dart); nothing here is invented.

/// One line of a similar table's order, matched to this restaurant's menu.
@immutable
class SimilarLine {
  const SimilarLine({required this.itemId, required this.qty, this.dish});
  final String itemId;
  final int qty;

  /// The dish as it is on the menu now, or null when it is no longer on sale.
  final GuestItem? dish;
  bool get available => dish != null;

  /// What this line comes to in rupees, worked in paise; nothing for a dish
  /// that is gone.
  double get lineTotal {
    final d = dish;
    return d == null ? 0 : fromPaise(toPaise(d.item.price) * qty);
  }
}

/// Another table's recent order, ready to preview and copy.
@immutable
class SimilarTable {
  const SimilarTable({required this.preview, required this.lines});
  final TableOrderPreview preview;
  final List<SimilarLine> lines;

  /// Unique per order, so a list of tables can be keyed.
  String get id => preview.id;

  /// How the server names that table ("Table 5").
  String get who => preview.who;

  /// How many people sat at that table, when the server shares it.
  int? get partySize => preview.partySize;
  DateTime get orderedAt => preview.orderedAt;

  Iterable<SimilarLine> get availableLines => lines.where((l) => l.available);

  /// The lines whose dish is no longer on sale: shown, never counted or added.
  Iterable<SimilarLine> get missingLines => lines.where((l) => !l.available);

  /// Portions of the dishes that are still on sale.
  int get portions => availableLines.fold(0, (n, l) => n + l.qty);

  /// What the dishes still on sale cost, in rupees, summed in paise so it
  /// matches the cart to the paisa.
  double get total => fromPaise(
    availableLines.fold<int>(
      0,
      (sum, l) => sum + toPaise(l.dish!.item.price) * l.qty,
    ),
  );

  /// The lines with a dish that was ordered twice made one (their counts
  /// added), in the order the dishes were first ordered: one row per dish.
  List<SimilarLine> get distinctLines {
    final byDish = <String, SimilarLine>{};
    for (final l in lines) {
      final seen = byDish[l.itemId];
      byDish[l.itemId] = seen == null
          ? l
          : SimilarLine(
              itemId: l.itemId,
              qty: seen.qty + l.qty,
              dish: seen.dish ?? l.dish,
            );
    }
    return byDish.values.toList();
  }

  /// How many portions [picks] come to. A pick of a dish this table did not
  /// order, or that is off the menu now, or of nothing, counts for nothing.
  int portionsOf(Iterable<({String itemId, int qty})> picks) =>
      _priced(picks).fold(0, (n, p) => n + p.qty);

  /// What [picks] come to in rupees, worked in paise (see [portionsOf]).
  double totalOf(Iterable<({String itemId, int qty})> picks) => fromPaise(
    _priced(picks).fold<int>(0, (sum, p) => sum + toPaise(p.price) * p.qty),
  );

  Iterable<({double price, int qty})> _priced(
    Iterable<({String itemId, int qty})> picks,
  ) sync* {
    final dishes = {
      for (final l in availableLines) l.itemId: l.dish!.item.price,
    };
    for (final p in picks) {
      final price = dishes[p.itemId];
      if (price != null && p.qty >= 1) yield (price: price, qty: p.qty);
    }
  }

  /// Calls [add] once for every dish still on sale, in the order they were
  /// ordered, and returns how many portions that was.
  int addTo(void Function(GuestItem dish, int qty) add) {
    var portions = 0;
    for (final l in availableLines) {
      if (l.qty < 1) continue;
      add(l.dish!, l.qty);
      portions += l.qty;
    }
    return portions;
  }
}

/// "Tables like yours": loads the previews when asked (once for a party size,
/// again once they have grown old), resolves them against the menu and copies
/// one into the cart, all of it or just some.
class SimilarTables extends ChangeNotifier {
  SimilarTables({
    required this.source,
    required this.catalog,
    this.staleAfter = const Duration(minutes: 3),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The most tables ever shown.
  static const maxTables = 4;

  final GuestSimilarTables source;
  final GuestCatalog Function() catalog;

  /// How long a load stays fresh for the same party size.
  final Duration staleAfter;
  final DateTime Function() _now;

  List<SimilarTable> _tables = const [];
  bool _loading = false;
  bool _disposed = false;

  /// Counts loads as they start; a result is kept only if it is still the
  /// latest one when it arrives.
  int _generation = 0;
  int? _askedFor;
  DateTime? _askedAt;
  Future<void>? _running;

  /// Previews that still have at least one dish on sale, newest first, at
  /// most [maxTables].
  List<SimilarTable> get tables => _tables;

  /// True while a load runs.
  bool get loading => _loading;

  /// Whether [load] would ask the server for this party size now: nothing was
  /// asked for it yet, or the last ask was more than [staleAfter] ago.
  bool needsLoad(int partySize) {
    final at = _askedAt;
    return _askedFor != partySize ||
        at == null ||
        _now().difference(at) > staleAfter;
  }

  /// Loads (or reloads when [partySize] changed, or the last load is older
  /// than [staleAfter]). Never throws: a failure leaves [tables] empty,
  /// because this is a nicety, not part of ordering.
  Future<void> load({required int partySize}) async {
    if (_disposed) return;
    if (!needsLoad(partySize)) {
      // Loaded (or loading) for this party a moment ago: wait for it if it is
      // still on its way, and do not ask the server again.
      await _running;
      return;
    }
    final mine = ++_generation;
    // Tables seen for another party size are never shown for this one.
    if (_askedFor != partySize) _tables = const [];
    _askedFor = partySize;
    _askedAt = _now();
    _loading = true;
    notifyListeners();
    final run = _fetch(partySize, mine);
    _running = run;
    await run;
  }

  Future<void> _fetch(int partySize, int mine) async {
    List<SimilarTable> found;
    try {
      found = _resolve(await source.forParty(partySize: partySize));
    } catch (_) {
      found = const [];
    }
    // A newer load took over while this one was away: its answer is the one
    // that counts. The same when the guest has left.
    if (_disposed || mine != _generation) return;
    _tables = found;
    _loading = false;
    _running = null;
    notifyListeners();
  }

  /// Newest first, one per order, only dishes the menu still sells, at most
  /// [maxTables]; a preview with nothing left on sale is dropped.
  List<SimilarTable> _resolve(List<TableOrderPreview> previews) {
    final menu = catalog();
    final newestFirst = previews.indexed.toList()
      ..sort((a, b) {
        final byTime = b.$2.orderedAt.compareTo(a.$2.orderedAt);
        // Equal times keep the order the server sent them in.
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    final seen = <String>{};
    final out = <SimilarTable>[];
    for (final (_, preview) in newestFirst) {
      if (!seen.add(preview.id)) continue;
      final table = SimilarTable(
        preview: preview,
        lines: [
          for (final l in preview.lines)
            // A line of nothing is not a line.
            if (l.qty > 0)
              SimilarLine(
                itemId: l.itemId,
                qty: l.qty,
                dish: menu.item(l.itemId),
              ),
        ],
      );
      if (table.availableLines.isEmpty) continue;
      out.add(table);
      if (out.length == maxTables) break;
    }
    return List.unmodifiable(out);
  }

  /// Adds every dish of [table] that is still on sale by calling [add] once
  /// per line, and returns how many portions went in.
  int copyToCart(
    SimilarTable table,
    void Function(GuestItem dish, int qty) add,
  ) => table.addTo(add);

  /// Adds just what the guest picked: each of [picks] (a dish and how many
  /// portions) goes to [add], and the number of portions that went in comes
  /// back. A pick of a dish that is not on the menu, or of nothing, is left
  /// out, so the cart only ever gets what can be sold.
  int copySelected(
    Iterable<({String itemId, int qty})> picks,
    void Function(GuestItem dish, int qty) add,
  ) {
    final menu = catalog();
    var portions = 0;
    for (final p in picks) {
      final dish = menu.item(p.itemId);
      if (dish == null || p.qty < 1) continue;
      add(dish, p.qty);
      portions += p.qty;
    }
    return portions;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
