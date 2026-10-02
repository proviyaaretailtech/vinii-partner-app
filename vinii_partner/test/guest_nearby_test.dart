import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/application/guest_nearby.dart';
import 'package:vinii_partner/application/guest_session.dart';
import 'package:vinii_partner/application/guest_social.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/storefront.dart';
import 'package:vinii_partner/presentation/guest/guest_browse.dart';
import 'package:vinii_partner/presentation/guest/guest_categories.dart';
import 'package:vinii_partner/presentation/guest/guest_item_detail.dart';
import 'package:vinii_partner/presentation/guest/guest_nearby.dart';
import 'package:vinii_partner/presentation/guest/guest_widgets.dart';
import 'package:vinii_partner/presentation/theme/guest_theme.dart';

import '../tool/gallery/gallery_nearby.dart';
import 'guest_runtime_test.dart'
    show
        RecordingGateway,
        menu,
        noBudget,
        pumpGuest,
        settle,
        storefront,
        table12,
        tapText;

// ── The feed ──────────────────────────────────────────────────────────────

/// A source the test pushes orders into by hand.
class FakeNearby extends GuestNearby {
  final controller = StreamController<NearbyOrder>.broadcast();
  int listens = 0;

  @override
  Stream<NearbyOrder> orders() {
    listens++;
    return controller.stream;
  }
}

class ThrowingNearby extends GuestNearby {
  @override
  Stream<NearbyOrder> orders() => throw StateError('no such channel');
}

/// A feed on the test's fake clock, started, with every alert it shows
/// written down (which order, and how many seconds into the test).
class Rig {
  Rig(
    this.tester, {
    bool Function(NearbyOrder)? canShow,
    Duration cooldown = const Duration(seconds: 20),
    Duration showFor = const Duration(seconds: 7),
    GuestNearby? source,
    bool start = true,
  }) : source = source ?? FakeNearby(),
       t0 = tester.binding.clock.now() {
    feed = NearbyFeed(
      source: this.source,
      canShow: canShow ?? (_) => true,
      cooldown: cooldown,
      showFor: showFor,
      now: tester.binding.clock.now,
    );
    feed.addListener(_record);
    if (start) feed.start();
  }

  final WidgetTester tester;
  final GuestNearby source;
  final DateTime t0;
  late final NearbyFeed feed;
  int notifications = 0;
  final shown = <(String id, double second)>[];

  FakeNearby get fake => source as FakeNearby;

  void _record() {
    notifications++;
    final c = feed.current;
    if (c != null) shown.add((c.id, seconds));
  }

  double get seconds =>
      tester.binding.clock.now().difference(t0).inMilliseconds / 1000;

  List<String> get ids => [for (final s in shown) s.$1];

  double shownAt(String id) => shown.firstWhere((s) => s.$1 == id).$2;

  /// An order placed [age] ago, as of this moment.
  NearbyOrder order(
    String id,
    String itemId, {
    double age = 0,
    int qty = 1,
    String who = 'Table 7',
  }) => NearbyOrder(
    id: id,
    itemId: itemId,
    qty: qty,
    who: who,
    at: tester.binding.clock.now().subtract(
      Duration(milliseconds: (age * 1000).round()),
    ),
  );

  Future<void> emit(NearbyOrder o) async {
    fake.controller.add(o);
    await tester.pump();
  }

  /// Moves the fake clock forward to [second] seconds into the test.
  Future<void> at(double second) async {
    final ms = (second * 1000).round() - (seconds * 1000).round();
    expect(ms, greaterThanOrEqualTo(0), reason: 'time only moves forward');
    await tester.pump(Duration(milliseconds: ms));
  }

  /// The test is over: nothing may be left running.
  ///
  /// Nothing here awaits a future of its own: inside a widget test only
  /// `pump` moves the clock and the microtasks on.
  Future<void> finish() async {
    feed.dispose();
    unawaited(fake.controller.close());
    await tester.pump();
  }
}

