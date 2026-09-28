import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/failure.dart';
import '../data/backend.dart';
import '../domain/billing.dart';
import '../domain/guest_catalog.dart';
import '../domain/menu.dart';
import '../domain/organization.dart';
import '../domain/storefront.dart';
import 'guest_gateway.dart';
import 'menu_editor.dart';

/// Storefront Studio's shared state: what is published, the saved draft,
/// and the working copy ([draft]) every Studio section edits.
///
/// Edits stay in memory until "Save draft" or "Publish", so a person can
/// try a template or colour in the live preview without changing anything
/// guests see. The working copy survives switching tabs (the controller
/// lives in `AppScope.feature`) and is dropped on organization switch.
///
/// The menu comes from the shared [MenuEditorController], so a dish added or
/// marked sold out in the Menu tab shows in Studio's preview straight away.
class StudioController extends ChangeNotifier {
  StudioController({
    required this.org,
    required StorefrontRepository storefront,
    required PosRepository pos,
    required MenuEditorController menu,
  }) : _repo = storefront,
       _posRepo = pos,
       _menuSource = menu {
    _menuSource.addListener(_menuChanged);
  }

  final Organization org;
  final StorefrontRepository _repo;
  final PosRepository _posRepo;
  final MenuEditorController _menuSource;

  StorefrontState? _state;
  StorefrontDefinition? _draft;
  StorefrontDefinition? _saved;
  AppFailure? _failure;
  bool _loading = false;
  bool _busy = false;
  bool _fullPreviewOpen = false;
  bool _disposed = false;
  int _revision = 0;

  /// Studio's preview: the real menu and bill settings, but nothing is ever
  /// sent (see [PreviewGuestGateway]). One instance for the controller's
  /// life, so the guest runtime keeps its visit across edits.
  late final PreviewGuestGateway gateway = PreviewGuestGateway(_billCharges);

  /// Bill settings are read once per Studio visit, not on every preview
  /// restart; a failed read is retried next time.
  Future<BillCharges>? _charges;
  Future<BillCharges> _billCharges() {
    final cached = _charges;
    if (cached != null) return cached;
    final f = _charges = _posRepo.billCharges();
    unawaited(f.then<void>((_) {}, onError: (Object _) => _charges = null));
    return f;
  }

  StorefrontState? get state => _state;
  AppFailure? get failure => _failure;
  bool get loading => _loading;
  bool get loaded => _state != null && _draft != null;

  /// A save, publish, discard or restore is running; buttons wait.
  bool get busy => _busy;

  /// The working copy. Only valid once [loaded].
  StorefrontDefinition get draft => _draft!;

  MenuSnapshot get menu => _menuSource.menu ?? MenuSnapshot.empty;

  /// Bumps when the saved baseline changes (load, save, publish, discard,
  /// restore). Previews key the guest runtime on it, so it starts afresh
  /// then. Ordinary edits do not restart it: the runtime takes a new
  /// definition in place and restyles, without replaying its entrance
  /// animations on every keystroke.
  int get revision => _revision;

  /// Changed here since the last save or load.
  bool get dirty =>
      _draft != null && _saved != null && _canon(_draft!) != _canon(_saved!);

  /// Guests see something different from this draft (saved or not).
  bool get hasUnpublishedChanges =>
      dirty || (_state?.hasUnpublishedChanges ?? false);

  /// The full-screen preview is open; the small one in Studio steps aside so
  /// two guest runtimes never run at once.
  bool get fullPreviewOpen => _fullPreviewOpen;
  set fullPreviewOpen(bool v) {
    if (v == _fullPreviewOpen) return;
    _fullPreviewOpen = v;
    _notify();
  }

  Future<void> ensureLoaded() async {
    if (!loaded && !_loading) await load();
  }

