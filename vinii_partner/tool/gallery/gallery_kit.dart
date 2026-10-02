// The gallery's invented restaurants and stand-in services, shared by the
// browser build (main.dart) and the offline renderer (guest_review_test.dart).
//
// Plain Dart with nothing browser-only in it, so the Dart VM can load it too.
// NOT part of the app and never built into it. The dish names and prices are
// copied from the founder's two reference boards (docs/reference/). Nothing
// here is read from or written to Supabase.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vinii_partner/application/guest_coupons.dart';
import 'package:vinii_partner/application/guest_gateway.dart';
import 'package:vinii_partner/application/guest_payments.dart';
import 'package:vinii_partner/application/guest_social.dart';
import 'package:vinii_partner/data/payments/cashfree_checkout.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/domain/storefront.dart';
import 'package:vinii_partner/presentation/guest/guest_app.dart';

import 'gallery_nearby.dart';
import 'gallery_similar.dart';

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final q = Uri.base.queryParameters;
    final fixture = switch (q['t']) {
      'artisan' => Fixture.artisan(),
      'fresh' => Fixture.fresh(),
      _ => Fixture.bistro(),
    };
    final table = q['table'] == null
        ? null
        : DiningTable(id: 'gallery-t${q['table']}', label: '${q['table']}');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VINII design gallery (fixtures)',
      home: GuestApp(
        definition: fixture.definition,
        menu: fixture.menu,
        gateway: GalleryGateway.forFixture(fixture),
        table: table ?? const DiningTable(id: 'gallery-t12', label: '12'),
      ),
    );
  }
}

/// A local stand-in for the order front door. Orders live only in memory and
/// the kitchen "moves" them on a timer so live tracking can be reviewed.
class GalleryGateway extends GuestOrderGateway {
  /// [online] false stands for a restaurant with no online payment.
  GalleryGateway({this.online = true}) : _nearby = null, _similar = null;

  /// The gallery restaurant [f]: invented activity at "the tables around"
  /// and three invented "tables like yours", built from its own dishes.
  /// Switch them off in the address with ?nearby=0 and ?similar=0.
  GalleryGateway.forFixture(
    Fixture f, {
    this.online = true,
    Duration nearbyEvery = const Duration(seconds: 14),
  }) : _nearby = GalleryNearby(f.itemIds, every: nearbyEvery),
       _similar = GallerySimilarTables(f.baskets());

  final bool online;
  final GalleryNearby? _nearby;
  final GallerySimilarTables? _similar;

  @override
  GuestNearby? get nearby =>
      Uri.base.queryParameters['nearby'] == '0' ? null : _nearby;

  @override
  GuestSimilarTables? get similarTables =>
      Uri.base.queryParameters['similar'] == '0' ? null : _similar;

  var _n = 1252;

  @override
  bool get isPreview => false;

  /// Online payment is on unless ?pay=0, so the payments page can be reviewed.
  @override
  GuestPayments? get payments =>
      !online || Uri.base.queryParameters['pay'] == '0' ? null : _payments;
  final _payments = GalleryPayments();

  /// Coupon codes are on unless ?coupons=0 (or [online] is false for a
  /// restaurant that takes nothing online): SAVE10, FLAT50 and WELCOME.
  @override
  GuestCoupons? get coupons =>
      !online || Uri.base.queryParameters['coupons'] == '0' ? null : _coupons;
  final _coupons = GalleryCoupons();

  @override
  Future<BillCharges> charges() async => BillCharges.defaults;

  @override
  Future<PlacedOrder> place(PosOrderDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _n++;
    return PlacedOrder(
      id: 'gallery-$_n',
      version: 'v1',
      displayNo: 'VB$_n',
      status: PosStatus.sentToKitchen,
      serviceType: draft.serviceType,
      createdAt: DateTime.now(),
      lines: draft.lines,
      bill: draft.bill,
      table: draft.table,
      scheduledFor: draft.scheduledFor,
      placedBy: PlacedBy.guest,
    );
  }

