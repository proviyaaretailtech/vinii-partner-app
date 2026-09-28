import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/organization.dart';
import '../../domain/storefront.dart';
import 'staff_theme.dart';

/// The guest storefront's look, derived from a [StorefrontDefinition]: the
/// template gives the palette and type, the definition's accent overrides
/// the highlight colour. Two reference boards map to two templates:
/// "Vinii Bistro" → [StorefrontTemplate.bistroNight], "The Windough" →
/// [StorefrontTemplate.artisanDay].
@immutable
class GuestPalette extends ThemeExtension<GuestPalette> {
  const GuestPalette({
    required this.template,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.ink,
    required this.inkMuted,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.danger,
    required this.displayFamily,
    required this.scriptFamily,
    required this.bodyFamily,
  });

  final StorefrontTemplate template;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color ink;
  final Color inkMuted;
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color danger;
  final String? displayFamily;

  /// Handwritten headline family (artisan template); null = use display.
  final String? scriptFamily;
  final String? bodyFamily;

  bool get isDark => background.computeLuminance() < 0.2;

  static GuestPalette of(BuildContext context) =>
      Theme.of(context).extension<GuestPalette>()!;

  /// Remote fonts are off in tests (no network there); the bundled Inter
  /// is used instead.
  static bool remoteFonts = true;

  factory GuestPalette.from(StorefrontDefinition def) {
    final accent =
        parseHexColor(def.accentHex) ??
        parseHexColor(def.template.defaultAccent)!;
    String? family(String name) {
      if (!remoteFonts) return null;
      try {
        return GoogleFonts.getFont(name).fontFamily;
      } catch (_) {
        return null;
      }
    }

    return switch (def.template) {
      StorefrontTemplate.bistroNight => GuestPalette(
        template: def.template,
        background: const Color(0xFF0B0B0C),
        surface: const Color(0xFF17171A),
        surfaceAlt: const Color(0xFF222226),
        border: const Color(0xFF2C2C31),
        ink: Colors.white,
        inkMuted: const Color(0xFFA1A1AA),
        accent: accent,
        onAccent: onColor(accent),
        success: const Color(0xFF22C55E),
        danger: const Color(0xFFEF4444),
        displayFamily: family('Plus Jakarta Sans'),
        scriptFamily: null,
        bodyFamily: family('Plus Jakarta Sans'),
      ),
      StorefrontTemplate.artisanDay => GuestPalette(
        template: def.template,
        background: const Color(0xFFF6F0E7),
        surface: Colors.white,
        surfaceAlt: const Color(0xFFEFE5D8),
        border: const Color(0xFFE2D5C4),
        ink: const Color(0xFF1E1915),
        inkMuted: const Color(0xFF7A6E64),
        accent: accent,
        onAccent: onColor(accent),
        success: const Color(0xFF3E8E5A),
        danger: const Color(0xFFD9534F),
        displayFamily: family('Playfair Display'),
        scriptFamily: family('Kaushan Script'),
        bodyFamily: family('DM Sans'),
      ),
      StorefrontTemplate.freshMinimal => GuestPalette(
        template: def.template,
        background: Colors.white,
        surface: const Color(0xFFF6F7F6),
        surfaceAlt: const Color(0xFFECEFEC),
        border: const Color(0xFFE3E7E3),
        ink: const Color(0xFF0F1A12),
        inkMuted: const Color(0xFF65706A),
        accent: accent,
        onAccent: onColor(accent),
        success: const Color(0xFF16A34A),
        danger: const Color(0xFFDC2626),
        displayFamily: family('Outfit'),
        scriptFamily: null,
        bodyFamily: family('Outfit'),
      ),
    };
  }

  TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color? color,
  }) => TextStyle(
    fontFamily: displayFamily ?? 'Inter',
    fontSize: size,
    fontWeight: weight,
    height: 1.08,
    letterSpacing: template == StorefrontTemplate.artisanDay ? 0 : -0.8,
    color: color ?? ink,
  );

  /// The big welcome headline: handwritten for the artisan template.
  TextStyle hero(double size, {Color? color}) => scriptFamily == null
      ? display(size, color: color)
      : TextStyle(
          fontFamily: scriptFamily,
          fontSize: size * 1.05,
          height: 1.05,
          color: color ?? ink,
        );

  TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    fontFamily: bodyFamily ?? 'Inter',
    fontSize: size,
    fontWeight: weight,
    height: 1.4,
    color: color ?? ink,
  );

  /// Prices: always bold, tabular figures so totals do not jiggle.
  TextStyle price(double size, {Color? color}) => TextStyle(
    fontFamily: bodyFamily ?? 'Inter',
    fontSize: size,
    fontWeight: FontWeight.w800,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color ?? ink,
  );

  /// A full ThemeData so Material widgets inside the guest runtime (sliders,
  /// switches, text fields, sheets) pick up the template.
  ThemeData toTheme() {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: onAccent,
          surface: surface,
          onSurface: ink,
          error: danger,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: bodyFamily ?? 'Inter',
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      extensions: [this],
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
        fontFamily: bodyFamily ?? 'Inter',
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: accent,
        inactiveTrackColor: surfaceAlt,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.15),
        trackHeight: 6,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        hintStyle: TextStyle(color: inkMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: TextStyle(
          color: background,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  GuestPalette copyWith() => this;

  @override
  GuestPalette lerp(GuestPalette? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
