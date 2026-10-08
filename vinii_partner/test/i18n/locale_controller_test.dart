import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/l10n/l10n.dart';
import 'package:vinii_partner/l10n/locale_controller.dart';
import 'package:vinii_partner/l10n/locales.dart';
import 'package:vinii_partner/presentation/settings/language_screen.dart';

import '../support/fake_backend.dart';
import '../support/fake_fonts.dart';
import '../support/harness.dart';

/// The language machinery: instant in-place switching, the lazy Devanagari
/// font, the inline loader and its failure path, last tap wins, the saved
/// language applied before the first frame, and the silent server mirror.
class _Rig {
  _Rig._(this.backend, this.fonts, this.services, this.announced);

  final FakeBackend backend;
  final FakeScriptFonts fonts;
  final AppServices services;
  final List<String> announced;

  LocaleController get locale => services.locale;

  static Future<_Rig> make({
    Map<String, Object> prefs = const {},
    List<Locale> device = const [Locale('en', 'US')],
    bool fontReady = false,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final backend = FakeBackend();
    final fonts = FakeScriptFonts(ready: fontReady);
    final announced = <String>[];
    final services = await testServices(
      backend,
      prefsValues: prefs,
      localeController: (p) => LocaleController(
        prefs: p,
        server: backend.userPreferences,
        fonts: fonts,
        timeout: timeout,
        deviceLocales: device,
        announcer: (m, _) => announced.add(m),
      ),
    );
    return _Rig._(backend, fonts, services, announced);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => Intl.defaultLocale = null);

  group('switching in place', () {
    testWidgets('repaints at once and keeps typed text, scroll and route', (
      tester,
    ) async {
      final rig = await _Rig.make(fontReady: true);
      final field = TextEditingController();
      final scroll = ScrollController();
      await tester.pumpWidget(
        wrapLocalized(
          rig.services,
          Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  Text(context.l10n.commonSave),
                  Expanded(
                    child: ListView(
                      controller: scroll,
                      children: [
                        TextField(controller: field),
                        for (var i = 0; i < 40; i++)
                          SizedBox(height: 60, child: Text('row $i')),
                        FilledButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                body: Text(
                                  context.l10n.commonCancel,
                                  key: const Key('second'),
                                ),
                              ),
                            ),
                          ),
                          child: const Text('go'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'पनीर 2 plates');
      scroll.jumpTo(300);
      await tester.pump();
      expect(find.text('Save'), findsOneWidget);

      await rig.locale.select(hindiLocale);
      await tester.pump();

      expect(find.text('सहेजें'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(field.text, 'पनीर 2 plates');
      expect(scroll.offset, 300);
      expect(Intl.defaultLocale, 'hi');

      // A pushed route stays put too, and follows the language.
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('second')), findsOneWidget);
      expect(find.text('रद्द करें'), findsOneWidget);
      await rig.locale.select(englishLocale);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('second')), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('number and date formats follow in the same frame', (
      tester,
    ) async {
      final rig = await _Rig.make(fontReady: true);
      await tester.pumpWidget(
        wrapLocalized(
          rig.services,
          Builder(
            builder: (context) => Text(
              DateFormat('EEE').format(DateTime.utc(2026, 10, 3)),
              key: const Key('day'),
            ),
          ),
        ),
      );
      expect(tester.widget<Text>(find.byKey(const Key('day'))).data, 'Sat');
      await rig.locale.select(hindiLocale);
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('day'))).data, 'शनि');
    });
  });

  group('the Devanagari font is lazy', () {
    test('an English start never loads it', () async {
      final rig = await _Rig.make(device: const [Locale('en', 'IN')]);
      await rig.locale.restore();
      expect(rig.fonts.loads, 0);
      expect(rig.locale.active, englishLocale);
    });

    test('an unknown phone language falls back to English', () async {
      final rig = await _Rig.make(device: const [Locale('fr'), Locale('de')]);
      await rig.locale.restore();
      expect(rig.locale.active, englishLocale);
      expect(rig.fonts.loads, 0);
    });

    test('a Hindi phone loads it before the first frame', () async {
      final rig = await _Rig.make(device: const [Locale('hi', 'IN')]);
      await rig.locale.restore();
      expect(rig.fonts.loads, 1);
      expect(rig.locale.active, hindiLocale);
      expect(rig.fonts.isReady(ScriptKind.devanagari), isTrue);
    });

    test('the saved language beats the phone language', () async {
      final rig = await _Rig.make(
        prefs: {'locale': 'en'},
        device: const [Locale('hi', 'IN')],
      );
      await rig.locale.restore();
      expect(rig.locale.active, englishLocale);
      expect(rig.fonts.loads, 0);
    });

    testWidgets('saved Hindi is on screen in the very first frame', (
      tester,
    ) async {
      final rig = await _Rig.make(prefs: {'locale': 'hi'});
      await rig.locale.restore(); // what main() awaits before runApp
      expect(rig.fonts.loads, 1);
      await tester.pumpWidget(
        wrapLocalized(
          rig.services,
          Builder(builder: (context) => Text(context.l10n.commonSave)),
        ),
      );
      // One frame, no further pumps: Hindi already.
      expect(find.text('सहेजें'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('a font that cannot load at start-up starts in English, keeps '
        'the saved choice, and switches when a retry succeeds', (tester) async {
      final rig = await _Rig.make(prefs: {'locale': 'hi'});
      rig.fonts.failWith = Exception('offline');
      await rig.locale.restore();
      expect(rig.locale.active, englishLocale);
      expect(rig.services.prefs.localeCode, 'hi');

      rig.fonts.failWith = null;
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(rig.locale.active, hindiLocale);
    });
  });

  group('the loader', () {
    testWidgets('shows on the chosen tile only; English stays until the swap', (
      tester,
    ) async {
      final rig = await _Rig.make();
      final gate = rig.fonts.hold();
      await tester.pumpWidget(
        wrapLocalized(rig.services, const LanguageScreen()),
      );
      expect(find.text('Language'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('हिन्दी'));
      await tester.pump();

      // Still English everywhere; one inline spinner, no dialog.
      expect(find.text('Language'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      final spinnerTile = find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(of: spinnerTile, matching: find.text('हिन्दी')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: spinnerTile, matching: find.text('English')),
        findsNothing,
      );
      expect(rig.locale.active, englishLocale);
      expect(rig.locale.pending, hindiLocale);

      gate.complete();
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('भाषा'), findsOneWidget); // swapped, atomically
      expect(find.text('Language'), findsNothing);
      expect(rig.locale.active, hindiLocale);
      expect(rig.locale.pending, isNull);
    });

    testWidgets(
      'a failed load keeps English, shows an inline error and Retry',
      (tester) async {
        final rig = await _Rig.make();
        rig.fonts.failWith = Exception('network');
        await tester.pumpWidget(
          wrapLocalized(rig.services, const LanguageScreen()),
        );
        await tester.tap(find.text('हिन्दी'));
        await tester.pump();
        await tester.pump();

        expect(rig.locale.active, englishLocale);
        expect(rig.locale.failed, hindiLocale);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.textContaining('Could not switch to हिन्दी'),
          findsOneWidget,
        );
        expect(find.text('Language'), findsOneWidget);

        rig.fonts.failWith = null;
        await tester.tap(find.text('Try again'));
        await tester.pump();
        await tester.pump();
        expect(rig.locale.active, hindiLocale);
        expect(rig.locale.failed, isNull);
        expect(find.text('भाषा'), findsOneWidget);
      },
    );

    testWidgets('a font that takes longer than 8 seconds counts as failed', (
      tester,
    ) async {
      final rig = await _Rig.make();
      rig.fonts.hold(); // never completes
      await tester.pumpWidget(
        wrapLocalized(rig.services, const LanguageScreen()),
      );
      await tester.tap(find.text('हिन्दी'));
      await tester.pump(const Duration(seconds: 7));
      expect(rig.locale.pending, hindiLocale);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(rig.locale.pending, isNull);
      expect(rig.locale.failed, hindiLocale);
      expect(rig.locale.active, englishLocale);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('double tap loads once; the last selection wins', (
      tester,
    ) async {
      final rig = await _Rig.make();
      final gate = rig.fonts.hold();
      await tester.pumpWidget(
        wrapLocalized(rig.services, const LanguageScreen()),
      );
      await tester.tap(find.text('हिन्दी'));
      await tester.tap(find.text('हिन्दी'));
      await tester.pump();
      expect(rig.fonts.loads, 1, reason: 'one shared load for two taps');

      // Changed their mind while it loads: back to English.
      await tester.tap(find.text('English'));
      await tester.pump();
      expect(rig.locale.pending, isNull);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(rig.locale.active, englishLocale, reason: 'last tap won');
      expect(find.text('Language'), findsOneWidget);

      // And the other way round: English then Hindi, Hindi wins.
      await tester.tap(find.text('हिन्दी'));
      await tester.pump();
      await tester.pump();
      expect(rig.locale.active, hindiLocale);
    });

    testWidgets('a slow earlier request cannot overwrite a later choice', (
      tester,
    ) async {
      final rig = await _Rig.make();
      final gate = rig.fonts.hold();
      unawaited(rig.locale.select(hindiLocale)); // slow
      await tester.pump();
      unawaited(rig.locale.select(englishLocale)); // newer choice
      await tester.pump();
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(rig.locale.active, englishLocale);
      expect(rig.locale.failed, isNull);
    });
  });

  group('accessibility', () {
    testWidgets('tiles are a radio group; the change is announced in the new '
        'language', (tester) async {
      final handle = tester.ensureSemantics();
      final rig = await _Rig.make(fontReady: true);
      await tester.pumpWidget(
        wrapLocalized(rig.services, const LanguageScreen()),
      );
      SemanticsNode node(String label) => tester.getSemantics(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
      );
      bool checked(SemanticsNode n) =>
          n.getSemanticsData().flagsCollection.isChecked == CheckedState.isTrue;
      expect(checked(node('English')), isTrue);
      expect(checked(node('हिन्दी')), isFalse);
      expect(
        node('हिन्दी')
            .getSemanticsData()
            .flagsCollection
            .isInMutuallyExclusiveGroup,
        isTrue,
      );

      await tester.tap(find.text('हिन्दी'));
      await tester.pump();
      await tester.pump();
      expect(checked(node('हिन्दी')), isTrue);
      expect(checked(node('English')), isFalse);
      expect(rig.announced, ['भाषा बदलकर हिन्दी हो गई']);
      handle.dispose();
    });
  });

  group('the server mirror', () {
    test(
      'a choice is written to user_preferences and the flag cleared',
      () async {
        final rig = await _Rig.make(fontReady: true);
        await rig.locale.syncForUser('u1');
        await rig.locale.select(hindiLocale);
        await Future<void>.delayed(Duration.zero);
        expect(rig.backend.userPreferences.saves, [
          (userId: 'u1', locale: 'hi'),
        ]);
        expect(rig.services.prefs.localeCode, 'hi');
        expect(rig.services.prefs.localeSyncPending, isFalse);
      },
    );

    test('offline: silent, remembered, retried on the next launch', () async {
      final rig = await _Rig.make(fontReady: true);
      rig.backend.userPreferences.offline = true;
      await rig.locale.syncForUser('u1');
      await rig.locale.select(hindiLocale); // must not throw
      await Future<void>.delayed(Duration.zero);
      expect(rig.locale.active, hindiLocale);
      expect(rig.services.prefs.localeCode, 'hi');
      expect(rig.services.prefs.localeSyncPending, isTrue);
      expect(rig.backend.userPreferences.saves, isEmpty);

      // Next launch: same prefs, back online, the person signs in again.
      rig.backend.userPreferences.offline = false;
      final next = LocaleController(
        prefs: rig.services.prefs,
        server: rig.backend.userPreferences,
        fonts: rig.fonts,
        deviceLocales: const [Locale('en')],
      );
      await next.restore();
      expect(next.active, hindiLocale);
      await next.syncForUser('u1');
      expect(rig.backend.userPreferences.saves, [(userId: 'u1', locale: 'hi')]);
      expect(rig.services.prefs.localeSyncPending, isFalse);
    });

    test('chosen while signed out: written once somebody signs in', () async {
      final rig = await _Rig.make(fontReady: true);
      await rig.locale.select(hindiLocale);
      expect(rig.services.prefs.localeSyncPending, isTrue);
      expect(rig.backend.userPreferences.saves, isEmpty);
      await rig.locale.syncForUser('u9');
      expect(rig.backend.userPreferences.saves, [(userId: 'u9', locale: 'hi')]);
    });

    test('a new phone adopts the language saved on the server', () async {
      final rig = await _Rig.make(fontReady: true);
      rig.backend.userPreferences.stored['u1'] = 'hi';
      await rig.locale.syncForUser('u1');
      expect(rig.locale.active, hindiLocale);
      expect(rig.services.prefs.localeCode, 'hi');
      expect(rig.services.prefs.localeSyncPending, isFalse);
      expect(rig.backend.userPreferences.saves, isEmpty, reason: 'no echo');
      expect(rig.announced, isEmpty, reason: 'a silent adoption');
    });

    test(
      'an explicit choice on this phone is not overridden by the server',
      () async {
        final rig = await _Rig.make(prefs: {'locale': 'en'}, fontReady: true);
        rig.backend.userPreferences.stored['u1'] = 'hi';
        await rig.locale.syncForUser('u1');
        expect(rig.locale.active, englishLocale);
      },
    );

    test('a server that cannot be reached is silent', () async {
      final rig = await _Rig.make(fontReady: true);
      rig.backend.userPreferences.offline = true;
      await rig.locale.syncForUser('u1'); // must not throw
      expect(rig.locale.active, englishLocale);
    });
  });
}
