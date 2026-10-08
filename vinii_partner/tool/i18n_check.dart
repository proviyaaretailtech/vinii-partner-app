// The i18n gate for VINII Partner.
//
//   dart run tool/i18n_check.dart            check + write the status report
//   dart run tool/i18n_check.dart --strict   also fail while hard-coded UI
//                                            strings remain
//   dart run tool/i18n_check.dart --no-report
//
// 1. Catalogues (lib/l10n/app_en.arb, app_hi.arb): every key in both, no
//    empty value, same placeholders in both, valid ICU plural/select syntax,
//    Latin digits in Hindi, pseudo-locale file in sync. Any of these fails
//    the run (exit 1).
// 2. Scan of lib/**/*.dart for user-visible strings that are still
//    hard-coded: Text('…'), label/hint/tooltip/title… arguments, SnackBar and
//    showDone messages, AppFailure messages without a code. Write
//    `// i18n-ignore: reason` on the line (or the line above) for a string
//    that must stay English (brand name, stored merchant default, …); wrap a
//    block in `// i18n-ignore-start: reason` … `// i18n-ignore-end`.
// 3. Writes /Users/lohit/agentic-os-coder/docs/I18N_STATUS_partner.md
//    (counts per file + the remaining list). Text above the
//    `<!-- GENERATED BELOW -->` marker is kept as written by hand.
import 'dart:convert';
import 'dart:io';

import 'i18n_pseudo.dart' as pseudo;

const generatedMarker =
    '<!-- GENERATED BELOW: dart run tool/i18n_check.dart -->';
const defaultReport = '../../docs/I18N_STATUS_partner.md';

Future<void> main(List<String> args) async {
  final strict = args.contains('--strict');
  final writeReport = !args.contains('--no-report');
  final outArg = args.where((a) => a.startsWith('--out=')).firstOrNull;
  final out = outArg?.substring(6) ?? defaultReport;
  final root = Directory.current.path;

  final cat = checkCatalogues(root);
  final scan = scanSources(root, cat.keys);

  stdout
    ..writeln(
      'catalogue: ${cat.enCount} en keys, ${cat.hiCount} hi keys, '
      '${cat.errors.length} errors, ${cat.warnings.length} warnings',
    )
    ..writeln(
      'sources: ${scan.convertedRefs} catalogue references, '
      '${scan.findings.length} hard-coded UI strings left in '
      '${scan.filesWithFindings} files, ${scan.candidates.length} other '
      'candidates',
    );
  for (final e in cat.errors) {
    stdout.writeln('  ERROR $e');
  }
  if (writeReport) {
    final file = File(out);
    final header = file.existsSync()
        ? file.readAsStringSync().split(generatedMarker).first
        : '# VINII Partner internationalisation status\n\n';
    file.writeAsStringSync(
      '$header$generatedMarker\n${renderReport(cat, scan)}',
    );
    stdout.writeln('wrote $out');
  }
  if (cat.errors.isNotEmpty || (strict && scan.findings.isNotEmpty)) exit(1);
}

// ---------------------------------------------------------------------------
// Catalogues

class CatalogueReport {
  final errors = <String>[];
  final warnings = <String>[];
  var enCount = 0;
  var hiCount = 0;
  Set<String> keys = {};
}

