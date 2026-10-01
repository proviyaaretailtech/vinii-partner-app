import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/app/routes.dart';
import 'package:vinii_partner/application/table_codes_controller.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/presentation/table_codes/code_exporter.dart';
import 'package:vinii_partner/presentation/table_codes/table_card_image.dart';
import 'package:vinii_partner/presentation/table_codes/table_codes_screen.dart';
import 'package:vinii_partner/presentation/table_codes/table_sheet_pdf.dart';
import 'package:vinii_partner/presentation/theme/staff_theme.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

const _t1 = TableCode(
  id: 't1',
  label: '1',
  seats: 2,
  areaName: 'Indoor',
  qrToken: 'abcdefghij',
);
const _t2 = TableCode(
  id: 't2',
  label: '2',
  areaName: 'Indoor',
  qrToken: 'k3x9a1b2c4',
  sortOrder: 1,
);
const _t3 = TableCode(id: 't3', label: '3', areaName: 'Indoor', sortOrder: 2);
const _t10 = TableCode(
  id: 't10',
  label: '10',
  seats: 6,
  areaName: 'Rooftop',
  qrToken: 'rooftop001',
);
const _t11 = TableCode(
  id: 't11',
  label: '11',
  areaName: 'Rooftop',
  isActive: false,
  qrToken: 'rooftop002',
);
const _counter = TableCode(id: 'tc', label: 'Counter', seats: 1);
const _tables = [_t1, _t2, _t3, _t10, _t11, _counter];

class _Exporter implements CodeExporter {
  final saved = <CodeCard>[];
  final printed = <({String title, List<CodeCard> cards})>[];
  AppFailure? failSave;
  AppFailure? failPrint;

  @override
  Future<void> saveImage(CodeCard card) async {
    if (failSave != null) throw failSave!;
    saved.add(card);
  }

  @override
  Future<void> printSheet(String title, List<CodeCard> cards) async {
    if (failPrint != null) throw failPrint!;
    printed.add((title: title, cards: cards));
  }
}

