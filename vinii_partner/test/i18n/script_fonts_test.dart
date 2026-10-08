import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vinii_partner/l10n/locales.dart';
import 'package:vinii_partner/l10n/script_fonts.dart';

/// The Devanagari font really is a bundled asset that loads on demand.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the font file and its licence are bundled', () {
    expect(File(BundledScriptFonts.devanagariAsset).existsSync(), isTrue);
    expect(
      File('assets/fonts/NotoSansDevanagari-LICENSE.txt').existsSync(),
      isTrue,
    );
    // It is an asset, not a pubspec `fonts:` family: English users never load it.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/fonts/NotoSansDevanagari.ttf'));
    expect(pubspec, isNot(contains('family: NotoSansDevanagari')));
  });

  test(
    'nothing is loaded until it is asked for; latin needs nothing',
    () async {
      final fonts = BundledScriptFonts();
      expect(fonts.isReady(ScriptKind.latin), isTrue);
      expect(fonts.isReady(ScriptKind.devanagari), isFalse);
      await fonts.ensureLoaded(ScriptKind.latin); // a no-op
      expect(fonts.isReady(ScriptKind.devanagari), isFalse);
    },
  );

  test('loading registers the family; a second call is instant', () async {
    final fonts = BundledScriptFonts();
    final first = fonts.ensureLoaded(ScriptKind.devanagari);
    final second = fonts.ensureLoaded(ScriptKind.devanagari);
    await Future.wait([first, second]);
    expect(fonts.isReady(ScriptKind.devanagari), isTrue);
    await fonts.ensureLoaded(ScriptKind.devanagari);
  });

  test('a missing asset fails, and the next call tries again', () async {
    final fonts = BundledScriptFonts(bundle: _EmptyBundle());
    await expectLater(
      fonts.ensureLoaded(ScriptKind.devanagari),
      throwsA(anything),
    );
    expect(fonts.isReady(ScriptKind.devanagari), isFalse);
    await expectLater(
      fonts.ensureLoaded(ScriptKind.devanagari),
      throwsA(anything),
    );
  });

  test('Devanagari lines get room for their marks, Latin keeps its height', () {
    Intl.defaultLocale = 'en';
    expect(scriptLineHeight(1.08), 1.08);
    Intl.defaultLocale = 'hi';
    expect(scriptLineHeight(1.08), 1.3);
    expect(scriptLineHeight(1.5), 1.5);
    Intl.defaultLocale = null;
  });
}

class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(FlutterError('no such asset: $key'));
}
