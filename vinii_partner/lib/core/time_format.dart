import 'package:intl/intl.dart';

/// "just now", "4 min ago", "2 h ago", then the date.
String timeAgo(DateTime at, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(at);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return DateFormat('d MMM').format(at.toLocal());
}

/// 12:14 PM
String clockTime(DateTime at) => DateFormat('h:mm a').format(at.toLocal());

/// Sat, 16 Sep
String shortDay(DateTime at) => DateFormat('EEE, d MMM').format(at.toLocal());

/// 04:18:24 — used by countdowns such as "Limited today, ends in".
String hms(Duration d) {
  final v = d.isNegative ? Duration.zero : d;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(v.inHours)}:${two(v.inMinutes % 60)}:${two(v.inSeconds % 60)}';
}
