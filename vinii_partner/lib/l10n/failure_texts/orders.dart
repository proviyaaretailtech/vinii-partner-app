import '../app_localizations.dart';
import 'types.dart';

/// Failure codes raised by the orders area: code -> sentence.
///
/// Also used here but registered in core.dart: `session_ended`,
/// `permission_denied`, `something_wrong`, `offline`.
const Map<String, FailureBuilder> ordersFailureTexts = {
  'orders_unavailable': _unavailable,
  'orders_gone': _gone,
  'orders_changed_first': _changedFirst,
  'orders_request_refused': _requestRefused,
  'orders_update_app': _updateApp,
  'orders_not_connected_db': _notConnectedDb,
  'orders_could_not': _couldNot,
  'orders_not_answering': _notAnswering,
  'orders_bad_reply': _badReply,
  'orders_wrong_org': _wrongOrg,
  'orders_already_sending': _alreadySending,
};

String _unavailable(AppLocalizations l, Map<String, Object?> a) =>
    l.failOrdersUnavailable;
String _gone(AppLocalizations l, Map<String, Object?> a) => l.failOrdersGone;
String _changedFirst(AppLocalizations l, Map<String, Object?> a) =>
    l.failOrdersChangedFirst;
String _requestRefused(AppLocalizations l, Map<String, Object?> a) =>
    l.failOrdersRequestRefused;
String _updateApp(AppLocalizations l, Map<String, Object?> a) =>
    l.failOrdersUpdateApp;
String _notConnectedDb(AppLocalizations l, Map<String, Object?> a) =>
    l.failOrdersNotConnectedDb;
String _couldNot(AppLocalizations l, Map<String, Object?> a) =>
    l.failOrdersCouldNot(status: '${a['status'] ?? ''}');
String _notAnswering(AppLocalizations l, Map<String, Object?> a) =>
    l.failOrdersNotAnswering;
String _badReply(AppLocalizations l, Map<String, Object?> a) =>
    l.failOrdersBadReply;
String _wrongOrg(AppLocalizations l, Map<String, Object?> a) =>
    l.failOrdersWrongOrg(
      name: a['name'] == null ? l.ordersAnotherRestaurant : '${a['name']}',
      org: '${a['org'] ?? ''}',
    );
String _alreadySending(AppLocalizations l, Map<String, Object?> a) =>
    l.failOrdersAlreadySending;
