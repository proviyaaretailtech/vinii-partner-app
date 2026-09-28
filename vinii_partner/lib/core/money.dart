import 'package:intl/intl.dart';

final _whole = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
final _paise = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// `₹1,440` — Indian digit grouping (₹1,00,000). Paise are shown only when
/// the amount has them, so menu prices stay clean and GST lines stay exact.
String rupees(num amount) {
  final hasPaise = (amount * 100).round() % 100 != 0;
  return (hasPaise ? _paise : _whole).format(amount);
}

/// Money is computed in paise so repeated additions never drift
/// (0.1 + 0.2 problems on a restaurant bill are not acceptable).
int toPaise(num rupees) => (rupees * 100).round();

double fromPaise(int paise) => paise / 100;
