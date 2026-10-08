import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/domain/delivery_order.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/domain/staff.dart';
import 'package:vinii_partner/l10n/app_localizations.dart';
import 'package:vinii_partner/l10n/app_localizations_en.dart';
import 'package:vinii_partner/l10n/app_localizations_hi.dart';
import 'package:vinii_partner/l10n/failure_text.dart';
import 'package:vinii_partner/l10n/failure_texts/auth.dart';
import 'package:vinii_partner/l10n/failure_texts/billing.dart';
import 'package:vinii_partner/l10n/failure_texts/core.dart';
import 'package:vinii_partner/l10n/failure_texts/guest.dart';
import 'package:vinii_partner/l10n/failure_texts/menu.dart';
import 'package:vinii_partner/l10n/failure_texts/orders.dart';
import 'package:vinii_partner/l10n/failure_texts/pos.dart';
import 'package:vinii_partner/l10n/failure_texts/session.dart';
import 'package:vinii_partner/l10n/failure_texts/studio.dart';
import 'package:vinii_partner/l10n/failure_texts/tables.dart';
import 'package:vinii_partner/l10n/failure_texts/team.dart';
import 'package:vinii_partner/l10n/labels.dart';

/// Status words, payment methods, roles and failure kinds travel as CODES;
/// every code must have a real label in every language.
void main() {
  final en = AppLocalizationsEn();
  final hi = AppLocalizationsHi();
  final both = <(String, AppLocalizations)>[('en', en), ('hi', hi)];

  /// A label exists, is not the raw code, and (for Hindi) is not just the
  /// English word again — except for acronyms that stay Latin on purpose.
  void expectLabeled<T>(
    Iterable<T> codes,
    String Function(AppLocalizations l, T code) label,
    String Function(T code) rawCode, {
    Set<String> sameInHindi = const {},
  }) {
    final seenEn = <String>{};
    for (final c in codes) {
      for (final (name, l) in both) {
        final text = label(l, c);
        expect(text.trim(), isNotEmpty, reason: '$c in $name');
        expect(text, isNot(rawCode(c)), reason: '$c shows its code in $name');
      }
      final e = label(en, c);
      final h = label(hi, c);
      if (!sameInHindi.contains(e)) {
        expect(h, isNot(e), reason: '$c is not translated: "$e"');
        expect(
          RegExp(r'[ऀ-ॿ]').hasMatch(h),
          isTrue,
          reason: '$c has no Devanagari: "$h"',
        );
      }
      seenEn.add(e);
    }
  }

  test('every POS order status has a label, distinct from the others', () {
    expectLabeled<PosStatus>(
      PosStatus.values,
      (l, s) => l.posStatusLabel(s),
      (s) => s.dbValue,
    );
    final labels = PosStatus.values.map(en.posStatusLabel).toSet();
    expect(labels.length, PosStatus.values.length);
  });

  test('the English words are the ones the app has always shown', () {
    expect(PosStatus.values.map(en.posStatusLabel), [
      'New',
      'In billing',
      'In kitchen',
      'Ready',
      'Awaiting payment',
      'Paid',
      'Served',
      'Cancelled',
    ]);
    expect(PaymentMethod.values.map(en.paymentMethodLabel), [
      'Cash',
      'UPI',
      'Card',
    ]);
    expect(ServiceType.values.map(en.serviceTypeLabel), [
      'Dine-in',
      'Takeaway',
      'Delivery',
    ]);
    expect(DeliveryStatus.values.map(en.deliveryStatusLabel), [
      'New',
      'Preparing',
      'Ready',
      'Out for delivery',
      'Delivered',
      'Cancelled',
    ]);
    expect(InboxTab.values.map(en.inboxTabLabel), [
      'New',
      'Preparing',
      'Ready',
      'Past',
    ]);
  });

  test('every delivery state and inbox tab has a label', () {
    expectLabeled<DeliveryStatus>(
      DeliveryStatus.values,
      (l, s) => l.deliveryStatusLabel(s),
      (s) => s.name,
    );
    expectLabeled<InboxTab>(
      InboxTab.values,
      (l, t) => l.inboxTabLabel(t),
      (t) => t.apiName,
    );
  });

  test('every payment method and service type has a label', () {
    expectLabeled<PaymentMethod>(
      PaymentMethod.values,
      (l, m) => l.paymentMethodLabel(m),
      (m) => m.dbValue,
      sameInHindi: {'UPI'}, // an acronym: Latin in Hindi too
    );
    expectLabeled<ServiceType>(
      ServiceType.values,
      (l, t) => l.serviceTypeLabel(t),
      (t) => t.channel,
    );
    expectLabeled<ServiceType>(
      ServiceType.values,
      (l, t) => l.serviceTypeHint(t),
      (t) => t.channel,
    );
  });

  test('every failure kind has a title', () {
    expectLabeled<FailureKind>(
      FailureKind.values,
      (l, k) => l.failureKindTitle(k),
      (k) => k.name,
    );
  });

  test('every role slug the app knows has a label (no raw slug)', () {
    final slugs = {for (final r in capabilityRoles.values) ...r};
    expect(slugs, isNotEmpty);
    for (final slug in slugs) {
      for (final (name, l) in both) {
        final text = l.roleLabel(slug);
        expect(text, isNot(slug), reason: '$slug has no label in $name');
        expect(text.trim(), isNotEmpty);
      }
      expect(
        RegExp(r'[ऀ-ॿ]').hasMatch(hi.roleLabel(slug)),
        isTrue,
        reason: '$slug has no Devanagari',
      );
    }
  });

  test('an unknown role falls back to its server name, then its slug', () {
    expect(hi.roleLabel('chef_de_cuisine', fallback: 'Chef'), 'Chef');
    expect(hi.roleLabel('chef_de_cuisine'), 'chef_de_cuisine');
    expect(en.roleLabel('chef_de_cuisine', fallback: '  '), 'chef_de_cuisine');
  });

  test(
    'every failure code in the catalogue gives a sentence in both languages',
    () {
      expect(failureCatalogue, isNotEmpty);
      for (final entry in failureCatalogue.entries) {
        final e = entry.value(en, const {});
        final h = entry.value(hi, const {});
        expect(e.trim(), isNotEmpty, reason: '${entry.key} (en)');
        expect(h.trim(), isNotEmpty, reason: '${entry.key} (hi)');
        expect(h, isNot(e), reason: '${entry.key} is not translated');
      }
    },
  );

  test('no failure code is claimed by two areas', () {
    final seen = <String>{};
    for (final area in [
      coreFailureTexts,
      authFailureTexts,
      sessionFailureTexts,
      ordersFailureTexts,
      posFailureTexts,
      menuFailureTexts,
      tablesFailureTexts,
      billingFailureTexts,
      studioFailureTexts,
      teamFailureTexts,
      guestFailureTexts,
    ]) {
      for (final code in area.keys) {
        expect(seen.add(code), isTrue, reason: 'duplicate code $code');
      }
    }
    expect(seen.length, failureCatalogue.length);
  });

  test(
    'a failure with no code, or an unknown one, shows its English message',
    () {
      const plain = AppFailure('Custom words');
      expect(failureText(hi, plain), 'Custom words');
      const unknown = AppFailure('Unknown thing', code: 'no_such_code');
      expect(failureText(hi, unknown), 'Unknown thing');
    },
  );

  test('a coded failure is translated, with the English text unchanged', () {
    const f = AppFailure(
      'You are offline. Check the connection and try again.',
      kind: FailureKind.offline,
      code: 'offline',
    );
    expect(failureText(en, f), f.message);
    expect(failureText(hi, f), contains('ऑफ़लाइन'));
  });
}
