import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Wall-clock time in India. A restaurant's day is Asia/Kolkata whatever
/// timezone the phone is set to; India has no daylight saving, so a fixed
/// +05:30 offset is exact.
///
/// Use it for INSTANTS (a `placed_at` timestamp from the server). A value
/// the person built from a picker ("7:30 PM", "tomorrow") is already wall
/// clock: format it directly with [wallClock] / [DateFormat].
DateTime inIst(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 5, minutes: 30));

/// A [DateFormat] for [pattern] in the language the app is showing right now
/// (`Intl.defaultLocale`, which `LocaleController` sets on every switch).
/// Digits stay Latin (0-9) in Hindi, as docs/I18N.md requires.
DateFormat dateFormat(String pattern, {String? locale}) {
  try {
    return DateFormat(pattern, locale);
  } on ArgumentError {
    // Date symbols for this locale are not loaded: English, never a crash.
    return DateFormat(pattern, 'en');
  }
}

/// "just now", "4 min ago", "2 h ago", then the date.
String timeAgo(AppLocalizations l, DateTime at, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(at);
  if (diff.inSeconds < 45) return l.timeJustNow;
  if (diff.inMinutes < 60) return l.timeMinutesAgo(minutes: diff.inMinutes);
  if (diff.inHours < 24) return l.timeHoursAgo(hours: diff.inHours);
  return dayMonth(at);
}

/// 12:14 PM (India time)
String clockTime(DateTime at) => dateFormat('h:mm a').format(inIst(at));

/// 12:14 PM for a value that is already wall clock (a picked time slot).
String wallClock(DateTime at) => dateFormat('h:mm a').format(at);

/// 16 Sep (India time)
String dayMonth(DateTime at) => dateFormat('d MMM').format(inIst(at));

/// Sat, 16 Sep (India time)
String shortDay(DateTime at) => dateFormat('EEE, d MMM').format(inIst(at));

/// 16 Sep 2026, 12:14 PM (India time)
String dayMonthYearTime(DateTime at) =>
    dateFormat('d MMM y, h:mm a').format(inIst(at));

/// 04:18:24 — used by countdowns such as "Limited today, ends in".
String hms(Duration d) {
  final v = d.isNegative ? Duration.zero : d;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(v.inHours)}:${two(v.inMinutes % 60)}:${two(v.inSeconds % 60)}';
}
