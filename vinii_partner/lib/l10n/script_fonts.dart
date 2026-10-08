import 'dart:async';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show Intl;

import 'locales.dart';

/// Font families the themes list in `fontFamilyFallback`. Inter has no
/// Devanagari glyphs, so Hindi text falls through to this family once it has
/// been loaded; until then it is simply not registered, which costs nothing.
const kScriptFontFallback = <String>['NotoSansDevanagari'];

/// A line-height multiple that is safe for the language on screen: Devanagari
/// carries marks above and below the line, so a tight Latin value such as
/// 1.05 would collide lines or clip the marks. Latin text keeps [latin].
double scriptLineHeight(double latin, {double devanagariMin = 1.3}) {
  final hindi = Intl.getCurrentLocale().startsWith('hi');
  return hindi && latin < devanagariMin ? devanagariMin : latin;
}

/// Loads the font a language's script needs, once, on demand.
abstract class ScriptFontLoader {
  /// True when [script] needs no loading or has already been loaded.
  bool isReady(ScriptKind script);

  /// Completes when [script]'s font is registered with the engine. Calls made
  /// while a load is running share it. Throws if the font cannot be read; the
  /// next call tries again.
  Future<void> ensureLoaded(ScriptKind script);
}

/// Noto Sans Devanagari, bundled as an ASSET (not a pubspec `fonts:` family)
/// so an English user never loads it: it is read through `rootBundle` and
/// registered with a `FontLoader` only when Hindi is chosen, or at start-up
/// when Hindi was the saved language. On the web the asset is fetched from
/// the server at that moment, not with the first page.
class BundledScriptFonts implements ScriptFontLoader {
  BundledScriptFonts({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const devanagariAsset = 'assets/fonts/NotoSansDevanagari.ttf';

  final AssetBundle _bundle;
  Future<void>? _devanagari;
  var _devanagariDone = false;

  @override
  bool isReady(ScriptKind script) => switch (script) {
    ScriptKind.latin => true,
    ScriptKind.devanagari => _devanagariDone,
  };

  @override
  Future<void> ensureLoaded(ScriptKind script) {
    if (isReady(script)) return Future.value();
    return _devanagari ??= _loadDevanagari();
  }

  Future<void> _loadDevanagari() async {
    try {
      final loader = FontLoader(kScriptFontFallback.first)
        ..addFont(_bundle.load(devanagariAsset));
      await loader.load();
      _devanagariDone = true;
    } catch (_) {
      _devanagari = null; // let the next call try again
      rethrow;
    }
  }
}
