import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import 'studio_preview_screen.dart';
import 'studio_screen.dart';
import 'studio_section_screen.dart';

/// The Storefront tab: Studio and its sections, inside the tab.
final storefrontBranchRoutes = <RouteBase>[
  GoRoute(
    path: Routes.storefront,
    builder: (context, state) => const StudioScreen(),
    routes: [
      GoRoute(
        path: 'section/:key',
        builder: (context, state) => StudioSectionScreen(
          key: ValueKey('studio-${state.pathParameters['key']}'),
          sectionKey: state.pathParameters['key']!,
        ),
      ),
    ],
  ),
];

/// Full screen, above the tabs: the preview a guest would see.
final studioRootRoutes = <RouteBase>[
  GoRoute(
    path: Routes.storefrontPreview,
    builder: (context, state) => const StudioPreviewScreen(),
  ),
];
