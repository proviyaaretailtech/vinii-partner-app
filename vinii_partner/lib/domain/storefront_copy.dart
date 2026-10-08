/// Every piece of guest-facing text a restaurant can change in the VINII OS
/// storefront CMS, as one registry shared with the web: the same keys,
/// English defaults and length caps as `apps/web/src/lib/storefront-copy.ts`
/// in the Master app. "Place order" is edited once and means the same on the
/// table QR page and in this app's guest runtime.
///
/// A surface uses the keys it has screens for and ignores the rest. Keys are
/// stable identifiers: a label may be renamed, a key never.
///
/// Pure Dart: no Flutter imports.
library;

import '../core/json.dart';

/// The languages a restaurant can write its guest text in.
// i18n-ignore: a language is named in its own script, whatever the app shows
enum CopyLanguage {
  en('en', 'English', 'English'),
  hi('hi', 'हिन्दी (Hindi)', 'हिन्दी'),
  mr('mr', 'मराठी (Marathi)', 'मराठी');

  const CopyLanguage(this.key, this.label, this.nativeName);

  /// What is stored (`default_language`, the keys of `copy`).
  final String key;
  final String label;

  /// The language's own name in its own script, for the guest's switch.
  final String nativeName;

  static CopyLanguage? fromKey(Object? k) =>
      values.where((l) => l.key == k).firstOrNull;
}

/// One editable piece of guest text.
class CopyKey {
  const CopyKey(this.key, this.label, this.fallback, this.max);

  final String key;

  /// Where the guest sees it, for an editor.
  final String label;

  /// English default shown when the restaurant has not written its own.
  final String fallback;

  /// Hard cap so a long label cannot break a button.
  final int max;
}

class CopyGroup {
  const CopyGroup(this.id, this.title, this.keys);
  final String id;
  final String title;
  final List<CopyKey> keys;
}

// i18n-ignore: stored merchant default. The `fallback` English texts below
// are the guest-facing copy the app writes into a restaurant's storefront
// (shared with the web registry), not UI. The group `title`s and key `label`s
// are editor metadata that no phone screen shows yet: when one does, they
// need AppLocalizations mappings.
const copyGroups = <CopyGroup>[
  CopyGroup('welcome', 'Welcome', [
    CopyKey('welcome.cta', 'Start button', 'Start exploring', 28),
    CopyKey('welcome.table_line', 'Table line', "You're at {table}", 40),
    CopyKey(
      'welcome.pin_prompt',
      'PIN prompt',
      'Enter the table PIN to join your party',
      70,
    ),
    CopyKey('welcome.new_party', 'Start a new party', 'Start a new order', 28),
  ]),
  CopyGroup('menu', 'Menu', [
    CopyKey('menu.title', 'Menu heading', 'What are you in the mood for?', 50),
    CopyKey('menu.search', 'Search box', 'Search dishes', 32),
    CopyKey('menu.add', 'Add button', 'Add', 14),
    CopyKey('menu.sold_out', 'Sold-out label', 'Sold out', 16),
    CopyKey('menu.swipe_hint', 'Swipe hint', 'Swipe right to add', 32),
    CopyKey('menu.empty', 'Empty menu', 'The menu is being prepared', 60),
  ]),
  CopyGroup('order', 'Order & checkout', [
    CopyKey('cart.view', 'View order button', 'View order', 22),
    CopyKey('cart.title', 'Order heading', 'Your order', 30),
    CopyKey(
      'cart.notes_hint',
      'Notes box',
      'Any special requests? (less spicy, no onions…)',
      70,
    ),
    CopyKey('cart.estimated', 'Estimate label', 'Estimated total', 30),
    CopyKey('cart.place', 'Place order button', 'Place order', 22),
    CopyKey('order.placed', 'Order placed heading', 'Order placed!', 30),
  ]),
  CopyGroup('tracking', 'Tracking', [
    CopyKey('order.tracking', 'Tracking heading', 'Your order', 30),
    CopyKey('order.confirmed', 'Step: confirmed', 'Order confirmed', 30),
    CopyKey('order.in_kitchen', 'Step: in the kitchen', 'In the kitchen', 30),
    CopyKey('order.ready', 'Step: ready', 'Ready', 30),
    CopyKey('order.served', 'Step: served', 'Served — enjoy your meal!', 40),
  ]),
  CopyGroup('service', 'Service & bill', [
    CopyKey('service.call_waiter', 'Call waiter button', 'Call a waiter', 24),
    CopyKey('bill.title', 'Bill heading', 'Your bill', 30),
    CopyKey('bill.ask', 'Ask for bill button', 'Ask for the bill', 24),
    CopyKey('bill.split', 'Split bill button', 'Split bill', 20),
    CopyKey(
      'bill.thanks',
      'Thank-you line',
      'Thank you for dining with us',
      60,
    ),
  ]),
  CopyGroup('budget', 'Group budget', [
    CopyKey('budget.title', 'Budget heading', 'Dining with friends?', 40),
    CopyKey(
      'budget.subtitle',
      'Budget explainer',
      'Set a budget to stay on track.',
      80,
    ),
    CopyKey('budget.cta', 'Budget button', 'Save & continue', 24),
  ]),
];