Future<(FakeBackend, _Exporter, List<String>)> _open(
  WidgetTester tester, {
  String role = 'manager',
  List<TableCode> tables = _tables,
  FakeBackend? backend,
}) async {
  tester.view.physicalSize = const Size(1170, 7000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  final b = backend ?? FakeBackend();
  b.tableCodeRows = [...tables];
  final services = await testServices(b);
  services.session.membership = membershipAs(role);
  final exporter = _Exporter();
  final router = GoRouter(
    initialLocation: Routes.tableCodes,
    routes: [
      GoRoute(
        path: Routes.tableCodes,
        builder: (context, state) => TableCodesScreen(exporter: exporter),
      ),
      GoRoute(
        path: '/guest',
        builder: (context, state) =>
            Text('Guest at ${state.uri.queryParameters['table']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp.router(
        theme: staffTheme(brightness: Brightness.light),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (b, exporter, copied);
}

void main() {
  group('the list of tables', () {
    test('groups follow the floor, with unsectioned tables last', () async {
      final b = FakeBackend()..tableCodeRows = [..._tables];
      final c = TableCodesController(repository: b.tableCodes, canIssue: true);
      await c.load();
      expect(
        [for (final g in c.groups) (g.name, g.tables.length)],
        [('Indoor', 3), ('Rooftop', 2), (null, 1)],
      );
      expect(c.withCodes.length, 4);
      expect(c.printable.map((t) => t.id), [
        't1',
        't2',
        't10',
      ], reason: 'a table out of service is not printed');
    });

    test('a link is the storefront address, /t/ and the code', () {
      expect(_t1.link('https://vinii.app'), 'https://vinii.app/t/abcdefghij');
      expect(_t1.link('https://vinii.app/'), 'https://vinii.app/t/abcdefghij');
      expect(_t3.link('https://vinii.app'), isNull);
    });

    test('only the right roles issue codes', () async {
      final b = FakeBackend()..tableCodeRows = [..._tables];
      final c = TableCodesController(repository: b.tableCodes, canIssue: false);
      await c.load();
      await expectLater(
        c.issue(_t3),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.forbidden,
          ),
        ),
      );
      expect(b.issuedCodes, 0);
    });
  });

  group('the Table QR codes screen', () {
    testWidgets('every table under its section, with the code it really has', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('Indoor · 3'), findsOneWidget);
      expect(find.text('Rooftop · 2'), findsOneWidget);
      expect(find.text('Other tables · 1'), findsOneWidget);
      expect(find.textContaining('4 of 6 tables have a code'), findsOneWidget);
      expect(find.text('Table 1'), findsOneWidget);
      expect(find.text('Counter'), findsOneWidget);

      final codes = tester
          .widgetList<TableCodeImage>(find.byType(TableCodeImage))
          .map((q) => q.link)
          .whereType<String>()
          .toSet();
      expect(codes, {
        'https://vinii.app/t/abcdefghij',
        'https://vinii.app/t/k3x9a1b2c4',
        'https://vinii.app/t/rooftop001',
        'https://vinii.app/t/rooftop002',
      });
      expect(find.text('vinii.app/t/abcdefghij'), findsOneWidget);
      expect(find.text('Not in use'), findsOneWidget);
      expect(find.text('No code yet'), findsNWidgets(2));
    });

    testWidgets('Preview as guest opens the storefront at that table', (
      tester,
    ) async {
      await _open(tester);

      expect(
        find.byKey(const Key('preview-t11')),
        findsNothing,
        reason: 'a table out of service has no guest',
      );
      await tester.tap(find.byKey(const Key('preview-t2')));
      await tester.pumpAndSettle();
      expect(find.text('Guest at t2'), findsOneWidget);
    });

    testWidgets('Copy link puts the table link on the clipboard', (
      tester,
    ) async {
      final (_, _, copied) = await _open(tester);
      await tester.tap(find.byKey(const Key('copy-t1')));
      await tester.pumpAndSettle();
      expect(copied, ['https://vinii.app/t/abcdefghij']);
      expect(find.text('Link for Table 1 copied.'), findsOneWidget);
    });

    testWidgets('Save image hands the card to the device', (tester) async {
      final (_, exporter, _) = await _open(tester);
      await tester.tap(find.byKey(const Key('save-t10')));
      await tester.pumpAndSettle();

      final card = exporter.saved.single;
      expect(card.tableName, 'Table 10');
      expect(card.restaurant, 'Test Kitchen');
      expect(card.link, 'https://vinii.app/t/rooftop001');
      expect(card.fileName, 'test-kitchen-table-10-qr.png');
      expect(find.text('Saved the picture for Table 10.'), findsOneWidget);
    });

    testWidgets('a device that cannot save a picture says so', (tester) async {
      final (_, exporter, _) = await _open(tester);
      exporter.failSave = const AppFailure(
        'Saving the picture works in the browser for now.',
        kind: FailureKind.notReady,
      );
      await tester.tap(find.byKey(const Key('save-t1')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('works in the browser for now'),
        findsOneWidget,
      );
    });

    testWidgets('Print all sends the in-use coded tables as one sheet', (
      tester,
    ) async {
      final (_, exporter, _) = await _open(tester);
      await tester.tap(find.byKey(const Key('print-all')));
      await tester.pumpAndSettle();

      final sheet = exporter.printed.single;
      expect(sheet.title, 'Table QR codes - Test Kitchen');
      expect(sheet.cards.map((c) => c.tableName), [
        'Table 1',
        'Table 2',
        'Table 10',
      ]);
    });

    testWidgets('Print all is off while no table has a code', (tester) async {
      await _open(tester, tables: const [_t3, _counter]);
      final button = tester.widget<TextButton>(
        find.byKey(const Key('print-all')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a manager issues the first code for a table', (tester) async {
      final (backend, _, _) = await _open(tester);

      await tester.tap(find.byKey(const Key('issue-t3')));
      await tester.pumpAndSettle();

      expect(backend.issuedCodes, 1);
      expect(find.byKey(const Key('issue-t3')), findsNothing);
      expect(find.text('vinii.app/t/issued0001'), findsOneWidget);
      expect(
        find.text('Code issued for Table 3. Print its sticker.'),
        findsOneWidget,
      );
      expect(find.text('No code yet'), findsOneWidget); // the counter still
    });

    testWidgets('a captain can look but not issue', (tester) async {
      await _open(tester, role: 'captain');
      expect(find.byType(QrImageView), findsNWidgets(4));
      expect(find.byKey(const Key('issue-t3')), findsNothing);
      expect(find.byKey(const Key('replace-t1')), findsNothing);
      expect(find.text('An admin or manager can issue it.'), findsNWidgets(2));
    });

    testWidgets('until the database function exists the dialog says so', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..failIssueCode = const AppFailure(
          'Issuing table codes from the phone needs a database update that is '
          'waiting for approval. Until then, issue codes from the VINII control '
          'panel.',
          kind: FailureKind.notReady,
        );
      final (_, _, _) = await _open(tester, backend: backend);

      await tester.tap(find.byKey(const Key('issue-t3')));
      await tester.pumpAndSettle();

      expect(find.text('Not available yet'), findsOneWidget);
      expect(find.textContaining('VINII control panel'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('issue-t3')), findsOneWidget);
    });

    testWidgets('replacing a code warns that printed stickers stop working', (
      tester,
    ) async {
      final (backend, _, _) = await _open(tester);

      await tester.tap(find.byKey(const Key('replace-t2')));
      await tester.pumpAndSettle();
      expect(find.text('Replace the code for Table 2?'), findsOneWidget);
      expect(
        find.textContaining('Printed stickers will stop working'),
        findsOneWidget,
      );

      await tester.tap(find.text('Keep the code'));
      await tester.pumpAndSettle();
      expect(backend.issuedCodes, 0);
      expect(find.text('vinii.app/t/k3x9a1b2c4'), findsOneWidget);

      await tester.tap(find.byKey(const Key('replace-t2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('replace-code-confirm')));
      await tester.pumpAndSettle();

      expect(backend.issuedCodes, 1);
      expect(find.text('vinii.app/t/k3x9a1b2c4'), findsNothing);
      expect(find.text('vinii.app/t/issued0001'), findsOneWidget);
      expect(find.textContaining('Print its new sticker'), findsOneWidget);
    });

    testWidgets('a restaurant with no tables is told where to add them', (
      tester,
    ) async {
      await _open(tester, tables: const []);
      expect(find.text('No tables yet'), findsOneWidget);
      expect(find.textContaining('VINII control panel'), findsOneWidget);
      expect(find.byKey(const Key('print-all')), findsNothing);
    });

    testWidgets('a role that may not look is told so', (tester) async {
      await _open(tester, role: 'kitchen');
      expect(find.text('Not available for your role'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('on a wide screen the tables sit in columns', (tester) async {
      tester.view.physicalSize = const Size(1280, 4000);
      tester.view.devicePixelRatio = 1;
      await _open(tester);
      // _open resets the size; set it again for this check.
      tester.view.physicalSize = const Size(1280, 4000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      final a = tester.getTopLeft(find.byKey(const Key('table-t1')));
      final b = tester.getTopLeft(find.byKey(const Key('table-t2')));
      expect(b.dy, a.dy, reason: 'side by side');
      expect(b.dx, greaterThan(a.dx + 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('the picture and the sheet', () {
    testWidgets('a card renders as a PNG picture', (tester) async {
      final png = await tester.runAsync(
        () => renderTableCardPng(
          link: 'https://vinii.app/t/abcdefghij',
          tableName: 'Table 1',
          restaurant: 'Test Kitchen',
        ),
      );
      expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(png.length, greaterThan(2000));
    });

    testWidgets('the words under a code render as a small picture', (
      tester,
    ) async {
      final label = await tester.runAsync(
        () => renderTableLabelPng(
          tableName: 'Table 1',
          restaurant: 'Test Kitchen',
        ),
      );
      expect(label!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(label.length, lessThan(60000));
    });

    testWidgets('cards are laid out on an A4 sheet, three across', (
      tester,
    ) async {
      final label = await tester.runAsync(
        () => renderTableLabelPng(
          tableName: 'Table 1',
          restaurant: 'Test Kitchen',
        ),
      );
      final pdf = await tester.runAsync(
        () => buildTableSheetPdf(
          title: 'Table QR codes',
          cards: [
            for (var i = 0; i < 10; i++)
              SheetCard(link: 'https://vinii.app/t/abcdefghi$i', label: label!),
          ],
        ),
      );
      expect(String.fromCharCodes(pdf!.sublist(0, 5)), '%PDF-');
      // Ten cards at nine a page: two pages.
      final pages = RegExp(r'/Type\s*/Page\b')
          .allMatches(String.fromCharCodes(pdf))
          .length;
      expect(pages, 2);
    });
  });
}
