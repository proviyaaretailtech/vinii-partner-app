import '../app_localizations.dart';
import 'types.dart';

/// Failure codes raised by the team area: code -> sentence.
const Map<String, FailureBuilder> teamFailureTexts = {
  'team_not_admin': _notAdmin,
  'team_self_role': _selfRole,
  'team_self_suspend': _selfSuspend,
  'team_last_admin': _lastAdmin,
  'team_already_saving': _alreadySaving,
};

String _notAdmin(AppLocalizations l, Map<String, Object?> a) =>
    l.teamBlockNotAdmin;
String _selfRole(AppLocalizations l, Map<String, Object?> a) =>
    l.teamBlockSelfRole;
String _selfSuspend(AppLocalizations l, Map<String, Object?> a) =>
    l.teamBlockSelfSuspend;
String _lastAdmin(AppLocalizations l, Map<String, Object?> a) =>
    l.teamBlockLastAdmin;
String _alreadySaving(AppLocalizations l, Map<String, Object?> a) =>
    l.teamAlreadySaving;
