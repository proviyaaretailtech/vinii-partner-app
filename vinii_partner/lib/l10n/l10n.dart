import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';

export 'app_localizations.dart';

/// `context.l10n.someKey` — the one way a screen reads a message.
///
/// Falls back to English when no localisation delegate is mounted above the
/// widget (a bare `MaterialApp` in a widget test, the design gallery), so a
/// missing delegate never crashes a screen. In the real app the delegate is
/// always there (lib/app/app.dart).
extension AppL10nContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      _englishFallback;
}

final AppLocalizations _englishFallback = AppLocalizationsEn();
