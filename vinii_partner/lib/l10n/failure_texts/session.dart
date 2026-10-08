import '../app_localizations.dart';
import 'types.dart';

/// Failure codes raised by the session area: code -> sentence.
/// Add `'my_code': (l, a) => l.failMyCode,` (and import
/// '../app_localizations.dart' when you do) plus the matching ARB key.
const Map<String, FailureBuilder> sessionFailureTexts = {
  'channels_not_ready': _channelsNotReady,
  'channel_not_changed': _channelNotChanged,
};

String _channelsNotReady(AppLocalizations l, Map<String, Object?> a) =>
    l.channelsFailNotReady;
String _channelNotChanged(AppLocalizations l, Map<String, Object?> a) =>
    l.channelsFailNotChanged;
