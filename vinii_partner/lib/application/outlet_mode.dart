import '../domain/delivery_order.dart';

/// The three states of the store, as staff name them: Open, Paused, Closed.
enum OutletMode { open, paused, closed }

/// The opening time "Close for today" waits for: 9:00 AM today if that is
/// still ahead (closing after midnight), otherwise 9:00 AM tomorrow.
DateTime nextOpening([DateTime? now]) {
  final n = now ?? DateTime.now();
  final nine = DateTime(n.year, n.month, n.day, 9);
  return nine.isAfter(n) ? nine : DateTime(n.year, n.month, n.day + 1, 9);
}

/// Which of the three states the partner server's answer describes.
///
/// One Local keeps two facts, "accepting" and "back at". There is no third
/// value, so "Closed for today" is stored as not accepting until exactly
/// 9:00 AM, while a pause ends at a time counted from the moment it was set
/// (30 minutes, an hour, two hours), which is never exactly 9:00:00. Every
/// phone reads the same answer the same way, and nothing is kept on this
/// phone.
OutletMode outletModeOf(OutletStatus status) {
  if (status.accepting) return OutletMode.open;
  final back = status.backAt?.toLocal();
  if (back != null && back.hour == 9 && back.minute == 0 && back.second == 0) {
    return OutletMode.closed;
  }
  return OutletMode.paused;
}
