import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/application/guest_session.dart';
import 'package:vinii_partner/application/guest_similar.dart';
import 'package:vinii_partner/application/guest_social.dart';
import 'package:vinii_partner/core/money.dart';
import 'package:vinii_partner/domain/guest_catalog.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/storefront.dart';
import 'package:vinii_partner/presentation/guest/guest_similar.dart';
import 'package:vinii_partner/presentation/guest/guest_welcome.dart';
import 'package:vinii_partner/presentation/guest/guest_widgets.dart';
import 'package:vinii_partner/presentation/widgets/food_art.dart';

import 'guest_runtime_test.dart'
    show
        RecordingGateway,
        menu,
        noBudget,
        pumpGuest,
        settle,
        storefront,
        table12;

// The test menu (guest_runtime_test.dart): Paneer Tikka ₹600, Chicken Biryani
// ₹400, Brownie ₹150. Anything else is "off the menu".

/// A canned answer from "the server", and a record of every question asked.
class _Source extends GuestSimilarTables {
  _Source([Future<List<TableOrderPreview>> Function(int partySize)? respond])
    : respond = respond ?? ((_) async => const []);

  _Source.fixed(List<TableOrderPreview> previews)
    : respond = ((_) async => previews);

  Future<List<TableOrderPreview>> Function(int partySize) respond;
  final calls = <int>[];

  @override
  Future<List<TableOrderPreview>> forParty({required int partySize}) {
    calls.add(partySize);
    return respond(partySize);
  }
}

/// The recording gateway of the runtime tests, with a tables feed.
class _Gateway extends RecordingGateway {
  _Gateway(this._similar);
  final GuestSimilarTables? _similar;

  @override
  GuestSimilarTables? get similarTables => _similar;
}

const _usual = [
  TableOrderLine(itemId: 'i-biryani', qty: 2),
  TableOrderLine(itemId: 'i-paneer', qty: 1),
  TableOrderLine(itemId: 'i-brownie', qty: 1),
];

TableOrderPreview _preview(
  String id, {
  String who = 'Table 5',
  int? party = 4,
  int minutesAgo = 12,
  DateTime? at,
  List<TableOrderLine> lines = _usual,
}) => TableOrderPreview(
  id: id,
  who: who,
  partySize: party,
  lines: lines,
  orderedAt: at ?? DateTime.now().subtract(Duration(minutes: minutesAgo)),
);

List<String> _ids(SimilarTables t) => [for (final x in t.tables) x.id];

