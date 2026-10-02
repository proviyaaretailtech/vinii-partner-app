import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/time_format.dart';
import '../../domain/guest_catalog.dart';
import '../theme/guest_theme.dart';
import '../widgets/food_art.dart';
import '../widgets/rings.dart';
import 'guest_categories.dart';
import 'guest_effects.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';

/// Board 2 #14 ("Chef's picks", "Limited today — ends in 04:18:24") and
/// Board 1 #14 ("Discover more" while waiting). Every section comes from the
/// catalog, which already honours the chefsPicks / limitedToday switches;
/// empty sections are left out.
class GuestDiscoverScreen extends StatelessWidget {
  const GuestDiscoverScreen({super.key, this.waiting = false});

  /// Opened from live tracking: "Keep exploring while we prepare…".
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final picks = s.catalog.chefsPicks;
    final limited = s.catalog.limitedToday;
    final shown = {...picks.map((i) => i.item.id)};
    final recommended = [
      for (final i in s.catalog.allItems)
        if (i.tags.contains('Bestseller') && !shown.contains(i.item.id)) i,
    ];
    return GuestPage(
      alerts: !waiting,
      alertsTop: 64,
      bottom: s.lines.isEmpty ? null : const CartBar(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GuestTopBar(title: waiting ? 'Discover more' : 'Specials'),
          if (waiting) const Center(child: PreviewBanner()),
          if (waiting)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Keep exploring while we prepare your order.',
                textAlign: TextAlign.center,
                style: p.body(14, color: p.inkMuted),
              ),
            ),
          if (picks.isNotEmpty) ...[
            const _Heading(title: "Chef's picks", subtitle: 'Curated for you'),
            _Row(items: picks, big: true),
          ],
          if (limited.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Limited today',
                      style: p.display(20, weight: FontWeight.w700),
                    ),
                  ),
                  Countdown(
                    deadline: limited.first.endsAt,
                    builder: (context, left) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: p.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'Ends in ${hms(left)}',
                        style: p.price(13, color: p.danger),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _Row(items: [for (final l in limited) l.item], big: false),
          ],
          if (recommended.isNotEmpty) ...[
            const _Heading(title: 'Recommended for you'),
            _Row(items: recommended, big: false),
          ],
          if (picks.isEmpty && limited.isEmpty && recommended.isEmpty) ...[
            const _Heading(title: 'From the menu'),
            const DiscoverStrip(),
          ],
        ],
      ),
    );
  }
}

/// A horizontal strip for the tracking screen: chef's picks, then
/// bestsellers, then the menu itself — always the restaurant's own dishes.
class DiscoverStrip extends StatelessWidget {
  const DiscoverStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = GuestScope.of(context);
    final seen = <String>{};
    final items = [
      for (final i in [
        ...s.catalog.chefsPicks,
        ...s.catalog.allItems.where((i) => i.tags.contains('Bestseller')),
        ...s.catalog.allItems,
      ])
        if (seen.add(i.item.id)) i,
    ].take(8).toList();
    return _Row(items: items, big: true);
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: p.display(20, weight: FontWeight.w700),
            ),
            if (subtitle != null)
              TextSpan(
                text: '  ·  $subtitle',
                style: p.body(13.5, color: p.inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.items, required this.big});
  final List<GuestItem> items;
  final bool big;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: big ? 270 : 200,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: items.length,
      separatorBuilder: (context, i) => const SizedBox(width: 14),
      itemBuilder: (context, i) =>
          _Card(item: items[i], width: big ? 210 : 150),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.item, required this.width});
  final GuestItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final i = item.item;
    final liked = s.liked.contains(i.id);
    final big = width > 180;
    return GestureDetector(
      onTap: () => GuestFlow.openItem(context, item),
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FoodArt(name: i.name, imageUrl: i.imageUrl, radius: 0),
              const PhotoScrim(strength: 0.9),
              if (s.features.likes)
                Positioned(
                  top: 8,
                  right: 8,
                  child: RoundIcon(
                    icon: liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 34,
                    color: liked ? p.danger : Colors.white,
                    background: Colors.black.withValues(alpha: 0.35),
                    tooltip: liked ? 'Saved for later' : 'Save for later',
                    onTap: () => s.toggleLike(i.id),
                  ),
                ),
              if (big && item.tags.isNotEmpty)
                Positioned(
                  top: 12,
                  left: 12,
                  child: TagChip(item.tags.first, onImage: true),
                ),
              Positioned(
                left: 14,
                right: 10,
                bottom: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: p.display(
                              big ? 18 : 15,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rupees(i.price),
                            style: p.price(big ? 17 : 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    RoundIcon(
                      icon: Icons.add_rounded,
                      size: 36,
                      tooltip: 'Add ${i.name}',
                      background: p.accent,
                      color: p.onAccent,
                      onTap: () => addWithHaptic(context, item),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
