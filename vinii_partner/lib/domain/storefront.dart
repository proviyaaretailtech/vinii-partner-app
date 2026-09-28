import 'organization.dart';

/// The guest-facing storefront — the organization's own ordering website and
/// table app — described as data. Storefront Studio edits it; the guest
/// runtime renders it. Two restaurants look and behave differently because
/// their definitions differ, never because the code knows their names.
///
/// Stored as JSON (snake_case keys, `schema_version`). Readers ignore unknown
/// keys and fill missing ones with defaults, so an older app can read a newer
/// definition and the reverse.
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
    this.tableLabel = 'Table',
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
  };

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
          : 'Table',
    );
  }
}

List<Object?> _list(Object? v) => v is List ? v : const [];
Map<String, dynamic> _map(Object? v) => v is Map
    ? v.map((k, val) => MapEntry('$k', val))
    : const <String, dynamic>{};

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
  );

  const StorefrontTemplate({
    required this.key,
    required this.label,
    required this.description,
    required this.defaultAccent,
    required this.defaultTagline,
    required this.defaultHeroTitle,
    required this.defaultHeroSubtitle,
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

  static StorefrontTemplate? fromKey(String? k) =>
      values.where((t) => t.key == k).firstOrNull;
}

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

class StorefrontBrand {
  const StorefrontBrand({
    required this.displayName,
    this.tagline = '',
    this.locationLine = '',
    this.heroTitle = '',
    this.heroSubtitle = '',
    this.logoUrl,
    this.coverUrl,
  });

  final String displayName;
  final String tagline;

  /// "Indiranagar, Bengaluru" under the name on the welcome screen.
  final String locationLine;
  final String heroTitle;
  final String heroSubtitle;
  final String? logoUrl;
  final String? coverUrl;

  StorefrontBrand copyWith({
    String? displayName,
    String? tagline,
    String? locationLine,
    String? heroTitle,
    String? heroSubtitle,
    String? logoUrl,
    String? coverUrl,
  }) => StorefrontBrand(
    displayName: displayName ?? this.displayName,
    tagline: tagline ?? this.tagline,
    locationLine: locationLine ?? this.locationLine,
    heroTitle: heroTitle ?? this.heroTitle,
    heroSubtitle: heroSubtitle ?? this.heroSubtitle,
    logoUrl: logoUrl ?? this.logoUrl,
    coverUrl: coverUrl ?? this.coverUrl,
  );

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'tagline': tagline,
    'location_line': locationLine,
    'hero_title': heroTitle,
    'hero_subtitle': heroSubtitle,
    if (logoUrl != null) 'logo_url': logoUrl,
    if (coverUrl != null) 'cover_url': coverUrl,
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
      logoUrl: j['logo_url'] as String?,
      coverUrl: j['cover_url'] as String?,
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
const storefrontTags = [
  'Bestseller',
  'Spicy',
  "Chef's special",
  'Seasonal',
  'New',
  'Vegan',
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

  DateTime endsOn(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(endsAt.substring(0, 2)),
    int.parse(endsAt.substring(3)),
  );

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
