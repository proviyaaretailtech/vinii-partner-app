/// Small helpers for decoded JSON (maps, lists and plain values).
library;

/// A deep copy of decoded JSON, so a stored definition never shares a
/// mutable map or list with whoever handed it in or reads it out.
Object? jsonCopy(Object? v) {
  if (v is Map) {
    return <String, dynamic>{
      for (final e in v.entries) '${e.key}': jsonCopy(e.value),
    };
  }
  if (v is List) return <dynamic>[for (final e in v) jsonCopy(e)];
  return v;
}

Map<String, dynamic> jsonCopyMap(Map<dynamic, dynamic> m) =>
    jsonCopy(m)! as Map<String, dynamic>;

/// Deep equality of decoded JSON, ignoring map key order.
bool jsonEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !jsonEquals(e.value, b[e.key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
