import '../app_localizations.dart';
import 'types.dart';

/// Failure codes raised by the studio area: code -> sentence.
/// Add `'my_code': (l, a) => l.failMyCode,` (and import
/// '../app_localizations.dart' when you do) plus the matching ARB key.
const Map<String, FailureBuilder> studioFailureTexts = {
  'studio_not_loaded': _notLoaded,
  'studio_publish_pending': _publishPending,
  'studio_problem_name': _problemName,
  'studio_problem_modes': _problemModes,
  'studio_problem_budget': _problemBudget,
  'studio_problem_preorder': _problemPreOrder,
  'studio_problem_empty_menu': _problemEmptyMenu,
};

String _notLoaded(AppLocalizations l, Map<String, Object?> a) =>
    l.studioNotLoaded;
String _publishPending(AppLocalizations l, Map<String, Object?> a) =>
    l.studioNoteDraftOnPhone;
String _problemName(AppLocalizations l, Map<String, Object?> a) =>
    l.studioProblemName;
String _problemModes(AppLocalizations l, Map<String, Object?> a) =>
    l.studioProblemModes;
String _problemBudget(AppLocalizations l, Map<String, Object?> a) =>
    l.studioProblemBudget;
String _problemPreOrder(AppLocalizations l, Map<String, Object?> a) =>
    l.studioProblemPreOrder;
String _problemEmptyMenu(AppLocalizations l, Map<String, Object?> a) =>
    l.studioProblemEmptyMenu;
