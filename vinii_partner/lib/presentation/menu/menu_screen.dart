import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../application/menu_editor.dart';
import '../../core/money.dart';
import '../../domain/menu.dart';
import '../../domain/staff.dart';
import '../../l10n/failure_text.dart';
import '../../l10n/l10n.dart';
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/food_art.dart';
import '../widgets/state_views.dart';
import 'menu_scope.dart';
import 'panel.dart';

/// The Menu tab: the POS Item Master as the restaurant sees it — every
/// category in menu order, each dish with its price and a sold-out switch.
///
/// Everyone who may see the menu can browse it; only editors get the add
/// buttons, and the availability switch follows its own capability, because
/// the person marking a dish sold out mid-service is often not the one who
/// sets prices.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late final MenuEditorController _c = menuEditorOf(context);
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.ensureLoaded();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _can(Capability c) => AppScope.of(context).session.can(c);

  void _openItem(MenuItem item) => context.push(Routes.menuItem(item.id));

  void _newItem({String? categoryId}) => context.push(
    Uri(
      path: Routes.menuNewItem,
      queryParameters: categoryId == null ? null : {'category': categoryId},
    ).toString(),
  );

  Future<void> _toggle(MenuItem item, bool available) async {
    try {
      await _c.setAvailable(item, available);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _can(Capability.editMenu);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final l = context.l10n;
        final menu = _c.menu;
        final isEmpty =
            menu != null && menu.categories.isEmpty && menu.items.isEmpty;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.commonMenu),
            actions: [
              if (menu != null)
                TextButton.icon(
                  onPressed: () => context.push(Routes.menuCategories),
                  icon: const Icon(Icons.segment_rounded, size: 20),
                  label: Text(l.menuCategories),
                ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: canEdit && menu != null && !isEmpty
              ? FloatingActionButton.extended(
                  onPressed: _newItem,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.menuAddItem),
                )
              : null,
          body: _body(menu, isEmpty: isEmpty, canEdit: canEdit),
        );
      },
    );
  }

  Widget _body(
    MenuSnapshot? menu, {
    required bool isEmpty,
    required bool canEdit,
  }) {
    if (menu == null) {
      if (_c.failure != null && !_c.loading) {
        return FailureView(failure: _c.failure!, onRetry: _c.load);
      }
      return LoadingView(label: context.l10n.menuLoading);
    }
    if (isEmpty) {
      return RefreshIndicator(
        onRefresh: _c.load,
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: _EmptyMenu(
                canEdit: canEdit,
                onAddCategory: () => context.push(Routes.menuCategories),
                onAddDish: _newItem,
              ),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _c.load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _header(menu)),
          ..._sections(menu, canEdit: canEdit),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  Widget _header(MenuSnapshot menu) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final soldOut = menu.items.where((i) => !i.isAvailable).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.menuSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l.menuSearchClear,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Stretch so the three boxes stay one height when a longer
          // translation wraps in one of them.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stat(label: l.menuStatDishes, value: '${menu.items.length}'),
                const SizedBox(width: 8),
                _Stat(
                  label: l.menuCategories,
                  value: '${menu.categories.length}',
                ),
                const SizedBox(width: 8),
                _Stat(
                  label: l.menuSoldOut,
                  value: '$soldOut',
                  color: soldOut > 0 ? t.danger : null,
                ),
              ],
            ),
          ),
          if (_c.failure != null) ...[
            const SizedBox(height: 12),
            NoticeBanner(
              icon: Icons.sync_problem_rounded,
              tone: t.warning,
              message: l.menuRefreshFailed(reason: failureText(l, _c.failure!)),
            ),
          ],
        ],
      ),
    );
  }

  bool _matches(MenuItem i) =>
      _query.isEmpty ||
      i.name.toLowerCase().contains(_query) ||
      (i.description?.toLowerCase().contains(_query) ?? false);

  List<Widget> _sections(MenuSnapshot menu, {required bool canEdit}) {
    final l = context.l10n;
    final canToggle = _can(Capability.toggleAvailability);
    final groups = <({MenuCategory? category, List<MenuItem> items})>[
      for (final c in _c.categories) (category: c, items: menu.itemsIn(c.id)),
      if (menu.items.any((i) => menu.category(i.categoryId) == null))
        (
          category: null,
          items:
              menu.items
                  .where((i) => menu.category(i.categoryId) == null)
                  .toList()
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        ),
    ];
    final out = <Widget>[];
    for (final g in groups) {
      final shown = g.items.where(_matches).toList();
      if (_query.isNotEmpty && shown.isEmpty) continue;
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PanelLabel(
              l.menuCategoryHeading(
                name: g.category?.name ?? l.menuUncategorised,
                count: g.items.length,
              ),
              trailing: canEdit && g.category != null && _query.isEmpty
                  ? _SmallAction(
                      label: l.commonAdd,
                      onTap: () => _newItem(categoryId: g.category!.id),
                    )
                  : null,
            ),
          ),
        ),
      );
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Panel(
              padding: null,
              children: shown.isEmpty
                  ? [
                      _EmptyCategoryRow(
                        onAdd: canEdit
                            ? () => _newItem(categoryId: g.category?.id)
                            : null,
                      ),
                    ]
                  : [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const PanelDivider(indent: 84),
                        _ItemRow(
                          item: shown[i],
                          canToggle: canToggle,
                          onTap: () => _openItem(shown[i]),
                          onToggle: (v) => _toggle(shown[i], v),
                        ),
                      ],
                    ],
            ),
          ),
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.search_off_rounded,
            title: l.menuNoMatchTitle(query: _search.text.trim()),
            message: l.menuNoMatchMessage,
          ),
        ),
      );
    }
    return out;
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.canToggle,
    required this.onTap,
    required this.onToggle,
  });

  final MenuItem item;
  final bool canToggle;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final off = !item.isAvailable;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 56,
              child: FoodArt(
                name: item.name,
                imageUrl: item.imageUrl,
                radius: 14,
                dim: off,
                animate: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (item.foodType != null) ...[
                        FoodTypeMark(item.foodType, size: 13),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: off ? t.inkMuted : t.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        rupees(item.price),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: off ? t.inkMuted : t.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (item.isRecommended) const BestsellerMark(),
                      if (off)
                        Text(
                          context.l10n.menuSoldOut,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: t.danger,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Semantics(
              label: context.l10n.menuAvailable,
              child: Switch(
                value: item.isAvailable,
                onChanged: canToggle ? onToggle : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Bestseller" mark, from the POS "recommended" flag.
class BestsellerMark extends StatelessWidget {
  const BestsellerMark({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: t.tint(t.warning),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12, color: t.warning),
          const SizedBox(width: 3),
          Text(
            context.l10n.menuBestseller,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: t.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: color ?? t.ink,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: t.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 16, color: t.inkSecondary),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCategoryRow extends StatelessWidget {
  const _EmptyCategoryRow({this.onAdd});
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return ListTile(
      leading: Icon(Icons.restaurant_outlined, color: t.inkMuted),
      title: Text(
        context.l10n.menuCategoryEmpty,
        style: TextStyle(color: t.inkMuted, fontSize: 14),
      ),
      trailing: onAdd == null
          ? null
          : TextButton(onPressed: onAdd, child: Text(context.l10n.menuAddDish)),
    );
  }
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu({
    required this.canEdit,
    required this.onAddCategory,
    required this.onAddDish,
  });

  final bool canEdit;
  final VoidCallback onAddCategory;
  final VoidCallback onAddDish;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: t.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 36,
              color: t.inkSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.menuEmptyTitle,
            textAlign: TextAlign.center,
            style: text.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            canEdit ? l.menuEmptyBodyEditor : l.menuEmptyBodyViewer,
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          if (canEdit) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddCategory,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(l.menuAddACategory),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddDish,
                icon: const Icon(Icons.add_rounded),
                label: Text(l.menuAddDish),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