/// Names of the placeholders a message uses, or throws [FormatException] when
/// the ICU syntax is broken. `{count, plural, …}` and `{x, select, …}` need an
/// `other` branch.
Map<String, String> icuPlaceholders(String message) {
  final names = <String, String>{};
  var i = 0;

  void skipSpace() {
    while (i < message.length && ' \t\r\n'.contains(message[i])) {
      i++;
    }
  }

  String ident() {
    final m = RegExp(r'[A-Za-z_]\w*').matchAsPrefix(message, i);
    if (m == null) {
      throw FormatException(
        'bad placeholder near "${message.substring(i, (i + 12).clamp(0, message.length))}"',
      );
    }
    i = m.end;
    return m.group(0)!;
  }

  void parse({required bool untilClose}) {
    while (i < message.length) {
      final c = message[i];
      if (c == '{') {
        i++;
        skipSpace();
        final name = ident();
        skipSpace();
        if (i >= message.length) throw const FormatException('unterminated {');
        if (message[i] == '}') {
          i++;
          names.putIfAbsent(name, () => 'plain');
          continue;
        }
        if (message[i] != ',') {
          throw FormatException('bad placeholder "$name"');
        }
        i++;
        skipSpace();
        final kind = ident();
        if (kind != 'plural' && kind != 'select') {
          throw FormatException('only plural/select allowed, got "$kind"');
        }
        names[name] = kind;
        skipSpace();
        if (i >= message.length || message[i] != ',') {
          throw FormatException('"$name, $kind" needs branches');
        }
        i++;
        var hasOther = false;
        while (true) {
          skipSpace();
          final m = RegExp(r'(=\d+|[A-Za-z_]\w*)\s*\{')
              .matchAsPrefix(message, i);
          if (m == null) break;
          if (m.group(1) == 'other') hasOther = true;
          i = m.end;
          parse(untilClose: true);
          if (i >= message.length) {
            throw const FormatException('unterminated branch');
          }
          i++; // closing }
        }
        skipSpace();
        if (i >= message.length || message[i] != '}') {
          throw FormatException('unterminated $kind');
        }
        i++;
        if (!hasOther) {
          throw FormatException('$kind "$name" needs an "other" branch');
        }
      } else if (c == '}') {
        if (untilClose) return;
        throw const FormatException('unbalanced }');
      } else {
        i++;
      }
    }
    if (untilClose) throw const FormatException('unbalanced {');
  }

  parse(untilClose: false);
  return names;
}

