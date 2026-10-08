import '../../domain/menu.dart';
import '../../l10n/l10n.dart';

/// Words for the menu's codes. The diet marker (`food_type`) is a code in the
/// domain and on the wire; this is the one place that turns it into words for
/// the reader (docs/I18N.md rule 6). Other screens (the mark in
/// lib/presentation/widgets/chips.dart, the guest deck) import it from here.
extension MenuLabels on AppLocalizations {
  String foodTypeLabel(FoodType t) => switch (t) {
    FoodType.veg => menuFoodTypeVeg,
    FoodType.nonVeg => menuFoodTypeNonVeg,
    FoodType.egg => menuFoodTypeEgg,
  };

  /// A storefront tag by the English word that is STORED on the dish
  /// (`storefrontTags`). The stored value never changes with the language, so
  /// the guest storefront and later translations keep working from one
  /// source; only the chip the staff member reads is translated. A tag this
  /// build does not know shows as stored.
  String storefrontTagLabel(String stored) => switch (stored) {
    'Bestseller' => menuBestseller,
    'Spicy' => menuTagSpicy,
    "Chef's special" => menuTagChefsSpecial,
    'Seasonal' => menuTagSeasonal,
    'New' => menuTagNew,
    'Vegan' => menuTagVegan,
    'Jain' => menuTagJain,
    'Gluten-free' => menuTagGlutenFree,
    _ => stored,
  };

  /// An allergen by the English word that is STORED on the dish; see
  /// [storefrontTagLabel]. An allergen the owner typed shows as typed.
  String allergenLabel(String stored) => switch (stored) {
    'Gluten' => menuAllergenGluten,
    'Dairy' => menuAllergenDairy,
    'Egg' => menuAllergenEgg,
    'Nuts' => menuAllergenNuts,
    'Tree nuts' => menuAllergenTreeNuts,
    'Peanuts' => menuAllergenPeanuts,
    'Soy' => menuAllergenSoy,
    'Sesame' => menuAllergenSesame,
    'Shellfish' => menuAllergenShellfish,
    'Fish' => menuAllergenFish,
    'Mustard' => menuAllergenMustard,
    _ => stored,
  };
}
