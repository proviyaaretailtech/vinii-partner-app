import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_scope.dart';
import '../../application/menu_editor.dart';
import '../../application/studio_controller.dart';
import '../../core/failure.dart';
import '../../core/money.dart';
import '../../domain/menu.dart';
import '../../domain/staff.dart';
import '../../domain/storefront.dart';
import '../studio/studio_scope.dart';
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/food_art.dart';
import '../widgets/state_views.dart';
import 'item_storefront_card.dart';
import 'menu_scope.dart';
import 'panel.dart';

/// One dish: its POS row (name, price, category, veg mark, availability)
/// and, for people who work on the storefront, its guest-only details.
///
/// [itemId] `new` creates a dish; [initialCategoryId] preselects its
/// category. People without `editMenu` see the same screen read-only, so a
/// kitchen login can still check a price or a description.
class ItemEditorScreen extends StatefulWidget {
  const ItemEditorScreen({
    super.key,
    required this.itemId,
    this.initialCategoryId,
  });

  static const newId = 'new';

  final String itemId;
  final String? initialCategoryId;

  @override
  State<ItemEditorScreen> createState() => _ItemEditorScreenState();
}

enum _PhotoAction { camera, gallery, remove }

class _ItemEditorScreenState extends State<ItemEditorScreen> {
  late final MenuEditorController _c = menuEditorOf(context);
  StudioController? _studio;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _prep = TextEditingController();
  final _kcal = TextEditingController();

  String? _categoryId;
  FoodType? _foodType;
  String _course = 'eat';
  bool _recommended = false;
  bool _available = true;
  String? _imageUrl;
  MenuItem? _original;

  /// A photo picked for a dish that has no id yet; uploaded right after the
  /// first save.
  Uint8List? _pendingPhoto;
  String _pendingExt = 'jpg';

  /// Set once a new dish has been saved, so a retry updates instead of
  /// creating a second copy.
  String? _createdId;

  List<String> _tags = const [];
  List<String> _ingredients = const [];
  List<String> _allergens = const [];
  bool _hidden = false;

  bool _filled = false;
  bool _missing = false;
  bool _studioLoading = false;
  bool _studioReady = false;
  AppFailure? _studioFailure;
  bool _uploading = false;
  bool _saving = false;
  String _savedItem = '';
  String _savedPresentation = '';

  bool get _isNew =>
      widget.itemId == ItemEditorScreen.newId && _createdId == null;
  String? get _id =>
      _createdId ??
      (widget.itemId == ItemEditorScreen.newId ? null : widget.itemId);

