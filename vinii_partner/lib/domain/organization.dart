import 'dart:ui';

/// A merchant tenant (`organizations` row). Everything in the app is scoped
/// to exactly one of these at a time.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    this.type = 'restaurant',
    this.accentHex,
    this.city,
    this.settings = const {},
  });

  final String id;
  final String name;

  /// URL-safe name; the storefront lives at `<base>/s/<slug>`.
  final String slug;

  /// `organizations.type` (restaurant, cafe, franchise…). Picks the starter
  /// template, never a code path.
  final String type;

  /// `organizations.theme.accent` — the org's brand colour ("Chameleon",
  /// OS migration 0009). Null means the platform default.
  final String? accentHex;

  final String? city;

  /// `organizations.settings`. The app reads `app` (min version, tabs) and
  /// `storefront` (published guest experience) from here.
  final Map<String, dynamic> settings;

  Color? get accent => parseHexColor(accentHex);

  String get initials {
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.toLowerCase() != 'the')
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Organization copyWith({Map<String, dynamic>? settings, String? accentHex}) =>
      Organization(
        id: id,
        name: name,
        slug: slug,
        type: type,
        accentHex: accentHex ?? this.accentHex,
        city: city,
        settings: settings ?? this.settings,
      );
}

Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final v = hex.replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v)) return null;
  return Color(int.parse('FF$v', radix: 16));
}

String toHexColor(Color c) {
  String two(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}'.toUpperCase();
}
