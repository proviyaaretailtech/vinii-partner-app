import '../app_localizations.dart';
import 'types.dart';

/// Failure codes raised by the guest area: code -> sentence.
/// Add `'my_code': (l, a) => l.failMyCode,` (and import
/// '../app_localizations.dart' when you do) plus the matching ARB key.
const Map<String, FailureBuilder> guestFailureTexts = {
  'guest_already_placing': _alreadyPlacing,
  'guest_not_marked_guest': _notMarkedGuest,
  'guest_pay_web_only': _payWebOnly,
  'guest_pay_unreachable': _payUnreachable,
};

String _alreadyPlacing(AppLocalizations l, Map<String, Object?> a) =>
    l.failGuestAlreadyPlacing;

String _notMarkedGuest(AppLocalizations l, Map<String, Object?> a) =>
    l.failGuestNotMarkedGuest;

String _payWebOnly(AppLocalizations l, Map<String, Object?> a) =>
    l.failGuestPayWebOnly;

String _payUnreachable(AppLocalizations l, Map<String, Object?> a) =>
    l.failGuestPayUnreachable;