CatalogueReport checkCatalogues(String root, {bool checkPseudo = true}) {
  final r = CatalogueReport();
  Map<String, dynamic> load(String name) {
    final f = File('$root/lib/l10n/$name');
    if (!f.existsSync()) {
      r.errors.add('$name is missing');
      return {};
    }
    try {
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException catch (e) {
      r.errors.add('$name is not valid JSON: ${e.message}');
      return {};
    }
  }

  final en = load('app_en.arb');
  final hi = load('app_hi.arb');
  List<String> messageKeys(Map<String, dynamic> m) =>
      m.keys.where((k) => !k.startsWith('@')).toList();
  final enKeys = messageKeys(en);
  final hiKeys = messageKeys(hi);
  r.enCount = enKeys.length;
  r.hiCount = hiKeys.length;
  r.keys = enKeys.toSet();

  for (final k in enKeys) {
    if (!hi.containsKey(k)) {
      r.errors.add('key "$k" is in app_en.arb but not in app_hi.arb');
    }
  }
  for (final k in hiKeys) {
    if (!en.containsKey(k)) {
      r.errors.add('key "$k" is in app_hi.arb but not in app_en.arb');
    }
  }

  for (final k in enKeys) {
    final e = en[k];
    final h = hi[k];
    if (e is! String || e.trim().isEmpty) {
      r.errors.add('"$k" is empty in app_en.arb');
      continue;
    }
    if (!hi.containsKey(k)) continue;
    if (h is! String || h.trim().isEmpty) {
      r.errors.add('"$k" is empty in app_hi.arb');
      continue;
    }
    Map<String, String> pe, ph;
    try {
      pe = icuPlaceholders(e);
    } on FormatException catch (x) {
      r.errors.add('"$k" (en): ${x.message}');
      continue;
    }
    try {
      ph = icuPlaceholders(h);
    } on FormatException catch (x) {
      r.errors.add('"$k" (hi): ${x.message}');
      continue;
    }
    if (pe.keys.toSet().difference(ph.keys.toSet()).isNotEmpty ||
        ph.keys.toSet().difference(pe.keys.toSet()).isNotEmpty) {
      r.errors.add(
        '"$k": placeholders differ, en ${pe.keys.toList()..sort()} vs hi ${ph.keys.toList()..sort()}',
      );
    }
    final meta = en['@$k'];
    final declared = meta is Map
        ? ((meta['placeholders'] as Map?)?.keys.toSet() ?? <Object?>{})
        : <Object?>{};
    if (pe.isNotEmpty && declared.isEmpty) {
      r.errors.add('"$k" uses placeholders but @$k declares none');
    } else if (pe.keys
        .toSet()
        .difference(declared.cast<String>().toSet())
        .isNotEmpty) {
      r.errors.add('"$k": placeholder used but not declared in @$k');
    }
    if (meta is! Map || (meta['description'] as String? ?? '').isEmpty) {
      r.warnings.add('"$k" has no description');
    }
    if (RegExp('[०-९]').hasMatch(h)) {
      r.errors.add(
        '"$k" (hi) uses Devanagari digits; docs/I18N.md requires Latin 0-9',
      );
    }
    if (h == e && RegExp(r'[A-Za-z]{4,}').hasMatch(h)) {
      r.warnings.add('"$k" is identical in hi and en (untranslated?)');
    }
  }
  if (checkPseudo && !_pseudoInSync(root)) {
    r.errors.add(
      'lib/l10n/pseudo_localizations.dart is out of date: run `dart run tool/i18n_pseudo.dart`',
    );
  }
  return r;
}

bool _pseudoInSync(String root) {
  final f = File('$root/lib/l10n/pseudo_localizations.dart');
  final arb = File('$root/lib/l10n/app_en.arb');
  if (!f.existsSync() || !arb.existsSync()) return false;
  return f.readAsStringSync() == pseudo.generate(arb.readAsStringSync());
}

// ---------------------------------------------------------------------------
// Source scan

class Finding {
  Finding(this.file, this.line, this.kind, this.text);
  final String file;
  final int line;
  final String kind;
  final String text;
}

class ScanReport {
  final findings = <Finding>[];
  final candidates = <Finding>[];
  final convertedByFile = <String, int>{};
  var convertedRefs = 0;
  final usedKeys = <String>{};
  var filesScanned = 0;
  int get filesWithFindings => findings.map((f) => f.file).toSet().length;
}

/// Argument names whose string value a person reads.
const uiNamedArgs = {
  'label',
  'labelText',
  'hint',
  'hintText',
  'helperText',
  'errorText',
  'tooltip',
  'title',
  'subtitle',
  'semanticLabel',
  'semanticsLabel',
  'message',
  'counterText',
  'prefixText',
  'suffixText',
  'description',
  'caption',
  'header',
  'footer',
  'placeholder',
  'actionLabel',
  'emptyLabel',
  'buttonLabel',
  'confirmLabel',
  'cancelLabel',
  'text',
  'body',
  'heading',
};

/// Calls whose first argument is read by a person.
const uiPositionalCalls = {'Text', 'SelectableText', 'Tab', 'Chip'};

/// Functions whose Nth positional string argument is read by a person.
const uiHelperCalls = {'showDone': 1, 'showMessage': 1, 'announce': 0};

final _generated = RegExp(
  r'(app_localizations(_\w+)?|pseudo_localizations)\.dart$',
);

ScanReport scanSources(String root, Set<String> catalogueKeys) {
  final report = ScanReport();
  final lib = Directory('$root/lib');
  final files =
      lib
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) => f.path.endsWith('.dart') && !_generated.hasMatch(f.path),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final rel = f.path.substring(root.length + 1);
    final source = f.readAsStringSync();
    final scan = _scanFile(rel, source, catalogueKeys);
    report.filesScanned++;
    report.findings.addAll(scan.findings);
    report.candidates.addAll(scan.candidates);
    if (scan.converted > 0) report.convertedByFile[rel] = scan.converted;
    report.convertedRefs += scan.converted;
    report.usedKeys.addAll(scan.used);
  }
  return report;
}

class _Tok {
  _Tok(this.kind, this.text, this.line, this.depth);
  final String kind; // 'str' | 'id' | 'p' (punctuation)
  final String text; // for 'str': the literal's content (raw, with $ markers)
  final int line;
  final int depth; // bracket depth at this token
}