void main() {
  group('NearbyFeed', () {
    testWidgets('start() listens once, however often it is called', (
      tester,
    ) async {
      final rig = Rig(tester, start: false);
      expect(rig.fake.listens, 0, reason: 'nothing is heard before start');
      rig.feed.start();
      rig.feed.start();
      rig.feed.start();
      expect(rig.fake.listens, 1);
      await rig.finish();
    });

    testWidgets('the first fresh order is shown at once and closes by itself '
        'after showFor', (tester) async {
      final rig = Rig(tester);
      expect(rig.feed.current, isNull);

      await rig.emit(rig.order('a', 'i-biryani', qty: 2, who: 'Table 9'));
      expect(rig.feed.current?.id, 'a');
      expect(rig.feed.current?.who, 'Table 9');
      expect(rig.feed.current?.qty, 2);

      await rig.at(6.9);
      expect(rig.feed.current?.id, 'a', reason: 'still up just before 7 s');
      await rig.at(7);
      expect(rig.feed.current, isNull);
      expect(rig.notifications, 2, reason: 'one change to show, one to close');
      await rig.finish();
    });

    testWidgets('showFor is the feed\'s own setting', (tester) async {
      final rig = Rig(tester, showFor: const Duration(seconds: 3));
      await rig.emit(rig.order('a', 'i-biryani'));
      await rig.at(2.9);
      expect(rig.feed.current?.id, 'a');
      await rig.at(3);
      expect(rig.feed.current, isNull);
      await rig.finish();
    });

    testWidgets('the next alert waits the cooldown after the last one was '
        'shown', (tester) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('a', 'i-biryani'));
      await rig.at(8);
      await rig.emit(rig.order('b', 'i-paneer'));
      expect(rig.feed.current, isNull, reason: 'a closed at 7, b has to wait');

      // a was shown at 0 s, so b may come 20 s after that, at 20 s.
      await rig.at(19.9);
      expect(rig.feed.current, isNull);
      await rig.at(20);
      expect(rig.feed.current?.id, 'b');
      expect(rig.ids, ['a', 'b']);
      expect(rig.shownAt('b'), 20);
      await rig.finish();
    });

    testWidgets('the cooldown can be set', (tester) async {
      final rig = Rig(tester, cooldown: const Duration(seconds: 45));
      await rig.emit(rig.order('a', 'i-biryani'));
      await rig.at(20);
      // Placed at 20 s, so still fresh enough (25 s old) when its turn comes.
      await rig.emit(rig.order('b', 'i-paneer'));
      await rig.at(44.9);
      expect(rig.ids, ['a']);
      await rig.at(45);
      expect(rig.ids, ['a', 'b']);
      await rig.finish();
    });

    testWidgets('dismiss() closes at once and the cooldown starts there', (
      tester,
    ) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('a', 'i-biryani'));
      await rig.at(2);
      rig.feed.dismiss();
      expect(rig.feed.current, isNull, reason: 'closed in the same moment');

      await rig.at(3);
      await rig.emit(rig.order('b', 'i-paneer'));
      await rig.at(21.9);
      expect(rig.feed.current, isNull);
      await rig.at(22);
      expect(rig.feed.current?.id, 'b', reason: '2 s dismissed + 20 s');
      await rig.finish();
    });

    testWidgets('added() closes at once and the cooldown starts there', (
      tester,
    ) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('a', 'i-biryani'));
      await rig.at(3);
      rig.feed.added();
      expect(rig.feed.current, isNull);

      await rig.emit(rig.order('b', 'i-paneer'));
      await rig.at(22.9);
      expect(rig.feed.current, isNull);
      await rig.at(23);
      expect(rig.feed.current?.id, 'b');
      await rig.finish();
    });

    testWidgets('closing with nothing on screen changes nothing', (
      tester,
    ) async {
      final rig = Rig(tester);
      rig.feed.dismiss();
      rig.feed.added();
      expect(rig.notifications, 0);

      // No cooldown was started by those calls.
      await rig.emit(rig.order('a', 'i-biryani'));
      expect(rig.feed.current?.id, 'a');
      await rig.finish();
    });

    testWidgets('only one alert is ever on screen', (tester) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('a', 'i-biryani'));
      await rig.emit(rig.order('b', 'i-paneer'));
      await rig.emit(rig.order('c', 'i-brownie'));
      expect(rig.feed.current?.id, 'a', reason: 'b and c wait their turn');
      expect(rig.ids, ['a']);
      await rig.finish();
    });

    testWidgets('at most three wait; the oldest waiting ones are dropped', (
      tester,
    ) async {
      final rig = Rig(
        tester,
        cooldown: const Duration(seconds: 1),
        showFor: const Duration(seconds: 2),
      );
      await rig.emit(rig.order('a', 'i-1'));
      for (final id in ['b', 'c', 'd', 'e', 'f']) {
        await rig.emit(rig.order(id, 'i-$id'));
      }
      expect(rig.feed.current?.id, 'a');

      await rig.at(30);
      // b and c were pushed out by d, e and f.
      expect(rig.ids, ['a', 'd', 'e', 'f']);
      await rig.finish();
    });

    testWidgets('an order older than 30 s when it arrives is never shown', (
      tester,
    ) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('old', 'i-biryani', age: 31));
      expect(rig.feed.current, isNull);
      await rig.at(60);
      expect(rig.ids, isEmpty);

      // 30 s exactly is still fresh enough.
      await rig.emit(rig.order('edge', 'i-paneer', age: 30));
      expect(rig.feed.current?.id, 'edge');
      await rig.finish();
    });

    testWidgets('an order that went stale while it waited is dropped', (
      tester,
    ) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('a', 'i-biryani'));
      await rig.at(1);
      // Placed 15 s ago; its turn is at 20 s, when it will be 34 s old.
      await rig.emit(rig.order('late', 'i-paneer', age: 15));
      await rig.at(15);
      await rig.emit(rig.order('fresh', 'i-brownie'));

      await rig.at(40);
      expect(rig.ids, ['a', 'fresh']);
      expect(rig.shownAt('fresh'), 20, reason: 'it simply took the turn');
      await rig.finish();
    });

    testWidgets(
      'an order exactly 30 s old when its turn comes is still shown',
      (tester) async {
        final rig = Rig(tester);
        await rig.emit(rig.order('a', 'i-biryani'));
        await rig.at(1);
        // Placed 11 s ago, so exactly 30 s old at 20 s.
        await rig.emit(rig.order('edge', 'i-paneer', age: 11));
        await rig.at(20);
        expect(rig.feed.current?.id, 'edge');
        await rig.finish();
      },
    );

    testWidgets('an order stamped slightly ahead of the phone is not stale', (
      tester,
    ) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('ahead', 'i-biryani', age: -5));
      expect(rig.feed.current?.id, 'ahead');
      await rig.finish();
    });

    testWidgets('the same dish is not alerted again within two minutes', (
      tester,
    ) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('a', 'i-biryani'));
      await rig.at(8);
      await rig.emit(rig.order('b', 'i-biryani'));
      await rig.at(30);
      expect(rig.ids, ['a'], reason: 'b is the same dish, 30 s after a');

      // A different dish is not held back by that.
      await rig.emit(rig.order('other', 'i-paneer'));
      expect(rig.feed.current?.id, 'other');

      await rig.at(119.9);
      await rig.emit(rig.order('c', 'i-biryani'));
      expect(rig.ids, ['a', 'other'], reason: 'a was shown 119.9 s ago');

      await rig.at(120);
      await rig.emit(rig.order('d', 'i-biryani'));
      expect(rig.feed.current?.id, 'd', reason: 'two minutes have passed');
      await rig.finish();
    });

    testWidgets('two waiting orders for one dish give it one alert', (
      tester,
    ) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('a', 'i-paneer'));
      await rig.emit(rig.order('b', 'i-biryani'));
      await rig.emit(rig.order('c', 'i-biryani'));
      await rig.at(100);
      expect(rig.ids, ['a', 'b']);
      await rig.finish();
    });

    testWidgets('the same order id is never shown twice', (tester) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('x', 'i-biryani'));
      await rig.at(8);
      // Delivered again while waiting: it still takes one place.
      await rig.emit(rig.order('y', 'i-paneer'));
      await rig.emit(rig.order('y', 'i-paneer'));
      await rig.at(60);
      expect(rig.ids, ['x', 'y']);

      // And again long after the cooldown and the two minutes are over.
      await rig.at(300);
      await rig.emit(rig.order('x', 'i-biryani'));
      await rig.emit(rig.order('y', 'i-paneer'));
      expect(rig.feed.current, isNull);
      expect(rig.ids, ['x', 'y']);
      await rig.finish();
    });

    testWidgets('an order with no portions is ignored', (tester) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('none', 'i-biryani', qty: 0));
      expect(rig.feed.current, isNull);
      await rig.finish();
    });

    testWidgets('canShow is asked again when the order\'s turn comes', (
      tester,
    ) async {
      final inOrder = <String>{};
      final rig = Rig(tester, canShow: (o) => !inOrder.contains(o.itemId));
      await rig.emit(rig.order('a', 'i-biryani'));
      await rig.at(1);
      await rig.emit(rig.order('b', 'i-paneer'));
      await rig.at(2);
      await rig.emit(rig.order('c', 'i-brownie'));

      // The guest adds b's dish by themselves while b waits.
      await rig.at(10);
      inOrder.add('i-paneer');

      await rig.at(40);
      expect(rig.ids, ['a', 'c'], reason: 'b is skipped, c takes the turn');
      await rig.finish();
    });

    testWidgets('an order canShow refuses on arrival takes no place in the '
        'queue', (tester) async {
      final rig = Rig(
        tester,
        canShow: (o) => !o.itemId.startsWith('gone'),
        cooldown: const Duration(seconds: 1),
        showFor: const Duration(seconds: 2),
      );
      await rig.emit(rig.order('a', 'i-1'));
      for (var i = 0; i < 5; i++) {
        await rig.emit(rig.order('junk$i', 'gone-$i'));
      }
      await rig.emit(rig.order('g', 'i-g'));
      await rig.emit(rig.order('h', 'i-h'));
      await rig.emit(rig.order('i', 'i-i'));

      await rig.at(30);
      expect(rig.ids, ['a', 'g', 'h', 'i']);
      await rig.finish();
    });

    testWidgets('a canShow that fails only skips that order', (tester) async {
      final rig = Rig(
        tester,
        canShow: (o) => o.itemId == 'bad' ? throw StateError('boom') : true,
      );
      await rig.emit(rig.order('x', 'bad'));
      expect(rig.feed.current, isNull);
      await rig.emit(rig.order('y', 'i-paneer'));
      expect(rig.feed.current?.id, 'y');
      await rig.finish();
    });

    testWidgets(
      'listeners are told about every change and only about changes',
      (tester) async {
        final rig = Rig(tester);
        await rig.emit(rig.order('a', 'i-biryani'));
        expect(rig.notifications, 1);
        await rig.emit(rig.order('b', 'i-paneer'));
        expect(rig.notifications, 1, reason: 'a waiting order is not a change');
        rig.feed.dismiss();
        expect(rig.notifications, 2);
        await rig.at(25);
        expect(rig.notifications, 3, reason: 'b came on at 20 s');
        await rig.at(30);
        expect(rig.notifications, 4, reason: 'and went at 27 s');
        await rig.finish();
      },
    );

    testWidgets('a source that fails stops the feed quietly', (tester) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('a', 'i-biryani'));

      rig.fake.controller.addError(StateError('connection lost'));
      await tester.pump();
      expect(rig.fake.controller.hasListener, isFalse, reason: 'stopped');
      expect(tester.takeException(), isNull);

      // The alert already up simply runs its course; nothing new comes.
      expect(rig.feed.current?.id, 'a');
      rig.fake.controller.add(rig.order('b', 'i-paneer'));
      await rig.at(60);
      expect(rig.feed.current, isNull);
      expect(rig.ids, ['a']);
      await rig.finish();
    });

    testWidgets('a source that ends stops the feed quietly; waiting orders '
        'still get their turn', (tester) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('a', 'i-biryani'));
      await rig.emit(rig.order('b', 'i-paneer'));

      unawaited(rig.fake.controller.close());
      await tester.pump();
      expect(tester.takeException(), isNull);

      await rig.at(40);
      expect(rig.ids, ['a', 'b']);
      await rig.finish();
    });

    testWidgets('a source that cannot even be opened does not throw', (
      tester,
    ) async {
      final feed = NearbyFeed(
        source: ThrowingNearby(),
        canShow: (_) => true,
        now: tester.binding.clock.now,
      );
      feed.start();
      feed.start();
      expect(feed.current, isNull);
      feed.dispose();
    });

    testWidgets('dispose cancels the subscription and every timer', (
      tester,
    ) async {
      final rig = Rig(tester);
      await rig.emit(rig.order('a', 'i-biryani'));
      await rig.emit(rig.order('b', 'i-paneer'));
      final before = rig.notifications;

      rig.feed.dispose();
      expect(rig.fake.controller.hasListener, isFalse);

      // The test binding fails if a timer is left over; nothing may fire.
      await rig.at(300);
      expect(rig.notifications, before);
      rig.feed.start(); // after dispose: nothing happens
      expect(rig.fake.listens, 1);
      unawaited(rig.fake.controller.close());
      await tester.pump();
    });
  });

  group('GalleryNearby (the gallery\'s invented feed)', () {
    testWidgets('first order after 4 s, then one every 14 s, rotating', (
      tester,
    ) async {
      final nearby = GalleryNearby(['i-biryani', 'i-paneer', 'i-brownie']);
      final got = <NearbyOrder>[];
      final sub = nearby.orders().listen(got.add);

      await tester.pump(const Duration(milliseconds: 3900));
      expect(got, isEmpty);
      await tester.pump(const Duration(milliseconds: 100));
      expect(got, hasLength(1));
      await tester.pump(const Duration(seconds: 13));
      expect(got, hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(got, hasLength(2));
      await tester.pump(const Duration(seconds: 14 * 3));
      expect(got, hasLength(5));

      expect(
        [for (final o in got) o.itemId],
        ['i-biryani', 'i-paneer', 'i-brownie', 'i-biryani', 'i-paneer'],
      );
      expect({for (final o in got) o.who}.length, greaterThan(2));
      expect(got.map((o) => o.qty).toSet(), {1, 2});
      expect(got.map((o) => o.id).toSet(), hasLength(5), reason: 'unique ids');
      expect(got.first.who, startsWith('Table '));

      unawaited(sub.cancel());
      // Cancelling leaves no timer behind.
      await tester.pump(const Duration(minutes: 5));
      expect(got, hasLength(5));
    });

    testWidgets('every is adjustable and an empty dish list sends nothing', (
      tester,
    ) async {
      final quick = <NearbyOrder>[];
      final a = GalleryNearby(
        ['i-biryani'],
        every: const Duration(seconds: 2),
        startAfter: const Duration(seconds: 1),
      ).orders().listen(quick.add);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 4));
      expect(quick, hasLength(3));
      unawaited(a.cancel());

      final none = <NearbyOrder>[];
      final b = GalleryNearby(const []).orders().listen(none.add);
      await tester.pump(const Duration(minutes: 1));
      expect(none, isEmpty);
      unawaited(b.cancel());
      await tester.pump();
    });
  });

  group('NearbyAlertHost', () {
    final card = find.byKey(const ValueKey('nearby-alert'));
    final add = find.byKey(const ValueKey('nearby-add'));
    final close = find.byKey(const ValueKey('nearby-close'));
    final open = find.byKey(const ValueKey('nearby-open'));

    testWidgets('the alert appears over the categories page', (tester) async {
      final m = await openMenu(tester);
      expect(card, findsNothing);

      await orderedNearby(tester, m.fake, qty: 2);

      expect(card, findsOneWidget);
      expect(find.text('Table 7 just ordered'), findsOneWidget);
      // The no-break space keeps "×2" with the last word of the name.
      expect(find.text('Chicken Biryani\u00A0×2'), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Add')), findsOne);

      // In the phone column, 20 px in from each side, clear of the header.
      final box = tester.getRect(card);
      expect(box.left, 20);
      expect(box.right, 370);
      expect(box.top, 56);
      expect(box.height, inInclusiveRange(64, 80), reason: 'two lines tall');
      expect(find.byType(NearbyAlertHost), findsOneWidget);
    });

    testWidgets('a quantity of one shows no multiplier', (tester) async {
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake, itemId: 'i-paneer', qty: 1);
      expect(find.text('Paneer Tikka'), findsWidgets);
      expect(find.textContaining('×'), findsNothing);
    });

    testWidgets('a table the server did not name is "A table near you"', (
      tester,
    ) async {
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake, who: '  ');
      expect(find.text('A table near you just ordered'), findsOneWidget);
    });

    testWidgets('the buttons are at least 44 px, the Add word is the '
        'restaurant\'s own', (tester) async {
      final m = await openMenu(
        tester,
        definition: storefront(features: noBudget).copyWith(
          copy: StorefrontCopy({
            CopyLanguage.en: {'menu.add': 'Grab'},
          }),
        ),
      );
      await orderedNearby(tester, m.fake);
      expect(find.descendant(of: card, matching: find.text('Grab')), findsOne);
      expect(
        find.descendant(of: card, matching: find.text('Add')),
        findsNothing,
      );

      expect(tester.getSize(add).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(add).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(close), const Size(44, 44));
      expect(tester.getSize(open).height, greaterThanOrEqualTo(44));
    });

    testWidgets('Add takes the storefront\'s button shape and style', (
      tester,
    ) async {
      final m = await openMenu(
        tester,
        definition: storefront(features: noBudget).copyWith(
          theme: StorefrontTheme(
            buttonShape: StorefrontButtonShape.square,
            buttonStyle: StorefrontButtonStyle.outline,
          ),
        ),
      );
      await orderedNearby(tester, m.fake);
      final p = GuestPalette.of(tester.element(add));
      final pill = tester.widget<Material>(add);
      expect(pill.color, Colors.transparent, reason: 'outline, not filled');
      final shape = pill.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(6));
      expect(shape.side.color, p.accent);

      // And the default is the pill, filled with the accent.
      final d = await openMenu(tester);
      await orderedNearby(tester, d.fake);
      final plain = tester.widget<Material>(add);
      expect(plain.color, GuestPalette.of(tester.element(add)).accent);
      expect(plain.shape, isA<StadiumBorder>());
    });

    testWidgets('Add puts one portion in the order, says Added, then the card '
        'goes', (tester) async {
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake, qty: 2);
      expect(m.session.qtyOf('i-biryani'), 0);

      await tester.tap(add);
      await tester.pump();
      expect(
        m.session.qtyOf('i-biryani'),
        1,
        reason: 'one portion, not the two the other table had',
      );
      expect(m.feed.current, isNull, reason: 'the feed closed it at once');
      expect(find.text('Added'), findsOneWidget);
      expect(find.text('Add'), findsNothing);

      // A second tap while it says Added does not add a second portion.
      await tester.tap(add, warnIfMissed: false);
      await settle(tester, ms: 500);
      expect(m.session.qtyOf('i-biryani'), 1);
      expect(card, findsOneWidget, reason: 'still confirming after 0.5 s');

      await settle(tester, ms: 900);
      expect(card, findsNothing);
      expect(find.text('View order (1)'), findsOneWidget);
    });

    testWidgets('close dismisses the alert and adds nothing', (tester) async {
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake);

      await tester.tap(close);
      await tester.pump();
      expect(m.feed.current, isNull);
      expect(m.session.qtyOf('i-biryani'), 0);

      await settle(tester, ms: 400);
      expect(card, findsNothing);
      expect(find.text('View order (1)'), findsNothing);
    });

    testWidgets('closing while it says Added removes the card at once', (
      tester,
    ) async {
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake);
      await tester.tap(add);
      await tester.pump();
      await tester.tap(close);
      await settle(tester, ms: 400);
      expect(card, findsNothing);
      expect(m.session.qtyOf('i-biryani'), 1);
    });

    testWidgets('left alone, the alert closes itself after seven seconds', (
      tester,
    ) async {
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake);

      await settle(tester, ms: 6500);
      expect(card, findsOneWidget);
      await settle(tester, ms: 800);
      expect(card, findsNothing);
      expect(m.feed.current, isNull);
    });

    testWidgets('tapping the picture or name opens the dish and keeps the '
        'alert open', (tester) async {
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake);

      await tester.tap(open);
      await settle(tester, ms: 1800);

      expect(find.byType(GuestItemDetailScreen), findsOneWidget);
      expect(m.feed.current?.id, 'n1', reason: 'nobody closed it');
      expect(m.session.qtyOf('i-biryani'), 0);
      // The dish page is not a browsing page: it shows no alert of its own.
      expect(
        find.descendant(of: find.byType(GuestItemDetailScreen), matching: card),
        findsNothing,
      );
    });

    testWidgets('only the card takes taps; the page around it still does', (
      tester,
    ) async {
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake);

      // The search button sits in the header, beside the card's empty space.
      await tester.tap(find.byTooltip('Search'));
      await settle(tester);
      expect(find.text('Search dishes'), findsWidgets);
      expect(m.feed.current?.id, 'n1', reason: 'the alert was not touched');
    });

    testWidgets('the alert stays with the guest from categories to the deck', (
      tester,
    ) async {
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake);

      await tester.tap(find.text('All dishes').last);
      await settle(tester, ms: 1500);

      final onDeck = find.descendant(
        of: find.byType(GuestBrowseScreen),
        matching: card,
      );
      expect(onDeck, findsOneWidget);
      // Over the deck the whole page can still be used.
      await tester.tap(find.byKey(const ValueKey('deck-add')));
      await settle(tester, ms: 1600);
      expect(m.session.qtyOf('i-paneer'), 1);
    });

    testWidgets('a dish already in the order, or off the menu, is not '
        'alerted', (tester) async {
      final m = await openMenu(tester);
      m.session.add(m.session.catalog.item('i-biryani')!);
      await tester.pump();

      await orderedNearby(tester, m.fake, id: 'a');
      expect(card, findsNothing, reason: 'biryani is already in the order');

      await orderedNearby(tester, m.fake, id: 'b', itemId: 'i-ghost');
      expect(card, findsNothing, reason: 'not on this menu');

      await orderedNearby(tester, m.fake, id: 'c', itemId: 'i-brownie');
      expect(card, findsOneWidget);
    });

    testWidgets('with nothing shared, nothing is added to the page', (
      tester,
    ) async {
      await pumpGuest(
        tester,
        definition: storefront(features: noBudget),
        gateway: RecordingGateway(),
        table: table12,
      );
      await tapText(tester, 'Start exploring');
      expect(find.byType(GuestCategoriesScreen), findsOneWidget);
      expect(card, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('moving: slides down into place and fades in', (tester) async {
      final m = await openMenu(tester);
      m.fake.controller.add(nearbyOrder('n1'));
      await tester.pump();
      await tester.pump();

      final start = tester.getTopLeft(card);
      final opacity = tester.widget<FadeTransition>(
        find.ancestor(of: card, matching: find.byType(FadeTransition)).first,
      );
      expect(opacity.opacity.value, lessThan(0.1));

      await settle(tester, ms: 600);
      final end = tester.getTopLeft(card);
      expect(start.dx, end.dx);
      expect(start.dy, lessThan(end.dy), reason: 'it came down from above');
      expect(opacity.opacity.value, 1);
    });

    testWidgets('reduced motion: it only fades, it does not travel', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final m = await openMenu(tester);
      m.fake.controller.add(nearbyOrder('n1'));
      await tester.pump();
      await tester.pump();

      final start = tester.getTopLeft(card);
      final opacity = tester.widget<FadeTransition>(
        find.ancestor(of: card, matching: find.byType(FadeTransition)).first,
      );
      expect(opacity.opacity.value, lessThan(0.1), reason: 'it does fade');

      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getTopLeft(card), start, reason: 'never moves');
      await settle(tester, ms: 400);
      expect(tester.getTopLeft(card), start);
      expect(opacity.opacity.value, 1);
      expect(m.feed.current?.id, 'n1');
    });

    testWidgets('a screen reader hears it as one live message and can add or '
        'dismiss by action', (tester) async {
      final handle = tester.ensureSemantics();
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake, qty: 2);

      final alert = find.semantics.byLabel(
        'Table 7 just ordered Chicken Biryani ×2',
      );
      expect(alert, findsOneWidget);
      final data = alert.evaluate().single.getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      final actions = {
        for (final id in data.customSemanticsActionIds ?? [])
          CustomSemanticsAction.getAction(id as int)!.label,
      };
      expect(actions, {'Add to order', 'Dismiss'});

      // The words are said once: the texts inside the card are not read too.
      expect(find.semantics.byLabel('Table 7 just ordered'), findsNothing);

      // The two buttons can also be reached one by one.
      expect(find.semantics.byLabel('Add'), findsOneWidget);
      expect(find.semantics.byLabel('Dismiss'), findsOneWidget);

      tester.semantics.performAction(
        alert,
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Add to order'),
        ),
      );
      await settle(tester, ms: 300);
      expect(m.session.qtyOf('i-biryani'), 1);
      expect(
        find.semantics.byLabel('Added Chicken Biryani to your order'),
        findsOneWidget,
        reason: 'the live message changes, so it is read out again',
      );
      await settle(tester, ms: 1400);
      handle.dispose();
    });

    testWidgets('dismissing by action closes it', (tester) async {
      final handle = tester.ensureSemantics();
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake, qty: 1);

      tester.semantics.performAction(
        find.semantics.byLabel('Table 7 just ordered Chicken Biryani'),
        SemanticsAction.customAction,
        args: CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Dismiss'),
        ),
      );
      await settle(tester, ms: 400);
      expect(card, findsNothing);
      expect(m.feed.current, isNull);
      expect(m.session.qtyOf('i-biryani'), 0);
      handle.dispose();
    });

    testWidgets('a double tap on the card by a screen reader opens the dish', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final m = await openMenu(tester);
      await orderedNearby(tester, m.fake, qty: 1);

      tester.semantics.tap(
        find.semantics.byLabel('Table 7 just ordered Chicken Biryani'),
      );
      await settle(tester, ms: 1800);
      expect(find.byType(GuestItemDetailScreen), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a narrow phone, big text and a long name still fit', (
      tester,
    ) async {
      const longName = 'Hyderabadi Dum Chicken Biryani with Mirchi Ka Salan';
      final m = await openMenu(
        tester,
        snapshot: MenuSnapshot(
          categories: menu.categories,
          items: [
            for (final i in menu.items)
              if (i.id == 'i-biryani') i.copyWith(name: longName) else i,
          ],
        ),
      );
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();

      await orderedNearby(tester, m.fake, qty: 12, who: 'Table 15');
      expect(card, findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'nothing overflowed');
      final box = tester.getRect(card);
      expect(box.left, 20);
      expect(box.right, 300);
      // Add moved under the words rather than squeezing them to a few
      // letters, and the card is still only a few lines tall.
      expect(tester.getRect(add).top, greaterThan(tester.getRect(open).top));
      expect(box.height, lessThan(190));
      expect(tester.getRect(add).right, lessThanOrEqualTo(box.right));
      expect(tester.getRect(close).right, lessThanOrEqualTo(box.right));
    });

    testWidgets('endInset centres the card beside a side panel', (
      tester,
    ) async {
      GuestPalette.remoteFonts = false;
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = FakeNearby();
      final definition = storefront(features: noBudget);
      final session = GuestSession(
        definition: definition,
        menu: menu,
        gateway: NearbyGateway(fake),
        table: table12,
      );
      await tester.pumpWidget(
        GuestScope(
          session: session,
          onExit: null,
          child: MaterialApp(
            theme: GuestPalette.from(definition).toTheme(),
            home: const NearbyAlertHost(endInset: 380, child: Scaffold()),
          ),
        ),
      );
      fake.controller.add(nearbyOrder('n1'));
      await tester.pump();
      await tester.pump();
      await settle(tester, ms: 500);

      // Centred in the 1060 px left of a 380 px panel, not in the screen.
      expect(tester.getRect(card).center.dx, 530);
      expect(tester.getRect(card).width, 440);

      // Too little room would be left: the inset is ignored, not squeezed in.
      tester.view.physicalSize = const Size(600, 900);
      await tester.pump();
      expect(tester.getRect(card).center.dx, 300);
      expect(tester.getRect(card).width, 440);

      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });

    testWidgets('on a wide screen it stays in the phone-width column, '
        'centred', (tester) async {
      final m = await openMenu(tester);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pump();

      await orderedNearby(tester, m.fake);
      final box = tester.getRect(card);
      expect(box.width, 440, reason: '480 px column less 20 px each side');
      expect(box.center.dx, 720);
    });
  });
}

