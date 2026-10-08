import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/i18n_check.dart';

/// The English and Hindi catalogues stay in step, and the gate that says so
/// (tool/i18n_check.dart) really catches the mistakes it claims to.
void main() {
  final root = Directory.current.path;

  group('the real catalogues', () {
    test('no parity, empty-value, placeholder or syntax error', () {
      final r = checkCatalogues(root);
      expect(r.errors, isEmpty, reason: r.errors.join('\n'));
    });

    test('every English key exists in Hindi and nothing extra', () {
      Set<String> keys(String f) => (jsonDecode(
        File('$root/lib/l10n/$f').readAsStringSync(),
      ) as Map<String, dynamic>).keys.where((k) => !k.startsWith('@')).toSet();
      final en = keys('app_en.arb');
      final hi = keys('app_hi.arb');
      expect(en.difference(hi), isEmpty, reason: 'missing from app_hi.arb');
      expect(hi.difference(en), isEmpty, reason: 'only in app_hi.arb');
      expect(en.length, greaterThan(100));
    });

    test('Hindi uses Latin digits and Hindi text is really Hindi', () {
      final hi = jsonDecode(
        File('$root/lib/l10n/app_hi.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final values = hi.entries
          .where((e) => !e.key.startsWith('@'))
          .map((e) => '${e.value}');
      for (final v in values) {
        expect(RegExp('[०-९]').hasMatch(v), isFalse, reason: v);
      }
      // Most messages carry Devanagari (acronym-only ones such as "UPI" do not).
      final devanagari = values
          .where((v) => RegExp(r'[ऀ-ॿ]').hasMatch(v))
          .length;
      expect(devanagari / values.length, greaterThan(0.9));
    });
  });

  group('the gate catches mistakes', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('i18n_check_');
      Directory('${dir.path}/lib/l10n').createSync(recursive: true);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    void arbs(Map<String, Object?> en, Map<String, Object?> hi) {
      File('${dir.path}/lib/l10n/app_en.arb').writeAsStringSync(jsonEncode(en));
      File('${dir.path}/lib/l10n/app_hi.arb').writeAsStringSync(jsonEncode(hi));
    }

    List<String> errors() =>
        checkCatalogues(dir.path, checkPseudo: false).errors;

    test('a clean pair passes', () {
      arbs(
        {
          'a': 'Hello {name}',
          '@a': {
            'description': 'x',
            'placeholders': {
              'name': {'type': 'String'},
            },
          },
        },
        {'a': 'नमस्ते {name}'},
      );
      expect(errors(), isEmpty);
    });

    test('a key missing from Hindi, and one only in Hindi', () {
      arbs({'a': 'A', 'b': 'B'}, {'a': 'ए', 'c': 'सी'});
      final e = errors().join('\n');
      expect(e, contains('"b" is in app_en.arb but not in app_hi.arb'));
      expect(e, contains('"c" is in app_hi.arb but not in app_en.arb'));
    });

    test('an empty value', () {
      arbs({'a': 'A'}, {'a': '  '});
      expect(errors().join(), contains('"a" is empty in app_hi.arb'));
    });

    test('placeholders that differ between the languages', () {
      arbs(
        {
          'a': 'Hi {name}',
          '@a': {
            'placeholders': {
              'name': {'type': 'String'},
            },
          },
        },
        {'a': 'नमस्ते {naam}'},
      );
      expect(errors().join(), contains('placeholders differ'));
    });

    test('a plural with no other branch, and an unbalanced brace', () {
      arbs(
        {
          'a': '{n, plural, =1{one}}',
          '@a': {
            'placeholders': {
              'n': {'type': 'int'},
            },
          },
          'b': 'Hello {name',
        },
        {'a': '{n, plural, =1{एक}}', 'b': 'नमस्ते {name'},
      );
      final e = errors().join('\n');
      expect(e, contains('needs an "other" branch'));
      expect(e, contains('"b" (en)'));
    });

    test('Devanagari digits in Hindi', () {
      arbs({'a': 'Table 4'}, {'a': 'टेबल ४'});
      expect(errors().join(), contains('Devanagari digits'));
    });

    test('ICU placeholders are read through plural branches', () {
      expect(
        icuPlaceholders(
          '{count, plural, =0{none} one{{count} item} other{{count} items}} for {name}',
        ).keys.toSet(),
        {'count', 'name'},
      );
    });
  });

  group('the scan finds hard-coded strings and honours the exceptions', () {
    test('what it flags and what it leaves alone', () {
      final dir = Directory.systemTemp.createTempSync('i18n_scan_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/lib/presentation').createSync(recursive: true);
      File('${dir.path}/lib/presentation/a.dart').writeAsStringSync('''
import 'package:flutter/material.dart';

class A extends StatelessWidget {
  const A({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(children: [
      const Text('Hard coded'),                       // flagged
      Text(l.commonSave),                             // converted
      Text(DateFormat('d MMM').format(x)),            // format pattern, not text
      Tooltip(message: 'Tip', child: SizedBox()),      // flagged: message:
      TextField(decoration: InputDecoration(hintText: 'Search items')), // flagged
      Text('Brand'), // i18n-ignore: product name
      Text(isNew ? 'Add' : 'Edit'),                   // both flagged
      Text('\$count'),                                 // no letters
      Text('dine_in'),                                // a code, not a sentence
      showDone(context, 'Saved'),                     // flagged
      throw AppFailure('Something broke'),            // flagged: no code
      throw AppFailure('Offline', code: 'offline'),   // has a code
    ]);
  }
}
''');
      final scan = scanSources(dir.path, {'commonSave'});
      final kinds = scan.findings.map((f) => f.text).toList()..sort();
      expect(kinds, [
        'Add',
        'Edit',
        'Hard coded',
        'Saved',
        'Search items',
        'Something broke',
        'Tip',
      ]);
      expect(scan.convertedRefs, 1);
    });
  });
}