class _FileScan {
  final findings = <Finding>[];
  final candidates = <Finding>[];
  var converted = 0;
  final used = <String>{};
}

_FileScan _scanFile(String rel, String src, Set<String> keys) {
  final out = _FileScan();
  final ignoreLines = <int>{};
  final interpolated = <String>{};
  int? regionStart;
  final toks = <_Tok>[];
  var i = 0, line = 1, depth = 0;
  final n = src.length;

  bool isIdStart(String c) => RegExp(r'[A-Za-z_$]').hasMatch(c);
  bool isIdPart(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

  while (i < n) {
    final c = src[i];
    if (c == '\n') {
      line++;
      i++;
      continue;
    }
    if (c == ' ' || c == '\t' || c == '\r') {
      i++;
      continue;
    }
    if (src.startsWith('//', i)) {
      final end = src.indexOf('\n', i);
      final text = src.substring(i, end == -1 ? n : end);
      if (text.contains('i18n-ignore-start')) regionStart = line;
      if (text.contains('i18n-ignore-end') && regionStart != null) {
        for (var l = regionStart; l <= line; l++) {
          ignoreLines.add(l);
        }
        regionStart = null;
      }
      if (text.contains('i18n-ignore') && !text.contains('i18n-ignore-')) {
        // A comment on its own line covers the next line too; a trailing
        // comment covers only its own line.
        final lineStart = src.lastIndexOf('\n', i == 0 ? 0 : i - 1) + 1;
        final alone = src.substring(lineStart, i).trim().isEmpty;
        ignoreLines.add(line);
        if (alone) ignoreLines.add(line + 1);
      }
      i = end == -1 ? n : end;
      continue;
    }
    if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i + 2);
      final stop = end == -1 ? n : end + 2;
      final block = src.substring(i, stop);
      if (block.contains('i18n-ignore')) {
        ignoreLines
          ..add(line)
          ..add(line + 1);
      }
      line += '\n'.allMatches(block).length;
      i = stop;
      continue;
    }
    // String literal (optionally raw).
    var rawStr = false;
    var si = i;
    if (c == 'r' && i + 1 < n && (src[i + 1] == "'" || src[i + 1] == '"')) {
      rawStr = true;
      si = i + 1;
    }
    if (src[si] == "'" || src[si] == '"') {
      final quote = src[si];
      final triple = src.startsWith(quote * 3, si);
      final startLine = line;
      var j = si + (triple ? 3 : 1);
      final content = StringBuffer();
      var braces = 0;
      while (j < n) {
        final ch = src[j];
        if (ch == '\n') line++;
        if (!rawStr && ch == r'\' && j + 1 < n) {
          content.write(src.substring(j, j + 2));
          if (src[j + 1] == '\n') line++;
          j += 2;
          continue;
        }
        if (!rawStr && ch == r'$' && j + 1 < n && src[j + 1] == '{') {
          // interpolation: skip to the matching }
          content.write(r'${}');
          braces = 1;
          j += 2;
          final interpStart = j;
          while (j < n && braces > 0) {
            if (src[j] == '{') braces++;
            if (src[j] == '}') braces--;
            if (src[j] == '\n') line++;
            // a nested string with braces is rare enough; keep it simple
            j++;
          }
          // Keys used inside an interpolation still count as used.
          for (final m in RegExp(
            r'[A-Za-z_]\w*',
          ).allMatches(src.substring(interpStart, j))) {
            interpolated.add(m.group(0)!);
          }
          continue;
        }
        if (triple ? src.startsWith(quote * 3, j) : ch == quote) {
          break;
        }
        content.write(ch);
        j++;
      }
      i = j + (triple ? 3 : 1);
      toks.add(_Tok('str', content.toString(), startLine, depth));
      continue;
    }
    if (isIdStart(c)) {
      var j = i;
      while (j < n && isIdPart(src[j])) {
        j++;
      }
      toks.add(_Tok('id', src.substring(i, j), line, depth));
      i = j;
      continue;
    }
    if ('([{'.contains(c)) {
      toks.add(_Tok('p', c, line, depth));
      depth++;
      i++;
      continue;
    }
    if (')]}'.contains(c)) {
      depth--;
      toks.add(_Tok('p', c, line, depth));
      i++;
      continue;
    }
    toks.add(_Tok('p', c, line, depth));
    i++;
  }

  // converted references: `.key` where key is a catalogue key
  for (var t = 1; t < toks.length; t++) {
    if (toks[t].kind == 'id' &&
        keys.contains(toks[t].text) &&
        toks[t - 1].kind == 'p' &&
        toks[t - 1].text == '.') {
      out.converted++;
    }
    // Inside `extension … on AppLocalizations` a key is a bare name.
    if (toks[t].kind == 'id' && keys.contains(toks[t].text)) {
      out.used.add(toks[t].text);
    }
  }

  out.used.addAll(interpolated.where(keys.contains));

  bool ignored(int ln) => ignoreLines.contains(ln);

  // Joins `'a' 'b'` into one literal; returns the literal text and the index
  // after it.
  (String, int) literalAt(int t) {
    var text = toks[t].text;
    var u = t + 1;
    while (u < toks.length && toks[u].kind == 'str') {
      text += toks[u].text;
      u++;
    }
    return (text, u);
  }

  final seen = <int>{}; // token indices of literals already reported

  void report(int t, String kind) {
    if (seen.contains(t)) return;
    final (text, _) = literalAt(t);
    if (!_looksVisible(text)) return;
    if (ignored(toks[t].line)) return;
    seen.add(t);
    out.findings.add(Finding(rel, toks[t].line, kind, text));
  }

  // Scan the tokens of one argument expression starting at [from] at bracket
  // depth [d]; flag literals sitting directly at that depth (so literals in
  // nested calls such as DateFormat('d MMM') are not flagged).
  void scanArg(int from, int d, String kind) {
    var u = from;
    while (u < toks.length) {
      final tk = toks[u];
      if (tk.kind == 'p' &&
          (tk.text == ',' || tk.text == ';') &&
          tk.depth == d) {
        break;
      }
      if (tk.kind == 'p' && ')]}'.contains(tk.text) && tk.depth < d) {
        break;
      }
      if (tk.kind == 'str' && tk.depth == d) {
        // a literal followed by `[` or `.` is a key/method receiver, skip
        report(u, kind);
        // skip adjacent literals
        while (u + 1 < toks.length && toks[u + 1].kind == 'str') {
          u++;
        }
      }
      u++;
    }
  }

  for (var t = 0; t < toks.length; t++) {
    final tk = toks[t];
    if (tk.kind != 'id') continue;
    final next = t + 1 < toks.length ? toks[t + 1] : null;

    // Text('…'), Tab(text: …)
    if (uiPositionalCalls.contains(tk.text) &&
        next != null &&
        next.kind == 'p' &&
        next.text == '(' &&
        (t == 0 || !(toks[t - 1].kind == 'p' && toks[t - 1].text == '.'))) {
      // arguments live at depth next.depth + 1
      scanArg(t + 2, next.depth + 1, tk.text);
      continue;
    }
    // named UI argument  label: '…'
    if (uiNamedArgs.contains(tk.text) &&
        next != null &&
        next.kind == 'p' &&
        next.text == ':' &&
        t + 2 < toks.length) {
      scanArg(t + 2, tk.depth, '${tk.text}:');
      continue;
    }
    // showDone(context, '…')
    if (uiHelperCalls.containsKey(tk.text) &&
        next != null &&
        next.kind == 'p' &&
        next.text == '(') {
      var commas = 0;
      var u = t + 2;
      final want = uiHelperCalls[tk.text]!;
      while (u < toks.length && !(toks[u].depth <= next.depth)) {
        if (toks[u].kind == 'p' &&
            toks[u].text == ',' &&
            toks[u].depth == next.depth + 1) {
          commas++;
        } else if (toks[u].kind == 'str' &&
            toks[u].depth == next.depth + 1 &&
            commas == want) {
          report(u, '${tk.text}()');
        }
        u++;
      }
      continue;
    }
    // AppFailure('…') without a code
    if (tk.text == 'AppFailure' &&
        next != null &&
        next.kind == 'p' &&
        next.text == '(') {
      var hasCode = false;
      var u = t + 2;
      var firstStr = -1;
      while (u < toks.length && toks[u].depth > next.depth) {
        if (toks[u].kind == 'id' &&
            toks[u].text == 'code' &&
            u + 1 < toks.length &&
            toks[u + 1].text == ':' &&
            toks[u].depth == next.depth + 1) {
          hasCode = true;
        }
        if (firstStr == -1 &&
            toks[u].kind == 'str' &&
            toks[u].depth == next.depth + 1) {
          firstStr = u;
        }
        u++;
      }
      if (!hasCode && firstStr != -1) {
        report(firstStr, 'AppFailure without code');
      }
      continue;
    }
  }

  // Lower-confidence candidates: a sentence-like literal anywhere else.
  for (var t = 0; t < toks.length; t++) {
    final tk = toks[t];
    if (tk.kind != 'str' || seen.contains(t)) continue;
    final (text, _) = literalAt(t);
    if (ignored(tk.line)) continue;
    if (!_looksVisible(text)) continue;
    final plain = text.replaceAll(RegExp(r'\$\{\}|\$\w+'), '').trim();
    // Needs a space, a capital start and some length: a sentence, not a key.
    if (!plain.contains(' ') || plain.length < 6) continue;
    if (!RegExp(r'^[A-Z]').hasMatch(plain)) continue;
    if (RegExp(r'[/=<>(){}\[\]|\\]').hasMatch(plain)) continue;
    // previous significant tokens: skip logging, errors and assertions
    final prev = t >= 2 ? '${toks[t - 2].text}${toks[t - 1].text}' : '';
    if (RegExp(
      r'(debugPrint|print|Exception|Error|assert|RegExp|StateError)\(?$',
    ).hasMatch(prev)) {
      continue;
    }
    out.candidates.add(Finding(rel, tk.line, 'string', text));
    seen.add(t);
  }
  return out;
}

