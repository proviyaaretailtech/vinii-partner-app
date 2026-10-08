import '../app_localizations.dart';
import 'types.dart';

/// Failure codes raised by the pos area: code -> sentence.
/// Add `'my_code': (l, a) => l.failMyCode,` (and import
/// '../app_localizations.dart' when you do) plus the matching ARB key.
const Map<String, FailureBuilder> posFailureTexts = {
  // Sell flow: the cart and its blockers (sell_).
  'sell_blocker_empty': _sellBlockerEmpty,
  'sell_blocker_no_table': _sellBlockerNoTable,
  'sell_blocker_no_phone': _sellBlockerNoPhone,
  'sell_already_sending': _sellAlreadySending,
  // Payment, checkout and the POS data layer (pay_ / charge_).
  'pay_second_part_failed': _paySecondPartFailed,
  'pay_add_item': _payAddItem,
  'pay_choose_table': _payChooseTable,
  'pay_enter_received': _payEnterReceived,
  'pay_bad_order_shape': _payBadOrderShape,
  'pay_tables_not_ready': _payTablesNotReady,
  'pay_place_not_ready': _payPlaceNotReady,
  'pay_record_not_ready': _payRecordNotReady,
  'pay_status_not_ready': _payStatusNotReady,
  'charge_adjust_not_ready': _chargeAdjustNotReady,
};

String _paySecondPartFailed(AppLocalizations l, Map<String, Object?> a) =>
    l.failPaySecondPartFailed(reason: '${a['reason'] ?? ''}');
String _payAddItem(AppLocalizations l, Map<String, Object?> a) =>
    l.failPayAddItem;
// Same sentences as the server codes server_bad_table / server_amount_received.
String _payChooseTable(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerBadTable;
String _payEnterReceived(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerAmountReceived;
String _payBadOrderShape(AppLocalizations l, Map<String, Object?> a) =>
    l.failPayBadOrderShape;
String _payTablesNotReady(AppLocalizations l, Map<String, Object?> a) =>
    l.failPayTablesNotReady;
String _payPlaceNotReady(AppLocalizations l, Map<String, Object?> a) =>
    l.failPayPlaceNotReady;
String _payRecordNotReady(AppLocalizations l, Map<String, Object?> a) =>
    l.failPayRecordNotReady;
String _payStatusNotReady(AppLocalizations l, Map<String, Object?> a) =>
    l.failPayStatusNotReady;
String _chargeAdjustNotReady(AppLocalizations l, Map<String, Object?> a) =>
    l.failChargeAdjustNotReady;

String _sellBlockerEmpty(AppLocalizations l, Map<String, Object?> a) =>
    l.sellBlockerEmpty;
String _sellBlockerNoTable(AppLocalizations l, Map<String, Object?> a) =>
    l.sellBlockerNoTable;
String _sellBlockerNoPhone(AppLocalizations l, Map<String, Object?> a) =>
    l.sellBlockerNoPhone;
String _sellAlreadySending(AppLocalizations l, Map<String, Object?> a) =>
    l.sellAlreadySending;
