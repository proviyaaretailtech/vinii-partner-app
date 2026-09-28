import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import 'about_screen.dart';
import 'settings_screen.dart';

final moreBranchRoutes = <RouteBase>[
  GoRoute(
    path: Routes.more,
    builder: (context, state) => const SettingsScreen(),
    routes: [
      GoRoute(path: 'about', builder: (context, state) => const AboutScreen()),
    ],
  ),
];