  @override
  Stream<PlacedOrder> watch(PlacedOrder order) async* {
    yield order;
    for (final s in const [PosStatus.ready, PosStatus.delivered]) {
      await Future<void>.delayed(const Duration(seconds: 8));
      yield order.copyWith(status: s, version: 'v-${s.dbValue}');
    }
  }
}

/// A pretend coupon service for the gallery. Three invented codes; the real
/// server decides everything itself (docs/GUEST_SERVER_CONTRACT.md).
///   SAVE10  10% off the food, up to ₹100, on orders from ₹300
///   FLAT50  ₹50 off orders from ₹250
///   WELCOME ₹30 off any order
class GalleryCoupons extends GuestCoupons {
  GalleryCoupons();

  @override
  Future<CouponResult> check({
    required String code,
    required List<CartLine> lines,
    required ServiceType serviceType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final food = lines.fold<double>(0, (s, l) => s + l.lineTotal);
    CouponResult tooSmall(String code, double min) => CouponResult.invalid(
      code: code,
      message:
          'Add ₹${(min - food).ceil()} more to use $code '
          '(minimum order ₹${min.toInt()}).',
    );
    switch (code.toUpperCase()) {
      case 'SAVE10':
        if (food < 300) return tooSmall('SAVE10', 300);
        final off = (food * 0.10).clamp(0, 100).toDouble();
        return CouponResult.valid(
          code: 'SAVE10',
          discount: off,
          label: '10% off, up to ₹100',
        );
      case 'FLAT50':
        if (food < 250) return tooSmall('FLAT50', 250);
        return const CouponResult.valid(
          code: 'FLAT50',
          discount: 50,
          label: '₹50 off',
        );
      case 'WELCOME':
        return const CouponResult.valid(
          code: 'WELCOME',
          discount: 30,
          label: '₹30 off your first order',
        );
      default:
        return CouponResult.invalid(
          code: code,
          message: "That code isn't valid. Check it and try again.",
        );
    }
  }
}

/// A pretend payment service. With ?fakecf=1 the real Cashfree web checkout
/// runs against a pretend script; otherwise a dialog stands in for the
/// gateway's window so every outcome can be tried.
class GalleryPayments extends GuestPayments {
  GalleryPayments();

  var _asked = 0;
  CheckoutResult _chosen = CheckoutResult.completed;

  @override
  bool get available => true;

  @override
  bool get needsPayerPhone => true;

  @override
  Future<OnlinePayment> start({
    required List<PlacedOrder> orders,
    required double amount,
    required String idempotencyKey,
    String? payerPhone,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _asked = 0;
    return OnlinePayment(
      attemptId: 'gallery-$idempotencyKey',
      sessionId: 'session_gallery_only',
      amount: amount,
      linkUrl: 'https://pay.example.invalid/gallery/$idempotencyKey',
    );
  }

  @override
  Future<CheckoutResult> openCheckout(
    BuildContext context,
    OnlinePayment payment,
  ) async {
    if (Uri.base.queryParameters['fakecf'] == '1') {
      _chosen = await const CashfreeCheckout().open(payment);
      return _chosen;
    }
    final picked = await showDialog<CheckoutResult>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Simulated payment window'),
        content: const Text(
          'Design gallery only. In the real app this is the gateway\'s own '
          'window; no money moves here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, CheckoutResult.dropped),
            child: const Text('Close window'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, CheckoutResult.failed),
            child: const Text('Payment fails'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, CheckoutResult.completed),
            child: const Text('Pay successfully'),
          ),
        ],
      ),
    );
    return _chosen = picked ?? CheckoutResult.dropped;
  }

  @override
  Future<PaymentOutcome> outcome(OnlinePayment payment) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return switch (_chosen) {
      CheckoutResult.completed =>
        // A UPI approval is rarely instant: the first look says "pending".
        ++_asked < 2 ? PaymentOutcome.pending : PaymentOutcome.paid,
      CheckoutResult.failed => PaymentOutcome.failed,
      CheckoutResult.dropped => PaymentOutcome.dropped,
    };
  }
}

