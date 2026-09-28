/// The organization's menu — the POS "Item Master" (`menu_categories`,
/// `menu_items`). One Local, the POS and the guest storefront all sell these
/// same rows; nothing is copied.
class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final int sortOrder;

  MenuCategory copyWith({String? name, int? sortOrder}) => MenuCategory(
    id: id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

/// `menu_items.food_type`: veg, non_veg, egg.
enum FoodType {
  veg('veg', 'Veg'),
  nonVeg('non_veg', 'Non-veg'),
  egg('egg', 'Egg');

  const FoodType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static FoodType? fromDb(String? v) =>
      FoodType.values.where((f) => f.dbValue == v).firstOrNull;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.categoryId,
    this.description,
    this.imageUrl,
    this.foodType,
    this.course = 'eat',
    this.isAvailable = true,
    this.isRecommended = false,
    this.prepMinutes,
    this.sortOrder = 0,
  });

  final String id;
  final String? categoryId;
  final String name;

  /// Rupees, excluding GST (POS convention; GST is added on the bill).
  final double price;
  final String? description;

  /// Public URL in the `item-images` storage bucket, or null. Screens fall
  /// back to [FoodArt] so a menu without photos still looks deliberate.
  final String? imageUrl;
  final FoodType? foodType;

  /// `eat` or `drink` (`menu_items.course`).
  final String course;

  /// Available in the POS at all. Per-channel switches (One Local) live in
  /// `item_channel_status` and are handled by the channel screens.
  final bool isAvailable;

  /// Shown to guests as "Bestseller".
  final bool isRecommended;
  final int? prepMinutes;
  final int sortOrder;

  MenuItem copyWith({
    String? categoryId,
    bool clearCategory = false,
    String? name,
    double? price,
    String? description,
    String? imageUrl,
    bool clearImage = false,
    FoodType? foodType,
    String? course,
    bool? isAvailable,
    bool? isRecommended,
    int? prepMinutes,
    int? sortOrder,
  }) => MenuItem(
    id: id,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    name: name ?? this.name,
    price: price ?? this.price,
    description: description ?? this.description,
    imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
    foodType: foodType ?? this.foodType,
    course: course ?? this.course,
    isAvailable: isAvailable ?? this.isAvailable,
    isRecommended: isRecommended ?? this.isRecommended,
    prepMinutes: prepMinutes ?? this.prepMinutes,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

/// Categories with their items, in menu order. What the Sell screen, the
/// Menu screen and the guest storefront all render from.
class MenuSnapshot {
  const MenuSnapshot({required this.categories, required this.items});

  final List<MenuCategory> categories;
  final List<MenuItem> items;

  static const empty = MenuSnapshot(categories: [], items: []);

  List<MenuItem> itemsIn(String? categoryId) =>
      items.where((i) => i.categoryId == categoryId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  MenuItem? item(String id) => items.where((i) => i.id == id).firstOrNull;

  MenuCategory? category(String? id) =>
      categories.where((c) => c.id == id).firstOrNull;
}
