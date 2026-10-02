// An INVENTED "tables like yours" feed for the design gallery only.
//
// NOT part of the app and never built into it. The tables, their parties and
// the times below are made up so the strip and its sheet can be reviewed
// without a restaurant behind them; the dishes come from the gallery's own
// invented menus (gallery_kit.dart). Nothing here is read from or written to
// Supabase, and the real gateways have no such feed until the server function
// exists (docs/GUEST_SERVER_CONTRACT.md).
//
// Plain Dart with nothing browser-only in it, so the Dart VM can load it too
// (the offline renderer, similar_review_test.dart, does).
import 'package:vinii_partner/application/guest_social.dart';

/// Three pretend tables, newest first. [baskets] holds what each of them
/// ordered, built from the fixture's own dish ids: the first basket is
/// "Table 5", the second "Table 11", the third "Table 2". Fewer baskets mean
/// fewer tables.
class GallerySimilarTables extends GuestSimilarTables {
  GallerySimilarTables(this.baskets);

  final List<List<({String itemId, int qty})>> baskets;

  static const _tables = [
    (who: 'Table 5', partySize: 4, minutesAgo: 12),
    (who: 'Table 11', partySize: 3, minutesAgo: 31),
    (who: 'Table 2', partySize: 5, minutesAgo: 48),
  ];

  /// Whatever the party size asked for, the same three come back: this is a
  /// picture of the feature, not a model of it.
  @override
  Future<List<TableOrderPreview>> forParty({required int partySize}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    return [
      for (var i = 0; i < _tables.length && i < baskets.length; i++)
        TableOrderPreview(
          id: 'gallery-similar-$i',
          who: _tables[i].who,
          partySize: _tables[i].partySize,
          orderedAt: now.subtract(Duration(minutes: _tables[i].minutesAgo)),
          lines: [
            for (final l in baskets[i])
              TableOrderLine(itemId: l.itemId, qty: l.qty),
          ],
        ),
    ];
  }
}
