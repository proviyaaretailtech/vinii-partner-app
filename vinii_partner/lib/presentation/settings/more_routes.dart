import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../bill_settings/bill_settings_screen.dart';
import '../table_codes/table_codes_screen.dart';
import '../team/team_screen.dart';
import 'about_screen.dart';
import 'language_screen.dart';
import 'settings_screen.dart';

final moreBranchRoutes = <RouteBase>[
  GoRoute(
    path: Routes.more,
    builder: (context, state) => const SettingsScreen(),
    routes: [
      GoRoute(path: 'about', builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: 'language',
        builder: (context, state) => const LanguageScreen(),
      ),
      GoRoute(
        path: 'bill',
        builder: (context, state) => const BillSettingsScreen(),
      ),
      GoRoute(path: 'team', builder: (context, state) => const TeamScreen()),
      GoRoute(
        path: 'tables',
        builder: (context, state) => const TableCodesScreen(),
      ),
    ],
  ),
];
