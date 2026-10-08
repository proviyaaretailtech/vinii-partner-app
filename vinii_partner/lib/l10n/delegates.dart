import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_localizations.dart';
import 'locales.dart';
import 'pseudo_localizations.dart';

/// Everything `MaterialApp.localizationsDelegates` needs: the app's own
/// messages, then the framework's (Material, widgets, Cupertino) for `en`
/// and `hi`. In a build made with `--dart-define=PSEUDO_LOCALE=true` the
/// pseudo-language comes first so `en_XA` finds it before the English one;
/// otherwise the constant is false and the pseudo class is compiled out.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  if (kPseudoLocale) PseudoLocalizationsDelegate(),
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The same list with the pseudo-language always mounted, for tests.
const List<LocalizationsDelegate<dynamic>> pseudoTestDelegates = [
  PseudoLocalizationsDelegate(),
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
