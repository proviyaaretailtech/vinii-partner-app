import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../domain/pos_order.dart';
import 'checkout_screen.dart';
import 'pos_order_screen.dart';
import 'sell_screen.dart';

/// The Sell tab: menu → checkout → the saved order. Checkout and the order
/// are children of `/sell`, so "back" from a saved order returns to the
/// menu, not to a checkout that has already been sent.
final sellBranchRoutes = <RouteBase>[
  GoRoute(
    path: Routes.sell,
    builder: (context, state) => const SellScreen(),
    routes: [
      GoRoute(
        path: 'checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: 'order/:id',
        builder: (context, state) => PosOrderScreen(
          orderId: state.pathParameters['id']!,
          // Present when Checkout or Open orders hands the order over; a
          // restored or typed location loads it from the server instead.
          initial: state.extra is PlacedOrder
              ? state.extra! as PlacedOrder
              : null,
        ),
      ),
    ],
  ),
];