  bool _can(Capability c) => AppScope.of(context).session.can(c);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _price, _prep, _kcal]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (!mounted) return;
    await _c.ensureLoaded();
    if (!mounted || _c.menu == null) return;
    _fill();
    if (_can(Capability.viewStorefront)) await _loadStorefront();
  }

  void _fill() {
    final menu = _c.menu!;
    if (widget.itemId == ItemEditorScreen.newId) {
      final cat = widget.initialCategoryId;
      _categoryId = menu.category(cat) == null ? null : cat;
    } else {
      final item = menu.item(widget.itemId);
      if (item == null) {
        setState(() => _missing = true);
        return;
      }
      _original = item;
      _name.text = item.name;
      _desc.text = item.description ?? '';
      _price.text = _plainPrice(item.price);
      _prep.text = item.prepMinutes?.toString() ?? '';
      _categoryId = menu.category(item.categoryId) == null
          ? null
          : item.categoryId;
      _foodType = item.foodType;
      _course = item.course == 'drink' ? 'drink' : 'eat';
      _recommended = item.isRecommended;
      _available = item.isAvailable;
      _imageUrl = item.imageUrl;
    }
    _savedItem = _itemSignature();
    _savedPresentation = _presentationSignature();
    setState(() => _filled = true);
  }

  Future<void> _loadStorefront() async {
    final studio = _studio ??= studioOf(context);
    setState(() {
      _studioLoading = true;
      _studioFailure = null;
    });
    await studio.ensureLoaded();
    if (!mounted) return;
    if (!studio.loaded) {
      setState(() {
        _studioLoading = false;
        _studioFailure =
            studio.failure ??
            const AppFailure('The storefront could not be loaded.');
      });
      return;
    }
    final id = _id;
    final p = id == null
        ? const ItemPresentation(itemId: '')
        : studio.presentationOf(id);
    setState(() {
      _tags = [...p.tags];
      _ingredients = [...p.ingredients];
      _allergens = [...p.allergens];
      _hidden = p.hidden;
      _kcal.text = p.kcal?.toString() ?? '';
      _savedPresentation = _presentationSignature();
      _studioLoading = false;
      _studioReady = true;
    });
  }

  static String _plainPrice(double p) =>
      p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);

  String _itemSignature() => [
    _name.text.trim(),
    _desc.text.trim(),
    double.tryParse(_price.text.trim())?.toString() ?? _price.text.trim(),
    _prep.text.trim(),
    _categoryId,
    _foodType?.dbValue,
    _course,
    _recommended,
    _available,
    _imageUrl,
  ].join('|');

  ItemPresentation _presentation(String itemId) => ItemPresentation(
    itemId: itemId,
    tags: _tags,
    ingredients: _ingredients,
    allergens: _allergens,
    kcal: int.tryParse(_kcal.text.trim()),
    hidden: _hidden,
  );

  String _presentationSignature() => jsonEncode(_presentation('').toJson());

  bool get _itemChanged =>
      _pendingPhoto != null || _itemSignature() != _savedItem;
  bool get _presentationChanged =>
      _studioReady && _presentationSignature() != _savedPresentation;
  bool get _dirty => _filled && (_itemChanged || _presentationChanged);

  MenuItem _itemFromForm(String id) {
    final menu = _c.menu ?? MenuSnapshot.empty;
    final siblings = menu.itemsIn(_categoryId);
    final nextOrder = siblings.isEmpty
        ? 1
        : siblings.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final desc = _desc.text.trim();
    return MenuItem(
      id: id,
      categoryId: _categoryId,
      name: _name.text.trim(),
      price: double.parse(_price.text.trim()),
      description: desc.isEmpty ? null : desc,
      imageUrl: _imageUrl,
      foodType: _foodType,
      course: _course,
      isAvailable: _available,
      isRecommended: _recommended,
      prepMinutes: int.tryParse(_prep.text.trim()),
      sortOrder: _original?.sortOrder ?? nextOrder,
    );
  }

  Future<void> _save() async {
    final editMenu = _can(Capability.editMenu);
    final editStorefront =
        _can(Capability.editStorefront) && _studio != null && _studioReady;
    if (editMenu && !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      var id = _id;
      var name = _name.text.trim();
      final wasNew = _isNew;
      if (editMenu && (wasNew || _itemChanged)) {
        var saved = await _c.saveItem(_itemFromForm(id ?? ''), isNew: wasNew);
        if (wasNew) _createdId = saved.id;
        id = saved.id;
        name = saved.name;
        if (_pendingPhoto != null) {
          final url = await _c.uploadImage(
            saved.id,
            _pendingPhoto!,
            extension: _pendingExt,
          );
          _imageUrl = url;
          _pendingPhoto = null;
          saved = await _c.saveItem(_itemFromForm(saved.id), isNew: false);
        }
        _original = saved;
        _savedItem = _itemSignature();
      }
      if (editStorefront && id != null && _presentationChanged) {
        await _studio!.saveItemPresentation(_presentation(id));
        _savedPresentation = _presentationSignature();
      }
      if (!mounted) return;
      showDone(context, wasNew ? '$name is on the menu' : 'Saved');
      context.pop();
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _photo() async {
    final t = ViniiTokens.of(context);
    final hasPhoto = _imageUrl != null || _pendingPhoto != null;
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, _PhotoAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, _PhotoAction.gallery),
              ),
              if (hasPhoto)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: t.danger),
                  title: Text(
                    'Remove photo',
                    style: TextStyle(color: t.danger),
                  ),
                  onTap: () => Navigator.pop(context, _PhotoAction.remove),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == _PhotoAction.remove) {
      setState(() {
        _imageUrl = null;
        _pendingPhoto = null;
      });
      return;
    }
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: action == _PhotoAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) {
        showFailure(
          context,
          const AppFailure(
            'Could not open the camera or photos. Allow access in the phone settings and try again.',
          ),
        );
      }
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final ext = _extensionOf(file.name);
    final id = _id;
    if (id == null) {
      // A new dish has no id to name the photo by yet: keep it until Save.
      setState(() {
        _pendingPhoto = bytes;
        _pendingExt = ext;
      });
      return;
    }
    setState(() => _uploading = true);
    try {
      final url = await _c.uploadImage(id, bytes, extension: ext);
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _pendingPhoto = null;
      });
      showDone(context, 'Photo uploaded. Save to keep it on the dish.');
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? ext : 'jpg';
  }

  Future<void> _onBlockedPop() async {
    if (_saving) return;
    final leave = await confirmDiscard(context);
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editMenu = _can(Capability.editMenu);
    final viewStorefront = _can(Capability.viewStorefront);
    final editStorefront = _can(Capability.editStorefront);
    final canSave = editMenu || (viewStorefront && editStorefront);
    final title = widget.itemId == ItemEditorScreen.newId
        ? 'New item'
        : (editMenu ? 'Edit item' : 'Item');
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBlockedPop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        bottomNavigationBar: canSave && _filled && !_missing
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    onPressed: _saving || _uploading ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : Text(
                            widget.itemId == ItemEditorScreen.newId &&
                                    _createdId == null
                                ? 'Add to menu'
                                : 'Save changes',
                          ),
                  ),
                ),
              )
            : null,
        body: _body(
          editMenu: editMenu,
          viewStorefront: viewStorefront,
          editStorefront: editStorefront,
        ),
      ),
    );
  }

  Widget _body({
    required bool editMenu,
    required bool viewStorefront,
    required bool editStorefront,
  }) {
    if (_missing) {
      return EmptyView(
        icon: Icons.no_food_outlined,
        title: 'This dish is no longer on the menu',
        message: 'Someone may have removed it on another device.',
        actionLabel: 'Back to menu',
        onAction: () => context.pop(),
      );
    }
    if (!_filled) {
      if (_c.menu == null && _c.failure != null && !_c.loading) {
        return FailureView(failure: _c.failure!, onRetry: _start);
      }
      return const LoadingView();
    }
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    void changed() => setState(() {});
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (!editMenu) ...[
            const NoticeBanner(
              icon: Icons.lock_outline_rounded,
              message: 'Only owners, admins and managers can change dishes.',
            ),
            const SizedBox(height: 12),
          ],
          _PhotoBlock(
            name: _name.text.trim(),
            imageUrl: _imageUrl,
            pending: _pendingPhoto,
            uploading: _uploading,
            onTap: editMenu && !_uploading ? _photo : null,
          ),
          const PanelLabel('Details'),
          Panel(
            children: [
              TextFormField(
                controller: _name,
                enabled: editMenu,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: (_) => changed(),
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Give the dish a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                enabled: editMenu,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => changed(),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What makes it good, in a line or two',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      enabled: editMenu,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,7}(\.\d{0,2})?'),
                        ),
                      ],
                      onChanged: (_) => changed(),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixText: '₹ ',
                        helperText: 'Before GST',
                      ),
                      validator: (v) {
                        final p = double.tryParse(v?.trim() ?? '');
                        if (p == null) return 'Enter a price';
                        if (p < 0) return 'Price cannot be negative';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _prep,
                      enabled: editMenu,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onChanged: (_) => changed(),
                      decoration: const InputDecoration(
                        labelText: 'Prep time',
                        suffixText: 'min',
                        helperText: 'Optional',
                      ),
                    ),
                  ),
                ],
              ),
              if (!editMenu && _original != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Sells at ${rupees(_original!.price)} before GST',
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
          const PanelLabel('Kind'),
          Panel(
            children: [
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Uncategorised'),
                  ),
                  for (final c in _c.categories)
                    DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: editMenu
                    ? (v) => setState(() => _categoryId = v)
                    : null,
              ),
              const SizedBox(height: 16),
              Text('Food type', style: text.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in [...FoodType.values, null])
                    ChoiceChip(
                      avatar: f == null ? null : FoodTypeMark(f, size: 14),
                      label: Text(f?.label ?? 'Not set'),
                      selected: _foodType == f,
                      onSelected: editMenu
                          ? (_) => setState(() => _foodType = f)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Course', style: text.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'eat',
                    label: Text('Food'),
                    icon: Icon(Icons.restaurant_rounded),
                  ),
                  ButtonSegment(
                    value: 'drink',
                    label: Text('Drink'),
                    icon: Icon(Icons.local_cafe_outlined),
                  ),
                ],
                selected: {_course},
                showSelectedIcon: false,
                onSelectionChanged: editMenu
                    ? (v) => setState(() => _course = v.first)
                    : null,
              ),
            ],
          ),
          const PanelLabel('Selling'),
          Panel(
            padding: null,
            children: [
              SwitchListTile(
                secondary: Icon(Icons.star_outline_rounded, color: t.warning),
                title: const Text('Bestseller'),
                subtitle: const Text('Marked for guests and on the POS'),
                value: _recommended,
                onChanged: editMenu
                    ? (v) => setState(() => _recommended = v)
                    : null,
              ),
              const PanelDivider(),
              SwitchListTile(
                secondary: const Icon(Icons.point_of_sale_outlined),
                title: const Text('Available in the POS'),
                subtitle: const Text('Off = sold out everywhere you sell'),
                value: _available,
                onChanged: editMenu
                    ? (v) => setState(() => _available = v)
                    : null,
              ),
            ],
          ),
          if (viewStorefront) ...[
            const PanelLabel('On your storefront'),
            ItemStorefrontCard(
              enabled: editStorefront,
              loading:
                  _studioLoading || (!_studioReady && _studioFailure == null),
              failure: _studioFailure,
              onRetry: _loadStorefront,
              tags: _tags,
              ingredients: _ingredients,
              allergens: _allergens,
              hidden: _hidden,
              kcal: _kcal,
              onChanged: ({tags, ingredients, allergens, hidden}) =>
                  setState(() {
                    if (tags != null) _tags = tags;
                    if (ingredients != null) _ingredients = ingredients;
                    if (allergens != null) _allergens = allergens;
                    if (hidden != null) _hidden = hidden;
                  }),
            ),
          ],
        ],
      ),
    );
  }
}

/// The dish photo, or its illustrated stand-in, with the change button.
class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({
    required this.name,
    required this.imageUrl,
    required this.pending,
    required this.uploading,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final Uint8List? pending;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final has = imageUrl != null || pending != null;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (pending != null)
              Image.memory(pending!, fit: BoxFit.cover)
            else
              FoodArt(
                name: name.isEmpty ? 'Dish' : name,
                imageUrl: imageUrl,
                radius: 0,
              ),
            if (uploading)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            if (onTap != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: Material(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            has
                                ? Icons.edit_outlined
                                : Icons.add_a_photo_outlined,
                            size: 18,
                            color: t.ink,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            has ? 'Change photo' : 'Add photo',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: t.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (!has && onTap == null)
              Positioned(
                left: 12,
                bottom: 12,
                child: Text(
                  'No photo yet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
