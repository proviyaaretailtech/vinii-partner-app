import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:vinii_partner/core/money.dart';
import 'package:vinii_partner/core/time_format.dart';
import 'package:vinii_partner/l10n/app_localizations_en.dart';
import 'package:vinii_partner/l10n/app_localizations_hi.dart';

/// Money and dates: Indian grouping and Latin digits in both languages, and
/// India's wall clock whatever timezone the phone is set to.
void main() {
  setUpAll(() => initializeDateFormatting('hi'));
  tearDown(() => Intl.defaultLocale = null);

  group('money', () {
    test('Indian grouping, ₹ prefix', () {
      expect(rupees(1440), '₹1,440');
      expect(rupees(100000), '₹1,00,000');
      expect(rupees(1234567), '₹12,34,567');
      expect(rupees(0), '₹0');
    });

    test('paise appear only when the amount has them', () {
      expect(rupees(99.5), '₹99.50');
      expect(rupees(1234567.05), '₹12,34,567.05');
      expect(rupees(120.0), '₹120');
    });

    test('Hindi keeps Latin digits and the same grouping', () {
      Intl.defaultLocale = 'hi';
      expect(rupees(1234567), '₹12,34,567');
      expect(rupees(99.5), '₹99.50');
      expect(
        rupees(1234567, locale: 'hi_IN'),
        rupees(1234567, locale: 'en_IN'),
      );
      expect(RegExp('[०-९]').hasMatch(rupees(1234567)), isFalse);
      expect(indianNumber(1234567), '12,34,567');
    });

    test('paise arithmetic does not drift', () {
      expect(toPaise(0.1 + 0.2), 30);
      expect(fromPaise(1050), 10.5);
    });
  });

  group('India time', () {
    // 06:30 UTC is 12:00 noon in India.
    final noon = DateTime.utc(2026, 10, 3, 6, 30);

    test('an instant is shown in Asia/Kolkata, not the phone\'s zone', () {
      expect(inIst(noon), DateTime.utc(2026, 10, 3, 12, 0));
      expect(clockTime(noon), '12:00 PM');
      expect(clockTime(DateTime.utc(2026, 10, 3, 18, 31)), '12:01 AM');
      // The next India day starts at 18:30 UTC.
      expect(dayMonth(DateTime.utc(2026, 10, 3, 18, 29)), '3 Oct');
      expect(dayMonth(DateTime.utc(2026, 10, 3, 18, 30)), '4 Oct');
    });

    test('a local instant converts the same way as its UTC twin', () {
      expect(clockTime(noon.toLocal()), clockTime(noon));
    });

    test('wall-clock values the person picked are not shifted', () {
      expect(wallClock(DateTime(2026, 10, 3, 19, 30)), '7:30 PM');
    });

    test('formats follow the language, digits stay Latin', () {
      expect(shortDay(noon), 'Sat, 3 Oct');
      Intl.defaultLocale = 'hi';
      expect(shortDay(noon), 'शनि, 3 अक्टू॰');
      expect(dayMonthYearTime(noon), '3 अक्टू॰ 2026, 12:00 pm');
      expect(RegExp('[०-९]').hasMatch(dayMonthYearTime(noon)), isFalse);
    });

    test('a locale with no date data falls back to English, never crashes', () {
      expect(dateFormat('d MMM', locale: 'xx_NOPE').pattern, 'd MMM');
    });

    test('countdown clock', () {
      expect(
        hms(const Duration(hours: 4, minutes: 18, seconds: 24)),
        '04:18:24',
      );
      expect(hms(const Duration(seconds: -5)), '00:00:00');
    });
  });

  group('time ago', () {
    final en = AppLocalizationsEn();
    final hi = AppLocalizationsHi();
    final now = DateTime.utc(2026, 10, 3, 12);

    test('English', () {
      expect(
        timeAgo(en, now.subtract(const Duration(seconds: 10)), now: now),
        'just now',
      );
      expect(
        timeAgo(en, now.subtract(const Duration(minutes: 4)), now: now),
        '4 min ago',
      );
      expect(
        timeAgo(en, now.subtract(const Duration(hours: 2)), now: now),
        '2 h ago',
      );
    });

    test('Hindi', () {
      expect(
        timeAgo(hi, now.subtract(const Duration(seconds: 10)), now: now),
        'अभी-अभी',
      );
      expect(
        timeAgo(hi, now.subtract(const Duration(minutes: 4)), now: now),
        '4 मिनट पहले',
      );
      expect(
        timeAgo(hi, now.subtract(const Duration(hours: 2)), now: now),
        '2 घंटे पहले',
      );
    });
  });
}
