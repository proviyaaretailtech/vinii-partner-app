import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/application/bill_settings_controller.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/data/local_prefs.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/presentation/bill_settings/bill_settings_screen.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

Future<(BillSettingsController, FakeBackend, LocalPrefs)> _controller({
  bool canEdit = true,
  Map<String, Object> saved = const {},
  BillSettings? row,
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await LocalPrefs.open();
  final backend = FakeBackend();
  if (row != null) backend.saveBillSettingsElsewhere(row);
  final c = BillSettingsController(
    repository: backend.billSettings,
    prefs: prefs,
    orgId: 'org-1',
    canEdit: canEdit,
  );
  await c.load();
  return (c, backend, prefs);
}

void main() {
  group('the settings row', () {
    test('reads the database row and writes it back with blanks as null', () {
      final s = BillSettings.fromRow({
        'legal_name': ' Test Kitchen Pvt Ltd ',
        'address': null,
        'gstin': '22aaaaa0000a1z5',
        'fssai': '12345678901234',
        'phone': '98220 12345',
        'sgst_pct': '6.00',
        'cgst_pct': 6,
        'service_charge_pct': '10.00',
        'round_off_enabled': false,
        'footer_note': '',
        'updated_at': '2026-10-02T08:15:30.123456+00:00',
      });
      expect(s.legalName, 'Test Kitchen Pvt Ltd');
      expect(s.gstin, '22AAAAA0000A1Z5', reason: 'upper-cased');
      expect(s.gstPercent, 12);
      expect(s.serviceChargePercent, 10);
      expect(s.roundOff, isFalse);
      expect(s.exists, isTrue);

      final row = s.toRow('org-1');
      expect(row['organization_id'], 'org-1');
      expect(row['address'], isNull);
      expect(row['footer_note'], isNull);
      expect(row['sgst_pct'], 6);
      expect(row.containsKey('updated_at'), isFalse, reason: 'trigger sets it');
    });

    test('no row means the OS defaults and no version', () {
      final s = BillSettings.fromRow(null);
      expect(s.exists, isFalse);
      expect(s.gstPercent, 5);
      expect(s.serviceChargePercent, 0);
      expect(s.roundOff, isTrue);
    });

    test('GSTIN: the standard 15-character shape, capitals only', () {
      expect(gstinProblem(''), isNull, reason: 'optional');
      expect(gstinProblem('22AAAAA0000A1Z5'), isNull);
      expect(gstinProblem('27abcde1234f1z5'), isNull, reason: 'upper-cased');
      expect(gstinProblem('22AAAAA0000A1Z'), isNotNull, reason: 'too short');
      expect(gstinProblem('22AAAAA0000A1X5'), isNotNull, reason: 'no Z');
      expect(gstinProblem('AAAAAAA0000A1Z5'), isNotNull, reason: 'state code');
      expect(gstinProblem('22AAAAA0000A0Z5'), isNotNull, reason: 'entity 0');
    });

    test('FSSAI is 14 digits; the phone needs 10', () {
      expect(fssaiProblem('12345678901234'), isNull);
      expect(fssaiProblem('1234567890123'), isNotNull);
      expect(fssaiProblem('1234567890123A'), isNotNull);
      expect(billPhoneProblem('98220 12345'), isNull);
      expect(billPhoneProblem('+91 98220 12345'), isNull);
      expect(billPhoneProblem('12345'), isNotNull);
    });
  });

  group('the bill with a removed service charge', () {
    const ten = BillCharges(serviceChargePercent: 10);

    test('waiving takes the charge and the GST on it off the bill', () {
      final kept = BillSummary.of([(unitPrice: 1000, qty: 1)], charges: ten);
      final waived = BillSummary.of(
        [(unitPrice: 1000, qty: 1)],
        charges: ten,
        waiveServiceCharge: true,
      );
      expect(kept.serviceCharge, 100);
      expect(kept.payable, 1155); // 1100 + 27.50 + 27.50
      expect(waived.serviceCharge, 0);
      expect(waived.waivedServiceCharge, 100);
      expect(waived.serviceChargeWaived, isTrue);
      expect(waived.payable, 1050);
      expect(waived.servicePercent, 10);
    });

    test('waiving a bill that has no service charge changes nothing', () {
      final bill = BillSummary.of([
        (unitPrice: 1000, qty: 1),
      ], waiveServiceCharge: true);
      expect(bill.serviceChargeWaived, isFalse);
      expect(bill.waivedServiceCharge, 0);
      expect(bill.payable, 1050);
    });

    test('a saved bill works the percentage back from its amounts', () {
      final bill = BillSummary.stored(
        itemTotal: 1000,
        serviceCharge: 100,
        gst: 55,
        payable: 1155,
        gstPercent: 5,
      );
      expect(bill.servicePercent, 10);
    });
  });

  group('the Bill & GST working copy', () {
    test('starts from the saved row; nothing to save yet', () async {
      final (c, _, _) = await _controller();
      expect(c.saved!.exists, isFalse);
      expect(c.selectedGstPreset, 5);
      expect(c.customGst, isFalse);
      expect(c.serviceOn, isFalse);
      expect(c.isDirty, isFalse);
      expect(c.canSave, isFalse);
      expect(c.example.payable, 1050);
    });

    test('a GST preset sets CGST and SGST to half each', () async {
      final (c, _, _) = await _controller();
      c.pickGstPreset(18);
      expect([c.cgst, c.sgst], [9, 9]);
      expect(c.isDirty, isTrue);
      expect(c.example.sgst, 90);
      expect(c.example.payable, 1180);
      c.pickGstPreset(0);
      expect(c.example.payable, 1000);
    });

    test('a custom rate is split in half; out-of-range is refused', () async {
      final (c, _, _) = await _controller();
      c.pickCustomGst();
      c.setCustomGstText('7.5');
      expect([c.cgst, c.sgst], [3.75, 3.75]);
      expect(c.isValid, isTrue);
      c.setCustomGstText('120');
      expect(c.errors.containsKey(BillField.customGst), isTrue);
      expect(c.canSave, isFalse);
      c.setCustomGstText('12.55');
      expect(c.errors.containsKey(BillField.customGst), isTrue);
    });

    test('a saved rate that is not a preset opens as Custom', () async {
      final (c, _, _) = await _controller(
        row: const BillSettings(sgstPercent: 3.75, cgstPercent: 3.75),
      );
      expect(c.customGst, isTrue);
      expect(c.customGstText, '7.5');
      expect(c.selectedGstPreset, isNull);
    });

    test(
      'service charge: ON restores the last percentage, OFF saves 0',
      () async {
        final (c, backend, prefs) = await _controller(
          row: const BillSettings(serviceChargePercent: 7.5),
        );
        expect(c.serviceOn, isTrue);
        expect(c.serviceText, '7.5');
        expect(prefs.lastServiceCharge('org-1'), 7.5);

        c.setServiceOn(false);
        expect(c.draft.serviceChargePercent, 0);
        expect(c.example.serviceCharge, 0);
        expect(await c.save(), isTrue);
        expect(backend.billSettingsRow.serviceChargePercent, 0);

        c.setServiceOn(true);
        expect(c.serviceText, '7.5', reason: 'restored, not asked again');
        expect(c.example.serviceCharge, 75);
      },
    );

    test('with nothing remembered, ON starts at 5%', () async {
      final (c, _, _) = await _controller();
      c.setServiceOn(true);
      expect(c.serviceText, '5');
      expect(c.example.serviceCharge, 50);
    });

    test('service charge ON needs a percentage up to 50', () async {
      final (c, _, _) = await _controller();
      c.setServiceOn(true);
      c.setServiceText('');
      expect(c.errors.containsKey(BillField.service), isTrue);
      c.setServiceText('0');
      expect(c.errors.containsKey(BillField.service), isTrue);
      c.setServiceText('51');
      expect(c.errors.containsKey(BillField.service), isTrue);
      c.setServiceText('50');
      expect(c.errors, isEmpty);
      c.setServiceOn(false);
      c.setServiceText('');
      expect(c.errors, isEmpty, reason: 'OFF ignores the percentage box');
    });

    test(
      'a bad GSTIN blocks saving; a good one is saved in capitals',
      () async {
        final (c, backend, _) = await _controller();
        c.setGstin('22AAAA');
        expect(c.canSave, isFalse);
        c.setGstin('22aaaaa0000a1z5');
        expect(c.canSave, isTrue);
        expect(await c.save(), isTrue);
        expect(backend.billSettingsRow.gstin, '22AAAAA0000A1Z5');
        expect(c.justSaved, isTrue);
        expect(c.isDirty, isFalse, reason: 'saved, nothing left to save');
      },
    );

    test('a version that moved on is reported, and Reload fixes it', () async {
      final (c, backend, _) = await _controller(row: const BillSettings());
      c.pickGstPreset(12);
      backend.saveBillSettingsElsewhere(
        const BillSettings(sgstPercent: 9, cgstPercent: 9),
      );
      expect(await c.save(), isFalse);
      expect(c.stale, isTrue);
      expect(c.saveFailure?.kind, FailureKind.conflict);
      expect(c.canSave, isFalse);

      await c.load(force: true);
      expect(c.stale, isFalse);
      expect(c.gstTotal, 18, reason: 'their change, not ours');
      expect(c.isDirty, isFalse);
    });

    test('a failed save keeps the draft and says why', () async {
      final (c, backend, _) = await _controller();
      backend.failBillSettingsSave = const AppFailure(
        'You are offline.',
        kind: FailureKind.offline,
      );
      c.pickGstPreset(12);
      expect(await c.save(), isFalse);
      expect(c.saveFailure?.message, 'You are offline.');
      expect(c.stale, isFalse);
      expect(c.isDirty, isTrue);
      c.pickGstPreset(18);
      expect(c.saveFailure, isNull, reason: 'cleared by the next edit');
    });

    test('only owners and admins can save', () async {
      final (c, backend, _) = await _controller(canEdit: false);
      c.pickGstPreset(12);
      expect(c.canSave, isFalse);
      expect(await c.save(), isFalse);
      expect(backend.billSettingsSaves, isEmpty);
    });
  });

  group('the Bill & GST screen', () {
    Future<(AppServices, FakeBackend)> open(
      WidgetTester tester, {
      String role = 'org_owner',
      FakeBackend? backend,
      // Tall, so the whole form is on screen and tests need not scroll.
      Size size = const Size(1170, 6600),
      double ratio = 3,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = ratio;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      final b = backend ?? FakeBackend();
      final services = await testServices(b);
      services.session.membership = membershipAs(role);
      await tester.pumpWidget(wrapScreen(services, const BillSettingsScreen()));
      await tester.pumpAndSettle();
      return (services, b);
    }

    Finder save() => find.byKey(const Key('bill-save'));
    bool saveEnabled(WidgetTester tester) =>
        tester.widget<FilledButton>(save()).onPressed != null;

    testWidgets('an owner sees the sections and the example bill', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Bill & GST'), findsOneWidget);
      expect(find.text('CGST 2.5% + SGST 2.5%'), findsOneWidget);
      expect(find.text('Printed on every bill'), findsOneWidget);
      expect(find.text('Example: ₹1,000 of food'), findsOneWidget);
      expect(find.text('Guest pays'), findsOneWidget);
      expect(find.text('₹1,050'), findsOneWidget);
      expect(
        find.textContaining('No bill settings are saved yet'),
        findsOneWidget,
      );
      expect(saveEnabled(tester), isFalse, reason: 'nothing has changed');
      expect(find.text('Not saved yet.'), findsOneWidget);
    });

    testWidgets('picking 12% updates the split and the example, then saves', (
      tester,
    ) async {
      final (_, backend) = await open(tester);

      await tester.tap(find.text('12%'));
      await tester.pumpAndSettle();

      expect(find.text('CGST 6% + SGST 6%'), findsOneWidget);
      expect(find.text('₹1,120'), findsOneWidget);
      expect(saveEnabled(tester), isTrue);
      expect(
        find.text('You have changes that are not saved yet.'),
        findsOneWidget,
      );

      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(backend.billSettingsSaves.single.gstPercent, 12);
      expect(find.text('Bill settings saved.'), findsOneWidget);
      expect(find.text('All changes saved.'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('the service charge switch shows the percentage and the bill', (
      tester,
    ) async {
      final (_, backend) = await open(tester);

      expect(find.byKey(const Key('bill-service-percent')), findsNothing);
      await tester.tap(find.byKey(const Key('bill-service-switch')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('bill-service-switch')),
          matching: find.text('ON'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('bill-service-percent')), findsOneWidget);
      expect(find.text('Service charge (5%)'), findsOneWidget);

      await tester.tap(find.text('10%').last);
      await tester.pumpAndSettle();
      expect(find.text('Service charge (10%)'), findsOneWidget);
      expect(find.text('₹1,155'), findsOneWidget);

      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(backend.billSettingsRow.serviceChargePercent, 10);

      // OFF stores 0 and the next ON brings 10 back.
      await tester.tap(find.byKey(const Key('bill-service-switch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bill-service-percent')), findsNothing);
      await tester.tap(save());
      await tester.pumpAndSettle();
      expect(backend.billSettingsRow.serviceChargePercent, 0);

      await tester.tap(find.byKey(const Key('bill-service-switch')));
      await tester.pumpAndSettle();
      expect(find.text('Service charge (10%)'), findsOneWidget);
    });

    testWidgets('the rounding switch changes the example total', (
      tester,
    ) async {
      await open(
        tester,
        backend: FakeBackend()
          ..saveBillSettingsElsewhere(
            const BillSettings(sgstPercent: 2.255, cgstPercent: 2.255),
          ),
      );
      // 1000 + 22.55 + 22.55 = 1045.10 → rounded 1045
      expect(find.text('₹1,045'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bill-round-switch')));
      await tester.pumpAndSettle();
      expect(find.text('₹1,045.10'), findsOneWidget);
    });

    testWidgets('a half-typed GSTIN shows its error once the box is left', (
      tester,
    ) async {
      await open(tester);

      await tester.enterText(find.byKey(const Key('bill-gstin')), '22aaaa');
      await tester.pumpAndSettle();
      expect(find.text('22AAAA'), findsOneWidget, reason: 'capitals');
      expect(
        find.textContaining('A GSTIN has 15 letters and numbers'),
        findsNothing,
        reason: 'not while still typing',
      );

      await tester.tap(find.byKey(const Key('bill-fssai')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A GSTIN has 15 letters and numbers'),
        findsOneWidget,
      );
      expect(saveEnabled(tester), isFalse);
      expect(find.text('Fix the highlighted fields to save.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('bill-gstin')),
        '22AAAAA0000A1Z5',
      );
      await tester.pumpAndSettle();
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('FSSAI takes 14 digits and nothing else', (tester) async {
      await open(tester);
      await tester.enterText(
        find.byKey(const Key('bill-fssai')),
        '12ab3456789012345678',
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('bill-fssai')),
      );
      expect(field.controller!.text, '12345678901234');
    });

    testWidgets('a manager sees every field switched off', (tester) async {
      await open(tester, role: 'manager');

      expect(
        find.text('Only an owner or admin can change this.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('bill-save')), findsNothing);
      final gstin = tester.widget<TextField>(
        find.byKey(const Key('bill-gstin')),
      );
      expect(gstin.enabled, isFalse);
      final sw = tester.widget<Switch>(
        find.descendant(
          of: find.byKey(const Key('bill-round-switch')),
          matching: find.byType(Switch),
        ),
      );
      expect(sw.onChanged, isNull);
      // The example bill is still there to read.
      expect(find.text('Example: ₹1,000 of food'), findsOneWidget);
    });

    testWidgets('a role that may not look is told so', (tester) async {
      await open(tester, role: 'kitchen');
      expect(find.text('Not available for your role'), findsOneWidget);
      expect(find.byKey(const Key('bill-gstin')), findsNothing);
    });

    testWidgets('someone else saved first: Reload brings in their version', (
      tester,
    ) async {
      final backend = FakeBackend()
        ..saveBillSettingsElsewhere(const BillSettings());
      await open(tester, backend: backend);

      await tester.tap(find.text('12%'));
      await tester.pumpAndSettle();
      backend.saveBillSettingsElsewhere(
        const BillSettings(sgstPercent: 9, cgstPercent: 9),
      );
      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Someone else saved these settings'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('bill-save')), findsNothing);
      expect(backend.billSettingsSaves, isEmpty);

      await tester.tap(find.byKey(const Key('bill-reload')));
      await tester.pumpAndSettle();
      expect(find.text('CGST 9% + SGST 9%'), findsOneWidget);
      expect(find.byKey(const Key('bill-save')), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('a failed save says why and keeps the edits', (tester) async {
      final backend = FakeBackend()
        ..failBillSettingsSave = const AppFailure(
          'You are offline. Check the connection and try again.',
          kind: FailureKind.offline,
        );
      await open(tester, backend: backend);
      await tester.tap(find.text('18%'));
      await tester.pumpAndSettle();
      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(
        find.text('You are offline. Check the connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('CGST 9% + SGST 9%'), findsOneWidget);
      expect(saveEnabled(tester), isTrue, reason: 'the owner can try again');
    });

    testWidgets('on a real phone it scrolls to the end without overflowing', (
      tester,
    ) async {
      await open(tester, size: const Size(1170, 2532));
      expect(find.text('Bill & GST'), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bill-footer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('on a wide screen the form and the example sit side by side', (
      tester,
    ) async {
      await open(tester, size: const Size(1280, 800), ratio: 1);
      final preview = tester.getTopLeft(find.byKey(const Key('bill-preview')));
      final split = tester.getTopLeft(find.byKey(const Key('bill-gst-split')));
      expect(preview.dx, greaterThan(split.dx + 300));
      expect(tester.takeException(), isNull);
    });
  });
}
