import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Inter has no Devanagari. A `TextStyle` that names a font family itself
/// REPLACES the theme's style (and its fallback list), so Hindi text in it
/// would draw as empty boxes on the web and desktop. Every `fontFamily:` in
/// lib/ must come with `fontFamilyFallback: kScriptFontFallback`.
void main() {
  test('every explicit fontFamily carries the Devanagari fallback', () {
    final missing = <String>[];
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      // The painted dishes draw no words.
      if (f.path.contains('dish_art') || f.path.contains('food_art')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!RegExp(r'\bfontFamily:').hasMatch(lines[i])) continue;
        if (lines[i].trimLeft().startsWith('//')) continue;
        final near = lines
            .sublist(i, (i + 4).clamp(0, lines.length))
            .join('\n');
        if (!near.contains('fontFamilyFallback')) {
          missing.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
}
