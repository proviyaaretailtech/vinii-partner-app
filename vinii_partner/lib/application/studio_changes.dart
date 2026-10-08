import 'dart:convert';

import '../core/json.dart';
import '../domain/storefront.dart';

/// What kind of difference between the live storefront and the draft one
/// line of the publish confirmation describes. The screen turns each into
/// a sentence in the reader's language (see `studio_screen.dart`).
enum StorefrontChangeKind {
  firstPublish,
  template,
  accent,
  theme,
  categoryStyle,
  name,
  tagline,
  locationLine,
  heroTitle,
  heroSubtitle,
  logo,
  pictures,
  guestText,
  guestLanguage,
  serviceModes,
  tableLabel,
  preOrder,
  features,
  categories,
  itemDetails,
  chefsPicks,
  limitedToday,
}

/// One real difference between the live storefront and the draft: a
/// [kind] and the values the sentence needs.
///
/// * [StorefrontChangeKind.template]: [from] and [to] are
///   [StorefrontTemplate]s.
/// * [StorefrontChangeKind.accent]: [from] and [to] are upper-case `#RRGGBB`
///   strings.
/// * [StorefrontChangeKind.categoryStyle]: [from] and [to] are
///   [CategoryStyle]s.
/// * [StorefrontChangeKind.name] and [StorefrontChangeKind.tableLabel]: [to]
///   is what the restaurant typed.
/// * [StorefrontChangeKind.guestLanguage]: [to] is a [CopyLanguage].
/// * [StorefrontChangeKind.serviceModes]: [to] is a `List<GuestServiceMode>`.
/// * [StorefrontChangeKind.itemDetails]: [count] is how many dishes changed.
class StorefrontChange {
  const StorefrontChange(this.kind, {this.from, this.to, this.count = 0});

  final StorefrontChangeKind kind;
  final Object? from;
  final Object? to;
  final int count;

  /// The line in English, for tests and logs. What a person reads comes from
  /// the translated sentence the screen builds from [kind] and the values.
  // i18n-ignore: English for tests
  String get english => switch (kind) {
    StorefrontChangeKind.firstPublish =>
      'Your storefront goes live for the first time.',
    StorefrontChangeKind.template =>
      'Template: ${(from as StorefrontTemplate).label} → ${(to as StorefrontTemplate).label}',
    StorefrontChangeKind.accent => 'Accent colour: $from → $to',
    StorefrontChangeKind.theme => 'Colours, buttons and fonts',
    StorefrontChangeKind.categoryStyle =>
      'Category style: ${(from as CategoryStyle).label} → ${(to as CategoryStyle).label}',
    StorefrontChangeKind.name => 'Name: $to',
    StorefrontChangeKind.tagline => 'Tagline',
    StorefrontChangeKind.locationLine => 'Location line',
    StorefrontChangeKind.heroTitle => 'Welcome headline',
    StorefrontChangeKind.heroSubtitle => 'Welcome text',
    StorefrontChangeKind.logo => 'Logo',
    StorefrontChangeKind.pictures => 'Pictures',
    StorefrontChangeKind.guestText => 'Guest text',
    StorefrontChangeKind.guestLanguage =>
      'Guests start in ${(to as CopyLanguage).label}',
    StorefrontChangeKind.serviceModes =>
      'Ways to order: ${(to as List<GuestServiceMode>).map((m) => m.label).join(', ')}',
    StorefrontChangeKind.tableLabel => 'Table label: "$to"',
    StorefrontChangeKind.preOrder => 'Pre-order times',
    StorefrontChangeKind.features => 'Guest features',
    StorefrontChangeKind.categories => 'Categories shown to guests',
    StorefrontChangeKind.itemDetails =>
      count == 1
          ? 'Storefront details of 1 dish'
          : 'Storefront details of $count dishes',
    StorefrontChangeKind.chefsPicks => "Chef's picks",
    StorefrontChangeKind.limitedToday => 'Limited today offers',
  };
}