  /// Reads the storefront and the menu. Unsaved edits are kept unless
  /// [resetEdits]: a pull-to-refresh must not throw away someone's work.
  Future<void> load({bool resetEdits = false}) async {
    _loading = true;
    _notify();
    try {
      final results = await Future.wait<Object?>([
        _repo.load(org),
        _menuSource.loaded ? Future<void>.value() : _menuSource.load(),
      ]);
      if (!_menuSource.loaded && _menuSource.failure != null) {
        throw _menuSource.failure!;
      }
      _apply(results[0] as StorefrontState, resetEdits: resetEdits);
      _failure = null;
    } catch (e) {
      _failure = asFailure(e);
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Reloads the menu too (pull-to-refresh in Studio).
  Future<void> refresh() async {
    await _menuSource.load();
    await load();
  }

  /// Applies one change to the working copy.
  void edit(StorefrontDefinition Function(StorefrontDefinition d) change) {
    if (_draft == null) return;
    _draft = change(_draft!);
    _notify();
  }

  /// Forgets unsaved edits (keeps the saved draft).
  void revertEdits() {
    if (_saved == null) return;
    _draft = _saved;
    _notify();
  }

  Future<void> saveDraft() => _run(() async {
    await _repo.saveDraft(org, _draft!);
    _apply(await _repo.load(org), resetEdits: true);
  });

  /// Why the working copy cannot be published yet, in plain words. Empty
  /// when it can.
  List<String> publishProblems() {
    final d = _draft;
    if (d == null) return const ['The storefront has not loaded yet.'];
    final b = d.features.budget;
    return [
      if (d.brand.displayName.trim().isEmpty)
        "Add your restaurant's name in Brand & welcome.",
      if (d.serviceModes.isEmpty)
        'Turn on at least one way to order in How guests order.',
      if (b.enabled &&
          !(b.min > 0 && b.min <= b.defaultAmount && b.defaultAmount <= b.max))
        'Budget amounts need minimum ≤ starting amount ≤ maximum, in Guest features.',
      if (d.offers(GuestServiceMode.preOrder) &&
          d.preOrder.allSlotsFor(DateTime.now()).isEmpty)
        'Pre-order has no pickup times: the closing time must be at least one slot after the opening time.',
      if (GuestCatalog(menu: menu, definition: d).isEmpty) 'Guests would see an empty menu. Add dishes with a price in the Menu tab, keep them available, and keep at least one category visible.',
    ];
  }

  /// Publishes the working copy as the next version. Throws [AppFailure]
  /// (including `notReady` while the storefront tables are missing).
  Future<StorefrontVersion> publish({required String publishedBy}) async {
    final problems = publishProblems();
    if (problems.isNotEmpty) {
      throw AppFailure(problems.first, kind: FailureKind.rejected);
    }
    late StorefrontVersion v;
    await _run(() async {
      v = await _repo.publish(org, _draft!, publishedBy: publishedBy);
      _apply(await _repo.load(org), resetEdits: true);
    });
    return v;
  }

  /// Makes an older version live again, as a new version number (history
  /// only grows).
  Future<StorefrontVersion> restore(
    StorefrontVersion old, {
    required String publishedBy,
  }) async {
    late StorefrontVersion v;
    await _run(() async {
      v = await _repo.publish(org, old.definition, publishedBy: publishedBy);
      _apply(await _repo.load(org), resetEdits: true);
    });
    return v;
  }

  /// Throws away the saved draft and any unsaved edits: Studio goes back to
  /// what guests see now.
  Future<void> discardDraft() => _run(() async {
    await _repo.discardDraft(org);
    _apply(await _repo.load(org), resetEdits: true);
  });

  /// The storefront details of one menu item as Studio has them now.
  ItemPresentation presentationOf(String itemId) =>
      (_draft ?? _state?.effective(org))?.presentationOf(itemId) ??
      ItemPresentation(itemId: itemId);

  /// Saves one item's storefront details (tags, allergens…) into the saved
  /// draft, on top of what is stored — not on top of this person's unsaved
  /// Studio edits, which stay unsaved. Called from the item editor.
  Future<void> saveItemPresentation(ItemPresentation p) async {
    try {
      final fresh = await _repo.load(org);
      await _repo.saveDraft(org, _withPresentation(fresh.effective(org), p));
      final after = await _repo.load(org);
      if (_draft == null) {
        _state = after;
        _notify();
        return;
      }
      final keepEdits = dirty ? _withPresentation(_draft!, p) : null;
      _apply(after, resetEdits: true);
      if (keepEdits != null) _draft = keepEdits;
      _notify();
    } catch (e) {
      throw asFailure(e);
    }
  }

  static StorefrontDefinition _withPresentation(
    StorefrontDefinition d,
    ItemPresentation p,
  ) => p.isEmpty
      ? d.copyWith(items: {...d.items}..remove(p.itemId))
      : d.withItem(p);

  void _apply(StorefrontState s, {required bool resetEdits}) {
    final keep = !resetEdits && dirty ? _draft : null;
    _state = s;
    _saved = s.effective(org);
    _draft = keep ?? _saved;
    _revision++;
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_draft == null) {
      throw const AppFailure('The storefront has not loaded yet.');
    }
    _busy = true;
    _notify();
    try {
      await job();
    } catch (e) {
      throw asFailure(e);
    } finally {
      _busy = false;
      _notify();
    }
  }

  MenuSnapshot? _lastMenu;

  void _menuChanged() {
    // A different menu changes what the preview and the publish checks
    // see; a loading flag alone does not.
    if (identical(_menuSource.menu, _lastMenu)) return;
    _lastMenu = _menuSource.menu;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _menuSource.removeListener(_menuChanged);
    super.dispose();
  }
}

/// Key-order-independent JSON, so "changed" means the content changed.
String _canon(StorefrontDefinition d) => jsonEncode(_sorted(d.toJson()));

Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return [for (final e in v) _sorted(e)];
  return v;
}
