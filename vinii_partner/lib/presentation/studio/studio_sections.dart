import 'package:flutter/material.dart';

import '../../application/studio_controller.dart';
import '../../domain/storefront.dart';
import '../../l10n/l10n.dart';

/// The parts of Storefront Studio, in the order they are listed. The key is
/// the route segment (`/storefront/section/<key>`).
enum StudioSection {
  // i18n-ignore: English titles for tests; screens use studioSectionTitle
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

  /// The English title: tests and logs only. Screens show
  /// [StudioLabels.studioSectionTitle].
  // i18n-ignore: English fallback for logs/tests
  final String title;
  final IconData icon;

  static StudioSection? fromKey(String? k) =>
      values.where((s) => s.key == k).firstOrNull;

  /// Sections that change the draft; the rest only read it.
  bool get edits => this != share && this != history;

  /// One line under the title in Studio's list: the current value, so a
  /// person can see the state of their storefront without opening each part.
  String summary(
    AppLocalizations l,
    StudioController c, {
    required String address,
  }) {
    final d = c.draft;
    switch (this) {
      case look:
        return l.studioSummaryLook(
          // i18n-ignore: template name
          template: d.template.label,
          accent: d.accentHex.toUpperCase(),
          style: l.studioStyleName(d.categoryStyle),
        );
      case brand:
        final name = d.brand.displayName.trim();
        final headline = d.brand.heroTitle.trim();
        return [
          name.isEmpty ? l.studioSummaryNoName : name,
          headline.isEmpty ? l.studioSummaryNoHeadline : '"$headline"',
        ].join(' · ');
      case service:
        final modes = d.serviceModes.map(l.studioModeName).join(', ');
        return modes.isEmpty ? l.studioSummaryNothingOn : modes;
      case features:
        final flags = featureFlags(d.features);
        return l.studioSummaryFeatures(
          on: flags.where((f) => f).length,
          total: flags.length,
          style: d.features.swipeDeck
              ? l.studioSummaryDeckSwipe
              : l.studioSummaryDeckList,
        );
      case categories:
        final cats = c.menu.categories;
        if (cats.isEmpty) return l.studioCatsNone;
        final shown = cats
            .where((m) => d.categoryPresentation(m.id)?.visible ?? true)
            .length;
        return l.studioSummaryCategoriesShown(shown: shown, total: cats.length);
      case highlights:
        final picks = d.chefsPicks.length;
        final offers = d.limitedToday.length;
        if (picks == 0 && offers == 0) return l.studioSummaryHighlightsNone;
        return l.studioSummaryHighlights(picks: picks, offers: offers);
      case share:
        return address.replaceFirst(RegExp(r'^https?://'), '');
      case history:
        final s = c.state;
        final live = s?.published;
        if (live == null) return l.studioNothingPublished;
        return l.studioSummaryHistory(
          live: live.version,
          count: s?.history.length ?? 0,
        );
    }
  }
}

/// Words for the codes and enums Studio shows: sections, ways to order,
/// category styles, templates and button shapes. One place, with exhaustive
/// switches, so a new value is a compile error until it has every language.
extension StudioLabels on AppLocalizations {
  String studioSectionTitle(StudioSection s) => switch (s) {
    StudioSection.look => studioSectionLook,
    StudioSection.brand => studioSectionBrand,
    StudioSection.service => studioSectionService,
    StudioSection.features => studioSectionFeatures,
    StudioSection.categories => studioSectionCategories,
    StudioSection.highlights => studioSectionHighlights,
    StudioSection.share => studioSectionShare,
    StudioSection.history => studioSectionHistory,
  };

  /// A way to order, as the owner sees it in Studio. Dine-in, takeaway and
  /// delivery share the words the POS uses.
  String studioModeName(GuestServiceMode m) => switch (m) {
    GuestServiceMode.dineIn => serviceDineIn,
    GuestServiceMode.takeaway => serviceTakeaway,
    GuestServiceMode.preOrder => studioModePreOrder,
    GuestServiceMode.delivery => serviceDelivery,
  };

  String studioStyleName(CategoryStyle s) => switch (s) {
    CategoryStyle.grid => studioStyleTiles,
    CategoryStyle.wheel => studioStyleWheel,
  };

  String studioStyleHint(CategoryStyle s) => switch (s) {
    CategoryStyle.grid => studioStyleTilesHint,
    CategoryStyle.wheel => studioStyleWheelHint,
  };

  /// The one-line description of a template (its name stays as it is: it is
  /// the template's own name, the same one the web CMS shows).
  String studioTemplateBlurb(StorefrontTemplate t) => switch (t) {
    StorefrontTemplate.bistroNight => studioTemplateBistroNight,
    StorefrontTemplate.artisanDay => studioTemplateArtisanDay,
    StorefrontTemplate.freshMinimal => studioTemplateFreshMinimal,
  };

  /// The adjective that goes in front of "buttons".
  String studioShapeName(StorefrontButtonShape s) => switch (s) {
    StorefrontButtonShape.pill => studioShapePill,
    StorefrontButtonShape.rounded => studioShapeRounded,
    StorefrontButtonShape.square => studioShapeSquare,
  };
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