/// What guests will see change if [next] is published over [live], as typed
/// records for the publish confirmation. Pure, so it is easy to test and
/// never guesses: each entry comes from a real difference.
List<StorefrontChange> storefrontChanges(
  StorefrontDefinition? live,
  StorefrontDefinition next,
) {
  if (live == null) {
    return const [StorefrontChange(StorefrontChangeKind.firstPublish)];
  }
  String j(Object? v) => jsonEncode(v);
  final a = live.brand, b = next.brand;
  final itemChanges = {
    ...live.items.keys,
    ...next.items.keys,
  }.where((id) => j(live.items[id]?.toJson()) != j(next.items[id]?.toJson()));
  return [
    if (live.template != next.template)
      StorefrontChange(
        StorefrontChangeKind.template,
        from: live.template,
        to: next.template,
      ),
    if (live.accentHex.toUpperCase() != next.accentHex.toUpperCase())
      StorefrontChange(
        StorefrontChangeKind.accent,
        from: live.accentHex.toUpperCase(),
        to: next.accentHex.toUpperCase(),
      ),
    if (!jsonEquals(live.theme.toJson(), next.theme.toJson()))
      const StorefrontChange(StorefrontChangeKind.theme),
    if (live.categoryStyle != next.categoryStyle)
      StorefrontChange(
        StorefrontChangeKind.categoryStyle,
        from: live.categoryStyle,
        to: next.categoryStyle,
      ),
    if (a.displayName != b.displayName)
      StorefrontChange(StorefrontChangeKind.name, to: b.displayName),
    if (a.tagline != b.tagline)
      const StorefrontChange(StorefrontChangeKind.tagline),
    if (a.locationLine != b.locationLine)
      const StorefrontChange(StorefrontChangeKind.locationLine),
    if (a.heroTitle != b.heroTitle)
      const StorefrontChange(StorefrontChangeKind.heroTitle),
    if (a.heroSubtitle != b.heroSubtitle)
      const StorefrontChange(StorefrontChangeKind.heroSubtitle),
    if (a.logoUrl != b.logoUrl)
      const StorefrontChange(StorefrontChangeKind.logo),
    if (a.coverUrl != b.coverUrl ||
        !jsonEquals(live.media.toJson(), next.media.toJson()))
      const StorefrontChange(StorefrontChangeKind.pictures),
    if (!jsonEquals(live.copy.toJson(), next.copy.toJson()))
      const StorefrontChange(StorefrontChangeKind.guestText),
    if (live.guestLanguage != next.guestLanguage)
      StorefrontChange(
        StorefrontChangeKind.guestLanguage,
        to: next.guestLanguage,
      ),
    if (j([for (final m in live.serviceModes) m.key]) !=
        j([for (final m in next.serviceModes) m.key]))
      StorefrontChange(
        StorefrontChangeKind.serviceModes,
        to: List<GuestServiceMode>.of(next.serviceModes),
      ),
    if (live.tableLabel != next.tableLabel)
      StorefrontChange(StorefrontChangeKind.tableLabel, to: next.tableLabel),
    if (j(live.preOrder.toJson()) != j(next.preOrder.toJson()))
      const StorefrontChange(StorefrontChangeKind.preOrder),
    if (j(live.features.toJson()) != j(next.features.toJson()))
      const StorefrontChange(StorefrontChangeKind.features),
    if (j([for (final c in live.categories) c.toJson()]) !=
        j([for (final c in next.categories) c.toJson()]))
      const StorefrontChange(StorefrontChangeKind.categories),
    if (itemChanges.isNotEmpty)
      StorefrontChange(
        StorefrontChangeKind.itemDetails,
        count: itemChanges.length,
      ),
    if (j(live.chefsPicks) != j(next.chefsPicks))
      const StorefrontChange(StorefrontChangeKind.chefsPicks),
    if (j([for (final l in live.limitedToday) l.toJson()]) !=
        j([for (final l in next.limitedToday) l.toJson()]))
      const StorefrontChange(StorefrontChangeKind.limitedToday),
  ];
}

/// [storefrontChanges] in English, one line each. Kept for tests; the
/// publish confirmation renders [storefrontChanges] in the reader's language.
// i18n-ignore: English for tests
List<String> describeStorefrontChanges(
  StorefrontDefinition? live,
  StorefrontDefinition next,
) => [for (final c in storefrontChanges(live, next)) c.english];
