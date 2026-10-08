import 'dart:math' as math;

import '../core/json.dart';
import 'organization.dart';
import 'storefront_copy.dart';

export 'storefront_copy.dart';

/// The guest-facing storefront — the organization's own ordering website and
/// table app — described as data. Storefront Studio edits it; the guest
/// runtime renders it. Two restaurants look and behave differently because
/// their definitions differ, never because the code knows their names.
///
/// Stored as JSON (snake_case keys, `schema_version`). Readers ignore unknown
/// keys and fill missing ones with defaults, so an older app can read a newer
/// definition and the reverse.
///
/// The same document is edited by the VINII OS storefront CMS (Master app,
/// `apps/web/src/lib/storefront.ts`). Each editor changes only what it owns
/// and passes everything else through: [theme], [media], [copy] and
/// [defaultLanguage] are the CMS's and are written back exactly as read;
/// keys this app does not know at all are kept in [extra] (and
/// [StorefrontBrand.extra]) and written back too. So a save from the phone
/// never deletes something a newer CMS added.
class StorefrontDefinition {
  const StorefrontDefinition({
    this.schemaVersion = currentSchemaVersion,
    required this.template,
    required this.accentHex,
    required this.brand,
    this.serviceModes = const [
      GuestServiceMode.dineIn,
      GuestServiceMode.takeaway,
    ],
    this.preOrder = const PreOrderSettings(),
    this.features = const GuestFeatures(),
    this.categoryStyle = CategoryStyle.grid,
    this.categories = const [],
    this.items = const {},
    this.chefsPicks = const [],
    this.limitedToday = const [],
    this.gstPercent = 5,
    // i18n-ignore: stored merchant default (the word guests see before a table number)
    this.tableLabel = 'Table',
    this.theme = StorefrontTheme.empty,
    this.media = StorefrontMedia.empty,
    this.copy = StorefrontCopy.empty,
    this.defaultLanguage,
    this.extra = const {},
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final StorefrontTemplate template;

  /// Overrides the template's accent — buttons, rings, highlights.
  final String accentHex;
  final StorefrontBrand brand;

  /// In the order guests see them. Empty is not allowed by Studio.
  final List<GuestServiceMode> serviceModes;
  final PreOrderSettings preOrder;
  final GuestFeatures features;
  final CategoryStyle categoryStyle;

  /// Which menu categories guests see, in which order, with which emoji.
  /// Categories missing here are shown after these, in menu order.
  final List<CategoryPresentation> categories;

  /// Guest-only details for menu items (tags, ingredients, allergens,
  /// calories). The POS item row itself is never copied.
  final Map<String, ItemPresentation> items;

  /// Item ids for the "Chef's picks" row.
  final List<String> chefsPicks;
  final List<LimitedOffer> limitedToday;
  final double gstPercent;

  /// "Table" → "Table 12"; a hotel might use "Room".
  final String tableLabel;

  /// Colour, button and font choices from the CMS. Empty = the template's.
  final StorefrontTheme theme;

  /// Welcome and category pictures from the CMS.
  final StorefrontMedia media;

  /// The restaurant's own guest-facing text, per language (the copy
  /// registry in `storefront_copy.dart`).
  final StorefrontCopy copy;

  /// The language a guest starts in. Null when none is stored (or it is one
  /// this app does not know yet, which is then kept in [extra]).
  final CopyLanguage? defaultLanguage;

  /// Top-level keys this app does not understand, kept verbatim and written
  /// back by [toJson].
  final Map<String, dynamic> extra;

  /// The language a guest party starts in: [defaultLanguage], else English.
  CopyLanguage get guestLanguage => defaultLanguage ?? CopyLanguage.en;

  bool offers(GuestServiceMode mode) => serviceModes.contains(mode);

  ItemPresentation presentationOf(String itemId) =>
      items[itemId] ?? ItemPresentation(itemId: itemId);

  CategoryPresentation? categoryPresentation(String categoryId) =>
      categories.where((c) => c.categoryId == categoryId).firstOrNull;

  StorefrontDefinition copyWith({
    StorefrontTemplate? template,
    String? accentHex,
    StorefrontBrand? brand,
    List<GuestServiceMode>? serviceModes,
    PreOrderSettings? preOrder,
    GuestFeatures? features,
    CategoryStyle? categoryStyle,
    List<CategoryPresentation>? categories,
    Map<String, ItemPresentation>? items,
    List<String>? chefsPicks,
    List<LimitedOffer>? limitedToday,
    double? gstPercent,
    String? tableLabel,
    StorefrontTheme? theme,
    StorefrontMedia? media,
    StorefrontCopy? copy,
    CopyLanguage? defaultLanguage,
    Map<String, dynamic>? extra,
  }) => StorefrontDefinition(
    schemaVersion: schemaVersion,
    template: template ?? this.template,
    accentHex: accentHex ?? this.accentHex,
    brand: brand ?? this.brand,
    serviceModes: serviceModes ?? this.serviceModes,
    preOrder: preOrder ?? this.preOrder,
    features: features ?? this.features,
    categoryStyle: categoryStyle ?? this.categoryStyle,
    categories: categories ?? this.categories,
    items: items ?? this.items,
    chefsPicks: chefsPicks ?? this.chefsPicks,
    limitedToday: limitedToday ?? this.limitedToday,
    gstPercent: gstPercent ?? this.gstPercent,
    tableLabel: tableLabel ?? this.tableLabel,
    theme: theme ?? this.theme,
    media: media ?? this.media,
    copy: copy ?? this.copy,
    defaultLanguage: defaultLanguage ?? this.defaultLanguage,
    extra: extra ?? this.extra,
  );

  StorefrontDefinition withItem(ItemPresentation p) =>
      copyWith(items: {...items, p.itemId: p});

  /// The blank starting point for an organization that has never published:
  /// only real facts (its name, city and brand colour) are filled in. Every
  /// headline, tag, pick and offer stays empty until someone writes it —
  /// the template's example wording is shown in Studio as a hint, never
  /// saved as data.
  factory StorefrontDefinition.starter(Organization org) {
    final t =
        org.type.contains('bake') ||
            org.type.contains('cafe') ||
            org.type.contains('café')
        ? StorefrontTemplate.artisanDay
        : org.type.contains('cloud') || org.type.contains('qsr')
        ? StorefrontTemplate.freshMinimal
        : StorefrontTemplate.bistroNight;
    return StorefrontDefinition(
      template: t,
      accentHex: org.accentHex ?? t.defaultAccent,
      brand: StorefrontBrand(
        displayName: org.name,
        locationLine: org.city ?? '',
      ),
      serviceModes: const [GuestServiceMode.dineIn],
      categoryStyle: t == StorefrontTemplate.artisanDay
          ? CategoryStyle.wheel
          : CategoryStyle.grid,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'template': template.key,
    'accent': accentHex,
    'brand': brand.toJson(),
    'service_modes': [for (final m in serviceModes) m.key],
    'pre_order': preOrder.toJson(),
    'features': features.toJson(),
    'category_style': categoryStyle.key,
    'categories': [for (final c in categories) c.toJson()],
    'items': {for (final e in items.entries) e.key: e.value.toJson()},
    'chefs_picks': chefsPicks,
    'limited_today': [for (final l in limitedToday) l.toJson()],
    'gst_percent': gstPercent,
    'table_label': tableLabel,
    if (!theme.isEmpty) 'theme': theme.toJson(),
    if (!media.isEmpty) 'media': media.toJson(),
    if (!copy.isEmpty) 'copy': copy.toJson(),
    if (defaultLanguage != null) 'default_language': defaultLanguage!.key,
    // Last, and never over a key written above.
    for (final e in extra.entries)
      if (!_knownKeys.contains(e.key) || !_writes(e.key))
        e.key: jsonCopy(e.value),
  };

  /// Every top-level key this model reads.
  static const _knownKeys = {
    'schema_version',
    'template',
    'accent',
    'brand',
    'service_modes',
    'pre_order',
    'features',
    'category_style',
    'categories',
    'items',
    'chefs_picks',
    'limited_today',
    'gst_percent',
    'table_label',
    'theme',
    'media',
    'copy',
    'default_language',
  };

  /// Whether [toJson] writes known key [k] itself for this definition.
  bool _writes(String k) => switch (k) {
    'theme' => !theme.isEmpty,
    'media' => !media.isEmpty,
    'copy' => !copy.isEmpty,
    'default_language' => defaultLanguage != null,
    _ => true,
  };

  /// A stored key this model cannot use as it is, so it is carried through
  /// untouched instead: unknown keys, and CMS sections in a shape this app
  /// does not understand.
  static bool _passThrough(String k, Object? v) =>
      !_knownKeys.contains(k) ||
      (const {'theme', 'media', 'copy'}.contains(k) && v is! Map) ||
      (k == 'default_language' && CopyLanguage.fromKey(v) == null);

  factory StorefrontDefinition.fromJson(
    Map<String, dynamic> j, {
    required Organization org,
  }) {
    final starter = StorefrontDefinition.starter(org);
    final template =
        StorefrontTemplate.fromKey(j['template'] as String?) ??
        starter.template;
    final modes = [
      for (final k in _list(j['service_modes']))
        ?GuestServiceMode.fromKey('$k'),
    ];
    final accent = j['accent'] as String?;
    return StorefrontDefinition(
      schemaVersion:
          (j['schema_version'] as num?)?.toInt() ?? currentSchemaVersion,
      template: template,
      accentHex: parseHexColor(accent) == null
          ? template.defaultAccent
          : accent!,
      brand: j['brand'] is Map
          ? StorefrontBrand.fromJson(_map(j['brand']), fallback: starter.brand)
          : starter.brand,
      serviceModes: modes.isEmpty ? starter.serviceModes : modes,
      preOrder: j['pre_order'] is Map
          ? PreOrderSettings.fromJson(_map(j['pre_order']))
          : const PreOrderSettings(),
      features: j['features'] is Map
          ? GuestFeatures.fromJson(_map(j['features']))
          : const GuestFeatures(),
      categoryStyle:
          CategoryStyle.fromKey(j['category_style'] as String?) ??
          starter.categoryStyle,
      categories: [
        for (final c in _list(j['categories']))
          if (c is Map) CategoryPresentation.fromJson(_map(c)),
      ],
      items: {
        for (final e in _map(j['items']).entries)
          if (e.value is Map)
            e.key: ItemPresentation.fromJson(e.key, _map(e.value)),
      },
      chefsPicks: [for (final id in _list(j['chefs_picks'])) '$id'],
      limitedToday: [
        for (final l in _list(j['limited_today']))
          if (l is Map) LimitedOffer.fromJson(_map(l)),
      ],
      gstPercent: (j['gst_percent'] as num?)?.toDouble() ?? 5,
      tableLabel: (j['table_label'] as String?)?.trim().isNotEmpty == true
          ? j['table_label'] as String
          // i18n-ignore: stored merchant default (the word guests see before a table number)
          : 'Table',
      theme: j['theme'] is Map
          ? StorefrontTheme.fromJson(_map(j['theme']))
          : StorefrontTheme.empty,
      media: j['media'] is Map
          ? StorefrontMedia.fromJson(_map(j['media']))
          : StorefrontMedia.empty,
      copy: j['copy'] is Map
          ? StorefrontCopy.fromJson(_map(j['copy']))
          : StorefrontCopy.empty,
      defaultLanguage: CopyLanguage.fromKey(j['default_language']),
      extra: {
        for (final e in j.entries)
          if (_passThrough(e.key, e.value)) e.key: jsonCopy(e.value),
      },
    );
  }
}

List<Object?> _list(Object? v) => v is List ? v : const [];
Map<String, dynamic> _map(Object? v) => v is Map
    ? v.map((k, val) => MapEntry('$k', val))
    : const <String, dynamic>{};

// i18n-ignore: template `label`s are product names; `description` is English
// fallback text, screens use AppLocalizations.studioTemplateBlurb
// (studio_sections.dart). The `default*` wording below is example guest copy
// shown as a grey hint in an empty text field, never saved: it is guest
// content in the storefront's own language, not staff UI.
// i18n-ignore-start: template names are product names; the rest is an English fallback / example guest copy
enum StorefrontTemplate {
  bistroNight(
    key: 'bistro_night',
    label: 'Bistro Night',
    description: 'Dark and candle-lit with gold accents. Restaurants, bars, fine dining.',
    defaultAccent: '#F5B82E',
    defaultTagline: 'Swipe through dishes, set a budget, and order together.',
    defaultHeroTitle: 'Food Looks Better When You Explore It.',
    defaultHeroSubtitle:
        'Swipe through dishes, set a budget, and order together.',
    headingFont: StorefrontFont.plusJakartaSans,
    bodyFont: StorefrontFont.plusJakartaSans,
  ),
  artisanDay(
    key: 'artisan_day',
    label: 'Artisan Day',
    description: 'Warm cream and espresso with a handwritten headline. Bakeries and cafés.',
    defaultAccent: '#2B211B',
    defaultTagline: 'Artisanal bakery & café',
    defaultHeroTitle: 'Good Food Rises People Together',
    defaultHeroSubtitle:
        'Fresh bakes, honest ingredients and a little more joy for your table.',
    headingFont: StorefrontFont.playfairDisplay,
    bodyFont: StorefrontFont.dmSans,
  ),
  freshMinimal(
    key: 'fresh_minimal',
    label: 'Fresh Minimal',
    description:
        'Clean white and green. Quick service, cloud kitchens, juice bars.',
    defaultAccent: '#16A34A',
    defaultTagline: 'Fresh, fast and made for you',
    defaultHeroTitle: 'Hungry? Swipe. Tap. Done.',
    defaultHeroSubtitle:
        'Pick what you like, we will have it ready in minutes.',
    headingFont: StorefrontFont.outfit,
    bodyFont: StorefrontFont.outfit,
  );

  const StorefrontTemplate({
    required this.key,
    required this.label,
    required this.description,
    required this.defaultAccent,
    required this.defaultTagline,
    required this.defaultHeroTitle,
    required this.defaultHeroSubtitle,
    required this.headingFont,
    required this.bodyFont,
  });

  final String key;
  final String label;
  final String description;
  final String defaultAccent;

  /// Example wording shown as greyed-out hints in Studio's text fields.
  /// Never saved: a storefront says only what the merchant wrote.
  final String defaultTagline;
  final String defaultHeroTitle;
  final String defaultHeroSubtitle;

  /// The template's own faces, used unless [StorefrontTheme] picks others
  /// (the CMS's `TEMPLATES[].fonts`).
  final StorefrontFont headingFont;
  final StorefrontFont bodyFont;

  /// Button corners when the theme does not choose: pill on Bistro Night,
  /// rounded elsewhere (the CMS's `resolveLook`).
  StorefrontButtonShape get defaultButtonShape => this == bistroNight
      ? StorefrontButtonShape.pill
      : StorefrontButtonShape.rounded;

  static StorefrontTemplate? fromKey(String? k) =>
      values.where((t) => t.key == k).firstOrNull;
}
// i18n-ignore-end

// i18n-ignore: English fallback for logs/tests; screens use
// AppLocalizations.studioModeName (studio_sections.dart) and the hints in
// service_section.dart.
enum GuestServiceMode {
  dineIn('dine_in', 'Dine-in', 'Order fresh at your table'),
  takeaway('takeaway', 'Takeaway', 'Pick up at the counter'),
  preOrder('pre_order', 'Pre-order', 'Schedule a pickup for later'),
  delivery('delivery', 'Delivery', 'Delivered to your door');

  const GuestServiceMode(this.key, this.label, this.hint);
  final String key;
  final String label;
  final String hint;

  static GuestServiceMode? fromKey(String? k) =>
      values.where((m) => m.key == k).firstOrNull;
}

// i18n-ignore: English fallback for logs/tests; screens use
// AppLocalizations.studioStyleName / studioStyleHint (studio_sections.dart).
enum CategoryStyle {
  grid('grid', 'Tiles', 'A grid of photo tiles'),
  wheel('wheel', 'Wheel', 'A curved carousel guests swipe through');

  const CategoryStyle(this.key, this.label, this.hint);
  final String key;
  final String label;
  final String hint;

  static CategoryStyle? fromKey(String? k) =>
      values.where((c) => c.key == k).firstOrNull;
}

/// The curated faces a storefront may use, all available both to the web
/// (Google Fonts CSS) and here (google_fonts). The id is what is stored.
// i18n-ignore: font family names are brand names
enum StorefrontFont {
  plusJakartaSans('plus-jakarta-sans', 'Plus Jakarta Sans'),
  inter('inter', 'Inter'),
  dmSans('dm-sans', 'DM Sans'),
  poppins('poppins', 'Poppins'),
  outfit('outfit', 'Outfit'),
  playfairDisplay('playfair-display', 'Playfair Display', serif: true),
  sourceSerif4('source-serif-4', 'Source Serif 4', serif: true),
  kaushanScript('kaushan-script', 'Kaushan Script', headingOnly: true);

  const StorefrontFont(
    this.id,
    this.family, {
    this.serif = false,
    this.headingOnly = false,
  });

  final String id;

  /// The Google Fonts family name (what `GoogleFonts.getFont` takes).
  final String family;
  final bool serif;

  /// Script faces are for headings only: unreadable as body text.
  final bool headingOnly;

  static StorefrontFont? fromId(Object? id) =>
      values.where((f) => f.id == id).firstOrNull;
}

enum StorefrontButtonShape {
  pill('pill', 999),
  rounded('rounded', 14),
  square('square', 6);

  const StorefrontButtonShape(this.key, this.radius);
  final String key;

  /// Corner radius in logical pixels; 999 means fully round ends.
  final double radius;

  static StorefrontButtonShape? fromKey(Object? k) =>
      values.where((s) => s.key == k).firstOrNull;
}

enum StorefrontButtonStyle {
  filled('filled'),
  outline('outline');

  const StorefrontButtonStyle(this.key);
  final String key;

  static StorefrontButtonStyle? fromKey(Object? k) =>
      values.where((s) => s.key == k).firstOrNull;
}

/// `#RRGGBB`, the only colour form the storefront stores.
bool isHexColor(Object? v) =>
    v is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v);

/// The CMS's colour, button and font choices (the definition's `theme`).
/// Absent values mean "the template's". The phone does not edit these: it
/// paints them and passes them through.
///
/// The typed fields are the clean view (valid colours upper-cased, known
/// shapes and faces, never a script face as body text — the CMS's
/// `cleanTheme`). The stored JSON is kept as read and written back by
/// [toJson], so values this app cannot use yet are not lost.
class StorefrontTheme {
  const StorefrontTheme._({
    this.colors = const {},
    this.buttonShape,
    this.buttonStyle,
    this.headingFont,
    this.bodyFont,
    this._raw = const {},
  });

  static const empty = StorefrontTheme._();

  /// Builds a theme in code (tests; a future phone editor).
  factory StorefrontTheme({
    Map<String, String> colors = const {},
    StorefrontButtonShape? buttonShape,
    StorefrontButtonStyle? buttonStyle,
    StorefrontFont? headingFont,
    StorefrontFont? bodyFont,
  }) => StorefrontTheme.fromJson({
    if (colors.isNotEmpty) 'colors': Map<String, String>.of(colors),
    if (buttonShape != null || buttonStyle != null)
      'buttons': {
        if (buttonShape != null) 'shape': buttonShape.key,
        if (buttonStyle != null) 'style': buttonStyle.key,
      },
    if (headingFont != null || bodyFont != null)
      'fonts': {
        if (headingFont != null) 'heading': headingFont.id,
        if (bodyFont != null) 'body': bodyFont.id,
      },
  });

  factory StorefrontTheme.fromJson(Map<String, dynamic> j) {
    final c = _map(j['colors']), b = _map(j['buttons']), f = _map(j['fonts']);
    final body = StorefrontFont.fromId(f['body']);
    return StorefrontTheme._(
      colors: {
        for (final k in colorKeys)
          if (isHexColor(c[k])) k: (c[k] as String).toUpperCase(),
      },
      buttonShape: StorefrontButtonShape.fromKey(b['shape']),
      buttonStyle: StorefrontButtonStyle.fromKey(b['style']),
      headingFont: StorefrontFont.fromId(f['heading']),
      bodyFont: body == null || body.headingOnly ? null : body,
      raw: jsonCopyMap(j),
    );
  }

  /// The colours the CMS may override. The accent is the definition's own
  /// `accent`; surface_alt and border always come from the template.
  static const colorKeys = [
    'on_accent',
    'background',
    'surface',
    'text',
    'muted',
    'success',
    'danger',
  ];

  /// Valid overrides only, `#RRGGBB` upper-case, by [colorKeys] key.
  final Map<String, String> colors;
  final StorefrontButtonShape? buttonShape;
  final StorefrontButtonStyle? buttonStyle;
  final StorefrontFont? headingFont;
  final StorefrontFont? bodyFont;
  final Map<String, dynamic> _raw;

  bool get isEmpty => _raw.isEmpty;

  Map<String, dynamic> toJson() => jsonCopyMap(_raw);
}

/// The CMS's pictures (the definition's `media`): the welcome picture and
/// one per menu category. Values are picture references for [mediaUrl].
/// Like [StorefrontTheme], the stored JSON is written back as read.
class StorefrontMedia {
  const StorefrontMedia._({
    this.hero,
    this.categories = const {},
    this._raw = const {},
  });

  static const empty = StorefrontMedia._();

  factory StorefrontMedia({
    String? hero,
    Map<String, String> categories = const {},
  }) => StorefrontMedia.fromJson({
    if (hero != null && hero.isNotEmpty) 'hero': hero,
    if (categories.isNotEmpty) 'categories': Map<String, String>.of(categories),
  });

  factory StorefrontMedia.fromJson(Map<String, dynamic> j) => StorefrontMedia._(
    hero: j['hero'] is String && (j['hero'] as String).isNotEmpty
        ? j['hero'] as String
        : null,
    categories: {
      for (final e in _map(j['categories']).entries)
        if (e.value is String && (e.value as String).isNotEmpty)
          e.key: e.value as String,
    },
    raw: jsonCopyMap(j),
  );

  /// Full-bleed welcome picture behind the headline.
  final String? hero;

  /// Category tile pictures, by `menu_categories.id`.
  final Map<String, String> categories;
  final Map<String, dynamic> _raw;

  bool get isEmpty => _raw.isEmpty;

  Map<String, dynamic> toJson() => jsonCopyMap(_raw);
}

/// A guest-facing address for a picture reference, as the CMS's `mediaUrl`:
/// a full `http(s)://` URL is used as it is; a bucket path
/// (`<organization id>/<file>`) is served by the Master's `/media` route at
/// [base]. A phone has no "same origin", so with an empty [base] a bucket
/// path gives null and screens show their illustrated fallback.
String? mediaUrl(String? ref, String base) {
  if (ref == null || ref.trim().isEmpty) return null;
  final r = ref.trim();
  if (RegExp(r'^https?://').hasMatch(r)) return r;
  final b = base.trim().replaceFirst(RegExp(r'/+$'), '');
  if (b.isEmpty) return null;
  return '$b/media/${r.replaceFirst(RegExp(r'^/+'), '')}';
}

/// WCAG relative luminance of `#RRGGBB` (0 for anything else), as the CMS.
double hexLuminance(String hex) {
  final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex);
  if (m == null) return 0;
  final v = int.parse(m[1]!, radix: 16);
  double ch(int c) {
    final s = c / 255;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * ch((v >> 16) & 255) +
      0.7152 * ch((v >> 8) & 255) +
      0.0722 * ch(v & 255);
}

double contrastRatio(String a, String b) {
  final la = hexLuminance(a), lb = hexLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Near-black or white, whichever reads better on [bg] — the CMS's
/// `readableOn`, so button text matches its preview.
String readableOn(String bg) =>
    contrastRatio(bg, '#111115') >= contrastRatio(bg, '#FFFFFF')
    ? '#111115'
    : '#FFFFFF';

class StorefrontBrand {
  const StorefrontBrand({
    required this.displayName,
    this.tagline = '',
    this.locationLine = '',
    this.heroTitle = '',
    this.heroSubtitle = '',
    this.logoUrl,
    this.coverUrl,
    this.extra = const {},
  });

  final String displayName;
  final String tagline;

  /// "Indiranagar, Bengaluru" under the name on the welcome screen.
  final String locationLine;
  final String heroTitle;
  final String heroSubtitle;

  /// Picture references ([mediaUrl]), uploaded in the CMS.
  final String? logoUrl;
  final String? coverUrl;

  /// Keys of `brand` this app does not know, written back unchanged.
  final Map<String, dynamic> extra;

  static const _knownKeys = {
    'display_name',
    'tagline',
    'location_line',
    'hero_title',
    'hero_subtitle',
    'logo_url',
    'cover_url',
  };

  StorefrontBrand copyWith({
    String? displayName,
    String? tagline,
    String? locationLine,
    String? heroTitle,
    String? heroSubtitle,
    String? logoUrl,
    String? coverUrl,
    Map<String, dynamic>? extra,
  }) => StorefrontBrand(
    displayName: displayName ?? this.displayName,
    tagline: tagline ?? this.tagline,
    locationLine: locationLine ?? this.locationLine,
    heroTitle: heroTitle ?? this.heroTitle,
    heroSubtitle: heroSubtitle ?? this.heroSubtitle,
    logoUrl: logoUrl ?? this.logoUrl,
    coverUrl: coverUrl ?? this.coverUrl,
    extra: extra ?? this.extra,
  );

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'tagline': tagline,
    'location_line': locationLine,
    'hero_title': heroTitle,
    'hero_subtitle': heroSubtitle,
    if (logoUrl != null) 'logo_url': logoUrl,
    if (coverUrl != null) 'cover_url': coverUrl,
    for (final e in extra.entries)
      if (!_knownKeys.contains(e.key)) e.key: jsonCopy(e.value),
  };

  factory StorefrontBrand.fromJson(
    Map<String, dynamic> j, {
    required StorefrontBrand fallback,
  }) {
    String s(String key, String fb) =>
        (j[key] is String && (j[key] as String).trim().isNotEmpty)
        ? j[key] as String
        : fb;
    return StorefrontBrand(
      displayName: s('display_name', fallback.displayName),
      tagline: s('tagline', fallback.tagline),
      locationLine: j['location_line'] is String
          ? j['location_line'] as String
          : fallback.locationLine,
      heroTitle: s('hero_title', fallback.heroTitle),
      heroSubtitle: s('hero_subtitle', fallback.heroSubtitle),
      logoUrl: j['logo_url'] is String ? j['logo_url'] as String : null,
      coverUrl: j['cover_url'] is String ? j['cover_url'] as String : null,
      extra: {
        for (final e in j.entries)
          if (!_knownKeys.contains(e.key)) e.key: jsonCopy(e.value),
      },
    );
  }
}

class BudgetSettings {
  const BudgetSettings({
    this.enabled = true,
    this.defaultAmount = 3000,
    this.min = 500,
    this.max = 20000,
    this.step = 500,
  });

  final bool enabled;
  final int defaultAmount;
  final int min;
  final int max;
  final int step;

  BudgetSettings copyWith({
    bool? enabled,
    int? defaultAmount,
    int? min,
    int? max,
  }) => BudgetSettings(
    enabled: enabled ?? this.enabled,
    defaultAmount: defaultAmount ?? this.defaultAmount,
    min: min ?? this.min,
    max: max ?? this.max,
    step: step,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'default': defaultAmount,
    'min': min,
    'max': max,
    'step': step,
  };

  factory BudgetSettings.fromJson(Map<String, dynamic> j) {
    int i(String k, int fb) => (j[k] as num?)?.toInt() ?? fb;
    final min = i('min', 500), max = i('max', 20000);
    return BudgetSettings(
      enabled: j['enabled'] != false,
      min: min,
      max: max < min ? min : max,
      defaultAmount: i('default', 3000).clamp(min, max < min ? min : max),
      step: i('step', 500).clamp(50, 5000),
    );
  }
}

/// Switches for each part of the guest experience (the screens in the two
/// reference boards). Everything defaults on; Studio turns things off.
class GuestFeatures {
  const GuestFeatures({
    this.swipeDeck = true,
    this.budget = const BudgetSettings(),
    this.splitParty = true,
    this.likes = true,
    this.chefsPicks = true,
    this.limitedToday = true,
    this.discoverWhileWaiting = true,
    this.liveTracking = true,
    this.splitBill = true,
    this.feedback = true,
    this.showIngredients = true,
    this.showAllergens = true,
    this.showNutrition = true,
  });

  /// Tinder-style cards. Off = a scrolling list with Add buttons.
  final bool swipeDeck;
  final BudgetSettings budget;

  /// "Split between N people" on the budget screen and the bill.
  final bool splitParty;
  final bool likes;
  final bool chefsPicks;
  final bool limitedToday;
  final bool discoverWhileWaiting;
  final bool liveTracking;
  final bool splitBill;
  final bool feedback;
  final bool showIngredients;
  final bool showAllergens;
  final bool showNutrition;

  GuestFeatures copyWith({
    bool? swipeDeck,
    BudgetSettings? budget,
    bool? splitParty,
    bool? likes,
    bool? chefsPicks,
    bool? limitedToday,
    bool? discoverWhileWaiting,
    bool? liveTracking,
    bool? splitBill,
    bool? feedback,
    bool? showIngredients,
    bool? showAllergens,
    bool? showNutrition,
  }) => GuestFeatures(
    swipeDeck: swipeDeck ?? this.swipeDeck,
    budget: budget ?? this.budget,
    splitParty: splitParty ?? this.splitParty,
    likes: likes ?? this.likes,
    chefsPicks: chefsPicks ?? this.chefsPicks,
    limitedToday: limitedToday ?? this.limitedToday,
    discoverWhileWaiting: discoverWhileWaiting ?? this.discoverWhileWaiting,
    liveTracking: liveTracking ?? this.liveTracking,
    splitBill: splitBill ?? this.splitBill,
    feedback: feedback ?? this.feedback,
    showIngredients: showIngredients ?? this.showIngredients,
    showAllergens: showAllergens ?? this.showAllergens,
    showNutrition: showNutrition ?? this.showNutrition,
  );

  Map<String, dynamic> toJson() => {
    'swipe_deck': swipeDeck,
    'budget': budget.toJson(),
    'split_party': splitParty,
    'likes': likes,
    'chefs_picks': chefsPicks,
    'limited_today': limitedToday,
    'discover_while_waiting': discoverWhileWaiting,
    'live_tracking': liveTracking,
    'split_bill': splitBill,
    'feedback': feedback,
    'show_ingredients': showIngredients,
    'show_allergens': showAllergens,
    'show_nutrition': showNutrition,
  };

  factory GuestFeatures.fromJson(Map<String, dynamic> j) {
    bool b(String k) => j[k] != false;
    return GuestFeatures(
      swipeDeck: b('swipe_deck'),
      budget: j['budget'] is Map
          ? BudgetSettings.fromJson(_map(j['budget']))
          : const BudgetSettings(),
      splitParty: b('split_party'),
      likes: b('likes'),
      chefsPicks: b('chefs_picks'),
      limitedToday: b('limited_today'),
      discoverWhileWaiting: b('discover_while_waiting'),
      liveTracking: b('live_tracking'),
      splitBill: b('split_bill'),
      feedback: b('feedback'),
      showIngredients: b('show_ingredients'),
      showAllergens: b('show_allergens'),
      showNutrition: b('show_nutrition'),
    );
  }
}

class PreOrderSettings {
  const PreOrderSettings({
    this.daysAhead = 5,
    this.opensAt = '08:00',
    this.closesAt = '17:00',
    this.slotMinutes = 60,
    this.leadMinutes = 60,
  });

  /// How many days ahead guests may book, today included.
  final int daysAhead;

  /// "HH:mm", 24-hour, restaurant local time.
  final String opensAt;
  final String closesAt;
  final int slotMinutes;

  /// The earliest slot today is at least this far from now.
  final int leadMinutes;

  PreOrderSettings copyWith({
    int? daysAhead,
    String? opensAt,
    String? closesAt,
    int? slotMinutes,
    int? leadMinutes,
  }) => PreOrderSettings(
    daysAhead: daysAhead ?? this.daysAhead,
    opensAt: opensAt ?? this.opensAt,
    closesAt: closesAt ?? this.closesAt,
    slotMinutes: slotMinutes ?? this.slotMinutes,
    leadMinutes: leadMinutes ?? this.leadMinutes,
  );

  Map<String, dynamic> toJson() => {
    'days_ahead': daysAhead,
    'opens_at': opensAt,
    'closes_at': closesAt,
    'slot_minutes': slotMinutes,
    'lead_minutes': leadMinutes,
  };

  factory PreOrderSettings.fromJson(Map<String, dynamic> j) {
    String hm(String k, String fb) =>
        j[k] is String && RegExp(r'^\d{2}:\d{2}$').hasMatch(j[k] as String)
        ? j[k] as String
        : fb;
    return PreOrderSettings(
      daysAhead: ((j['days_ahead'] as num?)?.toInt() ?? 5).clamp(1, 30),
      opensAt: hm('opens_at', '08:00'),
      closesAt: hm('closes_at', '17:00'),
      slotMinutes: ((j['slot_minutes'] as num?)?.toInt() ?? 60).clamp(15, 240),
      leadMinutes: ((j['lead_minutes'] as num?)?.toInt() ?? 60).clamp(
        0,
        24 * 60,
      ),
    );
  }

  /// Every slot start for [day] (a local date), including ones already past,
  /// so screens can grey them out like the reference board. 08:00–17:00 in
  /// 60-minute slots gives 8:00 … 16:00.
  List<DateTime> allSlotsFor(DateTime day) {
    int minutes(String hm) =>
        int.parse(hm.substring(0, 2)) * 60 + int.parse(hm.substring(3));
    final open = minutes(opensAt), close = minutes(closesAt);
    return [
      for (var m = open; m + slotMinutes <= close; m += slotMinutes)
        DateTime(day.year, day.month, day.day, m ~/ 60, m % 60),
    ];
  }

  /// The slots on [day] a guest may still book: at least [leadMinutes] from
  /// now. Pure, so the pre-order screen and tests agree.
  List<DateTime> slotsFor(DateTime day, {DateTime? now}) {
    final earliest = (now ?? DateTime.now()).add(
      Duration(minutes: leadMinutes),
    );
    return allSlotsFor(day).where((slot) => !slot.isBefore(earliest)).toList();
  }
}

class CategoryPresentation {
  const CategoryPresentation({
    required this.categoryId,
    this.visible = true,
    this.emoji,
  });

  final String categoryId;
  final bool visible;
  final String? emoji;

  CategoryPresentation copyWith({bool? visible, String? emoji}) =>
      CategoryPresentation(
        categoryId: categoryId,
        visible: visible ?? this.visible,
        emoji: emoji ?? this.emoji,
      );

  Map<String, dynamic> toJson() => {
    'category_id': categoryId,
    'visible': visible,
    if (emoji != null) 'emoji': emoji,
  };

  factory CategoryPresentation.fromJson(Map<String, dynamic> j) =>
      CategoryPresentation(
        categoryId: '${j['category_id']}',
        visible: j['visible'] != false,
        emoji: j['emoji'] as String?,
      );
}

/// Tags guests see as chips on cards. "Bestseller" also comes automatically
/// from the POS "recommended" flag.
// i18n-ignore: stored merchant default (these exact words are saved on a dish
// and shown to guests as chips)
const storefrontTags = [
  'Bestseller',
  'Spicy',
  "Chef's special",
  'Seasonal',
  'New',
  'Vegan',
  'Jain',
  'Gluten-free',
];

class ItemPresentation {
  const ItemPresentation({
    required this.itemId,
    this.tags = const [],
    this.ingredients = const [],
    this.allergens = const [],
    this.kcal,
    this.hidden = false,
  });

  final String itemId;
  final List<String> tags;
  final List<String> ingredients;
  final List<String> allergens;
  final int? kcal;

  /// Sold in the POS but not shown on the storefront.
  final bool hidden;

  bool get isEmpty =>
      tags.isEmpty &&
      ingredients.isEmpty &&
      allergens.isEmpty &&
      kcal == null &&
      !hidden;

  ItemPresentation copyWith({
    List<String>? tags,
    List<String>? ingredients,
    List<String>? allergens,
    int? kcal,
    bool clearKcal = false,
    bool? hidden,
  }) => ItemPresentation(
    itemId: itemId,
    tags: tags ?? this.tags,
    ingredients: ingredients ?? this.ingredients,
    allergens: allergens ?? this.allergens,
    kcal: clearKcal ? null : (kcal ?? this.kcal),
    hidden: hidden ?? this.hidden,
  );

  Map<String, dynamic> toJson() => {
    if (tags.isNotEmpty) 'tags': tags,
    if (ingredients.isNotEmpty) 'ingredients': ingredients,
    if (allergens.isNotEmpty) 'allergens': allergens,
    if (kcal != null) 'kcal': kcal,
    if (hidden) 'hidden': true,
  };

  factory ItemPresentation.fromJson(String itemId, Map<String, dynamic> j) =>
      ItemPresentation(
        itemId: itemId,
        tags: [for (final t in _list(j['tags'])) '$t'],
        ingredients: [for (final t in _list(j['ingredients'])) '$t'],
        allergens: [for (final t in _list(j['allergens'])) '$t'],
        kcal: (j['kcal'] as num?)?.toInt(),
        hidden: j['hidden'] == true,
      );
}

/// "Limited today — ends in 04:18:24".
class LimitedOffer {
  const LimitedOffer({required this.itemId, this.endsAt = '18:00'});

  final String itemId;

  /// "HH:mm" local time, every day.
  final String endsAt;

  /// When the offer ends on [day]. A stored value that is not "HH:mm" (a
  /// stray "HH:mm:ss", or text from another writer) reads as far as it can
  /// and otherwise as 18:00, as [fromJson] does: it must never crash the
  /// guest's specials page.
  DateTime endsOn(DateTime day) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(endsAt.trim());
    final h = int.tryParse(m?.group(1) ?? '') ?? 18;
    final min = int.tryParse(m?.group(2) ?? '') ?? 0;
    return DateTime(
      day.year,
      day.month,
      day.day,
      h.clamp(0, 23),
      min.clamp(0, 59),
    );
  }

  Map<String, dynamic> toJson() => {'item_id': itemId, 'ends_at': endsAt};

  factory LimitedOffer.fromJson(Map<String, dynamic> j) => LimitedOffer(
    itemId: '${j['item_id']}',
    endsAt:
        j['ends_at'] is String &&
            RegExp(r'^\d{2}:\d{2}$').hasMatch(j['ends_at'] as String)
        ? j['ends_at'] as String
        : '18:00',
  );
}

/// A published, numbered storefront. Publishing freezes a copy; rolling back
/// publishes an earlier copy again as a new number, so history only grows.
class StorefrontVersion {
  const StorefrontVersion({
    required this.version,
    required this.definition,
    required this.publishedAt,
    this.publishedBy,
  });

  final int version;
  final StorefrontDefinition definition;
  final DateTime publishedAt;
  final String? publishedBy;
}

/// What Studio works with: the published storefront (what guests see now)
/// and this person's unpublished draft, if any.
class StorefrontState {
  const StorefrontState({
    this.draft,
    this.published,
    this.history = const [],
    this.note,
  });

  final StorefrontDefinition? draft;
  final StorefrontVersion? published;

  /// Newest first, the published one included.
  final List<StorefrontVersion> history;

  /// Shown in Studio when something limits saving (e.g. drafts are kept on
  /// this phone only).
  final String? note;

  bool get hasUnpublishedChanges => draft != null;

  StorefrontDefinition effective(Organization org) =>
      draft ?? published?.definition ?? StorefrontDefinition.starter(org);
}
