import 'package:flutter/foundation.dart';

import '../core/failure.dart';
import '../data/backend.dart';
import '../domain/menu.dart';

/// The Menu tab's shared state: the organization's real Item Master, loaded
/// once and kept in step with every write, so the list, the item editor and
/// the categories screen always agree without re-reading after each tap.
///
/// Named `MenuEditorController` so it never clashes with Flutter's own
/// `MenuController`. Obtained through `AppScope.feature`, so it is thrown
/// away on sign-out and organization switch.
class MenuEditorController extends ChangeNotifier {
  MenuEditorController(this._repo);

  final MenuRepository _repo;

  MenuSnapshot? _menu;
  AppFailure? _failure;
  bool _loading = false;
  bool _disposed = false;

  /// Null until the first load finishes.
  MenuSnapshot? get menu => _menu;
  AppFailure? get failure => _failure;
  bool get loading => _loading;
  bool get loaded => _menu != null;

  /// Categories in menu order (the order the POS and guests see).
  List<MenuCategory> get categories =>
      [...?_menu?.categories]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  int countIn(String? categoryId) =>
      _menu?.items.where((i) => i.categoryId == categoryId).length ?? 0;

  Future<void> ensureLoaded() async {
    if (_menu == null && !_loading) await load();
  }

  /// A failed refresh keeps the list already on screen; [failure] then says
  /// why it could not be updated (the screen shows it as a banner).
  Future<void> load() async {
    _loading = true;
    _notify();
    try {
      _menu = await _repo.load();
      _failure = null;
    } catch (e) {
      _failure = asFailure(e);
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Flips availability at once and tells the server; on failure the switch
  /// flips back and the error is rethrown for the screen to show. Staff at
  /// a busy counter should never wait on a spinner to mark a dish sold out.
  Future<void> setAvailable(MenuItem item, bool available) async {
    _replaceItem(item.copyWith(isAvailable: available));
    try {
      await _repo.setItemAvailable(item.id, available);
    } catch (e) {
      _replaceItem(item.copyWith(isAvailable: !available));
      throw asFailure(e);
    }
  }

  Future<MenuItem> saveItem(MenuItem item, {required bool isNew}) async {
    try {
      final saved = await _repo.saveItem(item, isNew: isNew);
      _replaceItem(saved);
      return saved;
    } catch (e) {
      throw asFailure(e);
    }
  }

  /// Uploads a photo and returns its public URL. The item row is updated by
  /// the caller's next save, so a cancelled edit leaves the item unchanged.
  Future<String> uploadImage(
    String itemId,
    Uint8List bytes, {
    required String extension,
  }) async {
    try {
      return await _repo.uploadItemImage(itemId, bytes, extension: extension);
    } catch (e) {
      throw asFailure(e);
    }
  }

  Future<MenuCategory> addCategory(String name) async {
    try {
      final saved = await _repo.saveCategory(
        MenuCategory(id: '', name: name.trim(), sortOrder: _nextSortOrder),
        isNew: true,
      );
      _setMenu(
        MenuSnapshot(
          categories: [
            ...?_menu?.categories.where((c) => c.id != saved.id),
            saved,
          ],
          items: _menu?.items ?? const [],
        ),
      );
      return saved;
    } catch (e) {
      throw asFailure(e);
    }
  }

  Future<void> renameCategory(MenuCategory category, String name) async {
    try {
      final saved = await _repo.saveCategory(
        category.copyWith(name: name.trim()),
        isNew: false,
      );
      _setMenu(
        MenuSnapshot(
          categories: [
            for (final c in _menu?.categories ?? const <MenuCategory>[])
              c.id == saved.id ? saved : c,
          ],
          items: _menu?.items ?? const [],
        ),
      );
    } catch (e) {
      throw asFailure(e);
    }
  }

  /// Items in the category stay on the menu as "Uncategorised".
  Future<void> deleteCategory(MenuCategory category) async {
    try {
      await _repo.deleteCategory(category.id);
      _setMenu(
        MenuSnapshot(
          categories: [
            for (final c in _menu?.categories ?? const <MenuCategory>[])
              if (c.id != category.id) c,
          ],
          items: [
            for (final i in _menu?.items ?? const <MenuItem>[])
              i.categoryId == category.id ? i.copyWith(clearCategory: true) : i,
          ],
        ),
      );
    } catch (e) {
      throw asFailure(e);
    }
  }

  /// Shows the new order immediately; puts the old one back if the server
  /// refuses, so the screen never shows an order nobody saved.
  Future<void> reorderCategories(List<String> idsInOrder) async {
    final before = _menu;
    if (before == null) return;
    final byId = {for (final c in before.categories) c.id: c};
    _setMenu(
      MenuSnapshot(
        categories: [
          for (var i = 0; i < idsInOrder.length; i++)
            if (byId[idsInOrder[i]] != null)
              byId[idsInOrder[i]]!.copyWith(sortOrder: i + 1),
        ],
        items: before.items,
      ),
    );
    try {
      await _repo.reorderCategories(idsInOrder);
    } catch (e) {
      _setMenu(before);
      throw asFailure(e);
    }
  }

  int get _nextSortOrder {
    final cats = _menu?.categories ?? const <MenuCategory>[];
    if (cats.isEmpty) return 1;
    final top = cats.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);
    return (top < cats.length ? cats.length : top) + 1;
  }

  void _replaceItem(MenuItem item) {
    final m = _menu ?? MenuSnapshot.empty;
    final exists = m.items.any((i) => i.id == item.id);
    _setMenu(
      MenuSnapshot(
        categories: m.categories,
        items: exists
            ? [for (final i in m.items) i.id == item.id ? item : i]
            : [...m.items, item],
      ),
    );
  }

  void _setMenu(MenuSnapshot m) {
    _menu = m;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
