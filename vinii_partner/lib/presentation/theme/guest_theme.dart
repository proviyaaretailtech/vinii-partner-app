import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/organization.dart';
import '../../domain/storefront.dart';
import '../../l10n/script_fonts.dart';

/// The guest storefront's look, derived from a [StorefrontDefinition]: the
/// template gives the palette and type, the definition's accent overrides
/// the highlight colour, and the CMS's [StorefrontTheme] may override
/// colours, button corners and style, and the heading and body faces. Two
/// reference boards map to two templates: "Vinii Bistro" →
/// [StorefrontTemplate.bistroNight], "The Windough" →
/// [StorefrontTemplate.artisanDay].
///
/// Resolution follows the CMS's `resolveLook`, so the phone paints what the
/// CMS preview shows.
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
    this.displayFace = StorefrontFont.plusJakartaSans,
    this.buttonRadius = 999,
    this.buttonOutline = false,
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

  /// Handwritten headline family (the artisan template's, or a script face
  /// chosen as the heading font); null = the hero uses [display].
  final String? scriptFamily;
  final String? bodyFamily;

  /// The heading face, so headings set it the way it is drawn: script faces
  /// at their one weight, sans faces tightly tracked.
  final StorefrontFont displayFace;

  /// Corner radius of guest buttons: 999 pill, 14 rounded, 6 square.
  final double buttonRadius;

  /// Main buttons drawn as an accent outline instead of an accent fill.
  final bool buttonOutline;

  bool get isDark => background.computeLuminance() < 0.2;

  /// The shape of a guest button, with an optional border.
  ShapeBorder buttonShape([BorderSide side = BorderSide.none]) =>
      buttonRadius >= 999
      ? StadiumBorder(side: side)
      : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          side: side,
        );

  static GuestPalette of(BuildContext context) =>
      Theme.of(context).extension<GuestPalette>()!;

  /// Remote fonts are off in tests (no network there); the bundled Inter
  /// is used instead.
  static bool remoteFonts = true;

  factory GuestPalette.from(StorefrontDefinition def) {
    final t = def.template;
    final theme = def.theme;
    final accent =
        parseHexColor(def.accentHex) ?? parseHexColor(t.defaultAccent)!;
    Color pick(String key, Color template) =>
        parseHexColor(theme.colors[key]) ?? template;
    String? family(StorefrontFont? font) {
      if (font == null || !remoteFonts) return null;
      try {
        return GoogleFonts.getFont(font.family).fontFamily;
      } catch (_) {
        return null;
      }
    }

    // A face picked in the CMS sets every heading, the welcome headline
    // included; script faces are never body text (the domain drops them).
    final heading = theme.headingFont;
    final display = heading ?? t.headingFont;
    final script = heading == null
        ? (t == StorefrontTemplate.artisanDay
              ? StorefrontFont.kaushanScript
              : null)
        : (heading.headingOnly ? heading : null);
    final (
      bg,
      surface,
      surfaceAlt,
      border,
      ink,
      muted,
      success,
      danger,
    ) = switch (t) {
      StorefrontTemplate.bistroNight => (
        const Color(0xFF0B0B0C),
        const Color(0xFF17171A),
        const Color(0xFF222226),
        const Color(0xFF2C2C31),
        Colors.white,
        const Color(0xFFA1A1AA),
        const Color(0xFF22C55E),
        const Color(0xFFEF4444),
      ),
      StorefrontTemplate.artisanDay => (
        const Color(0xFFF6F0E7),
        Colors.white,
        const Color(0xFFEFE5D8),
        const Color(0xFFE2D5C4),
        const Color(0xFF1E1915),
        const Color(0xFF7A6E64),
        const Color(0xFF3E8E5A),
        const Color(0xFFD9534F),
      ),
      StorefrontTemplate.freshMinimal => (
        Colors.white,
        const Color(0xFFF6F7F6),
        const Color(0xFFECEFEC),
        const Color(0xFFE3E7E3),
        const Color(0xFF0F1A12),
        const Color(0xFF65706A),
        const Color(0xFF16A34A),
        const Color(0xFFDC2626),
      ),
    };
    return GuestPalette(
      template: t,
      background: pick('background', bg),
      surface: pick('surface', surface),
      surfaceAlt: surfaceAlt,
      border: border,
      ink: pick('text', ink),
      inkMuted: pick('muted', muted),
      accent: accent,
      onAccent:
          parseHexColor(theme.colors['on_accent']) ??
          parseHexColor(readableOn(toHexColor(accent)))!,
      success: pick('success', success),
      danger: pick('danger', danger),
      displayFamily: family(display),
      scriptFamily: family(script),
      bodyFamily: family(theme.bodyFont ?? t.bodyFont),
      displayFace: display,
      buttonRadius: (theme.buttonShape ?? t.defaultButtonShape).radius,
      buttonOutline: theme.buttonStyle == StorefrontButtonStyle.outline,
    );
  }

  TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color? color,
  }) => TextStyle(
    fontFamily: displayFamily ?? 'Inter',
    fontFamilyFallback: kScriptFontFallback,
    fontSize: size,
    // A script face has one weight; a faux bold of it smears.
    fontWeight: displayFace.headingOnly ? FontWeight.w400 : weight,
    // Devanagari needs room for its marks above and below the line.
    height: scriptLineHeight(1.08),
    letterSpacing: displayFace.serif || displayFace.headingOnly ? 0 : -0.8,
    color: color ?? ink,
  );

  /// The big welcome headline: handwritten for the artisan template.
  TextStyle hero(double size, {Color? color}) => scriptFamily == null
      ? display(size, color: color)
      : TextStyle(
          fontFamily: scriptFamily,
          fontFamilyFallback: kScriptFontFallback,
          fontSize: size * 1.05,
          height: scriptLineHeight(1.05),
          color: color ?? ink,
        );

  TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    fontFamily: bodyFamily ?? 'Inter',
    fontFamilyFallback: kScriptFontFallback,
    fontSize: size,
    fontWeight: weight,
    height: scriptLineHeight(1.4),
    color: color ?? ink,
  );

  /// Prices: always bold, tabular figures so totals do not jiggle.
  TextStyle price(double size, {Color? color}) => TextStyle(
    fontFamily: bodyFamily ?? 'Inter',
    fontFamilyFallback: kScriptFontFallback,
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
      fontFamilyFallback: kScriptFontFallback,
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      extensions: [this],
      textTheme: base.textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
        fontFamily: bodyFamily ?? 'Inter',
        fontFamilyFallback: kScriptFontFallback,
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
  GuestPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? ink,
    Color? inkMuted,
    Color? accent,
    Color? onAccent,
  }) => GuestPalette(
    template: template,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    border: border ?? this.border,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    success: success,
    danger: danger,
    displayFamily: displayFamily,
    scriptFamily: scriptFamily,
    bodyFamily: bodyFamily,
    displayFace: displayFace,
    buttonRadius: buttonRadius,
    buttonOutline: buttonOutline,
  );

  @override
  GuestPalette lerp(GuestPalette? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
