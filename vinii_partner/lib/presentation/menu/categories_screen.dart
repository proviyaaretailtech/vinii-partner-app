import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../application/menu_editor.dart';
import '../../domain/menu.dart';
import '../../domain/staff.dart';
import '../../l10n/failure_text.dart';
import '../../l10n/l10n.dart';
import '../theme/staff_theme.dart';
import '../widgets/state_views.dart';
import 'menu_scope.dart';

/// The menu's categories, in the order the POS, One Local and guests see
/// them. Drag to reorder; add, rename and delete for editors. Deleting a
/// category never deletes dishes — they stay on the menu as
/// "Uncategorised", because losing a dish by tidying a heading would be a
/// nasty surprise mid-service.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final MenuEditorController _c = menuEditorOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.ensureLoaded();
    });
  }

  bool get _canEdit => AppScope.of(context).session.can(Capability.editMenu);

  Future<void> _add() async {
    final l = context.l10n;
    final name = await _askName(context, title: l.menuCategoryNewTitle);
    if (name == null) return;
    try {
      await _c.addCategory(name);
      if (mounted) showDone(context, l.menuCategoryAdded(name: name));
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _rename(MenuCategory c) async {
    final name = await _askName(
      context,
      title: context.l10n.menuCategoryRenameTitle,
      initial: c.name,
    );
    if (name == null || name == c.name) return;
    try {
      await _c.renameCategory(c, name);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _delete(MenuCategory c) async {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final count = _c.countIn(c.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.menuCategoryDeleteTitle(name: c.name)),
        content: Text(
          count == 0
              ? l.menuCategoryDeleteEmpty
              : l.menuCategoryDeleteKeeps(count: count),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: t.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _c.deleteCategory(c);
      if (mounted) showDone(context, l.menuCategoryDeleted(name: c.name));
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  /// [to] is already adjusted for the removed item (`onReorderItem`).
  Future<void> _reorder(List<MenuCategory> list, int from, int to) async {
    final ids = [for (final c in list) c.id];
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    try {
      await _c.reorderCategories(ids);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _canEdit;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final l = context.l10n;
        final menu = _c.menu;
        return Scaffold(
          appBar: AppBar(title: Text(l.menuCategories)),
          floatingActionButton: canEdit && menu != null
              ? FloatingActionButton.extended(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.menuAddCategory),
                )
              : null,
          body: _body(menu, canEdit),
        );
      },
    );
  }

  Widget _body(MenuSnapshot? menu, bool canEdit) {
    if (menu == null) {
      if (_c.failure != null && !_c.loading) {
        return FailureView(failure: _c.failure!, onRetry: _c.load);
      }
      return const LoadingView();
    }
    final l = context.l10n;
    final list = _c.categories;
    if (list.isEmpty) {
      return EmptyView(
        icon: Icons.segment_rounded,
        title: l.menuCategoriesEmptyTitle,
        message: l.menuCategoriesEmptyMessage,
        actionLabel: canEdit ? l.menuAddACategory : null,
        onAction: canEdit ? _add : null,
      );
    }
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(
            canEdit ? l.menuCategoriesDragHint : l.menuCategoriesOrderHint,
            style: text.bodyMedium,
          ),
        ),
        if (_c.failure != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: NoticeBanner(
              icon: Icons.sync_problem_rounded,
              tone: t.warning,
              message: l.menuRefreshFailed(reason: failureText(l, _c.failure!)),
            ),
          ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
            buildDefaultDragHandles: false,
            itemCount: list.length,
            onReorderItem: canEdit
                ? (from, to) => _reorder(list, from, to)
                : (_, _) {},
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              child: child,
            ),
            itemBuilder: (context, i) {
              final c = list[i];
              final count = _c.countIn(c.id);
              return Padding(
                key: ValueKey(c.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                    leading: canEdit
                        ? ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: t.inkMuted,
                                semanticLabel: l.menuDragToReorder,
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: t.inkMuted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(l.menuDishCount(count: count)),
                    trailing: canEdit
                        ? PopupMenuButton<String>(
                            tooltip: l.menuCategoryMoreFor(name: c.name),
                            onSelected: (v) =>
                                v == 'rename' ? _rename(c) : _delete(c),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(l.menuRename),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  l.commonDelete,
                                  style: TextStyle(color: t.danger),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Asks for a category name. Null when cancelled.
Future<String?> _askName(
  BuildContext context, {
  required String title,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (context) => _NameDialog(title: title, initial: initial),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done() {
    final v = _text.text.trim();
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _text,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _done(),
      decoration: InputDecoration(labelText: context.l10n.menuCategoryName),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.commonCancel),
      ),
      TextButton(
        onPressed: _text.text.trim().isEmpty ? null : _done,
        child: Text(context.l10n.commonSave),
      ),
    ],
  );
}