class Fixture {
  const Fixture(this.menu, this.definition);
  final MenuSnapshot menu;
  final StorefrontDefinition definition;

  /// Every dish id, in menu order.
  List<String> get itemIds => [for (final i in menu.items) i.id];

  /// Three invented orders of other tables, from this menu's own dishes: a
  /// starter and a main for a party of four, a lighter one, a sharing one.
  List<List<({String itemId, int qty})>> baskets() {
    final ids = itemIds;
    if (ids.length < 3) return const [];
    String at(int i) => ids[i % ids.length];
    return [
      [
        (itemId: at(0), qty: 2),
        (itemId: at(3), qty: 2),
        (itemId: at(ids.length - 1), qty: 4),
      ],
      [
        (itemId: at(1), qty: 1),
        (itemId: at(4), qty: 2),
        (itemId: at(6), qty: 1),
      ],
      [
        (itemId: at(2), qty: 2),
        (itemId: at(5), qty: 3),
        (itemId: at(ids.length - 2), qty: 2),
        (itemId: at(7), qty: 1),
      ],
    ];
  }

  static String _endsToday() {
    final now = DateTime.now();
    final h = (now.hour + 2).clamp(0, 23);
    return '${'$h'.padLeft(2, '0')}:59';
  }

  /// Board 1, "Vinii Bistro": dark and gold, dine-in with a table budget.
  factory Fixture.bistro() {
    const cats = [
      MenuCategory(id: 'c-starters', name: 'Starters', sortOrder: 1),
      MenuCategory(id: 'c-mains', name: 'Mains', sortOrder: 2),
      MenuCategory(id: 'c-pizza', name: 'Pizza', sortOrder: 3),
      MenuCategory(id: 'c-asian', name: 'Asian', sortOrder: 4),
      MenuCategory(id: 'c-desserts', name: 'Desserts', sortOrder: 5),
      MenuCategory(id: 'c-drinks', name: 'Drinks', sortOrder: 6),
    ];
    const items = [
      MenuItem(
        id: 'i-tikka',
        name: 'Paneer Tikka',
        price: 280,
        categoryId: 'c-starters',
        foodType: FoodType.veg,
        isRecommended: true,
        description: 'Cottage cheese marinated in yoghurt and spices, charred in the tandoor.',
      ),
      MenuItem(
        id: 'i-corn',
        name: 'Crispy Corn',
        price: 190,
        categoryId: 'c-starters',
        foodType: FoodType.veg,
        description: 'Golden corn tossed with pepper, onion and lime.',
        sortOrder: 1,
      ),
      MenuItem(
        id: 'i-c65',
        name: 'Chicken 65',
        price: 300,
        categoryId: 'c-starters',
        foodType: FoodType.nonVeg,
        description: 'Fiery fried chicken with curry leaf and green chilli.',
        sortOrder: 2,
      ),
      MenuItem(
        id: 'i-biryani',
        name: 'Chicken Biryani',
        price: 320,
        categoryId: 'c-mains',
        foodType: FoodType.nonVeg,
        isRecommended: true,
        description: 'Slow-cooked basmati layered with marinated chicken, saffron and fried onions.',
      ),
      MenuItem(
        id: 'i-butter',
        name: 'Butter Chicken',
        price: 360,
        categoryId: 'c-mains',
        foodType: FoodType.nonVeg,
        description: 'Tandoori chicken in a silky tomato and butter gravy.',
        sortOrder: 1,
      ),
      MenuItem(
        id: 'i-dal',
        name: 'Dal Makhani',
        price: 240,
        categoryId: 'c-mains',
        foodType: FoodType.veg,
        description: 'Black lentils simmered overnight with cream and butter.',
        sortOrder: 2,
      ),
      MenuItem(
        id: 'i-dosa',
        name: 'Masala Dosa',
        price: 180,
        categoryId: 'c-mains',
        foodType: FoodType.veg,
        description: 'Crisp rice crepe with spiced potato, chutney and sambar.',
        sortOrder: 3,
      ),
      MenuItem(
        id: 'i-margherita',
        name: 'Margherita Pizza',
        price: 290,
        categoryId: 'c-pizza',
        foodType: FoodType.veg,
        description: 'Tomato, fresh mozzarella and basil on a thin crust.',
      ),
      MenuItem(
        id: 'i-pepperoni',
        name: 'Pepperoni Pizza',
        price: 380,
        categoryId: 'c-pizza',
        foodType: FoodType.nonVeg,
        sortOrder: 1,
      ),
      MenuItem(
        id: 'i-penne',
        name: 'Penne Arrabbiata',
        price: 260,
        categoryId: 'c-asian',
        foodType: FoodType.veg,
        description: 'Classic Italian pasta tossed in spicy tomato sauce, garlic and fresh basil.',
      ),
      MenuItem(
        id: 'i-noodles',
        name: 'Veg Hakka Noodles',
        price: 210,
        categoryId: 'c-asian',
        foodType: FoodType.veg,
        sortOrder: 1,
      ),
      MenuItem(
        id: 'i-jamun',
        name: 'Gulab Jamun',
        price: 120,
        categoryId: 'c-desserts',
        foodType: FoodType.veg,
        description: 'Warm milk dumplings in cardamom syrup.',
      ),
      MenuItem(
        id: 'i-tiramisu',
        name: 'Tiramisu',
        price: 260,
        categoryId: 'c-desserts',
        foodType: FoodType.egg,
        sortOrder: 1,
      ),
      MenuItem(
        id: 'i-coffee',
        name: 'Cold Coffee',
        price: 150,
        categoryId: 'c-drinks',
        foodType: FoodType.veg,
        course: 'drink',
      ),
      MenuItem(
        id: 'i-lime',
        name: 'Fresh Lime Soda',
        price: 90,
        categoryId: 'c-drinks',
        foodType: FoodType.veg,
        course: 'drink',
        sortOrder: 1,
      ),
    ];
    return Fixture(
      const MenuSnapshot(categories: cats, items: items),
      StorefrontDefinition(
        template: StorefrontTemplate.bistroNight,
        accentHex: StorefrontTemplate.bistroNight.defaultAccent,
        brand: const StorefrontBrand(
          displayName: 'Vinii Bistro',
          locationLine: 'Indiranagar, Bengaluru',
          heroTitle: 'Food Looks Better When You Explore It.',
          heroSubtitle:
              'Swipe through dishes, set a budget, and order together.',
        ),
        serviceModes: const [GuestServiceMode.dineIn],
        features: const GuestFeatures(
          budget: BudgetSettings(defaultAmount: 7000, max: 20000, min: 1000),
        ),
        items: const {
          'i-tikka': ItemPresentation(
            itemId: 'i-tikka',
            tags: ['Chef Special'],
            ingredients: ['Paneer', 'Yoghurt', 'Capsicum', 'Onion'],
            allergens: ['Dairy'],
            kcal: 320,
          ),
          'i-penne': ItemPresentation(
            itemId: 'i-penne',
            tags: ['Chef Special'],
            ingredients: ['Tomato', 'Basil', 'Garlic', 'Pasta'],
            allergens: ['Gluten'],
            kcal: 410,
          ),
          'i-biryani': ItemPresentation(
            itemId: 'i-biryani',
            tags: ['Spicy'],
            ingredients: ['Basmati', 'Chicken', 'Saffron', 'Onion'],
            kcal: 520,
          ),
        },
        chefsPicks: const ['i-penne', 'i-tikka', 'i-tiramisu'],
        limitedToday: [
          LimitedOffer(itemId: 'i-jamun', endsAt: _endsToday()),
          LimitedOffer(itemId: 'i-margherita', endsAt: _endsToday()),
        ],
      ),
    );
  }

