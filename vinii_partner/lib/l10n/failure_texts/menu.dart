import '../app_localizations.dart';
import 'types.dart';

/// Failure codes raised by the menu area: code -> sentence.
/// Add `'my_code': (l, a) => l.failMyCode,` (and import
/// '../app_localizations.dart' when you do) plus the matching ARB key.
///
/// The "photo too large" refusal in lib/data/live/live_menu.dart reuses the
/// shared `photo_too_large` code from core.dart.
const Map<String, FailureBuilder> menuFailureTexts = {
  'menu_category_name_needed': _categoryNameNeeded,
  'menu_category_not_removed': _categoryNotRemoved,
  'menu_item_name_needed': _itemNameNeeded,
  'menu_price_negative': _priceNegative,
  'menu_item_gone': _itemGone,
  'menu_storefront_not_loaded': _storefrontNotLoaded,
  'menu_photo_picker': _photoPicker,
};

String _categoryNameNeeded(AppLocalizations l, Map<String, Object?> a) =>
    l.menuFailCategoryNameNeeded;
String _categoryNotRemoved(AppLocalizations l, Map<String, Object?> a) =>
    l.menuFailCategoryNotRemoved;
String _itemNameNeeded(AppLocalizations l, Map<String, Object?> a) =>
    l.menuFailItemNameNeeded;
String _priceNegative(AppLocalizations l, Map<String, Object?> a) =>
    l.menuFailPriceNegative;
String _itemGone(AppLocalizations l, Map<String, Object?> a) =>
    l.menuFailItemGone;
String _storefrontNotLoaded(AppLocalizations l, Map<String, Object?> a) =>
    l.menuFailStorefrontNotLoaded;
String _photoPicker(AppLocalizations l, Map<String, Object?> a) =>
    l.menuFailPhotoPicker;