/// A literal a person could read: it has a letter once interpolations are
/// removed, and is not a lone lowercase token (`orders`, `dine_in`, a path).
bool _looksVisible(String raw) {
  final text = raw.replaceAll(RegExp(r'\$\{\}|\$\w+'), '').trim();
  if (!RegExp(r'[A-Za-zऀ-ॿ]').hasMatch(text)) return false;
  if (RegExp(r'^[a-z0-9_\-./:#@%?=&,;+*]+$').hasMatch(text)) return false;
  if (RegExp(r'^[A-Za-z0-9_\-]+\.[A-Za-z0-9_.\-]+$').hasMatch(text)) {
    return false;
  }
  if (text.startsWith('http') ||
      text.startsWith('/') ||
      text.startsWith('package:')) {
    return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Report

String renderReport(CatalogueReport cat, ScanReport scan) {
  // The founder's day is India's: UTC + 05:30.
  final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  final stamp =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final byFile = <String, List<Finding>>{};
  for (final f in scan.findings) {
    byFile.putIfAbsent(f.file, () => []).add(f);
  }
  final candByFile = <String, int>{};
  for (final f in scan.candidates) {
    candByFile[f.file] = (candByFile[f.file] ?? 0) + 1;
  }
  final allFiles =
      {
        ...byFile.keys,
        ...candByFile.keys,
        ...scan.convertedByFile.keys,
      }.toList()..sort((a, b) {
        final ra = byFile[a]?.length ?? 0;
        final rb = byFile[b]?.length ?? 0;
        return rb != ra ? rb - ra : a.compareTo(b);
      });

  final b = StringBuffer()
    ..writeln('## Status (generated $stamp)')
    ..writeln()
    ..writeln('| Measure | Count |')
    ..writeln('|---|---|')
    ..writeln('| Catalogue keys, English | ${cat.enCount} |')
    ..writeln('| Catalogue keys, Hindi | ${cat.hiCount} |')
    ..writeln(
      '| Catalogue errors (parity, empty, placeholders, ICU) | ${cat.errors.length} |',
    )
    ..writeln(
      '| Catalogue warnings (no description, hi = en) | ${cat.warnings.length} |',
    )
    ..writeln(
      '| Catalogue references in lib/ (strings converted) | ${scan.convertedRefs} |',
    )
    ..writeln(
      '| Hard-coded UI strings remaining | ${scan.findings.length} in ${scan.filesWithFindings} files |',
    )
    ..writeln(
      '| Other string candidates (domain/application, lower confidence) | ${scan.candidates.length} |',
    )
    ..writeln(
      '| Catalogue keys no code uses (besides the shared `common…` set) | ${cat.keys.difference(scan.usedKeys).where((k) => !k.startsWith('common')).length} |',
    )
    ..writeln('| Dart files scanned | ${scan.filesScanned} |')
    ..writeln();
  if (cat.errors.isNotEmpty) {
    b.writeln('### Catalogue errors');
    for (final e in cat.errors) {
      b.writeln('- $e');
    }
    b.writeln();
  }
  b
    ..writeln('### Counts per file')
    ..writeln()
    ..writeln(
      'Converted = references to catalogue keys in the file. Remaining = hard-coded UI strings the scan found. Other = sentence-like literals outside UI arguments (check by hand).',
    )
    ..writeln()
    ..writeln('| File | Converted | Remaining | Other |')
    ..writeln('|---|---|---|---|');
  for (final f in allFiles) {
    b.writeln(
      '| `$f` | ${scan.convertedByFile[f] ?? 0} | ${byFile[f]?.length ?? 0} | ${candByFile[f] ?? 0} |',
    );
  }
  b
    ..writeln()
    ..writeln('### Remaining hard-coded UI strings');
  if (scan.findings.isEmpty) {
    b.writeln('\nNone.');
  }
  for (final f in byFile.keys.toList()..sort()) {
    b.writeln('\n`$f`');
    for (final x in byFile[f]!) {
      b.writeln('- L${x.line} ${x.kind} ${_show(x.text)}');
    }
  }
  b
    ..writeln()
    ..writeln('### Other string candidates (lower confidence)');
  final candGrouped = <String, List<Finding>>{};
  for (final f in scan.candidates) {
    candGrouped.putIfAbsent(f.file, () => []).add(f);
  }
  if (scan.candidates.isEmpty) b.writeln('\nNone.');
  for (final f in candGrouped.keys.toList()..sort()) {
    b.writeln('\n`$f`');
    for (final x in candGrouped[f]!) {
      b.writeln('- L${x.line} ${_show(x.text)}');
    }
  }
  // `common…` is the shared vocabulary kept ready for new screens.
  final unused =
      cat.keys
          .difference(scan.usedKeys)
          .where((k) => !k.startsWith('common'))
          .toList()
        ..sort();
  if (unused.isNotEmpty) {
    b
      ..writeln()
      ..writeln('### Catalogue keys no code uses (delete or wire up)');
    for (final k in unused.take(200)) {
      b.writeln('- `$k`');
    }
    if (unused.length > 200) b.writeln('- … and ${unused.length - 200} more');
  }
  if (cat.warnings.isNotEmpty) {
    b
      ..writeln()
      ..writeln('### Catalogue warnings');
    for (final w in cat.warnings.take(200)) {
      b.writeln('- $w');
    }
    if (cat.warnings.length > 200) {
      b.writeln('- … and ${cat.warnings.length - 200} more');
    }
  }
  return b.toString();
}

String _show(String s) {
  final one = s.replaceAll('\n', r'\n');
  final clipped = one.length > 90 ? '${one.substring(0, 90)}…' : one;
  return '`${clipped.replaceAll('`', "'")}`';
}
