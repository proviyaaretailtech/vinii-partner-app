import 'package:flutter/material.dart';

/// VINII colours, the same tokens as proviyaa-pos (`vinii_theme.dart`),
/// sampled from the approved POS reference screens.
class ViniiColors {
  const ViniiColors._();

  /// "Accepting orders" and success moments. Always with dark text on it.
  static const brandGreen = Color(0xFF76EC00);
  static const ink = Color(0xFF111115);
  static const inkSecondary = Color(0xFF555560);
  static const inkMuted = Color(0xFF94969E);
  static const pageLight = Color(0xFFF7F7F5);
  static const borderLight = Color(0xFFE3E5EB);
  static const pageDark = Color(0xFF0A0A0A);
  static const surfaceDark = Color(0xFF141418);
  static const borderDark = Color(0xFF24242C);

  static const blue = Color(0xFF2563EB);
  static const amber = Color(0xFFD97706);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
  static const purple = Color(0xFF7C3AED);
}

/// Where staff layouts change shape. Below [wide] a screen is one column
/// (phone, narrow tablet); from [wide] up it may show two panes side by side
/// (menu and ticket, form and preview) for a tablet or a counter computer.
class Breakpoints {
  const Breakpoints._();

  static const wide = 840.0;
}

/// Semantic colours screens use instead of raw hex, so light and dark both
/// work and a restaurant's brand colour never ends up as text on itself.
@immutable
class ViniiTokens extends ThemeExtension<ViniiTokens> {
  const ViniiTokens({
    required this.page,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Color page;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;

  /// The organization's brand colour (`organizations.theme.accent`), or ink.
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  static ViniiTokens of(BuildContext context) =>
      Theme.of(context).extension<ViniiTokens>()!;

  /// Soft background for a status colour ("New" chip, error banner).
  Color tint(Color c) => Color.alphaBlend(
    c.withValues(alpha: page.computeLuminance() > 0.5 ? 0.10 : 0.18),
    surface,
  );

  @override
  ViniiTokens copyWith() => this;

  @override
  ViniiTokens lerp(ViniiTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ViniiTokens(
      page: l(page, other.page),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      border: l(border, other.border),
      ink: l(ink, other.ink),
      inkSecondary: l(inkSecondary, other.inkSecondary),
      inkMuted: l(inkMuted, other.inkMuted),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      info: l(info, other.info),
    );
  }
}

Color onColor(Color c) =>
    c.computeLuminance() > 0.45 ? ViniiColors.ink : Colors.white;

/// The staff app's theme. [accent] is the organization's brand colour; when
/// it is too pale to carry white text it still works, because [onAccent] is
/// chosen by contrast.
ThemeData staffTheme({required Brightness brightness, Color? accent}) {
  final dark = brightness == Brightness.dark;
  final a = accent ?? (dark ? Colors.white : ViniiColors.ink);
  final tokens = ViniiTokens(
    page: dark ? ViniiColors.pageDark : ViniiColors.pageLight,
    surface: dark ? ViniiColors.surfaceDark : Colors.white,
    surfaceMuted: dark ? const Color(0xFF1C1C22) : const Color(0xFFF1F1EF),
    border: dark ? ViniiColors.borderDark : ViniiColors.borderLight,
    ink: dark ? const Color(0xFFF4F4F5) : ViniiColors.ink,
    inkSecondary: dark ? const Color(0xFFB4B4BC) : ViniiColors.inkSecondary,
    inkMuted: dark ? const Color(0xFF7C7C86) : ViniiColors.inkMuted,
    accent: a,
    onAccent: onColor(a),
    success: dark ? const Color(0xFF4ADE80) : ViniiColors.green,
    warning: dark ? const Color(0xFFFBBF24) : ViniiColors.amber,
    danger: dark ? const Color(0xFFF87171) : ViniiColors.red,
    info: dark ? const Color(0xFF60A5FA) : ViniiColors.blue,
  );
  final scheme = ColorScheme.fromSeed(seedColor: a, brightness: brightness)
      .copyWith(
        primary: a,
        onPrimary: tokens.onAccent,
        surface: tokens.surface,
        onSurface: tokens.ink,
        error: tokens.danger,
        outline: tokens.border,
        outlineVariant: tokens.border,
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Inter',
  );
  final text = base.textTheme.apply(
    bodyColor: tokens.ink,
    displayColor: tokens.ink,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return base.copyWith(
    scaffoldBackgroundColor: tokens.page,
    extensions: [tokens],
    dividerColor: tokens.border,
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(
        color: tokens.inkSecondary,
        height: 1.4,
      ),
      bodySmall: text.bodySmall?.copyWith(color: tokens.inkMuted),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.page,
      foregroundColor: tokens.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: tokens.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        backgroundColor: a,
        foregroundColor: tokens.onAccent,
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        foregroundColor: tokens.ink,
        side: BorderSide(color: tokens.border, width: 1.5),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.ink,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tokens.ink, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tokens.danger),
      ),
      labelStyle: TextStyle(color: tokens.inkSecondary),
      hintStyle: TextStyle(color: tokens.inkMuted),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: tokens.surface,
      selectedColor: tokens.ink,
      side: BorderSide(color: tokens.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        color: tokens.ink,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: 'Inter',
        color: tokens.page,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: tokens.page,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.surface,
      indicatorColor: tokens.tint(a),
      surfaceTintColor: Colors.transparent,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? tokens.ink
              : tokens.inkMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? tokens.ink
              : tokens.inkMuted,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? tokens.success : null,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.ink,
      contentTextStyle: TextStyle(
        fontFamily: 'Inter',
        color: tokens.page,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: tokens.inkSecondary,
      textColor: tokens.ink,
    ),
  );
}
