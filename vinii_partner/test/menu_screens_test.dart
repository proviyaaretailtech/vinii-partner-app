import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/app/routes.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/data/backend.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/staff.dart';
import 'package:vinii_partner/presentation/menu/menu_routes.dart';
import 'package:vinii_partner/presentation/studio/phone_preview.dart';
import 'package:vinii_partner/presentation/studio/studio_routes.dart';
import 'package:vinii_partner/presentation/theme/staff_theme.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

/// Rows for these tests only; the app itself never ships any.
const _menu = MenuSnapshot(
  categories: [
    MenuCategory(id: 'c1', name: 'Biriyani', sortOrder: 1),
    MenuCategory(id: 'c2', name: 'Drinks', sortOrder: 2),
  ],
  items: [
    MenuItem(
      id: 'i1',
      categoryId: 'c1',
      name: 'Chicken Biriyani',
      price: 280,
      foodType: FoodType.nonVeg,
      isRecommended: true,
      sortOrder: 1,
    ),
    MenuItem(
      id: 'i2',
      categoryId: 'c1',
      name: 'Veg Biriyani',
      price: 220,
      foodType: FoodType.veg,
      sortOrder: 2,
    ),
    MenuItem(
      id: 'i3',
      categoryId: 'c2',
      name: 'Masala Chai',
      price: 30,
      course: 'drink',
      isAvailable: false,
    ),
    MenuItem(id: 'i4', name: 'Water Bottle', price: 20),
  ],
);

