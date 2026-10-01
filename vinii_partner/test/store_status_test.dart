import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/application/outlet_mode.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/domain/delivery_order.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/domain/staff.dart';
import 'package:vinii_partner/presentation/orders/outlet_bar.dart';
import 'package:vinii_partner/presentation/settings/settings_screen.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

Future<AppServices> _services(
  WidgetTester tester,
  FakeBackend backend, {
  String role = 'manager',
  Size size = const Size(1170, 4400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  final services = await testServices(backend);
  await services.prefs.setRingEnabled(false);
  services.session.membership = membershipAs(role);
  services.session.user = const StaffUser(id: 'u-1', email: 'me@example.com');
  return services;
}

Future<AppServices> _openBar(
  WidgetTester tester,
  FakeBackend backend, {
  String role = 'manager',
}) async {
  final services = await _services(tester, backend, role: role);
  await services.inbox.refreshOutlet();
  await tester.pumpWidget(
    wrapScreen(
      services,
      const Scaffold(
        body: Padding(padding: EdgeInsets.all(16), child: OutletBar()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return services;
}

void main() {
  group('which state the server answer means', () {
    test('accepting is Open, whatever else it says', () {
      expect(
        outletModeOf(OutletStatus(accepting: true, backAt: DateTime.now())),
        OutletMode.open,
      );
    });

    test('a timed or open-ended pause is Paused', () {
      final soon = DateTime.now().add(const Duration(minutes: 30));
      expect(
        outletModeOf(OutletStatus(accepting: false, backAt: soon)),
        OutletMode.paused,
      );
      expect(
        outletModeOf(const OutletStatus(accepting: false)),
        OutletMode.paused,
      );
    });

    test('off until exactly 9:00 AM is Closed for today', () {
      expect(
        outletModeOf(
          OutletStatus(accepting: false, backAt: DateTime(2026, 10, 3, 9)),
        ),
        OutletMode.closed,
      );
      // Thirty seconds past 9 is not the opening time: that is a pause.
      expect(
        outletModeOf(
          OutletStatus(
            accepting: false,
            backAt: DateTime(2026, 10, 3, 9, 0, 30),
          ),
        ),
        OutletMode.paused,
      );
    });

    test('closing before 9 waits for this morning, after 9 for tomorrow', () {
      expect(
        nextOpening(DateTime(2026, 10, 2, 1, 30)),
        DateTime(2026, 10, 2, 9),
      );
      expect(
        nextOpening(DateTime(2026, 10, 2, 8, 59)),
        DateTime(2026, 10, 2, 9),
      );
      expect(nextOpening(DateTime(2026, 10, 2, 9)), DateTime(2026, 10, 3, 9));
      expect(nextOpening(DateTime(2026, 10, 2, 22)), DateTime(2026, 10, 3, 9));
      expect(nextOpening(DateTime(2026, 12, 31, 22)), DateTime(2027, 1, 1, 9));
    });
  });

  group('the store status control', () {
    testWidgets('open: green, a word, an icon and three choices', (
      tester,
    ) async {
      await _openBar(tester, FakeBackend());

      expect(find.text('Open'), findsNWidgets(2)); // the state and its button
      expect(find.textContaining('Accepting orders'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Close today'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('Pause asks how long, then pauses', (tester) async {
      final backend = FakeBackend();
      await _openBar(tester, backend);

      await tester.tap(find.byKey(const Key('outlet-paused')));
      await tester.pumpAndSettle();
      expect(find.text('Pause new orders'), findsOneWidget);
      expect(find.text('30 minutes'), findsOneWidget);
      expect(find.text('1 hour'), findsOneWidget);
      expect(find.text('2 hours'), findsOneWidget);
      expect(find.text('Until I turn it back on'), findsOneWidget);
      expect(
        find.textContaining('morning'),
        findsNothing,
        reason: 'the 9 AM choice is Close today now',
      );

      final before = DateTime.now();
      await tester.tap(find.text('30 minutes'));
      await tester.pumpAndSettle();

      expect(backend.outletStatus.accepting, isFalse);
      final back = backend.outletStatus.backAt!;
      expect(back.difference(before).inMinutes, inInclusiveRange(29, 30));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.textContaining('Back at'), findsWidgets);
      expect(find.byIcon(Icons.pause_circle_rounded), findsWidgets);
    });

    testWidgets('an open-ended pause says so', (tester) async {
      final backend = FakeBackend();
      await _openBar(tester, backend);

      await tester.tap(find.byKey(const Key('outlet-paused')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Until I turn it back on'));
      await tester.pumpAndSettle();

      expect(backend.outletStatus.accepting, isFalse);
      expect(backend.outletStatus.backAt, isNull);
      expect(find.text('Until you turn it back on'), findsOneWidget);
    });

    testWidgets('Close for today asks once, then stays closed until 9 AM', (
      tester,
    ) async {
      final backend = FakeBackend();
      await _openBar(tester, backend);

      await tester.tap(find.byKey(const Key('outlet-closed')));
      await tester.pumpAndSettle();
      expect(find.text('Close for today?'), findsOneWidget);
      expect(find.textContaining('9:00 AM'), findsOneWidget);
      expect(
        find.textContaining('Orders you already accepted are not affected'),
        findsOneWidget,
      );
      expect(backend.outletStatus.accepting, isTrue, reason: 'not yet');

      await tester.tap(find.byKey(const Key('outlet-close-confirm')));
      await tester.pumpAndSettle();

      expect(backend.outletStatus.accepting, isFalse);
      final back = backend.outletStatus.backAt!;
      expect([back.hour, back.minute, back.second], [9, 0, 0]);
      expect(back.isAfter(DateTime.now()), isTrue);
      expect(find.text('Closed'), findsOneWidget);
      expect(find.textContaining('Closed for today. Opens'), findsWidgets);
      expect(find.byIcon(Icons.do_not_disturb_on_rounded), findsWidgets);
    });

    testWidgets('Keep open leaves the store as it was', (tester) async {
      final backend = FakeBackend();
      await _openBar(tester, backend);

      await tester.tap(find.byKey(const Key('outlet-closed')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep open'));
      await tester.pumpAndSettle();

      expect(backend.outletStatus.accepting, isTrue);
      expect(find.textContaining('Accepting orders'), findsOneWidget);
    });

    testWidgets('from Closed, Open turns orders back on', (tester) async {
      final backend = FakeBackend()
        ..outletStatus = OutletStatus(accepting: false, backAt: nextOpening());
      await _openBar(tester, backend);
      expect(find.text('Closed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('outlet-open')));
      await tester.pumpAndSettle();

      expect(backend.outletStatus.accepting, isTrue);
      expect(backend.outletStatus.backAt, isNull);
      expect(
        find.text('Accepting orders. New ones ring on this phone.'),
        findsOneWidget,
      );
      expect(find.text('Open. Accepting orders again.'), findsOneWidget);
    });

    testWidgets('a refusal is explained and the state does not change', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..failOutletChange = const AppFailure(
          'One Local is not answering. Check the connection and try again.',
          kind: FailureKind.offline,
        );
      await _openBar(tester, backend);

      await tester.tap(find.byKey(const Key('outlet-paused')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 hour'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'One Local is not answering. Check the connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Accepting orders'), findsOneWidget);
    });

    testWidgets('a kitchen login sees the state and a lock, not the choices', (
      tester,
    ) async {
      await _openBar(tester, FakeBackend(), role: 'kitchen');

      expect(find.textContaining('Accepting orders'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.text('Only a manager can change this.'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Close today'), findsNothing);
    });

    testWidgets('does not overflow on a narrow phone', (tester) async {
      final backend = FakeBackend();
      // 320 logical pixels wide: the smallest phone still in use.
      final services = await _services(
        tester,
        backend,
        size: const Size(960, 1600),
      );
      await services.inbox.refreshOutlet();
      await tester.pumpWidget(
        wrapScreen(
          services,
          const Scaffold(
            body: Padding(padding: EdgeInsets.all(16), child: OutletBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Close today'), findsOneWidget);
    });
  });

  group('sales channels in More', () {
    const swiggy = SalesChannel(
      id: 'c-1',
      key: 'swiggy',
      name: 'Swiggy',
      connected: true,
      accepting: true,
    );
    const zomato = SalesChannel(
      id: 'c-2',
      key: 'zomato',
      name: 'Zomato',
      connected: true,
      accepting: false,
    );
    const website = SalesChannel(
      id: 'c-3',
      key: 'website',
      name: 'Website',
      connected: false,
      accepting: true,
    );

    Future<FakeBackend> openMore(
      WidgetTester tester, {
      String role = 'manager',
      List<SalesChannel> channels = const [swiggy, zomato, website],
    }) async {
      final backend = FakeBackend()..channelRows = [...channels];
      final services = await _services(tester, backend, role: role);
      await tester.pumpWidget(wrapScreen(services, const SettingsScreen()));
      await tester.pumpAndSettle();
      return backend;
    }

    Finder switchOf(String key) => find.descendant(
      of: find.byKey(Key('channel-$key')),
      matching: find.byType(Switch),
    );

    testWidgets(
      'each channel has its own ON/OFF; unconnected ones are off limits',
      (tester) async {
        await openMore(tester);

        expect(find.text('Sales channels'), findsOneWidget);
        expect(find.text('Swiggy'), findsOneWidget);
        expect(find.text('Taking orders'), findsOneWidget);
        expect(find.text('Not taking orders'), findsOneWidget);
        expect(find.text('Not connected yet'), findsOneWidget);
        expect(tester.widget<Switch>(switchOf('swiggy')).value, isTrue);
        expect(tester.widget<Switch>(switchOf('zomato')).value, isFalse);
        expect(tester.widget<Switch>(switchOf('website')).onChanged, isNull);
      },
    );

    testWidgets('switching OFF tells you what it costs and offers Undo', (
      tester,
    ) async {
      final backend = await openMore(tester);

      await tester.tap(switchOf('swiggy'));
      await tester.pumpAndSettle();

      expect(
        backend.channelRows.firstWhere((c) => c.key == 'swiggy').accepting,
        isFalse,
      );
      expect(
        find.text(
          'Swiggy is OFF. You will not get Swiggy orders until you turn it on.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        backend.channelRows.firstWhere((c) => c.key == 'swiggy').accepting,
        isTrue,
      );
    });

    testWidgets('switching ON just says so', (tester) async {
      final backend = await openMore(tester);
      await tester.tap(switchOf('zomato'));
      await tester.pumpAndSettle();
      expect(
        backend.channelRows.firstWhere((c) => c.key == 'zomato').accepting,
        isTrue,
      );
      expect(find.text('Zomato is ON.'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('a restaurant with no channels is told so, not shown samples', (
      tester,
    ) async {
      await openMore(tester, channels: const []);
      expect(
        find.textContaining('No sales channels are set up yet'),
        findsOneWidget,
      );
      expect(find.text('Swiggy'), findsNothing);
    });

    testWidgets('a channel that fails to switch stays as it was', (
      tester,
    ) async {
      final backend = await openMore(tester);
      backend.failChannelChange = const AppFailure(
        'That channel could not be changed. You may not have permission.',
        kind: FailureKind.forbidden,
      );
      await tester.tap(switchOf('swiggy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be changed'), findsOneWidget);
      expect(tester.widget<Switch>(switchOf('swiggy')).value, isTrue);
    });

    testWidgets('only owners, admins and managers get the switches', (
      tester,
    ) async {
      await openMore(tester, role: 'biller');
      expect(find.text('Sales channels'), findsNothing);
      expect(find.text('Swiggy'), findsNothing);
    });
  });

  group('what More offers each role', () {
    Future<void> as(WidgetTester tester, String role) async {
      final services = await _services(tester, FakeBackend(), role: role);
      await tester.pumpWidget(wrapScreen(services, const SettingsScreen()));
      await tester.pumpAndSettle();
    }

    final bill = find.text('Bill & GST');
    final team = find.text('Team');
    final codes = find.text('Table QR codes');

    testWidgets('an owner or manager sees all three', (tester) async {
      await as(tester, 'org_owner');
      expect([bill, team, codes].map((f) => f.evaluate().length), [1, 1, 1]);
      await as(tester, 'manager');
      expect([bill, team, codes].map((f) => f.evaluate().length), [1, 1, 1]);
    });

    testWidgets('a biller may look at the bill settings', (tester) async {
      await as(tester, 'biller');
      expect([bill, team, codes].map((f) => f.evaluate().length), [1, 1, 1]);
    });

    testWidgets('a captain sees the team and the table codes only', (
      tester,
    ) async {
      await as(tester, 'captain');
      expect([bill, team, codes].map((f) => f.evaluate().length), [0, 1, 1]);
    });

    testWidgets('a kitchen login sees the team list, nothing about money', (
      tester,
    ) async {
      await as(tester, 'kitchen');
      expect([bill, team, codes].map((f) => f.evaluate().length), [0, 1, 0]);
    });
  });
}
