import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../application/studio_controller.dart';
import '../../../domain/menu.dart';
import '../../../domain/storefront.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/state_views.dart';

/// Food emoji a restaurant can put on a category tile.
const categoryEmoji = [
  '🍛', '🍲', '🍱', '🍚', '🥘', '🍕', '🍝', '🍜', '🥟', '🍔', //
  '🥪', '🌯', '🫓', '🍗', '🍖', '🐟', '🍤', '🥚', '🧀', '🥗',
  '🥣', '🍟', '🍞', '🥐', '🍰', '🍫', '🍨', '🍮', '☕', '🍵',
  '🥤', '🧃', '🍹', '🌶️', '🍳', '🥙',
];

/// Which menu categories guests see, in which order, with which emoji.
/// Categories themselves (names, dishes) are edited in the Menu tab; this
/// only decides how they appear on the storefront.
class CategoriesSection extends StatelessWidget {
  const CategoriesSection({super.key, required this.controller});
  final StudioController controller;

  /// Studio's chosen order first, then any category it has not placed yet,
  /// in menu order — the same rule the guest runtime follows.
  static List<MenuCategory> ordered(MenuSnapshot menu, StorefrontDefinition d) {
    final byId = {for (final c in menu.categories) c.id: c};
    final placed = [
      for (final p in d.categories)
        if (byId[p.categoryId] != null) byId[p.categoryId]!,
    ];
    final rest =
        menu.categories
            .where((c) => d.categoryPresentation(c.id) == null)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [...placed, ...rest];
  }

  void _write(
    List<MenuCategory> order, {
    String? id,
    bool? visible,
    String? emoji,
    bool clearEmoji = false,
  }) {
    controller.edit((d) {
      return d.copyWith(
        categories: [
          for (final c in order)
            () {
              final p =
                  d.categoryPresentation(c.id) ??
                  CategoryPresentation(categoryId: c.id);
              if (c.id != id) return p;
              return CategoryPresentation(
                categoryId: c.id,
                visible: visible ?? p.visible,
                emoji: clearEmoji ? null : (emoji ?? p.emoji),
              );
            }(),
        ],
      );
    });
  }

  Future<void> _pickEmoji(
    BuildContext context,
    List<MenuCategory> order,
    MenuCategory c,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Emoji for ${c.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final e in categoryEmoji)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, e),
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ''),
                icon: const Icon(Icons.block_rounded),
                label: const Text('No emoji'),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    _write(
      order,
      id: c.id,
      emoji: picked.isEmpty ? null : picked,
      clearEmoji: picked.isEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final menu = controller.menu;
    final d = controller.draft;
    if (menu.categories.isEmpty) {
      return EmptyView(
        icon: Icons.segment_rounded,
        title: 'No categories on your menu yet',
        message: 'Add categories and dishes in the Menu tab, then choose here how guests see them.',
        actionLabel: 'Open Menu',
        onAction: () => context.go(Routes.menu),
      );
    }
    final order = ordered(menu, d);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(
            'Drag to set the order guests see. Hidden categories stay on the POS and One Local.',
            style: text.bodyMedium,
          ),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) {
            final list = [...order];
            final moved = list.removeAt(from);
            list.insert(to, moved);
            _write(list);
          },
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
          children: [
            for (var i = 0; i < order.length; i++)
              Padding(
                key: ValueKey(order[i].id),
                padding: const EdgeInsets.only(bottom: 8),
                child: _CategoryRow(
                  index: i,
                  category: order[i],
                  presentation: d.categoryPresentation(order[i].id),
                  dishes: menu.itemsIn(order[i].id).length,
                  onEmoji: () => _pickEmoji(context, order, order[i]),
                  onVisible: (v) => _write(order, id: order[i].id, visible: v),
                  tokens: t,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.index,
    required this.category,
    required this.presentation,
    required this.dishes,
    required this.onEmoji,
    required this.onVisible,
    required this.tokens,
  });

  final int index;
  final MenuCategory category;
  final CategoryPresentation? presentation;
  final int dishes;
  final VoidCallback onEmoji;
  final ValueChanged<bool> onVisible;
  final ViniiTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final visible = presentation?.visible ?? true;
    final emoji = presentation?.emoji;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: t.inkMuted,
                  semanticLabel: 'Drag to reorder',
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Choose emoji',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onEmoji,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.border),
                  ),
                  child: emoji == null
                      ? Icon(
                          Icons.add_reaction_outlined,
                          color: t.inkMuted,
                          size: 22,
                        )
                      : Text(emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: visible ? t.ink : t.inkMuted,
                    ),
                  ),
                  Text(
                    [
                      dishes == 1 ? '1 dish' : '$dishes dishes',
                      if (!visible) 'hidden from guests',
                    ].join(' · '),
                    style: TextStyle(fontSize: 12.5, color: t.inkMuted),
                  ),
                ],
              ),
            ),
            Switch(value: visible, onChanged: onVisible),
          ],
        ),
      ),
    );
  }
}
