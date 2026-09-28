import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/guest_catalog.dart';
import '../../domain/menu.dart';
import '../theme/guest_theme.dart';
import '../widgets/food_art.dart';
import 'guest_effects.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';

/// Board 1 #6 / Board 2 #5: the immersive dish page. Ingredients, allergens
/// and nutrition appear only when the storefront shows them AND the merchant
/// wrote them — nothing is guessed.
class GuestItemDetailScreen extends StatefulWidget {
  const GuestItemDetailScreen({super.key, required this.item});
  final GuestItem item;

  @override
  State<GuestItemDetailScreen> createState() => _GuestItemDetailScreenState();
}

class _GuestItemDetailScreenState extends State<GuestItemDetailScreen> {
  int _qty = 1;

  void _add() {
    final item = widget.item;
    addWithHaptic(context, item, qty: _qty);
    final nav = Navigator.of(context);
    nav.pop();
    showAddedSheet(nav.context, item);
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final f = s.features;
    final item = widget.item;
    final i = item.item;
    final pres = item.presentation;
    final liked = s.liked.contains(i.id);
    final pills = [
      ...item.tags,
      if (i.foodType == FoodType.veg && !item.tags.contains('Vegetarian'))
        'Vegetarian',
    ];
    final height = MediaQuery.sizeOf(context).height;
    return GuestPage(
      safeTop: false,
      bottom: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -250) _add();
        },
        child: Row(
          children: [
            QtyStepper(
              qty: _qty,
              min: 1,
              onChanged: (v) => setState(() => _qty = v),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GuestButton(
                key: const ValueKey('detail-add'),
                label: 'Add to order · ${rupees(i.price * _qty)}',
                icon: Icons.keyboard_arrow_up_rounded,
                style: p.isDark
                    ? GuestButtonStyle.success
                    : GuestButtonStyle.primary,
                onTap: _add,
              ),
            ),
          ],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: (height * 0.46).clamp(260, 460),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FoodArt(name: i.name, imageUrl: i.imageUrl, radius: 0),
                  const PhotoScrim(strength: 0.35, top: true),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        RoundIcon(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          color: Colors.white,
                          background: Colors.black.withValues(alpha: 0.4),
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        if (f.likes)
                          RoundIcon(
                            icon: liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            tooltip: liked
                                ? 'Saved for later'
                                : 'Save for later',
                            color: liked ? p.danger : Colors.white,
                            background: Colors.black.withValues(alpha: 0.4),
                            onTap: () => s.toggleLike(i.id),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: BoxDecoration(
                  color: p.background,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(i.name, style: p.display(28))),
                        const SizedBox(width: 12),
                        Text(
                          rupees(i.price),
                          style: p.price(
                            26,
                            color: p.isDark ? p.accent : p.ink,
                          ),
                        ),
                      ],
                    ),
                    if ((i.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        i.description!,
                        style: p.body(15, color: p.inkMuted),
                      ),
                    ],
                    if (pills.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final t in pills) TagChip(t)],
                      ),
                    ],
                    if (f.showIngredients && pres.ingredients.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Ingredients',
                        style: p.display(18, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 88,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final g in pres.ingredients) _Ingredient(g),
                          ],
                        ),
                      ),
                    ],
                    if (f.showAllergens && pres.allergens.isNotEmpty)
                      _Accordion(
                        title: 'Allergen information',
                        child: Text(
                          'Contains: ${pres.allergens.join(', ')}',
                          style: p.body(14, color: p.inkMuted),
                        ),
                      ),
                    if (f.showNutrition && pres.kcal != null)
                      _Accordion(
                        title: 'Nutritional info',
                        child: Text(
                          '${pres.kcal} kcal per serving',
                          style: p.body(14, color: p.inkMuted),
                        ),
                      ),
                    if (i.prepMinutes != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: p.inkMuted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'About ${i.prepMinutes} min to prepare',
                              style: p.body(13, color: p.inkMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ingredient extends StatelessWidget {
  const _Ingredient(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final emoji = FoodArt.emojiFor(name);
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: p.border),
            ),
            child: Text(
              emoji == '🍽️' ? name.characters.first.toUpperCase() : emoji,
              style: emoji == '🍽️'
                  ? p.display(20, color: p.inkMuted)
                  : const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: p.body(11.5, color: p.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Accordion extends StatefulWidget {
  const _Accordion({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GuestCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        onTap: () => setState(() => _open = !_open),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: p.body(15, weight: FontWeight.w700),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 240),
                    child: Icon(Icons.expand_more_rounded, color: p.inkMuted),
                  ),
                ],
              ),
              if (_open) ...[const SizedBox(height: 10), widget.child],
            ],
          ),
        ),
      ),
    );
  }
}

/// Board 1 #7: "Added to your order!" with the dish and two ways on.
/// [navContext] is the runtime navigator's own context, so the sheet works
/// after the detail page has already closed.
void showAddedSheet(BuildContext navContext, GuestItem item) {
  showModalBottomSheet<void>(
    context: navContext,
    isScrollControlled: true,
    builder: (context) {
      final p = GuestPalette.of(context);
      final s = GuestScope.of(context);
      final i = item.item;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SuccessCheck(size: 72),
              const SizedBox(height: 16),
              Text('Added to your order!', style: p.display(24)),
              const SizedBox(height: 16),
              GuestCard(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 56,
                      child: FoodArt(
                        name: i.name,
                        imageUrl: i.imageUrl,
                        radius: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        i.name,
                        maxLines: 2,
                        style: p.body(15, weight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '×${s.qtyOf(i.id)}  ${rupees(i.price * s.qtyOf(i.id))}',
                      style: p.price(15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GuestButton(
                      label: 'View order (${s.itemCount})',
                      style: GuestButtonStyle.outline,
                      dense: true,
                      onTap: () {
                        Navigator.of(context).pop();
                        GuestFlow.toOrder(navContext);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GuestButton(
                      label: 'Keep exploring',
                      dense: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
