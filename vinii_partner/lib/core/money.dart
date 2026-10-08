import 'package:intl/intl.dart';

/// Indian grouping (₹1,00,000) with Latin digits, in English and in Hindi
/// alike (docs/I18N.md rule 5). `hi_IN` and `en_IN` produce the same string;
/// the formatter follows the app's current language so a future locale with
/// its own grouping needs no change here.
final _whole = <String, NumberFormat>{};
final _paise = <String, NumberFormat>{};

String _localeFor(String? locale) {
  final l = locale ?? Intl.getCurrentLocale();
  return l.startsWith('hi') ? 'hi_IN' : 'en_IN';
}

NumberFormat _format(Map<String, NumberFormat> cache, String? locale, int d) {
  final key = _localeFor(locale);
  return cache[key] ??= NumberFormat.currency(
    locale: key,
    symbol: '₹',
    decimalDigits: d,
  );
}

/// `₹1,440` — Indian digit grouping (₹1,00,000). Paise are shown only when
/// the amount has them, so menu prices stay clean and GST lines stay exact.
String rupees(num amount, {String? locale}) {
  final hasPaise = (amount * 100).round() % 100 != 0;
  return (hasPaise ? _format(_paise, locale, 2) : _format(_whole, locale, 0))
      .format(amount);
}

/// `1,23,456` — a count or quantity with Indian grouping and no symbol.
String indianNumber(num value, {String? locale}) =>
    NumberFormat.decimalPattern(_localeFor(locale)).format(value);

/// Money is computed in paise so repeated additions never drift
/// (0.1 + 0.2 problems on a restaurant bill are not acceptable).
int toPaise(num rupees) => (rupees * 100).round();

double fromPaise(int paise) => paise / 100;