Future<AppServices> _services(FakeBackend backend, String role) async {
  final s = await testServices(backend);
  s.session.user = const StaffUser(
    id: 'u-1',
    email: 'aarav@example.com',
    fullName: 'Aarav',
  );
  s.session.membership = membershipAs(role);
  return s;
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppServices services, {
  String at = Routes.menu,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: at,
    routes: [
      ...menuBranchRoutes,
      ...storefrontBranchRoutes,
      ...studioRootRoutes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp.router(
        theme: staffTheme(brightness: Brightness.light),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _switchFor(String dish) => find.descendant(
  of: find.widgetWithText(InkWell, dish),
  matching: find.byType(Switch),
);

void main() {
  setUp(() => PhoneScreen.embedGuestApp = false);

  testWidgets('the menu lists real items by category, in menu order', (
    tester,
  ) async {
    final backend = FakeBackend(menu: _menu);
    await _pumpApp(tester, await _services(backend, 'org_owner'));

    expect(find.text('BIRIYANI · 2'), findsOneWidget);
    expect(find.text('DRINKS · 1'), findsOneWidget);
    expect(find.text('UNCATEGORISED · 1'), findsOneWidget);
    expect(find.text('Chicken Biriyani'), findsOneWidget);
    expect(find.text('₹280'), findsOneWidget);
    expect(find.text('Bestseller'), findsOneWidget);
    // The "Sold out" count at the top and the mark on Masala Chai.
    expect(find.text('Sold out'), findsNWidgets(2));
    expect(find.text('Add item'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'chai');
    await tester.pumpAndSettle();
    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Chicken Biriyani'), findsNothing);
  });

  testWidgets('an empty menu says so and offers the first steps', (
    tester,
  ) async {
    await _pumpApp(tester, await _services(FakeBackend(), 'org_owner'));
    expect(find.text('Your menu is empty'), findsOneWidget);
    expect(find.text('Add a category'), findsOneWidget);
    expect(find.text('Add a dish'), findsOneWidget);
  });

  testWidgets('a kitchen login can browse but not change the menu', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      await _services(FakeBackend(menu: _menu), 'kitchen'),
    );
    expect(find.text('Chicken Biriyani'), findsOneWidget);
    expect(find.text('Add item'), findsNothing);
    final s = tester.widget<Switch>(_switchFor('Chicken Biriyani'));
    expect(s.onChanged, isNull);
  });

  testWidgets('the availability switch updates the item through the backend', (
    tester,
  ) async {
    final backend = FakeBackend(menu: _menu);
    await _pumpApp(tester, await _services(backend, 'manager'));

    await tester.tap(_switchFor('Chicken Biriyani'));
    await tester.pumpAndSettle();

    expect(backend.menuSnapshot.item('i1')!.isAvailable, isFalse);
    expect(
      tester.widget<Switch>(_switchFor('Chicken Biriyani')).value,
      isFalse,
    );
  });

  testWidgets('a refused availability change flips back and says why', (
    tester,
  ) async {
    final backend = _RefusingBackend(menu: _menu);
    await _pumpApp(tester, await _services(backend, 'manager'));

    await tester.tap(_switchFor('Chicken Biriyani'));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(_switchFor('Chicken Biriyani')).value, isTrue);
    expect(find.text('You are offline.'), findsOneWidget);
  });

  testWidgets('the item editor checks name and price, then saves', (
    tester,
  ) async {
    final backend = FakeBackend(menu: _menu);
    await _pumpApp(
      tester,
      await _services(backend, 'org_owner'),
      at: '${Routes.menuNewItem}?category=c1',
    );

    expect(find.text('New item'), findsOneWidget);
    await tester.tap(find.text('Add to menu'));
    await tester.pumpAndSettle();
    expect(find.text('Give the dish a name'), findsOneWidget);
    expect(find.text('Enter a price'), findsOneWidget);
    expect(backend.menuSnapshot.items, hasLength(4));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Mutton Biriyani',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Price'), '340');

    // Storefront details go into the storefront draft, not the POS row.
    await tester.scrollUntilVisible(
      find.widgetWithText(FilterChip, 'Spicy'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Spicy'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Spicy'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add to menu'));
    await tester.pumpAndSettle();

    final saved = backend.menuSnapshot.items.firstWhere(
      (i) => i.name == 'Mutton Biriyani',
    );
    expect(saved.price, 340);
    expect(saved.categoryId, 'c1');
    final draft = backend.storefrontState.draft;
    expect(draft, isNotNull);
    expect(draft!.presentationOf(saved.id).tags, ['Spicy']);
    expect(backend.storefrontState.published, isNull);

    // Back on the list, with the new dish in its category.
    expect(find.text('BIRIYANI · 3'), findsOneWidget);
  });

  testWidgets('editing an existing item keeps its id and saves changes', (
    tester,
  ) async {
    final backend = FakeBackend(menu: _menu);
    await _pumpApp(
      tester,
      await _services(backend, 'manager'),
      at: Routes.menuItem('i2'),
    );
    expect(find.text('Edit item'), findsOneWidget);
    final name = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Name'),
    );
    expect(name.controller!.text, 'Veg Biriyani');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Price'),
      '240.50',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(backend.menuSnapshot.item('i2')!.price, 240.5);
    expect(backend.menuSnapshot.items, hasLength(4));
  });

  testWidgets('marketing edits storefront details, never the POS row', (
    tester,
  ) async {
    final backend = FakeBackend(menu: _menu);
    await _pumpApp(
      tester,
      await _services(backend, 'marketing_manager'),
      at: Routes.menuItem('i1'),
    );
    expect(find.text('Item'), findsOneWidget);
    final name = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Name'),
    );
    expect(name.enabled, isFalse);

    await tester.scrollUntilVisible(
      find.text('Hide from storefront'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Hide from storefront'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide from storefront'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(backend.storefrontState.draft!.presentationOf('i1').hidden, isTrue);
    expect(backend.menuSnapshot.item('i1')!.isAvailable, isTrue);
    expect(backend.menuSnapshot.item('i1')!.price, 280);
  });

  testWidgets('a kitchen login sees an item read-only, with no save', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      await _services(FakeBackend(menu: _menu), 'kitchen'),
      at: Routes.menuItem('i1'),
    );
    expect(find.text('Item'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);
    expect(find.text('On your storefront'.toUpperCase()), findsNothing);
    expect(
      find.text('Only owners, admins and managers can change dishes.'),
      findsOneWidget,
    );
  });

  testWidgets('a dish that no longer exists says so', (tester) async {
    await _pumpApp(
      tester,
      await _services(FakeBackend(menu: _menu), 'org_owner'),
      at: Routes.menuItem('gone'),
    );
    expect(find.text('This dish is no longer on the menu'), findsOneWidget);
  });

  testWidgets('categories can be added and are counted', (tester) async {
    final backend = FakeBackend(menu: _menu);
    await _pumpApp(
      tester,
      await _services(backend, 'org_owner'),
      at: Routes.menuCategories,
    );
    expect(find.text('Biriyani'), findsOneWidget);
    expect(find.text('2 dishes'), findsOneWidget);

    await tester.tap(find.text('Add category'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Desserts');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      backend.menuSnapshot.categories.map((c) => c.name),
      contains('Desserts'),
    );
    expect(find.text('Desserts'), findsOneWidget);
  });
}

/// A backend whose availability writes are refused, to check the switch
/// flips back instead of showing a change nobody saved.
class _RefusingBackend extends FakeBackend {
  _RefusingBackend({super.menu});

  MenuRepository? _wrapped;

  @override
  MenuRepository get menu => _wrapped ??= _RefusingMenu(super.menu);
}

class _RefusingMenu implements MenuRepository {
  _RefusingMenu(this.inner);
  final MenuRepository inner;

  @override
  Future<void> setItemAvailable(String itemId, bool available) async =>
      throw const AppFailure('You are offline.', kind: FailureKind.offline);

  @override
  Future<MenuSnapshot> load() => inner.load();

  @override
  Future<MenuCategory> saveCategory(
    MenuCategory category, {
    required bool isNew,
  }) => inner.saveCategory(category, isNew: isNew);

  @override
  Future<void> deleteCategory(String categoryId) =>
      inner.deleteCategory(categoryId);

  @override
  Future<void> reorderCategories(List<String> ids) =>
      inner.reorderCategories(ids);

  @override
  Future<MenuItem> saveItem(MenuItem item, {required bool isNew}) =>
      inner.saveItem(item, isNew: isNew);

  @override
  Future<String> uploadItemImage(
    String itemId,
    Uint8List bytes, {
    required String extension,
  }) => inner.uploadItemImage(itemId, bytes, extension: extension);
}
