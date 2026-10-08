import '../app_localizations.dart';
import 'types.dart';

/// Failure codes raised by the tables area: code -> sentence.
const Map<String, FailureBuilder> tablesFailureTexts = {
  'table_save_browser_only': _saveBrowserOnly,
  'table_picture_not_saved': _pictureNotSaved,
  'table_sheet_not_printed': _sheetNotPrinted,
  'table_issue_forbidden': _issueForbidden,
  'table_issue_busy': _issueBusy,
  'table_list_not_ready': _listNotReady,
  'table_issue_not_ready': _issueNotReady,
  'table_bad_shape': _badShape,
  'table_no_code_returned': _noCode,
};

String _saveBrowserOnly(AppLocalizations l, Map<String, Object?> a) =>
    l.tableFailSaveBrowserOnly;
String _pictureNotSaved(AppLocalizations l, Map<String, Object?> a) =>
    l.tableFailPictureNotSaved;
String _sheetNotPrinted(AppLocalizations l, Map<String, Object?> a) =>
    l.tableFailSheetNotPrinted;
String _issueForbidden(AppLocalizations l, Map<String, Object?> a) =>
    l.tableFailIssueForbidden;
String _issueBusy(AppLocalizations l, Map<String, Object?> a) =>
    l.tableFailBusy;
String _listNotReady(AppLocalizations l, Map<String, Object?> a) =>
    l.tableFailListNotReady;
String _issueNotReady(AppLocalizations l, Map<String, Object?> a) =>
    l.tableFailIssueNotReady;
String _badShape(AppLocalizations l, Map<String, Object?> a) =>
    l.tableFailBadShape;
String _noCode(AppLocalizations l, Map<String, Object?> a) => l.tableFailNoCode;
