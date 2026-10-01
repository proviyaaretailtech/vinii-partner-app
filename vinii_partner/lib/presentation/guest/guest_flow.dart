import 'package:flutter/material.dart';

import '../../domain/guest_catalog.dart';
import '../../domain/storefront.dart';
import 'guest_bill.dart';
import 'guest_browse.dart';
import 'guest_budget.dart';
import 'guest_categories.dart';
import 'guest_confirm.dart';
import 'guest_discover.dart';
import 'guest_item_detail.dart';
import 'guest_mode.dart';
import 'guest_order.dart';
import 'guest_payment.dart';
import 'guest_placed.dart';
import 'guest_preorder.dart';
import 'guest_tracking.dart';
import 'guest_widgets.dart';

/// The unified, config-driven journey in one place, so every screen asks
/// "what comes next?" here instead of knowing the storefront's settings:
///
/// Welcome → [mode] → [pre-order slot] → [party & budget] → categories →
/// deck ↔ detail ↔ budget ↔ discover → order → review → confirm → placed →
/// tracking → served → bill → order more.
class GuestFlow {
  const GuestFlow._();

  static NavigatorState _nav(BuildContext context) => Navigator.of(context);

  static Future<T?> _push<T>(
    BuildContext context,
    Widget page, {
    bool up = false,
  }) => _nav(context).push<T>(guestRoute<T>(page, up: up));

  /// From the welcome screen. [chosen] is set when the guest picked a mode
  /// on the welcome pills, so the mode question is skipped.
  static void start(BuildContext context, {GuestServiceMode? chosen}) {
    final s = GuestScope.read(context);
    if (chosen != null) s.update(() => s.mode = chosen);
    if (chosen == null && s.definition.serviceModes.length > 1) {
      _push<void>(context, const GuestModeScreen());
    } else {
      afterMode(context);
    }
  }

  static void afterMode(BuildContext context) {
    final s = GuestScope.read(context);
    if (s.mode == GuestServiceMode.preOrder) {
      _push<void>(context, const GuestPreOrderScreen());
    } else {
      afterSlot(context);
    }
  }

  static void afterSlot(BuildContext context) {
    final s = GuestScope.read(context);
    if (s.features.budget.enabled && !s.budgetAsked) {
      _push<void>(context, const GuestBudgetScreen());
    } else {
      toCategories(context);
    }
  }

  static void toCategories(BuildContext context) =>
      _push<void>(context, const GuestCategoriesScreen());

  /// [category] null = "All dishes".
  static void browse(BuildContext context, GuestCategory? category) =>
      _push<void>(context, GuestBrowseScreen(category: category));

  static Future<void> openItem(BuildContext context, GuestItem item) =>
      _push<void>(context, GuestItemDetailScreen(item: item), up: true);

  static void budgetOverview(BuildContext context) =>
      _push<void>(context, const GuestBudgetOverviewScreen(), up: true);

  static void discover(BuildContext context, {bool waiting = false}) =>
      _push<void>(context, GuestDiscoverScreen(waiting: waiting), up: true);

  static void toOrder(BuildContext context) =>
      _push<void>(context, const GuestOrderScreen());

  static void toReview(BuildContext context) =>
      _push<void>(context, const GuestReviewScreen());

  static void toConfirm(BuildContext context) =>
      _push<void>(context, const GuestConfirmScreen());

  /// After a successful place: the history behind is dropped, so "back"
  /// never returns to a cart that was already sent.
  static void placed(BuildContext context) => _nav(context).pushAndRemoveUntil(
    guestRoute<void>(const GuestPlacedScreen(), up: true),
    (r) => r.isFirst,
  );

  static void tracking(BuildContext context) =>
      _push<void>(context, const GuestTrackingScreen());

  static void served(BuildContext context) => _nav(context)
      .pushReplacement(guestRoute<void>(const GuestServedScreen(), up: true));

  static void bill(BuildContext context) =>
      _push<void>(context, const GuestBillScreen());

  /// Pay online. Only reachable when the gateway offers online payment.
  static void pay(BuildContext context) =>
      _push<void>(context, const GuestPaymentScreen(), up: true);

  /// A new round for the same party: fresh cart, same budget and table.
  static void orderMore(BuildContext context) => _nav(context)
      .pushAndRemoveUntil(
        guestRoute<void>(const GuestCategoriesScreen()),
        (r) => r.isFirst,
      );
}
