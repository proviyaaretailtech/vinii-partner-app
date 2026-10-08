import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/guest_catalog.dart';
import '../../domain/menu.dart';
import '../../l10n/l10n.dart';
import '../menu/menu_labels.dart';
import '../theme/guest_theme.dart';
import '../widgets/food_art.dart';
import 'guest_effects.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';
import 'look/look.dart';
import 'look/motion.dart';

/// Board 1 #6 / Board 2 #5: the immersive dish page. Ingredients, allergens
/// and nutrition appear only when the storefront shows them AND the merchant
/// wrote them — nothing is guessed.
class GuestItemDetailScreen extends StatefulWidget {
  const GuestItemDetailScreen({super.key, required this.item});
  final GuestItem item;

  @override
  State<GuestItemDetailScreen> createState() => _GuestItemDetailScreenState();
}

/// How round the top of the sheet is where it rises over the picture.
const _sheetRadius = 28.0;

class _GuestItemDetailScreenState extends State<GuestItemDetailScreen> {
  int _qty = 1;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
    final l = context.l10n;
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
    // The sheet the words sit on: lit a little on a dark page so it rises off
    // the picture instead of being a flat black slab.
    final sheet = p.isDark ? p.surfaceLit : p.background;
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
                label: l.guestItemAddToOrder(price: rupees(i.price * _qty)),
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
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: (height * 0.46).clamp(260, 460).roundToDouble(),
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The picture drifts slower than the page and swells when
                    // pulled down: it feels set behind the sheet, not on it.
                    AnimatedBuilder(
                      animation: _scroll,
                      builder: (context, child) {
                        final off = _scroll.hasClients ? _scroll.offset : 0.0;
                        return Transform.translate(
                          offset: Offset(0, off > 0 ? off * 0.42 : 0),
                          child: Transform.scale(
                            scale: 1 + (off < 0 ? -off / 700 : 0),
                            child: child,
                          ),
                        );
                      },
                      child: Hero(
                        tag: 'dish-${i.id}',
                        child: FoodArt(
                          name: i.name,
                          imageUrl: i.imageUrl,
                          radius: 0,
                        ),
                      ),
                    ),
                    // Only enough behind the two buttons to keep them legible; a
                    // light page wants far less than a dark one.
                    PhotoScrim(
                      strength: 0,
                      top: true,
                      topStrength: p.isDark ? 0.45 : 0.14,
                    ),
                    Positioned(
                      top: MediaQuery.paddingOf(context).top + 8,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          RoundIcon(
                            icon: Icons.close_rounded,
                            tooltip: l.commonClose,
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
                              tooltip: liked ? l.guestDishSaved : l.guestDishSave,
                              color: liked ? p.danger : Colors.white,
                              background: Colors.black.withValues(alpha: 0.4),
                              onTap: () => s.toggleLike(i.id),
                            ),
                        ],
                      ),
                    ),
                    // The rounded top of the sheet that carries the words. It is
                    // drawn here, on the picture's own sliver, because a
                    // viewport paints the first sliver over the ones after it.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _sheetRadius,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: sheet,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(_sheetRadius),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // One sliver for the whole sheet, so it always reaches the bottom
          // bar, whatever the length of the words, with no seam between a
          // sheet and a filler.
          SliverFillRemaining(
            hasScrollBody: false,
            child: ColoredBox(
              color: sheet,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Reveal(
                      delay: const Duration(milliseconds: 120),
                      child: Row(
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
                    ),
                    if ((i.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Reveal(
                        delay: const Duration(milliseconds: 120),
                        index: 1,
                        child: Text(
                          i.description!,
                          style: p.body(15, color: p.inkMuted),
                        ),
                      ),
                    ],
                    if (pills.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Reveal(
                        delay: const Duration(milliseconds: 120),
                        index: 2,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [for (final t in pills) TagChip(t)],
                        ),
                      ),
                    ],
                    if (f.showIngredients && pres.ingredients.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        l.guestItemIngredients,
                        style: p.display(18, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (n, g) in pres.ingredients.indexed)
                            Reveal(
                              delay: const Duration(milliseconds: 260),
                              index: n,
                              dy: 0,
                              dx: 12,
                              child: _Ingredient(g),
                            ),
                        ],
                      ),
                    ],
                    if (f.showAllergens && pres.allergens.isNotEmpty)
                      _Accordion(
                        title: l.guestItemAllergens,
                        child: Text(
                          l.guestItemContains(
                            list: pres.allergens.map(l.allergenLabel).join(', '),
                          ),
                          style: p.body(14, color: p.inkMuted),
                        ),
                      ),
                    if (f.showNutrition && pres.kcal != null)
                      _Accordion(
                        title: l.guestItemNutrition,
                        child: Text(
                          l.guestItemKcal(kcal: pres.kcal!),
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
                              l.guestItemPrep(minutes: i.prepMinutes!),
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

/// One ingredient as a plain labelled chip, tinted a food-toned hue that
/// stays the same for the same name. Words, not stand-in pictures.
class _Ingredient extends StatelessWidget {
  const _Ingredient(this.name);
  final String name;

  Color _tone() {
    const hues = [8.0, 24.0, 38.0, 52.0, 96.0, 128.0, 16.0, 350.0];
    final h =
        hues[name.toLowerCase().codeUnits.fold<int>(0, (a, c) => a + c) %
            hues.length];
    return HSLColor.fromAHSL(1, h, 0.62, 0.5).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final tone = _tone();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: p.isDark ? 0.16 : 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(name, style: p.body(13.5, weight: FontWeight.w600)),
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
      final l = context.l10n;
      final i = item.item;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SuccessCheck(size: 72),
              const SizedBox(height: 16),
              Text(
                l.guestItemAddedTitle,
                textAlign: TextAlign.center,
                style: p.display(24),
              ),
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
                      label: l.guestCartBarLabel(
                        label: l.guestCartView,
                        count: s.itemCount,
                      ),
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
                      label: l.guestItemKeepExploring,
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
