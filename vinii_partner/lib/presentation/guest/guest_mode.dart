import 'package:flutter/material.dart';

import '../../domain/storefront.dart';
import '../../l10n/l10n.dart';
import '../theme/guest_theme.dart';
import '../widgets/food_art.dart';
import 'guest_effects.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';
import 'look/look.dart';
import 'look/motion.dart';

/// Board 2 #3: "How would you like to enjoy …?" — one tall photo card per
/// enabled service mode, in the storefront's order. Photos are the
/// restaurant's own dishes (or the illustrated fallback), never stock art.
class GuestModeScreen extends StatelessWidget {
  const GuestModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final l = context.l10n;
    final modes = s.definition.serviceModes;
    final photos = [
      for (final i in s.catalog.allItems)
        if (i.item.imageUrl != null) i,
    ];
    final all = s.catalog.allItems;
    return GuestPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GuestTopBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Text(
              l.guestModeTitle(name: s.definition.brand.displayName),
              style: p.display(28),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: modes.length,
              separatorBuilder: (context, i) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final pool = photos.isNotEmpty ? photos : all;
                final art = pool.isEmpty ? null : pool[i % pool.length];
                return Reveal(
                  index: i,
                  dy: 26,
                  child: Pressable(
                    hoverScale: 1.015,
                    child: _ModeCard(
                      mode: modes[i],
                      // i18n-ignore: picks the illustration, never shown
                      name: art?.item.name ?? modes[i].label,
                      imageUrl: art?.item.imageUrl,
                      height: modes.length > 2 ? 170 : 230,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.name,
    required this.imageUrl,
    required this.height,
  });

  final GuestServiceMode mode;
  final String name;
  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.read(context);
    final l = context.l10n;
    final table = l.guestTableNameOf(s);
    final subtitle = switch (mode) {
      GuestServiceMode.dineIn when table != null => l.guestModeDineInAt(
        table: table,
      ),
      _ => l.guestModeHint(mode),
    };
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: p.lift(0.7),
        ),
        position: DecorationPosition.background,
        child: Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          child: InkWell(
            onTap: () {
              s.update(() => s.mode = mode);
              GuestFlow.afterMode(context);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                FoodArt(name: name, imageUrl: imageUrl, radius: 0),
                const PhotoScrim(strength: 0.8),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.guestModeLabel(mode),
                              style: p.display(26, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: p.body(
                                14,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: p.onAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
