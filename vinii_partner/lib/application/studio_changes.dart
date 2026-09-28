import 'dart:convert';

import '../domain/storefront.dart';

/// What guests will see change if [next] is published over [live], in
/// plain words for the publish confirmation. Pure, so it is easy to test
/// and never guesses: each line comes from a real difference.
List<String> describeStorefrontChanges(
  StorefrontDefinition? live,
  StorefrontDefinition next,
) {
  if (live == null) {
    return const ['Your storefront goes live for the first time.'];
  }
  String j(Object? v) => jsonEncode(v);
  final a = live.brand, b = next.brand;
  final itemChanges = {
    ...live.items.keys,
    ...next.items.keys,
  }.where((id) => j(live.items[id]?.toJson()) != j(next.items[id]?.toJson()));
  return [
    if (live.template != next.template)
      'Template: ${live.template.label} → ${next.template.label}',
    if (live.accentHex.toUpperCase() != next.accentHex.toUpperCase())
      'Accent colour: ${live.accentHex.toUpperCase()} → ${next.accentHex.toUpperCase()}',
    if (live.categoryStyle != next.categoryStyle)
      'Category style: ${live.categoryStyle.label} → ${next.categoryStyle.label}',
    if (a.displayName != b.displayName) 'Name: ${b.displayName}',
    if (a.tagline != b.tagline) 'Tagline',
    if (a.locationLine != b.locationLine) 'Location line',
    if (a.heroTitle != b.heroTitle) 'Welcome headline',
    if (a.heroSubtitle != b.heroSubtitle) 'Welcome text',
    if (j([for (final m in live.serviceModes) m.key]) !=
        j([for (final m in next.serviceModes) m.key]))
      'Ways to order: ${next.serviceModes.map((m) => m.label).join(', ')}',
    if (live.tableLabel != next.tableLabel) 'Table label: "${next.tableLabel}"',
    if (j(live.preOrder.toJson()) != j(next.preOrder.toJson()))
      'Pre-order times',
    if (j(live.features.toJson()) != j(next.features.toJson()))
      'Guest features',
    if (j([for (final c in live.categories) c.toJson()]) !=
        j([for (final c in next.categories) c.toJson()]))
      'Categories shown to guests',
    if (itemChanges.isNotEmpty)
      itemChanges.length == 1
          ? 'Storefront details of 1 dish'
          : 'Storefront details of ${itemChanges.length} dishes',
    if (j(live.chefsPicks) != j(next.chefsPicks)) "Chef's picks",
    if (j([for (final l in live.limitedToday) l.toJson()]) !=
        j([for (final l in next.limitedToday) l.toJson()]))
      'Limited today offers',
  ];
}
