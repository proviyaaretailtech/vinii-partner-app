import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import 'categories_screen.dart';
import 'item_editor_screen.dart';
import 'menu_screen.dart';

/// The Menu tab: the list, one dish (`new` creates one; `?category=` picks
/// its category) and the categories screen. All inside the tab, so the
/// bottom navigation stays visible.
final menuBranchRoutes = <RouteBase>[
  GoRoute(
    path: Routes.menu,
    builder: (context, state) => const MenuScreen(),
    routes: [
      GoRoute(
        path: 'item/:id',
        builder: (context, state) => ItemEditorScreen(
          key: ValueKey('item-${state.pathParameters['id']}'),
          itemId: state.pathParameters['id']!,
          initialCategoryId: state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        path: 'categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
    ],
  ),
];
