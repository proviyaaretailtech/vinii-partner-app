import '../core/failure.dart';
import 'app_localizations.dart';
import 'failure_texts/auth.dart';
import 'failure_texts/billing.dart';
import 'failure_texts/core.dart';
import 'failure_texts/guest.dart';
import 'failure_texts/menu.dart';
import 'failure_texts/orders.dart';
import 'failure_texts/pos.dart';
import 'failure_texts/session.dart';
import 'failure_texts/studio.dart';
import 'failure_texts/tables.dart';
import 'failure_texts/team.dart';
import 'failure_texts/types.dart';

/// Every code -> sentence map, one per area (see AppFailure.code).
final Map<String, FailureBuilder> failureCatalogue = {
  ...coreFailureTexts,
  ...authFailureTexts,
  ...sessionFailureTexts,
  ...ordersFailureTexts,
  ...posFailureTexts,
  ...menuFailureTexts,
  ...tablesFailureTexts,
  ...billingFailureTexts,
  ...studioFailureTexts,
  ...teamFailureTexts,
  ...guestFailureTexts,
};

/// The sentence for [failure] in the reader's language. A failure whose code
/// has no translation yet shows its English [AppFailure.message] — never a
/// blank and never the code itself.
String failureText(AppLocalizations l, AppFailure failure) {
  final build = failure.code == null ? null : failureCatalogue[failure.code];
  return build?.call(l, failure.args) ?? failure.message;
}