void main() {
  group('SimilarTables', () {
    late GuestCatalog catalog;
    setUp(() => catalog = GuestCatalog(menu: menu, definition: storefront()));

    SimilarTables make(GuestSimilarTables source, {DateTime Function()? now}) =>
        SimilarTables(source: source, catalog: () => catalog, now: now);

    final base = DateTime(2026, 10, 2, 13);
    DateTime ago(int minutes) => base.subtract(Duration(minutes: minutes));

    test('starts empty and idle', () {
      final t = make(_Source());
      expect(t.tables, isEmpty);
      expect(t.loading, isFalse);
    });

    test('lines are matched to the menu as it is now', () async {
      final t = make(
        _Source.fixed([
          _preview(
            'a',
            lines: const [
              TableOrderLine(itemId: 'i-biryani', qty: 2),
              TableOrderLine(itemId: 'i-gone', qty: 3),
            ],
          ),
        ]),
      );
      await t.load(partySize: 4);
      final table = t.tables.single;
      expect(table.lines, hasLength(2));
      expect(table.lines[0].dish!.item.name, 'Chicken Biryani');
      expect(table.lines[0].available, isTrue);
      expect(table.lines[1].itemId, 'i-gone');
      expect(table.lines[1].dish, isNull);
      expect(table.lines[1].available, isFalse);
      // The dish that left the menu is never counted.
      expect(table.availableLines, hasLength(1));
      expect(table.missingLines, hasLength(1));
      expect(table.portions, 2);
      expect(table.total, 800);
      expect(table.who, 'Table 5');
      expect(table.partySize, 4);
    });

    test('a dish that is off sale on the menu counts as gone', () async {
      // Switched off in the POS, or priced at nothing: not on the catalog.
      const offSale = MenuSnapshot(
        categories: [MenuCategory(id: 'c', name: 'Mains')],
        items: [
          MenuItem(id: 'on', name: 'On', price: 100, categoryId: 'c'),
          MenuItem(
            id: 'off',
            name: 'Off',
            price: 100,
            categoryId: 'c',
            isAvailable: false,
          ),
          MenuItem(id: 'free', name: 'Free', price: 0, categoryId: 'c'),
        ],
      );
      catalog = GuestCatalog(menu: offSale, definition: storefront());
      final t = make(
        _Source.fixed([
          _preview(
            'a',
            lines: const [
              TableOrderLine(itemId: 'on', qty: 1),
              TableOrderLine(itemId: 'off', qty: 1),
              TableOrderLine(itemId: 'free', qty: 1),
            ],
          ),
        ]),
      );
      await t.load(partySize: 2);
      expect(
        [for (final l in t.tables.single.lines) l.available],
        [true, false, false],
      );
    });

    test('drops previews with no dish left on sale', () async {
      final t = make(
        _Source.fixed([
          _preview(
            'all-gone',
            lines: const [TableOrderLine(itemId: 'i-gone', qty: 1)],
          ),
          _preview('empty', lines: const []),
          _preview(
            'nothing-ordered',
            lines: const [TableOrderLine(itemId: 'i-biryani', qty: 0)],
          ),
          _preview(
            'half',
            minutesAgo: 5,
            lines: const [
              TableOrderLine(itemId: 'i-gone', qty: 1),
              TableOrderLine(itemId: 'i-paneer', qty: 1),
            ],
          ),
        ]),
      );
      await t.load(partySize: 4);
      expect(_ids(t), ['half']);
    });

    test('a line of nothing or less is not a line', () async {
      final t = make(
        _Source.fixed([
          _preview(
            'a',
            lines: const [
              TableOrderLine(itemId: 'i-biryani', qty: 0),
              TableOrderLine(itemId: 'i-paneer', qty: -2),
              TableOrderLine(itemId: 'i-brownie', qty: 1),
            ],
          ),
        ]),
      );
      await t.load(partySize: 4);
      expect([for (final l in t.tables.single.lines) l.itemId], ['i-brownie']);
    });

    test('keeps the four newest, newest first', () async {
      final t = make(
        _Source.fixed([
          _preview('m30', at: ago(30)),
          _preview('m5', at: ago(5)),
          _preview('m50', at: ago(50)),
          _preview('m10', at: ago(10)),
          _preview('m90', at: ago(90)),
          _preview('m20', at: ago(20)),
        ]),
      );
      await t.load(partySize: 4);
      expect(_ids(t), ['m5', 'm10', 'm20', 'm30']);
      expect(SimilarTables.maxTables, 4);
    });

    test('the cap counts only tables with something to show', () async {
      final gone = [const TableOrderLine(itemId: 'i-gone', qty: 1)];
      final t = make(
        _Source.fixed([
          _preview('x1', at: ago(1), lines: gone),
          _preview('x2', at: ago(2), lines: gone),
          for (var i = 3; i <= 8; i++) _preview('ok$i', at: ago(i)),
        ]),
      );
      await t.load(partySize: 4);
      expect(_ids(t), ['ok3', 'ok4', 'ok5', 'ok6']);
    });

    test('equal times keep the order the server sent', () async {
      final t = make(
        _Source.fixed([
          _preview('first', at: ago(10)),
          _preview('second', at: ago(10)),
          _preview('third', at: ago(10)),
        ]),
      );
      await t.load(partySize: 4);
      expect(_ids(t), ['first', 'second', 'third']);
    });

    test('one table per order, the newest copy', () async {
      final t = make(
        _Source.fixed([
          _preview('same', at: ago(40), who: 'Table 1'),
          _preview('same', at: ago(10), who: 'Table 2'),
          _preview('other', at: ago(20)),
        ]),
      );
      await t.load(partySize: 4);
      expect(_ids(t), ['same', 'other']);
      expect(t.tables.first.who, 'Table 2');
    });

    test('the list cannot be changed from outside', () async {
      final t = make(_Source.fixed([_preview('a')]));
      await t.load(partySize: 4);
      expect(() => t.tables.add(t.tables.first), throwsUnsupportedError);
    });

    test('a failure leaves nothing and never throws', () async {
      final asyncFail = make(_Source((_) async => throw StateError('boom')));
      await asyncFail.load(partySize: 4);
      expect(asyncFail.tables, isEmpty);
      expect(asyncFail.loading, isFalse);

      // Also when the source throws before it even returns a future.
      final syncFail = make(_Source((_) => throw StateError('boom')));
      await syncFail.load(partySize: 4);
      expect(syncFail.tables, isEmpty);
      expect(syncFail.loading, isFalse);
    });

    test('a failure after a good load empties the list', () async {
      var fail = false;
      final source = _Source((_) async {
        if (fail) throw StateError('offline');
        return [_preview('a')];
      });
      var clock = base;
      final t = make(source, now: () => clock);
      await t.load(partySize: 4);
      expect(_ids(t), ['a']);

      fail = true;
      clock = base.add(const Duration(minutes: 4));
      await t.load(partySize: 4);
      expect(t.tables, isEmpty);
      expect(t.loading, isFalse);
    });

    test(
      'loading is true while a load runs, and listeners hear both ends',
      () async {
        final answer = Completer<List<TableOrderPreview>>();
        final t = make(_Source((_) => answer.future));
        var heard = 0;
        t.addListener(() => heard++);

        final done = t.load(partySize: 4);
        expect(t.loading, isTrue);
        expect(heard, 1);

        answer.complete([_preview('a')]);
        await done;
        expect(t.loading, isFalse);
        expect(heard, 2);
        expect(_ids(t), ['a']);
      },
    );

    test(
      'a result that arrives after a newer load started is ignored',
      () async {
        final slow = Completer<List<TableOrderPreview>>();
        final source = _Source(
          (party) => party == 2
              ? slow.future
              : Future.value([_preview('new', party: 3)]),
        );
        final t = make(source);
        var heard = 0;
        t.addListener(() => heard++);

        final first = t.load(partySize: 2);
        expect(t.loading, isTrue);
        await t.load(partySize: 3);
        expect(_ids(t), ['new']);
        expect(t.loading, isFalse);
        final heardBefore = heard;

        slow.complete([_preview('old')]);
        await first;
        // The late answer changed nothing and told nobody.
        expect(_ids(t), ['new']);
        expect(t.loading, isFalse);
        expect(heard, heardBefore);
      },
    );

    test(
      'an old answer does not stop a newer load from still loading',
      () async {
        final first = Completer<List<TableOrderPreview>>();
        final second = Completer<List<TableOrderPreview>>();
        final answers = [first, second];
        final t = make(_Source((_) => answers.removeAt(0).future));

        final a = t.load(partySize: 2);
        final b = t.load(partySize: 3);
        first.complete([_preview('old')]);
        await a;
        expect(t.loading, isTrue, reason: 'the newer load is still away');
        expect(t.tables, isEmpty);

        second.complete([_preview('new')]);
        await b;
        expect(t.loading, isFalse);
        expect(_ids(t), ['new']);
      },
    );

    test('an old answer does not rescue a newer load that failed', () async {
      final slow = Completer<List<TableOrderPreview>>();
      final t = make(
        _Source(
          (party) =>
              party == 2 ? slow.future : Future.error(StateError('offline')),
        ),
      );
      final first = t.load(partySize: 2);
      await t.load(partySize: 3);
      slow.complete([_preview('old')]);
      await first;
      expect(t.tables, isEmpty);
    });

    group('asks again', () {
      late _Source source;
      late DateTime clock;
      late SimilarTables t;

      setUp(() {
        source = _Source((_) async => [_preview('a')]);
        clock = base;
        t = make(source, now: () => clock);
      });

      test('not for the same party size a moment later', () async {
        await t.load(partySize: 4);
        await t.load(partySize: 4);
        clock = base.add(const Duration(minutes: 2, seconds: 59));
        await t.load(partySize: 4);
        expect(source.calls, [4]);
      });

      test('when the party size changed', () async {
        await t.load(partySize: 4);
        await t.load(partySize: 2);
        await t.load(partySize: 4);
        expect(source.calls, [4, 2, 4]);
      });

      test('when the last load is older than three minutes', () async {
        await t.load(partySize: 4);
        clock = base.add(const Duration(minutes: 3, seconds: 1));
        await t.load(partySize: 4);
        expect(source.calls, [4, 4]);

        // The three minutes run from the latest load.
        clock = clock.add(const Duration(minutes: 2));
        await t.load(partySize: 4);
        expect(source.calls, [4, 4]);
      });

      test('not while the same load is still away', () async {
        final answer = Completer<List<TableOrderPreview>>();
        source.respond = (_) => answer.future;
        final first = t.load(partySize: 4);
        final second = t.load(partySize: 4);
        expect(source.calls, [4]);

        answer.complete([_preview('a')]);
        // A caller that waits gets the tables, not an empty list.
        await second;
        expect(_ids(t), ['a']);
        await first;
      });

      test('needsLoad says when the next load would ask the server', () async {
        expect(t.needsLoad(4), isTrue, reason: 'nothing asked yet');
        await t.load(partySize: 4);
        expect(t.needsLoad(4), isFalse);
        expect(t.needsLoad(2), isTrue, reason: 'another party size');
        clock = base.add(const Duration(minutes: 3));
        expect(t.needsLoad(4), isFalse, reason: 'three minutes is not older');
        clock = base.add(const Duration(minutes: 3, seconds: 1));
        expect(t.needsLoad(4), isTrue);
      });

      test('the wait can be changed', () async {
        final quick = make(source, now: () => clock);
        expect(quick.staleAfter, const Duration(minutes: 3));
        final custom = SimilarTables(
          source: source,
          catalog: () => catalog,
          staleAfter: const Duration(seconds: 10),
          now: () => clock,
        );
        await custom.load(partySize: 4);
        clock = base.add(const Duration(seconds: 11));
        await custom.load(partySize: 4);
        expect(source.calls, [4, 4]);
      });

      test(
        'tables seen for another party are not kept while loading',
        () async {
          await t.load(partySize: 4);
          expect(_ids(t), ['a']);

          final answer = Completer<List<TableOrderPreview>>();
          source.respond = (_) => answer.future;
          final next = t.load(partySize: 2);
          expect(t.loading, isTrue);
          expect(t.tables, isEmpty);
          answer.complete([_preview('b')]);
          await next;
          expect(_ids(t), ['b']);
        },
      );

      test('tables stay while the same party is refreshed', () async {
        await t.load(partySize: 4);
        final answer = Completer<List<TableOrderPreview>>();
        source.respond = (_) => answer.future;
        clock = base.add(const Duration(minutes: 5));
        final refresh = t.load(partySize: 4);
        expect(t.loading, isTrue);
        expect(_ids(t), ['a'], reason: 'no flicker while it refreshes');
        answer.complete([_preview('b')]);
        await refresh;
        expect(_ids(t), ['b']);
      });
    });

    test(
      'copyToCart adds each dish still on sale once and counts portions',
      () async {
        final t = make(
          _Source.fixed([
            _preview(
              'a',
              lines: const [
                TableOrderLine(itemId: 'i-biryani', qty: 2),
                TableOrderLine(itemId: 'i-gone', qty: 5),
                TableOrderLine(itemId: 'i-paneer', qty: 1),
                TableOrderLine(itemId: 'i-biryani', qty: 1),
              ],
            ),
          ]),
        );
        await t.load(partySize: 4);
        final added = <(String, int)>[];
        final portions = t.copyToCart(
          t.tables.single,
          (dish, qty) => added.add((dish.item.id, qty)),
        );
        // One call per line, in order; the dish that is gone is left out.
        expect(added, [('i-biryani', 2), ('i-paneer', 1), ('i-biryani', 1)]);
        expect(portions, 4);
      },
    );

    test('copySelected adds just what was picked, as many as picked', () async {
      final t = make(_Source.fixed([_preview('a')]));
      final added = <(String, int)>[];
      final portions = t.copySelected([
        (itemId: 'i-paneer', qty: 3),
        (itemId: 'i-biryani', qty: 1),
      ], (dish, qty) => added.add((dish.item.id, qty)));
      expect(added, [('i-paneer', 3), ('i-biryani', 1)]);
      expect(portions, 4);
    });

    test('copySelected leaves out what cannot be sold or is not asked for', () {
      final t = make(_Source());
      final added = <(String, int)>[];
      final portions = t.copySelected([
        (itemId: 'i-gone', qty: 2),
        (itemId: 'i-biryani', qty: 0),
        (itemId: 'i-brownie', qty: -1),
        (itemId: 'i-paneer', qty: 1),
      ], (dish, qty) => added.add((dish.item.id, qty)));
      expect(added, [('i-paneer', 1)]);
      expect(portions, 1);
      expect(t.copySelected(const [], (_, _) => fail('nothing to add')), 0);
    });

    test('copySelected goes by the menu as it is when the guest taps', () {
      var current = catalog;
      final t = SimilarTables(source: _Source(), catalog: () => current);
      final picks = [(itemId: 'i-paneer', qty: 2)];
      expect(t.copySelected(picks, (_, _) {}), 2);
      // The dish went off sale after the tables were loaded.
      current = GuestCatalog(
        menu: const MenuSnapshot(
          categories: [MenuCategory(id: 'c', name: 'c')],
          items: [],
        ),
        definition: storefront(),
      );
      expect(t.copySelected(picks, (_, _) => fail('off the menu')), 0);
      t.dispose();
    });

    test(
      'what a pick comes to counts only the dishes that can be had',
      () async {
        final t = make(
          _Source.fixed([
            _preview(
              'a',
              lines: const [
                TableOrderLine(itemId: 'i-biryani', qty: 2),
                TableOrderLine(itemId: 'i-gone', qty: 1),
              ],
            ),
          ]),
        );
        await t.load(partySize: 4);
        final table = t.tables.single;
        final picks = [
          (itemId: 'i-biryani', qty: 3),
          (itemId: 'i-gone', qty: 5),
          (itemId: 'i-paneer', qty: 1), // not on this table's order
          (itemId: 'i-biryani', qty: 0),
        ];
        expect(table.portionsOf(picks), 3);
        expect(table.totalOf(picks), 1200);
        expect(table.portionsOf(const []), 0);
        expect(table.totalOf(const []), 0);
      },
    );

    test('a pick is worked in paise, like the cart', () {
      GuestItem dish(String id, double price) => GuestItem(
        item: MenuItem(id: id, name: id, price: price),
        category: const MenuCategory(id: 'c', name: 'c'),
        presentation: ItemPresentation(itemId: id),
        tags: const [],
      );
      final table = SimilarTable(
        preview: _preview('a'),
        lines: [SimilarLine(itemId: 'x', qty: 1, dish: dish('x', 19.99))],
      );
      expect(table.totalOf([(itemId: 'x', qty: 3)]), 59.97);
      expect(table.totalOf([(itemId: 'x', qty: 7)]), 139.93);
    });

    test('a dish ordered on two lines is one row, with both counts', () {
      GuestItem dish(String id) => GuestItem(
        item: MenuItem(id: id, name: id, price: 10),
        category: const MenuCategory(id: 'c', name: 'c'),
        presentation: ItemPresentation(itemId: id),
        tags: const [],
      );
      final table = SimilarTable(
        preview: _preview('a'),
        lines: [
          SimilarLine(itemId: 'a', qty: 1, dish: dish('a')),
          const SimilarLine(itemId: 'gone', qty: 2),
          SimilarLine(itemId: 'b', qty: 1, dish: dish('b')),
          SimilarLine(itemId: 'a', qty: 2, dish: dish('a')),
          const SimilarLine(itemId: 'gone', qty: 1),
        ],
      );
      final rows = table.distinctLines;
      expect([for (final l in rows) l.itemId], ['a', 'gone', 'b']);
      expect([for (final l in rows) l.qty], [3, 3, 1]);
      expect([for (final l in rows) l.available], [true, false, true]);
      // The lines themselves are as they came.
      expect(table.lines, hasLength(5));
    });

    test('copyToCart with nothing on sale adds nothing', () {
      final t = make(_Source());
      final table = SimilarTable(
        preview: _preview('a', lines: const []),
        lines: const [SimilarLine(itemId: 'i-gone', qty: 2)],
      );
      var calls = 0;
      expect(t.copyToCart(table, (_, _) => calls++), 0);
      expect(calls, 0);
    });

    test('money is worked in paise, so it matches the cart', () {
      GuestItem dish(String id, double price) => GuestItem(
        item: MenuItem(id: id, name: id, price: price),
        category: const MenuCategory(id: 'c', name: 'c'),
        presentation: ItemPresentation(itemId: id),
        tags: const [],
      );
      final table = SimilarTable(
        preview: _preview('a'),
        lines: [
          SimilarLine(itemId: 'x', qty: 3, dish: dish('x', 19.99)),
          SimilarLine(itemId: 'y', qty: 3, dish: dish('y', 0.1)),
        ],
      );
      // 3 x 19.99 + 3 x 0.10 would be 60.269999... as plain doubles.
      expect(table.total, 60.27);
      expect(table.lines.first.lineTotal, 59.97);
      expect(table.portions, 6);
    });

    test('a load that comes back after dispose says nothing', () async {
      final answer = Completer<List<TableOrderPreview>>();
      final t = make(_Source((_) => answer.future));
      final done = t.load(partySize: 4);
      t.dispose();
      answer.complete([_preview('a')]);
      await done;
      expect(t.tables, isEmpty);
      // And asking again is simply ignored.
      await t.load(partySize: 5);
    });
  });

  group('the words on a card', () {
    SimilarLine line(String name, {int qty = 1, bool gone = false}) =>
        SimilarLine(
          itemId: name,
          qty: qty,
          dish: gone
              ? null
              : GuestItem(
                  item: MenuItem(id: name, name: name, price: 100),
                  category: const MenuCategory(id: 'c', name: 'c'),
                  presentation: ItemPresentation(itemId: name),
                  tags: const [],
                ),
        );

    SimilarTable table({
      String who = 'Table 5',
      int? party = 4,
      List<SimilarLine>? lines,
    }) => SimilarTable(
      preview: _preview('t', who: who, party: party),
      lines: lines ?? [line('A'), line('B', qty: 2), line('C'), line('D')],
    );

    test('who it was and how many sat there', () {
      expect(similarShortLabel(table()), 'Table 5 · 4');
      expect(similarShortLabel(table(party: 1)), 'Table 5 · 1');
      expect(similarShortLabel(table(party: null)), 'Table 5');
      expect(similarShortLabel(table(party: 0)), 'Table 5');
    });

    test('a name that already says the party is not repeated', () {
      expect(
        similarShortLabel(table(who: 'A table of 4', party: 4)),
        'A table of 4',
      );
      // But a different number is information.
      expect(
        similarShortLabel(table(who: 'A table of 6', party: 4)),
        'A table of 6 · 4',
      );
      // And a table numbered like the party is only a number.
      expect(similarShortLabel(table(who: 'Table 4', party: 4)), 'Table 4 · 4');
    });

    test('a mouse resting on a card is shown the dishes, one to a line', () {
      expect(similarPeek(table()), '1 × A\n2 × B\n1 × C\n1 × D');
      // A dish that is gone is not in it; one ordered twice is one line.
      expect(
        similarPeek(
          table(
            lines: [
              line('A'),
              line('X', gone: true),
              line('A', qty: 2),
              line('B'),
            ],
          ),
        ),
        '3 × A\n1 × B',
      );
    });

    test('a screen reader hears everything the card leaves out', () {
      expect(
        similarSpoken(table()),
        'Table 5, 4 people. A, 2 B, C, D. Total ₹500',
      );
      expect(
        similarSpoken(table(party: 1, lines: [line('A')])),
        'Table 5, 1 person. A. Total ₹100',
      );
      expect(similarSpoken(table(party: null)), startsWith('Table 5. A, '));
      expect(
        similarSpoken(table(who: 'A table of 4')),
        startsWith('A table of 4. A, '),
      );
      // What cannot be had is neither named nor counted.
      expect(
        similarSpoken(table(lines: [line('A'), line('X', gone: true)])),
        'Table 5, 4 people. A. Total ₹100',
      );
    });

    test('how long ago', () {
      expect(similarAgo(Duration.zero), 'Just now');
      expect(similarAgo(const Duration(seconds: 59)), 'Just now');
      expect(similarAgo(const Duration(seconds: -30)), 'Just now');
      expect(similarAgo(const Duration(minutes: 1)), '1 min ago');
      expect(
        similarAgo(const Duration(minutes: 12, seconds: 40)),
        '12 min ago',
      );
      expect(similarAgo(const Duration(minutes: 59)), '59 min ago');
      expect(similarAgo(const Duration(minutes: 60)), '1 hr ago');
      expect(similarAgo(const Duration(hours: 5, minutes: 30)), '5 hr ago');
      expect(similarAgo(const Duration(hours: 24)), '1 day ago');
      expect(similarAgo(const Duration(days: 3, hours: 2)), '3 days ago');
    });
  });

  group('the strip and its sheet', () {
    testWidgets('are not there when the restaurant shares nothing', (
      tester,
    ) async {
      await _pump(tester, source: null);
      expect(find.text('Tables like yours'), findsNothing);
      expect(tester.getSize(find.byType(SimilarTablesStrip)).height, 0);
    });

    testWidgets('are not there when no table has anything to show', (
      tester,
    ) async {
      final source = _Source.fixed([
        _preview('gone', lines: const [TableOrderLine(itemId: 'i-x', qty: 1)]),
      ]);
      await _pump(tester, source: source);
      expect(source.calls, [2], reason: 'it did ask');
      expect(find.text('Tables like yours'), findsNothing);
      expect(find.byKey(const ValueKey('similar-strip')), findsNothing);
      expect(tester.getSize(find.byType(SimilarTablesStrip)).height, 0);
    });

    testWidgets('are not there for a takeaway party', (tester) async {
      final source = _Source.fixed([_preview('a')]);
      await _pump(
        tester,
        source: source,
        definition: storefront(
          features: noBudget,
          modes: const [GuestServiceMode.takeaway],
        ),
      );
      expect(source.calls, isEmpty, reason: 'tables are for dining in');
      expect(find.text('Tables like yours'), findsNothing);
    });

    testWidgets('show a card for each table, in pictures', (tester) async {
      final source = _Source.fixed([
        _preview('t5'),
        _preview(
          't11',
          who: 'Table 11',
          party: 3,
          minutesAgo: 31,
          lines: const [TableOrderLine(itemId: 'i-paneer', qty: 2)],
        ),
        _preview(
          'tn',
          who: 'A table near you',
          party: null,
          minutesAgo: 48,
          lines: const [TableOrderLine(itemId: 'i-brownie', qty: 1)],
        ),
      ]);
      await _pump(tester, source: source);

      expect(source.calls, [2], reason: 'the party is two by default');
      expect(find.text('Tables like yours'), findsOneWidget);
      expect(find.byKey(const ValueKey('similar-card-t5')), findsOneWidget);
      expect(find.byKey(const ValueKey('similar-card-t11')), findsOneWidget);
      expect(find.byKey(const ValueKey('similar-card-tn')), findsOneWidget);

      // Two small bits of text: who (with how many sat there), and the total.
      expect(find.text('Table 5 · 4'), findsOneWidget);
      expect(find.text('₹1,550'), findsOneWidget);
      expect(find.text('Table 11 · 3'), findsOneWidget);
      expect(find.text('₹1,200'), findsOneWidget);
      // The server's own words stand when it shares no party.
      expect(find.text('A table near you'), findsOneWidget);
      expect(find.text('₹150'), findsOneWidget);
      // A little people icon on each card, and the heading's own.
      expect(find.byIcon(Icons.people_alt_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
      // And no dish names, no chevron: the pictures say what it was.
      for (final name in ['Chicken Biryani', 'Paneer Tikka', 'Brownie']) {
        expect(find.text(name), findsNothing, reason: name);
      }
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      Finder pictures(String id) => find.descendant(
        of: find.byKey(ValueKey('similar-card-$id')),
        matching: find.byType(FoodArt),
      );
      expect(pictures('t5'), findsNWidgets(3));
      expect(pictures('t11'), findsOneWidget);
      expect(pictures('tn'), findsOneWidget);
      expect(find.byKey(const ValueKey('similar-more')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('show three dishes at most, and a bubble for the rest', (
      tester,
    ) async {
      final six = MenuSnapshot(
        categories: const [MenuCategory(id: 'c', name: 'Mains')],
        items: [
          for (var i = 0; i < 6; i++)
            MenuItem(
              id: 'd$i',
              name: 'Dish $i',
              price: 100,
              categoryId: 'c',
              sortOrder: i,
            ),
        ],
      );
      List<TableOrderLine> lines(int n) => [
        for (var i = 0; i < n; i++) TableOrderLine(itemId: 'd$i', qty: 1),
      ];
      await _pump(
        tester,
        snapshot: six,
        source: _Source.fixed([
          _preview('six', minutesAgo: 1, lines: lines(6)),
          _preview('four', minutesAgo: 2, lines: lines(4)),
          _preview('three', minutesAgo: 3, lines: lines(3)),
        ]),
      );
      Finder inCard(String id, Finder what) => find.descendant(
        of: find.byKey(ValueKey('similar-card-$id')),
        matching: what,
      );
      for (final id in ['six', 'four', 'three']) {
        expect(inCard(id, find.byType(FoodArt)), findsNWidgets(3), reason: id);
      }
      final more = find.byKey(const ValueKey('similar-more'));
      expect(inCard('six', find.text('+3')), findsOneWidget);
      expect(inCard('four', find.text('+1')), findsOneWidget);
      expect(inCard('three', more), findsNothing);
      expect(more, findsNWidgets(2));
      // The bubble sits beside the pictures, not over them.
      final six3 = tester.getRect(inCard('six', find.byType(FoodArt)).last);
      expect(tester.getRect(more.first).left, greaterThanOrEqualTo(six3.right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ask again when the party size changes', (tester) async {
      final source = _Source.fixed([_preview('t5')]);
      await _pump(tester, source: source);
      expect(source.calls, [2]);

      final session = _session(tester);
      session.update(() => session.partySize = 5);
      await settle(tester);
      expect(source.calls, [2, 5]);

      // Other changes to the order do not ask.
      session.update(() => session.notes = 'less spicy');
      await settle(tester);
      expect(source.calls, [2, 5]);
    });

    testWidgets(
      'a card opens the sheet with a row for each dish and the total',
      (tester) async {
        await _pump(tester, source: _Source.fixed([_preview('t5')]));
        await _openSheet(tester, 't5');

        expect(find.text('What Table 5 ordered'), findsOneWidget);
        expect(find.text('A table of 4 · 12 min ago'), findsOneWidget);

        Finder row(String id) => find.byKey(ValueKey('similar-line-$id'));
        Finder inRow(String id, String text) =>
            find.descendant(of: row(id), matching: find.text(text));
        expect(inRow('i-biryani', 'Chicken Biryani'), findsOneWidget);
        expect(inRow('i-biryani', '₹800'), findsOneWidget);
        expect(inRow('i-paneer', 'Paneer Tikka'), findsOneWidget);
        expect(inRow('i-paneer', '₹600'), findsOneWidget);
        expect(inRow('i-brownie', 'Brownie'), findsOneWidget);
        expect(inRow('i-brownie', '₹150'), findsOneWidget);
        // A picture per row, and every dish starts ticked, as many as they had.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('similar-sheet')),
            matching: find.byType(FoodArt),
          ),
          findsNWidgets(3),
        );
        for (final id in ['i-biryani', 'i-paneer', 'i-brownie']) {
          expect(_ticked(tester, id), isTrue, reason: id);
          expect(find.byKey(ValueKey('similar-add-$id')), findsOneWidget);
        }
        expect(_qtyOf(tester, 'i-biryani'), 2);
        expect(_qtyOf(tester, 'i-paneer'), 1);
        expect(_qtyOf(tester, 'i-brownie'), 1);

        // 4 portions for ₹1,550, on the total and on the button.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('similar-total')),
            matching: find.text('₹1,550'),
          ),
          findsOneWidget,
        );
        expect(find.text('4 dishes'), findsOneWidget);
        expect(_addAllLabel(tester), 'Add 4 dishes · ₹1,550');
        expect(find.text('Not now'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('what the sheet says of a table it knows little of', (
      tester,
    ) async {
      await _pump(
        tester,
        source: _Source.fixed([
          _preview('x', who: 'A table of 3', party: 3, minutesAgo: 95),
        ]),
      );
      await _openSheet(tester, 'x');
      // The name already says the party, so the line gives the time only.
      expect(find.text('What a table of 3 ordered'), findsOneWidget);
      expect(find.text('1 hr ago'), findsOneWidget);
    });

    testWidgets('and without a party it gives the time alone', (tester) async {
      await _pump(
        tester,
        source: _Source.fixed([_preview('x', party: null, minutesAgo: 3)]),
      );
      await _openSheet(tester, 'x');
      expect(find.text('3 min ago'), findsOneWidget);
    });

    testWidgets('Add all puts the dishes in the cart and closes the sheet', (
      tester,
    ) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final session = _session(tester);
      expect(find.text('in cart: 0'), findsOneWidget);
      expect(find.text('cart total: ₹0'), findsOneWidget);

      await _openSheet(tester, 't5');
      await tester.tap(find.byKey(const ValueKey('similar-add-all')));
      await settle(tester);

      expect(find.byKey(const ValueKey('similar-sheet')), findsNothing);
      expect(
        {for (final l in session.lines) l.itemId: l.qty},
        {'i-biryani': 2, 'i-paneer': 1, 'i-brownie': 1},
      );
      expect(find.text('in cart: 4'), findsOneWidget);
      expect(find.text('cart total: ₹1,550'), findsOneWidget);
      // Said once, in the room's own words.
      expect(find.text('Added 4 dishes from Table 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a dish already in the order just gets more portions', (
      tester,
    ) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final session = _session(tester);
      session.add(session.catalog.item('i-biryani')!);
      expect(session.qtyOf('i-biryani'), 1);

      await _openSheet(tester, 't5');
      await tester.tap(find.byKey(const ValueKey('similar-add-all')));
      await settle(tester);

      expect(session.qtyOf('i-biryani'), 3);
      expect(session.lines.where((l) => l.itemId == 'i-biryani'), hasLength(1));
      expect(find.text('in cart: 5'), findsOneWidget);
    });

    testWidgets('one dish is "1 dish"', (tester) async {
      await _pump(
        tester,
        source: _Source.fixed([
          _preview(
            'one',
            who: 'Table 9',
            lines: const [TableOrderLine(itemId: 'i-paneer', qty: 1)],
          ),
        ]),
      );
      await _openSheet(tester, 'one');
      expect(find.text('1 dish'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('similar-add-all')));
      await settle(tester);
      expect(find.text('Added 1 dish from Table 9'), findsOneWidget);
    });

    testWidgets('a dish that left the menu is dimmed, not counted, not added', (
      tester,
    ) async {
      await _pump(
        tester,
        source: _Source.fixed([
          _preview(
            'g',
            lines: const [
              TableOrderLine(itemId: 'i-gone', qty: 2),
              TableOrderLine(itemId: 'i-biryani', qty: 1),
            ],
          ),
        ]),
      );
      final session = _session(tester);
      // The card counts what can be had: one dish, ₹400.
      final card = find.byKey(const ValueKey('similar-card-g'));
      expect(
        find.descendant(of: card, matching: find.byType(FoodArt)),
        findsOneWidget,
      );
      expect(find.descendant(of: card, matching: find.text('₹400')), findsOne);

      await _openSheet(tester, 'g');
      // What can be had comes first; the gone dish sits below, dimmed.
      final first = find.byKey(const ValueKey('similar-line-i-biryani'));
      final gone = find.byKey(const ValueKey('similar-line-i-gone'));
      expect(
        find.descendant(of: first, matching: find.text('Chicken Biryani')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: gone, matching: find.text('No longer available')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: gone, matching: find.text('×2')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(gone).dy,
        greaterThan(tester.getTopLeft(first).dy),
      );
      FoodArt art(Finder row) => tester.widget<FoodArt>(
        find.descendant(of: row, matching: find.byType(FoodArt)),
      );
      expect(art(gone).dim, isTrue);
      expect(art(first).dim, isFalse);
      // Nothing to choose on it: no price, no tick, no count, no Add.
      expect(
        find.descendant(of: gone, matching: find.textContaining('₹')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('similar-tick-i-gone')), findsNothing);
      expect(find.byKey(const ValueKey('similar-qty-i-gone')), findsNothing);
      expect(find.byKey(const ValueKey('similar-add-i-gone')), findsNothing);
      expect(find.byKey(const ValueKey('similar-pick-i-gone')), findsNothing);
      // Tapping it changes nothing.
      await tester.tap(gone);
      await settle(tester);
      expect(_ticked(tester, 'i-biryani'), isTrue);
      expect(_addAllLabel(tester), 'Add 1 dish · ₹400');
      // The total and the count leave it out.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('similar-total')),
          matching: find.text('₹400'),
        ),
        findsOneWidget,
      );
      expect(find.text('1 dish'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('similar-add-all')));
      await settle(tester);
      expect(
        {for (final l in session.lines) l.itemId: l.qty},
        {'i-biryani': 1},
      );
      expect(find.text('Added 1 dish from Table 5'), findsOneWidget);
    });

    testWidgets(
      'take only some: untick one, change the count of two, add those',
      (tester) async {
        await _pump(tester, source: _Source.fixed([_preview('t5')]));
        final session = _session(tester);
        await _openSheet(tester, 't5');
        Finder total(String text) => find.descendant(
          of: find.byKey(const ValueKey('similar-total')),
          matching: find.text(text),
        );

        // Tapping the name drops the Brownie; the total and the button follow.
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('similar-line-i-brownie')),
            matching: find.text('Brownie'),
          ),
        );
        await settle(tester);
        expect(_ticked(tester, 'i-brownie'), isFalse);
        expect(_ticked(tester, 'i-biryani'), isTrue);
        expect(_addAllLabel(tester), 'Add 3 dishes · ₹1,400');
        expect(total('₹1,400'), findsOneWidget);
        expect(find.text('3 dishes'), findsOneWidget);

        // One more Paneer Tikka than the other table had.
        await _step(tester, 'i-paneer', up: true);
        expect(_qtyOf(tester, 'i-paneer'), 2);
        expect(_addAllLabel(tester), 'Add 4 dishes · ₹2,000');
        expect(total('₹2,000'), findsOneWidget);

        // And one Chicken Biryani instead of two.
        await _step(tester, 'i-biryani', up: false);
        expect(_qtyOf(tester, 'i-biryani'), 1);
        expect(_addAllLabel(tester), 'Add 3 dishes · ₹1,600');
        expect(total('₹1,600'), findsOneWidget);
        // Nothing is in the order until the guest says so.
        expect(session.lines, isEmpty);

        await tester.tap(find.byKey(const ValueKey('similar-add-all')));
        await settle(tester);
        expect(find.byKey(const ValueKey('similar-sheet')), findsNothing);
        expect(
          {for (final l in session.lines) l.itemId: l.qty},
          {'i-biryani': 1, 'i-paneer': 2},
        );
        expect(find.text('in cart: 3'), findsOneWidget);
        expect(find.text('cart total: ₹1,600'), findsOneWidget);
        expect(find.text('Added 3 dishes from Table 5'), findsOneWidget);
      },
    );

    testWidgets(
      'a tick that is taken off can be put back, by the tick or the count',
      (tester) async {
        await _pump(tester, source: _Source.fixed([_preview('t5')]));
        await _openSheet(tester, 't5');
        await tester.tap(find.byKey(const ValueKey('similar-tick-i-paneer')));
        await settle(tester);
        expect(_ticked(tester, 'i-paneer'), isFalse);
        await tester.tap(find.byKey(const ValueKey('similar-tick-i-paneer')));
        await settle(tester);
        expect(_ticked(tester, 'i-paneer'), isTrue);

        // Asking for a number of a dish is wanting it.
        await tester.tap(find.byKey(const ValueKey('similar-tick-i-brownie')));
        await settle(tester);
        expect(_ticked(tester, 'i-brownie'), isFalse);
        await _step(tester, 'i-brownie', up: true);
        expect(_ticked(tester, 'i-brownie'), isTrue);
        expect(_qtyOf(tester, 'i-brownie'), 2);
        expect(_addAllLabel(tester), 'Add 5 dishes · ₹1,700');
      },
    );

    testWidgets('a count stays between one and twenty', (tester) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      await _openSheet(tester, 't5');
      await _step(tester, 'i-brownie', up: false);
      expect(_qtyOf(tester, 'i-brownie'), 1, reason: 'not below one');
      for (var i = 0; i < 25; i++) {
        await _step(tester, 'i-brownie', up: true, settleFor: 0);
      }
      await settle(tester);
      expect(_qtyOf(tester, 'i-brownie'), 20, reason: 'not above twenty');
      expect(_addAllLabel(tester), 'Add 23 dishes · ₹4,400');
    });

    testWidgets('a tap on the stepper that does nothing does not tick the row', (
      tester,
    ) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      await _openSheet(tester, 't5');
      // Chicken Biryani is at two; Paneer Tikka is at one, and cannot go lower.
      expect(_qtyOf(tester, 'i-paneer'), 1);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('similar-qty-i-paneer')),
          matching: find.byIcon(Icons.remove_rounded),
        ),
      );
      await settle(tester);
      expect(_qtyOf(tester, 'i-paneer'), 1);
      expect(_ticked(tester, 'i-paneer'), isTrue, reason: 'still wanted');

      // The same on a dish that is not ticked: it stays not ticked.
      await tester.tap(find.byKey(const ValueKey('similar-tick-i-paneer')));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('similar-qty-i-paneer')),
          matching: find.byIcon(Icons.remove_rounded),
        ),
      );
      await settle(tester);
      expect(_ticked(tester, 'i-paneer'), isFalse);
      expect(_qtyOf(tester, 'i-paneer'), 1);
    });

    testWidgets('with nothing chosen the button asks for a dish and waits', (
      tester,
    ) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final session = _session(tester);
      await _openSheet(tester, 't5');
      for (final id in ['i-biryani', 'i-paneer', 'i-brownie']) {
        await tester.tap(find.byKey(ValueKey('similar-tick-$id')));
        await settle(tester);
      }
      expect(_addAllLabel(tester), 'Choose a dish');
      expect(
        tester
            .widget<GuestButton>(find.byKey(const ValueKey('similar-add-all')))
            .onTap,
        isNull,
      );
      expect(find.text('Nothing chosen'), findsNWidgets(1));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('similar-total')),
          matching: find.text('₹0'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('similar-add-all')),
        warnIfMissed: false,
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('similar-sheet')), findsOneWidget);
      expect(session.lines, isEmpty);

      // Tick one again and it is ready.
      await tester.tap(find.byKey(const ValueKey('similar-tick-i-paneer')));
      await settle(tester);
      expect(_addAllLabel(tester), 'Add 1 dish · ₹600');
    });

    testWidgets(
      'Add on a row puts just that dish in the order and the sheet stays',
      (tester) async {
        await _pump(tester, source: _Source.fixed([_preview('t5')]));
        final session = _session(tester);
        await _openSheet(tester, 't5');
        Finder inRow(String id, String text) => find.descendant(
          of: find.byKey(ValueKey('similar-line-$id')),
          matching: find.text(text),
        );
        expect(inRow('i-biryani', 'Add'), findsOneWidget);

        // Two Chicken Biryani, as set.
        await tester.tap(find.byKey(const ValueKey('similar-add-i-biryani')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          {for (final l in session.lines) l.itemId: l.qty},
          {'i-biryani': 2},
        );
        expect(find.text('in cart: 2'), findsOneWidget);
        expect(find.byKey(const ValueKey('similar-sheet')), findsOneWidget);
        // The row says so for a moment, and is no longer part of the rest.
        expect(inRow('i-biryani', 'Added'), findsOneWidget);
        expect(inRow('i-biryani', 'Add'), findsNothing);
        expect(_ticked(tester, 'i-biryani'), isFalse);
        expect(_addAllLabel(tester), 'Add 2 dishes · ₹750');
        // Nobody is "not now" once something went in.
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Not now'), findsNothing);

        // A press while it says "Added" does nothing more.
        await tester.tap(
          find.byKey(const ValueKey('similar-add-i-biryani')),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(session.qtyOf('i-biryani'), 2);

        // Then it is "Add" again, for another round if they want one.
        await settle(tester, ms: 2000);
        expect(inRow('i-biryani', 'Add'), findsOneWidget);
        expect(inRow('i-biryani', 'Added'), findsNothing);

        // The big button takes the rest, and the Biryani is not added twice.
        await tester.tap(find.byKey(const ValueKey('similar-add-all')));
        await settle(tester);
        expect(
          {for (final l in session.lines) l.itemId: l.qty},
          {'i-biryani': 2, 'i-paneer': 1, 'i-brownie': 1},
        );
        expect(find.text('Added 2 dishes from Table 5'), findsOneWidget);
      },
    );

    testWidgets('Add on a row takes the count the guest set', (tester) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final session = _session(tester);
      await _openSheet(tester, 't5');
      await _step(tester, 'i-paneer', up: true);
      await _step(tester, 'i-paneer', up: true);
      await tester.tap(find.byKey(const ValueKey('similar-add-i-paneer')));
      await settle(tester);
      expect({for (final l in session.lines) l.itemId: l.qty}, {'i-paneer': 3});
      await tester.tap(find.byKey(const ValueKey('similar-not-now')));
      await settle(tester);
      expect(find.byKey(const ValueKey('similar-sheet')), findsNothing);
      // Done closes it, and says nothing more.
      expect(find.textContaining('Added'), findsNothing);
    });

    testWidgets('Add on a row works for a dish that is not ticked', (
      tester,
    ) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final session = _session(tester);
      await _openSheet(tester, 't5');
      await tester.tap(find.byKey(const ValueKey('similar-tick-i-brownie')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('similar-add-i-brownie')));
      await settle(tester);
      expect(
        {for (final l in session.lines) l.itemId: l.qty},
        {'i-brownie': 1},
      );
    });

    testWidgets('Not now closes the sheet and adds nothing', (tester) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final session = _session(tester);
      await _openSheet(tester, 't5');
      await tester.tap(find.byKey(const ValueKey('similar-not-now')));
      await settle(tester);
      expect(find.byKey(const ValueKey('similar-sheet')), findsNothing);
      expect(session.lines, isEmpty);
      expect(find.textContaining('Added'), findsNothing);
      // The cards are still there to try another.
      expect(find.byKey(const ValueKey('similar-card-t5')), findsOneWidget);
    });

    testWidgets('a second tap on Add all adds once', (tester) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final session = _session(tester);
      await _openSheet(tester, 't5');
      final add = find.byKey(const ValueKey('similar-add-all'));
      await tester.tap(add);
      await tester.tap(add, warnIfMissed: false);
      await settle(tester);
      expect(session.itemCount, 4);
    });

    testWidgets('Add all can be reached and pressed with the keyboard', (
      tester,
    ) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final session = _session(tester);
      await _openSheet(tester, 't5');
      await _tabTo(tester, find.byKey(const ValueKey('similar-add-all')));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(session.itemCount, 4);
      expect(find.byKey(const ValueKey('similar-sheet')), findsNothing);
    });

    testWidgets('a row can be ticked and unticked with the keyboard', (
      tester,
    ) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      await _openSheet(tester, 't5');
      await _tabTo(tester, find.byKey(const ValueKey('similar-pick-i-paneer')));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(_ticked(tester, 'i-paneer'), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(_ticked(tester, 'i-paneer'), isTrue);
    });

    testWidgets('Escape closes the sheet and adds nothing', (tester) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final session = _session(tester);
      await _openSheet(tester, 't5');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byKey(const ValueKey('similar-sheet')), findsNothing);
      expect(session.lines, isEmpty);
      // Only the sheet went: the page under it is still there.
      expect(find.byKey(const ValueKey('similar-card-t5')), findsOneWidget);
    });

    testWidgets(
      'a card is a button that says everything it shows and leaves out',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, source: _Source.fixed([_preview('t5')]));
        final card = find.byKey(const ValueKey('similar-card-t5'));
        expect(
          tester.getSemantics(card),
          isSemantics(
            label:
                'Table 5, 4 people. 2 Chicken Biryani, Paneer Tikka, Brownie. '
                'Total ₹1,550',
            hint: 'See what they ordered',
            isButton: true,
            hasTapAction: true,
            hasLongPressAction: true,
          ),
        );
        handle.dispose();
      },
    );

    testWidgets('holding a card opens the sheet, as touching it does', (
      tester,
    ) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final session = _session(tester);
      await tester.longPress(find.byKey(const ValueKey('similar-card-t5')));
      await settle(tester);
      expect(find.byKey(const ValueKey('similar-sheet')), findsOneWidget);
      expect(find.text('What Table 5 ordered'), findsOneWidget);
      expect(session.lines, isEmpty, reason: 'only a look');
    });

    testWidgets('a card can be reached and opened with the keyboard', (
      tester,
    ) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      await _tabTo(tester, find.byKey(const ValueKey('similar-card-t5')));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.byKey(const ValueKey('similar-sheet')), findsOneWidget);
    });

    testWidgets('a mouse resting on a card is shown what is in it', (
      tester,
    ) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final peek = find.text(
        '2 × Chicken Biryani\n1 × Paneer Tikka\n1 × Brownie',
      );
      expect(peek, findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('similar-card-t5'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(peek, findsOneWidget);
      // It is a peek, not the sheet: nothing opened, nothing added.
      expect(find.byKey(const ValueKey('similar-sheet')), findsNothing);
      expect(_session(tester).lines, isEmpty);

      await mouse.moveTo(const Offset(1, 1));
      await settle(tester);
      expect(peek, findsNothing);
    });

    testWidgets(
      'the sheet reads in order: heading, each dish, total, buttons',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          source: _Source.fixed([
            _preview(
              'g',
              lines: const [
                TableOrderLine(itemId: 'i-gone', qty: 2),
                TableOrderLine(itemId: 'i-biryani', qty: 2),
              ],
            ),
          ]),
        );
        await _openSheet(tester, 'g');
        // A dish is a tick box that says what it is, how many and what for.
        expect(
          tester.getSemantics(
            find.bySemanticsLabel('Chicken Biryani, 2 portions, ₹800'),
          ),
          isSemantics(
            label: 'Chicken Biryani, 2 portions, ₹800',
            hasCheckedState: true,
            isChecked: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(
            find.bySemanticsLabel('Chicken Biryani quantity'),
          ),
          isSemantics(label: 'Chicken Biryani quantity', value: '2'),
        );
        expect(
          tester.getSemantics(
            find.bySemanticsLabel('Add Chicken Biryani to my order'),
          ),
          isSemantics(
            label: 'Add Chicken Biryani to my order',
            isButton: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        expect(
          find.bySemanticsLabel('No longer available, will not be added'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Total ₹800 for 2 dishes'),
          findsOneWidget,
        );
        // The heading is a heading, the main action a button with its words.
        expect(
          tester.getSemantics(find.byKey(const ValueKey('similar-title'))),
          isSemantics(isHeader: true, label: 'What Table 5 ordered'),
        );
        expect(
          tester.getSemantics(find.text('Add 2 dishes · ₹800')),
          isSemantics(
            label: 'Add 2 dishes · ₹800',
            isButton: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );

        // Untick it and the box says so; the button waits.
        await tester.tap(find.byKey(const ValueKey('similar-tick-i-biryani')));
        await settle(tester);
        expect(
          tester.getSemantics(
            find.bySemanticsLabel('Chicken Biryani, 2 portions, ₹800'),
          ),
          isSemantics(hasCheckedState: true, isChecked: false),
        );
        expect(find.bySemanticsLabel('Nothing chosen'), findsOneWidget);
        expect(
          tester.getSemantics(find.text('Choose a dish')),
          isSemantics(label: 'Choose a dish', isButton: true, isEnabled: false),
        );

        // And after an Add on a row, the change is announced.
        await tester.tap(find.byKey(const ValueKey('similar-add-i-biryani')));
        await tester.pump();
        expect(
          tester.getSemantics(find.bySemanticsLabel('Added Chicken Biryani')),
          isSemantics(label: 'Added Chicken Biryani', isLiveRegion: true),
        );
        await settle(tester, ms: 2000);
        handle.dispose();
      },
    );

    testWidgets('are there at once for someone who asked for less motion', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final source = _Source.fixed([_preview('t5')]);
      await _pumpUnsettled(tester, source: source);
      // One frame to ask, one for the answer, one to lay it out.
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Tables like yours'), findsOneWidget);
      final fade = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('similar-card-t5')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(fade.opacity, 1);

      await tester.tap(find.byKey(const ValueKey('similar-card-t5')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // The sheet is open at once, without a slide.
      final sheet = tester.getRect(find.byKey(const ValueKey('similar-sheet')));
      expect(sheet.bottom, lessThanOrEqualTo(2532 / 3 + 1));
      expect(sheet.top, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(find.byKey(const ValueKey('similar-sheet'))),
        sheet,
        reason: 'it did not move',
      );
    });

    testWidgets('come in when they arrive, a moment after the page', (
      tester,
    ) async {
      final source = _Source((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return [_preview('t5')];
      });
      await _pumpUnsettled(tester, source: source);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Tables like yours'), findsNothing);
      expect(source.calls, [2]);
      await settle(tester);
      expect(find.text('Tables like yours'), findsOneWidget);
      expect(find.text('Table 5 · 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grow taller, and stay whole, with large text', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      expect(tester.takeException(), isNull);
      final card = find.byKey(const ValueKey('similar-card-t5'));
      expect(tester.getSize(card).height, greaterThan(85));

      await _openSheet(tester, 't5');
      expect(tester.takeException(), isNull);
      final add = tester.getRect(find.byKey(const ValueKey('similar-add-all')));
      expect(add.bottom, lessThanOrEqualTo(2532 / 3));
    });

    testWidgets('fit a 320 pixel phone, long names included', (tester) async {
      const longMenu = MenuSnapshot(
        categories: [MenuCategory(id: 'c', name: 'Mains')],
        items: [
          MenuItem(
            id: 'long-1',
            name: 'Hyderabadi Dum Chicken Biryani with Mirchi Ka Salan',
            price: 12999.5,
            categoryId: 'c',
          ),
          MenuItem(
            id: 'long-2',
            name: 'Paneer Butter Masala with Garlic Butter Naan Basket',
            price: 480,
            categoryId: 'c',
            sortOrder: 1,
          ),
          MenuItem(
            id: 'long-3',
            name: 'Extra Large Mango Lassi',
            price: 160,
            categoryId: 'c',
            sortOrder: 2,
          ),
        ],
      );
      await _pump(
        tester,
        size: const Size(320, 640),
        snapshot: longMenu,
        source: _Source.fixed([
          _preview(
            'long',
            who: 'A table near the window on the first floor',
            party: 12,
            minutesAgo: 5,
            lines: const [
              TableOrderLine(itemId: 'long-1', qty: 12),
              TableOrderLine(itemId: 'long-2', qty: 4),
              TableOrderLine(itemId: 'long-3', qty: 10),
              TableOrderLine(itemId: 'long-gone', qty: 1),
            ],
          ),
          _preview(
            'short',
            minutesAgo: 20,
            lines: const [TableOrderLine(itemId: 'long-3', qty: 1)],
          ),
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('similar-card-long')), findsOneWidget);

      await _openSheet(tester, 'long');
      expect(tester.takeException(), isNull);
      // Nothing sticks out of the screen sideways.
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final sheet = tester.getRect(find.byKey(const ValueKey('similar-sheet')));
      expect(sheet.left, greaterThanOrEqualTo(0));
      expect(sheet.right, lessThanOrEqualTo(screen.width));
      // The count and the Add of a dish share a line and stay on the screen.
      final stepper = tester.getRect(
        find.byKey(const ValueKey('similar-qty-long-1')),
      );
      final addPill = tester.getRect(
        find.byKey(const ValueKey('similar-add-long-1')),
      );
      expect(stepper.right, lessThan(addPill.left));
      expect((stepper.center.dy - addPill.center.dy).abs(), lessThan(8));
      expect(addPill.right, lessThanOrEqualTo(screen.width));
      expect(addPill.height, greaterThanOrEqualTo(44));
      // The buttons are still on the screen, and a finger wide.
      final add = tester.getRect(find.byKey(const ValueKey('similar-add-all')));
      expect(add.bottom, lessThanOrEqualTo(screen.height));
      expect(add.height, greaterThanOrEqualTo(44));
      final notNow = tester.getRect(
        find.byKey(const ValueKey('similar-not-now')),
      );
      expect(notNow.height, greaterThanOrEqualTo(44));
      expect(notNow.bottom, lessThanOrEqualTo(screen.height));
    });

    testWidgets('keep the buttons on a short screen and scroll the rows', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(360, 420),
        source: _Source.fixed([
          _preview(
            'many',
            lines: const [
              TableOrderLine(itemId: 'i-biryani', qty: 2),
              TableOrderLine(itemId: 'i-paneer', qty: 1),
              TableOrderLine(itemId: 'i-brownie', qty: 1),
              TableOrderLine(itemId: 'i-gone', qty: 1),
              TableOrderLine(itemId: 'i-gone-2', qty: 1),
              TableOrderLine(itemId: 'i-gone-3', qty: 1),
            ],
          ),
        ]),
      );
      await _openSheet(tester, 'many');
      expect(tester.takeException(), isNull);
      final add = tester.getRect(find.byKey(const ValueKey('similar-add-all')));
      expect(add.bottom, lessThanOrEqualTo(420));
      final sheet = tester.getRect(find.byKey(const ValueKey('similar-sheet')));
      expect(sheet.height, lessThanOrEqualTo(420 * 0.95));
      expect(find.byType(Scrollable), findsWidgets);
    });

    testWidgets('a long order has every dish in the sheet, scrolled to', (
      tester,
    ) async {
      final many = MenuSnapshot(
        categories: const [MenuCategory(id: 'c', name: 'Mains')],
        items: [
          for (var i = 0; i < 12; i++)
            MenuItem(
              id: 'd$i',
              name: 'Dish $i',
              price: 100.0 + i,
              categoryId: 'c',
              sortOrder: i,
            ),
        ],
      );
      await _pump(
        tester,
        snapshot: many,
        source: _Source.fixed([
          _preview(
            'long',
            lines: [
              for (var i = 0; i < 12; i++)
                TableOrderLine(itemId: 'd$i', qty: 1),
            ],
          ),
        ]),
      );
      final session = _session(tester);
      await _openSheet(tester, 'long');
      // All twelve are there to reach, though only some fit the screen.
      for (var i = 0; i < 12; i++) {
        expect(find.byKey(ValueKey('similar-line-d$i')), findsOneWidget);
      }
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('similar-line-d11'))).dy,
        greaterThan(screen.height),
      );
      // The big button is in sight all the while, and takes all twelve.
      expect(
        tester.getRect(find.byKey(const ValueKey('similar-add-all'))).bottom,
        lessThanOrEqualTo(screen.height),
      );
      expect(_addAllLabel(tester), 'Add 12 dishes · ₹1,266');
      await tester.tap(find.byKey(const ValueKey('similar-add-all')));
      await settle(tester);
      expect(session.itemCount, 12);
    });

    testWidgets('keep to a phone-width panel on a wide screen', (tester) async {
      await _pump(
        tester,
        size: const Size(1440, 900),
        source: _Source.fixed([_preview('t5'), _preview('t6')]),
      );
      expect(tester.takeException(), isNull);
      await _openSheet(tester, 't5');
      final sheet = tester.getRect(find.byKey(const ValueKey('similar-sheet')));
      expect(sheet.width, lessThanOrEqualTo(480));
      expect(tester.takeException(), isNull);
    });
  });

  // The groups above run in the blunt Ahem type of the test framework, where
  // every letter is as wide as it is tall: if a layout holds there it holds
  // anywhere. These last ones run in the real Inter, to see the real sizes.
  group('at real type sizes', () {
    setUpAll(() async {
      final bytes = File('assets/fonts/Inter.ttf').readAsBytesSync();
      final loader = FontLoader('Inter')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    });

    Size cardSize(WidgetTester tester, String id) => tester.getSize(
      find.descendant(
        of: find.byKey(ValueKey('similar-card-$id')),
        matching: find.byType(GuestCard),
      ),
    );

    testWidgets('a card is about 170 by 72, and the heading is only a label', (
      tester,
    ) async {
      await _pump(tester, source: _Source.fixed([_preview('t5')]));
      final card = cardSize(tester, 't5');
      expect(card.width, 170);
      expect(card.height, inInclusiveRange(72, 76));
      // Who it was and the total share a line.
      expect(
        (tester.getCenter(find.text('Table 5 · 4')).dy -
                tester.getCenter(find.text('₹1,550')).dy)
            .abs(),
        lessThan(3),
      );
      // The whole row, heading included, is no taller than it has to be.
      final strip = tester.getSize(find.byKey(const ValueKey('similar-strip')));
      expect(strip.height, inInclusiveRange(100, 118));
      // Small and muted, not a title.
      final heading = tester.widget<Text>(
        find.byKey(const ValueKey('similar-heading')),
      );
      expect(heading.style!.fontSize, lessThanOrEqualTo(14));
      expect(heading.style!.color, isNot(Colors.white));
    });

    testWidgets('the compact card is about 170 by 60', (tester) async {
      await _pump(
        tester,
        source: _Source.fixed([_preview('t5')]),
        compact: true,
      );
      expect(find.text('Tables like yours'), findsNothing);
      final card = cardSize(tester, 't5');
      expect(card.width, 170);
      expect(card.height, inInclusiveRange(60, 64));
      final strip = tester.getSize(find.byKey(const ValueKey('similar-strip')));
      expect(strip.height, inInclusiveRange(60, 64));
    });

    testWidgets('every card of a row is as tall as the tallest', (
      tester,
    ) async {
      await _pump(
        tester,
        source: _Source.fixed([
          _preview('a', minutesAgo: 1),
          // A name too long for one line with the total: the total goes under.
          _preview(
            'b',
            minutesAgo: 2,
            who: 'A table near the window on the first floor',
          ),
        ]),
      );
      expect(tester.takeException(), isNull);
      final a = cardSize(tester, 'a');
      final b = cardSize(tester, 'b');
      expect(a.height, b.height);
      expect(a.height, greaterThan(72));
    });

    testWidgets('table twelve with a big bill still fits its card', (
      tester,
    ) async {
      await _pump(
        tester,
        source: _Source.fixed([
          _preview(
            'big',
            who: 'Table 12',
            party: 8,
            lines: const [TableOrderLine(itemId: 'i-paneer', qty: 20)],
          ),
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Table 12 · 8'), findsOneWidget);
      expect(find.text('₹12,000'), findsOneWidget);
      expect(cardSize(tester, 'big').width, 170);
    });
  });
}

/// The party's session, found from whatever is on screen.
GuestSession _session(WidgetTester tester) =>
    GuestScope.read(tester.element(find.byType(SimilarTablesStrip)));

/// A page on the runtime's own navigator with the strip on it, the way the
/// categories screen carries it, and the cart in plain words beside it.
class _Host extends StatelessWidget {
  const _Host({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = GuestScope.of(context);
    return GuestPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GuestTopBar(title: 'Categories'),
          SimilarTablesStrip(compact: compact),
          Text('in cart: ${s.itemCount}'),
          Text('cart total: ${rupees(s.estimate.itemTotal)}'),
        ],
      ),
    );
  }
}

Future<void> _pumpUnsettled(
  WidgetTester tester, {
  required GuestSimilarTables? source,
  StorefrontDefinition? definition,
  MenuSnapshot snapshot = menu,
  Size? size,
  bool compact = false,
}) async {
  await pumpGuest(
    tester,
    definition: definition ?? storefront(features: noBudget),
    gateway: _Gateway(source),
    snapshot: snapshot,
    table: table12,
  );
  if (size != null) {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
  }
  final nav = Navigator.of(tester.element(find.byType(GuestWelcomeScreen)));
  unawaited(
    nav.push(MaterialPageRoute<void>(builder: (_) => _Host(compact: compact))),
  );
  await tester.pump();
}

Future<void> _pump(
  WidgetTester tester, {
  required GuestSimilarTables? source,
  StorefrontDefinition? definition,
  MenuSnapshot snapshot = menu,
  Size? size,
  bool compact = false,
}) async {
  await _pumpUnsettled(
    tester,
    source: source,
    definition: definition,
    snapshot: snapshot,
    size: size,
    compact: compact,
  );
  await settle(tester);
}

Future<void> _openSheet(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('similar-card-$id')));
  await settle(tester);
  expect(find.byKey(const ValueKey('similar-sheet')), findsOneWidget);
}

