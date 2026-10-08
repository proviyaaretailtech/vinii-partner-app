/// Every path in the app, in one place. Feature route files and screens use
/// these instead of string literals.
class Routes {
  const Routes._();

  // Lifecycle gates (one per SessionStage).
  static const boot = '/boot';
  static const intro = '/intro';
  static const signIn = '/sign-in';
  static const resetPassword = '/sign-in/reset';
  static const noAccess = '/no-access';
  static const organizations = '/organizations';
  static const updateRequired = '/update';

  // Bottom-navigation tabs (branches of the home shell).
  static const orders = '/orders';
  static const sell = '/sell';
  static const menu = '/menu';
  static const storefront = '/storefront';
  static const more = '/more';

  // Inside tabs.
  static String deliveryOrder(String id) => '/orders/$id';
  static const sellCheckout = '/sell/checkout';
  static String posOrder(String id) => '/sell/order/$id';
  static String menuItem(String id) => '/menu/item/$id';
  static const menuNewItem = '/menu/item/new';
  static const menuCategories = '/menu/categories';
  static String storefrontSection(String key) => '/storefront/section/$key';
  static const about = '/more/about';
  static const language = '/more/language';
  static const billSettings = '/more/bill';
  static const team = '/more/team';
  static const tableCodes = '/more/tables';

  // Full screen, above the tabs.
  static String alert(String orderId) => '/alert/$orderId';
  static const storefrontPreview = '/storefront-preview';

  /// Hands the phone to a guest party. [tableId] preselects their table.
  static String guest({String? tableId}) =>
      tableId == null ? '/guest' : '/guest?table=$tableId';

  static const gates = {
    boot,
    intro,
    signIn,
    resetPassword,
    noAccess,
    organizations,
    updateRequired,
  };
}