  /// Board 2, "The Windough": warm cream, handwritten headline, pre-orders.
  factory Fixture.artisan() {
    const cats = [
      MenuCategory(id: 'c-breads', name: 'Breads', sortOrder: 1),
      MenuCategory(id: 'c-viennoiserie', name: 'Viennoiserie', sortOrder: 2),
      MenuCategory(id: 'c-pastries', name: 'Pastries', sortOrder: 3),
      MenuCategory(id: 'c-cakes', name: 'Cakes', sortOrder: 4),
      MenuCategory(id: 'c-cafe', name: 'Café', sortOrder: 5),
    ];
    const items = [
      MenuItem(
        id: 'a-sourdough',
        name: 'Sourdough Loaf',
        price: 320,
        categoryId: 'c-breads',
        foodType: FoodType.veg,
        isRecommended: true,
        description: 'Long-ferment country loaf with a blistered crust.',
      ),
      MenuItem(
        id: 'a-scroll',
        name: 'Cinnamon Scroll',
        price: 220,
        categoryId: 'c-viennoiserie',
        foodType: FoodType.veg,
        isRecommended: true,
        description: 'Soft, layered dough with cinnamon, brown sugar and a hint of vanilla.',
      ),
      MenuItem(
        id: 'a-pistachio',
        name: 'Pistachio Croissant',
        price: 280,
        categoryId: 'c-viennoiserie',
        foodType: FoodType.veg,
        sortOrder: 1,
      ),
      MenuItem(
        id: 'a-almond',
        name: 'Almond Croissant',
        price: 260,
        categoryId: 'c-viennoiserie',
        foodType: FoodType.veg,
        sortOrder: 2,
      ),
      MenuItem(
        id: 'a-danish',
        name: 'Blueberry Danish',
        price: 240,
        categoryId: 'c-pastries',
        foodType: FoodType.veg,
      ),
      MenuItem(
        id: 'a-raspberry',
        name: 'Raspberry Danish',
        price: 260,
        categoryId: 'c-pastries',
        foodType: FoodType.veg,
        sortOrder: 1,
      ),
      MenuItem(
        id: 'a-cake',
        name: 'Honey Fig Tart',
        price: 320,
        categoryId: 'c-cakes',
        foodType: FoodType.veg,
      ),
      MenuItem(
        id: 'a-latte',
        name: 'Iced Latte',
        price: 240,
        categoryId: 'c-cafe',
        foodType: FoodType.veg,
        course: 'drink',
      ),
    ];
    return Fixture(
      const MenuSnapshot(categories: cats, items: items),
      StorefrontDefinition(
        template: StorefrontTemplate.artisanDay,
        accentHex: StorefrontTemplate.artisanDay.defaultAccent,
        brand: const StorefrontBrand(
          displayName: 'The Windough',
          tagline: 'Artisanal bakery & café',
          locationLine: 'Table 12',
          heroTitle: 'Good Food Rises People Together',
          heroSubtitle: 'Fresh bakes, honest ingredients and a little more joy for your table.',
        ),
        serviceModes: const [
          GuestServiceMode.dineIn,
          GuestServiceMode.preOrder,
        ],
        categoryStyle: CategoryStyle.wheel,
        features: const GuestFeatures(
          budget: BudgetSettings(defaultAmount: 3000),
        ),
        chefsPicks: const ['a-scroll', 'a-pistachio'],
        limitedToday: [
          LimitedOffer(itemId: 'a-raspberry', endsAt: _endsToday()),
        ],
      ),
    );
  }

  factory Fixture.fresh() {
    final b = Fixture.bistro();
    return Fixture(
      b.menu,
      b.definition.copyWith(
        template: StorefrontTemplate.freshMinimal,
        accentHex: StorefrontTemplate.freshMinimal.defaultAccent,
        brand: const StorefrontBrand(displayName: 'Green Bowl'),
      ),
    );
  }
}
