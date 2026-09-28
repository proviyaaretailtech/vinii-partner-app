import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import 'delivery_order_screen.dart';
import 'new_order_alert_screen.dart';
import 'orders_screen.dart';

/// The Orders tab: the inbox and, inside it, one order's detail.
final ordersBranchRoutes = <RouteBase>[
  GoRoute(
    path: Routes.orders,
    builder: (context, state) => const OrdersScreen(),
    routes: [
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            DeliveryOrderScreen(orderId: state.pathParameters['id']!),
      ),
    ],
  ),
];

/// The new-order alert opens above the tabs (no bottom navigation), so it
/// covers whatever the person was doing, and slides up like a call screen.
final ordersRootRoutes = <RouteBase>[
  GoRoute(
    path: '/alert/:id',
    pageBuilder: (context, state) => MaterialPage<void>(
      key: state.pageKey,
      fullscreenDialog: true,
      child: NewOrderAlertScreen(orderId: state.pathParameters['id']!),
    ),
  ),
];