/// A gateway that, like a server that shares the tables around, has a stream
/// of what they order.
class NearbyGateway extends RecordingGateway {
  NearbyGateway(this.fake);
  final FakeNearby fake;

  @override
  GuestNearby? get nearby => fake;
}

typedef OpenMenu = ({FakeNearby fake, GuestSession session, NearbyFeed feed});

/// Welcome, past the start button, onto the categories page, which shows
/// alerts. The party's session and feed are the app's own.
Future<OpenMenu> openMenu(
  WidgetTester tester, {
  StorefrontDefinition? definition,
  MenuSnapshot snapshot = menu,
}) async {
  final fake = FakeNearby();
  await pumpGuest(
    tester,
    definition: definition ?? storefront(features: noBudget),
    gateway: NearbyGateway(fake),
    table: table12,
    snapshot: snapshot,
  );
  await tapText(tester, 'Start exploring');
  expect(find.byType(GuestCategoriesScreen), findsOneWidget);
  final session = GuestScope.read(tester.element(find.byType(NearbyAlertHost)));
  return (fake: fake, session: session, feed: session.nearbyFeed!);
}

NearbyOrder nearbyOrder(
  String id, {
  String itemId = 'i-biryani',
  int qty = 2,
  String who = 'Table 7',
}) =>
    NearbyOrder(id: id, itemId: itemId, qty: qty, who: who, at: DateTime.now());

/// Another table orders; the alert arrives and finishes sliding in.
Future<void> orderedNearby(
  WidgetTester tester,
  FakeNearby fake, {
  String id = 'n1',
  String itemId = 'i-biryani',
  int qty = 2,
  String who = 'Table 7',
}) async {
  fake.controller.add(nearbyOrder(id, itemId: itemId, qty: qty, who: who));
  await tester.pump();
  await tester.pump();
  await settle(tester, ms: 500);
}