/// Whether a dish's tick is on.
bool _ticked(WidgetTester tester, String id) => find
    .descendant(
      of: find.byKey(ValueKey('similar-tick-$id')),
      matching: find.byIcon(Icons.check_rounded),
    )
    .evaluate()
    .isNotEmpty;

/// The count on a dish's stepper.
int _qtyOf(WidgetTester tester, String id) =>
    tester.widget<QtyStepper>(find.byKey(ValueKey('similar-qty-$id'))).qty;

/// A press on the "+" (or the "−") of a dish's stepper.
Future<void> _step(
  WidgetTester tester,
  String id, {
  required bool up,
  int settleFor = 1200,
}) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(ValueKey('similar-qty-$id')),
      matching: find.byIcon(up ? Icons.add_rounded : Icons.remove_rounded),
    ),
  );
  if (settleFor > 0) {
    await settle(tester, ms: settleFor);
  } else {
    await tester.pump();
  }
}

/// The words on the big button.
String _addAllLabel(WidgetTester tester) => tester
    .widget<GuestButton>(find.byKey(const ValueKey('similar-add-all')))
    .label;

/// Presses Tab until the keyboard focus is inside [target].
Future<void> _tabTo(WidgetTester tester, Finder target) async {
  final goal = target.evaluate().single;
  for (var i = 0; i < 60; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) continue;
    if (focused == goal) return;
    var inside = false;
    focused.visitAncestorElements((e) {
      if (e == goal) inside = true;
      return !inside;
    });
    if (inside) return;
  }
  fail('the keyboard never reached $target');
}
