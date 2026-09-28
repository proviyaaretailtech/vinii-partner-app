import 'package:go_router/go_router.dart';

import '../application/session_controller.dart';
import '../domain/app_definition.dart';
import '../presentation/auth/forgot_password_screen.dart';
import '../presentation/auth/no_access_screen.dart';
import '../presentation/auth/sign_in_screen.dart';
import '../presentation/boot/splash_screen.dart';
import '../presentation/boot/update_required_screen.dart';
import '../presentation/guest/guest_routes.dart';
import '../presentation/menu/menu_routes.dart';
import '../presentation/onboarding/intro_screen.dart';
import '../presentation/orders/orders_routes.dart';
import '../presentation/org/org_picker_screen.dart';
import '../presentation/pos/sell_routes.dart';
import '../presentation/settings/more_routes.dart';
import '../presentation/shell/home_shell.dart';
import '../presentation/studio/studio_routes.dart';
import 'app_scope.dart';
import 'routes.dart';

/// The branch order of the home shell. Must match [AppTab]'s order.
const tabRoots = {
  AppTab.orders: Routes.orders,
  AppTab.sell: Routes.sell,
  AppTab.menu: Routes.menu,
  AppTab.storefront: Routes.storefront,
  AppTab.more: Routes.more,
};

AppTab? tabForLocation(String location) {
  for (final e in tabRoots.entries) {
    if (location == e.value || location.startsWith('${e.value}/')) return e.key;
  }
  return null;
}

/// One screen per lifecycle stage; the tabs only when the session is ready,
/// and only the tabs this person's application definition allows.
GoRouter buildRouter(AppServices services) {
  final session = services.session;
  return GoRouter(
    initialLocation: Routes.boot,
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final gate = switch (session.stage) {
        SessionStage.booting ||
        SessionStage.notConfigured ||
        SessionStage.bootError => Routes.boot,
        SessionStage.intro => Routes.intro,
        SessionStage.signedOut =>
          (loc == Routes.resetPassword ? Routes.resetPassword : Routes.signIn),
        SessionStage.noAccess => Routes.noAccess,
        SessionStage.choosingOrg => Routes.organizations,
        SessionStage.updateRequired => Routes.updateRequired,
        SessionStage.ready => null,
      };
      if (gate != null) return loc == gate ? null : gate;

      final def = session.definition!;
      final home = tabRoots[def.home]!;
      if (Routes.gates.contains(loc)) return home;
      final tab = tabForLocation(loc);
      if (tab != null && !def.tabs.contains(tab)) return home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.boot,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.intro,
        builder: (context, state) => const IntroScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
        routes: [
          GoRoute(
            path: 'reset',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.noAccess,
        builder: (context, state) => const NoAccessScreen(),
      ),
      GoRoute(
        path: Routes.organizations,
        builder: (context, state) => const OrgPickerScreen(),
      ),
      GoRoute(
        path: Routes.updateRequired,
        builder: (context, state) => const UpdateRequiredScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: ordersBranchRoutes),
          StatefulShellBranch(routes: sellBranchRoutes),
          StatefulShellBranch(routes: menuBranchRoutes),
          StatefulShellBranch(routes: storefrontBranchRoutes),
          StatefulShellBranch(routes: moreBranchRoutes),
        ],
      ),
      ...ordersRootRoutes,
      ...studioRootRoutes,
      ...guestRootRoutes,
    ],
  );
}
