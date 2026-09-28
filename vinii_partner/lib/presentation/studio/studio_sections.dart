import 'package:flutter/material.dart';

import '../../application/studio_controller.dart';
import '../../domain/storefront.dart';

/// The parts of Storefront Studio, in the order they are listed. The key is
/// the route segment (`/storefront/section/<key>`).
enum StudioSection {
  look('look', 'Template & colour', Icons.palette_outlined),
  brand('brand', 'Brand & welcome', Icons.waving_hand_outlined),
  service('service', 'How guests order', Icons.room_service_outlined),
  features('features', 'Guest features', Icons.tune_rounded),
  categories('categories', 'Menu on the storefront', Icons.grid_view_rounded),
  highlights(
    'highlights',
    "Chef's picks & offers",
    Icons.auto_awesome_outlined,
  ),
  share('share', 'Share & QR code', Icons.qr_code_2_rounded),
  history('history', 'Versions', Icons.history_rounded);

  const StudioSection(this.key, this.title, this.icon);
  final String key;
  final String title;
  final IconData icon;

  static StudioSection? fromKey(String? k) =>
      values.where((s) => s.key == k).firstOrNull;

  /// Sections that change the draft; the rest only read it.
  bool get edits => this != share && this != history;

  /// One line under the title in Studio's list: the current value, so a
  /// person can see the state of their storefront without opening each part.
  String summary(StudioController c, {required String address}) {
    final d = c.draft;
    switch (this) {
      case look:
        return '${d.template.label} · ${d.accentHex.toUpperCase()} · '
            '${d.categoryStyle.label}';
      case brand:
        final name = d.brand.displayName.trim();
        final headline = d.brand.heroTitle.trim();
        return [
          name.isEmpty ? 'No name yet' : name,
          headline.isEmpty ? 'no welcome headline yet' : '"$headline"',
        ].join(' · ');
      case service:
        final modes = d.serviceModes.map((m) => m.label).join(', ');
        return modes.isEmpty ? 'Nothing switched on' : modes;
      case features:
        final on = featureFlags(d.features).where((f) => f).length;
        return '$on of ${featureFlags(d.features).length} on · '
            '${d.features.swipeDeck ? 'swipe cards' : 'scrolling list'}';
      case categories:
        final cats = c.menu.categories;
        if (cats.isEmpty) return 'No categories on your menu yet';
        final shown = cats
            .where((m) => d.categoryPresentation(m.id)?.visible ?? true)
            .length;
        return '$shown of ${cats.length} categories shown';
      case highlights:
        final picks = d.chefsPicks.length;
        final offers = d.limitedToday.length;
        if (picks == 0 && offers == 0) return 'None chosen yet';
        return "$picks chef's ${picks == 1 ? 'pick' : 'picks'} · "
            '$offers limited today';
      case share:
        return address.replaceFirst(RegExp(r'^https?://'), '');
      case history:
        final s = c.state;
        final live = s?.published;
        final count = s?.history.length ?? 0;
        if (live == null) return 'Nothing published yet';
        return 'Version ${live.version} is live · $count '
            '${count == 1 ? 'version' : 'versions'} kept';
    }
  }
}

/// Every on/off switch of [GuestFeatures], for counting.
List<bool> featureFlags(GuestFeatures f) => [
  f.swipeDeck,
  f.budget.enabled,
  f.splitParty,
  f.likes,
  f.chefsPicks,
  f.limitedToday,
  f.discoverWhileWaiting,
  f.liveTracking,
  f.splitBill,
  f.feedback,
  f.showIngredients,
  f.showAllergens,
  f.showNutrition,
];

/// Where guests find the storefront. Works once the guest website is
/// deployed at that address.
String storefrontAddress(String baseUrl, String slug) {
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  return '$base/s/$slug';
}
