import '../app_localizations.dart';

/// Turns one failure code (and its arguments) into a sentence in the
/// reader's language. Each area keeps its own map (`orders.dart`, `pos.dart`
/// …) so screens being converted in parallel never edit the same file.
typedef FailureBuilder = String Function(
  AppLocalizations l,
  Map<String, Object?> args,
);
