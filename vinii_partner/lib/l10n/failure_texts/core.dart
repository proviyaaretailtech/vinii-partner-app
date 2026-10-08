import '../app_localizations.dart';
import 'types.dart';

/// Failures raised by the shared plumbing: connection, sign-in, the
/// database seams, and the coded errors the database functions raise
/// (`POS_STALE: …`, see lib/data/live/errors.dart).
const Map<String, FailureBuilder> coreFailureTexts = {
  'something_wrong': _somethingWrong,
  'offline': _offline,
  'not_ready': _notReady,
  'permission_denied': _permission,
  'already_exists': _alreadyExists,
  'invalid_details': _invalid,
  'record_gone': _recordGone,
  'session_ended': _sessionEnded,
  'upload_denied': _uploadDenied,
  'photo_too_large': _photoTooLarge,
  'bad_credentials': _badCredentials,
  'email_unconfirmed': _emailUnconfirmed,
  'rate_limited': _rateLimited,
  'user_banned': _userBanned,
  'sign_in_failed': _signInFailed,
  'signed_out_elsewhere': _signedOutElsewhere,
  'choose_org': _chooseOrg,
  'build_missing': _buildMissing,
  // Coded errors from the database functions: server_<name>.
  'server_stale': _stale,
  'server_conflict': _stale,
  'server_not_found': _notFound,
  'server_wrong_state': _wrongState,
  'server_forbidden': _forbidden,
  'server_bad_request': _badRequest,
  'server_expired': _expired,
  'server_gone': _expired,
  'server_item_unavailable': _itemUnavailable,
  'server_overpay': _overpay,
  'server_not_paid_in_full': _notPaidInFull,
  'server_has_payments': _hasPayments,
  'server_empty': _empty,
  'server_bad_qty': _badQty,
  'server_bad_table': _badTable,
  'server_coupon_unknown': _couponUnknown,
  'server_not_accepting': _notAccepting,
  'server_reason_needed': _reasonNeeded,
  'server_amount_received': _amountReceived,
};

String _somethingWrong(AppLocalizations l, Map<String, Object?> a) =>
    l.commonSomethingWrong;
String _offline(AppLocalizations l, Map<String, Object?> a) => l.failOffline;
String _notReady(AppLocalizations l, Map<String, Object?> a) => l.failNotReady;
String _permission(AppLocalizations l, Map<String, Object?> a) =>
    l.failPermission;
String _alreadyExists(AppLocalizations l, Map<String, Object?> a) =>
    l.failAlreadyExists;
String _invalid(AppLocalizations l, Map<String, Object?> a) =>
    l.failInvalidDetails;
String _recordGone(AppLocalizations l, Map<String, Object?> a) =>
    l.failRecordGone;
String _sessionEnded(AppLocalizations l, Map<String, Object?> a) =>
    l.failSessionEnded;
String _uploadDenied(AppLocalizations l, Map<String, Object?> a) =>
    l.failUploadDenied;
String _photoTooLarge(AppLocalizations l, Map<String, Object?> a) =>
    l.failPhotoTooLarge;
String _badCredentials(AppLocalizations l, Map<String, Object?> a) =>
    l.failBadCredentials;
String _emailUnconfirmed(AppLocalizations l, Map<String, Object?> a) =>
    l.failEmailUnconfirmed;
String _rateLimited(AppLocalizations l, Map<String, Object?> a) =>
    l.failRateLimited;
String _userBanned(AppLocalizations l, Map<String, Object?> a) =>
    l.failUserBanned;
String _signInFailed(AppLocalizations l, Map<String, Object?> a) =>
    l.failSignInFailed;
String _signedOutElsewhere(AppLocalizations l, Map<String, Object?> a) =>
    l.failSignedOutElsewhere;
String _chooseOrg(AppLocalizations l, Map<String, Object?> a) =>
    l.failChooseOrg;
String _buildMissing(AppLocalizations l, Map<String, Object?> a) =>
    l.failBuildMissing(settings: '${a['settings'] ?? ''}');
String _stale(AppLocalizations l, Map<String, Object?> a) => l.failServerStale;
String _notFound(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerNotFound;
String _wrongState(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerWrongState;
String _forbidden(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerForbidden;
String _badRequest(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerBadRequest;
String _expired(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerExpired;
String _itemUnavailable(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerItemUnavailable;
String _overpay(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerOverpay;
String _notPaidInFull(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerNotPaidInFull;
String _hasPayments(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerHasPayments;
String _empty(AppLocalizations l, Map<String, Object?> a) => l.failServerEmpty;
String _badQty(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerBadQty;
String _badTable(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerBadTable;
String _couponUnknown(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerCouponUnknown;
String _notAccepting(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerNotAccepting;
String _reasonNeeded(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerReasonNeeded;
String _amountReceived(AppLocalizations l, Map<String, Object?> a) =>
    l.failServerAmountReceived;