final List<CopyKey> copyKeys = [for (final g in copyGroups) ...g.keys];

final Map<String, CopyKey> _byKey = {for (final k in copyKeys) k.key: k};

CopyKey? copyKey(String key) => _byKey[key];

/// The restaurant's own wording, per language:
/// `{"en": {"cart.place": "Order now"}, "hi": {…}}` (the definition's
/// `copy`).
///
/// [texts] is the clean view guests read — registry keys only, trimmed,
/// blank values dropped, capped at each key's length, exactly like the
/// CMS's `cleanCopy`. The stored JSON is kept as it came and written back
/// unchanged by [toJson], so text a newer CMS added (a key or a language
/// this app does not know yet) survives a save from the phone.
class StorefrontCopy {
  const StorefrontCopy._(this.texts, this._raw);

  static const empty = StorefrontCopy._({}, {});

  /// Builds copy in code (tests; a future phone editor).
  factory StorefrontCopy(Map<CopyLanguage, Map<String, String>> texts) =>
      StorefrontCopy.fromJson({
        for (final e in texts.entries)
          if (e.value.isNotEmpty) e.key.key: Map<String, String>.of(e.value),
      });

  factory StorefrontCopy.fromJson(Map<String, dynamic> j) =>
      StorefrontCopy._(cleanCopy(j), jsonCopyMap(j));

  final Map<CopyLanguage, Map<String, String>> texts;
  final Map<String, dynamic> _raw;

  /// Nothing stored at all (the definition then has no `copy` key).
  bool get isEmpty => _raw.isEmpty;

  /// The restaurant's own text for [key] in [lang], or null.
  String? own(CopyLanguage lang, String key) => texts[lang]?[key];

  /// The languages a guest can switch between: English (always readable —
  /// the registry's defaults are English) and every other language the
  /// restaurant wrote text in.
  List<CopyLanguage> get guestLanguages => [
    for (final l in CopyLanguage.values)
      if (l == CopyLanguage.en || (texts[l]?.isNotEmpty ?? false)) l,
  ];

  Map<String, dynamic> toJson() => jsonCopyMap(_raw);
}

/// Drops unknown keys, unknown languages, blank values and text over the
/// key's cap: the CMS's `cleanCopy`, for what guests are shown.
Map<CopyLanguage, Map<String, String>> cleanCopy(Object? copy) {
  final out = <CopyLanguage, Map<String, String>>{};
  if (copy is! Map) return out;
  for (final lang in CopyLanguage.values) {
    final table = copy[lang.key];
    if (table is! Map) continue;
    final kept = <String, String>{};
    for (final e in table.entries) {
      final spec = _byKey['${e.key}'];
      final value = e.value;
      if (spec == null || value is! String) continue;
      final text = value.trim();
      if (text.isNotEmpty) kept[spec.key] = _cap(text, spec.max);
    }
    if (kept.isNotEmpty) out[lang] = kept;
  }
  return out;
}

/// The text a guest sees for [key]: the restaurant's own wording in the
/// guest's language, else its English wording, else the registry default
/// (else the key itself). `{table}`-style placeholders are filled from
/// [vars]; unknown ones are left as written. Same order as the CMS's
/// `copyText`.
String copyText(
  StorefrontCopy? copy,
  String key, [
  CopyLanguage lang = CopyLanguage.en,
  Map<String, String> vars = const {},
]) => _fill(ownCopyText(copy, key, lang) ?? _byKey[key]?.fallback ?? key, vars);

/// Only what the restaurant wrote for [key] (in [lang], else English);
/// null when it wrote nothing. For screens that keep their own wording
/// unless the restaurant chose different words.
String? ownCopyText(
  StorefrontCopy? copy,
  String key, [
  CopyLanguage lang = CopyLanguage.en,
  Map<String, String> vars = const {},
]) {
  String? pick(CopyLanguage l) {
    final t = copy?.texts[l]?[key]?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  final raw = pick(lang) ?? pick(CopyLanguage.en);
  return raw == null ? null : _fill(raw, vars);
}

String _fill(String text, Map<String, String> vars) =>
    text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => vars[m[1]] ?? m[0]!);

/// [text] cut to [max] UTF-16 units (as the CMS's `slice`), never in the
/// middle of an emoji's surrogate pair.
String _cap(String text, int max) {
  if (text.length <= max) return text;
  var end = max;
  final last = text.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return text.substring(0, end);
}
