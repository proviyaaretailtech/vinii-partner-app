import 'package:flutter/widgets.dart';

/// Build the app with `--dart-define=PSEUDO_LOCALE=true` to add a fake
/// "Pseudo" language to the language screen. Every catalogue string appears
/// accented and ~35% longer between ⟦ ⟧ marks, so text that is still plain
/// English is hard-coded, and a layout that breaks is found before Hindi
/// finds it. Compiled out of release builds (the flag is a constant).
const bool kPseudoLocale = bool.fromEnvironment('PSEUDO_LOCALE');

/// Writing systems that need a font the app does not load at start-up.
enum ScriptKind { latin, devanagari }

/// One language the app can show. The registry below is the single list the
/// language screen, the locale controller and `MaterialApp.supportedLocales`
/// are built from: adding Marathi is one entry here, one `app_mr.arb`, one row
/// in `app_locales` on the server.
@immutable
class AppLocale {
  const AppLocale({
    required this.code,
    required this.locale,
    required this.nativeName,
    required this.englishName,
    required this.sample,
    this.script = ScriptKind.latin,
  });

  /// What is stored in prefs and `user_preferences.locale`: `en`, `hi`.
  final String code;
  final Locale locale;

  /// The language's own name, shown on its tile in its own script.
  final String nativeName;
  final String englishName;

  /// A line in that language, so a person can judge it before choosing.
  final String sample;
  final ScriptKind script;

  bool get needsDevanagari => script == ScriptKind.devanagari;

  /// The name `intl` uses for number and date formats (the language; Indian
  /// grouping and Latin digits are the same for `en` and `hi`).
  String get intlName => locale.languageCode;

  @override
  bool operator ==(Object other) => other is AppLocale && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

const englishLocale = AppLocale(
  code: 'en',
  locale: Locale('en'),
  nativeName: 'English',
  englishName: 'English',
  sample: 'Orders, bills and tables in English',
);

const hindiLocale = AppLocale(
  code: 'hi',
  locale: Locale('hi'),
  nativeName: 'हिन्दी',
  englishName: 'Hindi',
  sample: 'ऑर्डर, बिल और टेबल हिन्दी में',
  script: ScriptKind.devanagari,
);

/// Test-only language: English, accented and stretched. See [kPseudoLocale].
const pseudoLocale = AppLocale(
  code: 'en_XA',
  locale: Locale('en', 'XA'),
  nativeName: 'Pseudo (test)',
  englishName: 'Pseudo-locale',
  sample: 'Ŏŕđěŕś, ƀĭłłś àńđ ţàƀłěś',
);

/// The languages a person can choose, in the order the screen lists them.
const List<AppLocale> appLocales = [englishLocale, hindiLocale];

/// [appLocales] plus the pseudo-locale when the build asks for it.
List<AppLocale> get selectableLocales => [
  ...appLocales,
  if (kPseudoLocale) pseudoLocale,
];

/// The registry entry for a stored [code], or null for an unknown or empty
/// one (an old build wrote it, or a newer one will).
AppLocale? appLocaleFor(String? code) {
  if (code == null) return null;
  for (final l in [...appLocales, pseudoLocale]) {
    if (l.code == code) return l;
  }
  return null;
}

/// The first of the device's languages the app supports, else English
/// (docs/I18N.md: fallback `en`). A phone set to `hi-IN` gives Hindi.
AppLocale resolveDeviceLocale(Iterable<Locale> device) {
  for (final d in device) {
    for (final l in appLocales) {
      if (l.locale.languageCode == d.languageCode) return l;
    }
  }
  return englishLocale;
}
