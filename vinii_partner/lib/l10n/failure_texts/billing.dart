import '../app_localizations.dart';
import 'types.dart';

/// Failure codes raised by the billing area: code -> sentence.
const Map<String, FailureBuilder> billingFailureTexts = {
  'bill_not_ready': _notReady,
  'bill_conflict': _conflict,
  'bill_not_saved': _notSaved,
};

String _notReady(AppLocalizations l, Map<String, Object?> a) =>
    l.billFailNotReady;
String _conflict(AppLocalizations l, Map<String, Object?> a) =>
    l.billFailConflict;
String _notSaved(AppLocalizations l, Map<String, Object?> a) =>
    l.billFailNotSaved;
