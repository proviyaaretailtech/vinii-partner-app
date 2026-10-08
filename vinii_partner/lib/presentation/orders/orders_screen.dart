import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../application/inbox_controller.dart';
import '../../core/money.dart';
import '../../core/time_format.dart';
import '../../domain/delivery_order.dart';
import '../../l10n/failure_text.dart';
import '../../l10n/l10n.dart';
import '../../l10n/labels.dart';
import '../../l10n/script_fonts.dart';
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/state_views.dart';
import 'order_widgets.dart';
import 'outlet_bar.dart';

/// PRT-002, the Orders home: the restaurant, whether it is taking One Local
/// orders, and the four inbox tabs.
///
/// The New tab is polled by [InboxController] every 5 s whatever screen is
/// open (that poll is what rings). The other tabs only matter while someone
/// is looking, so this screen refreshes the selected one every 10 s while
/// it is visible, and stops when another tab or screen covers it.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: InboxTab.values.length,
    vsync: this,
  )..addListener(_onTabChanged);
  late final InboxController _inbox = AppScope.of(context).inbox;
  Timer? _timer;
  bool _visible = true;

  InboxTab get _tab => InboxTab.values[_tabs.index];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_inbox.available) return;
      if (_inbox.lists[InboxTab.fresh] == null &&
          !_inbox.loading.contains(InboxTab.fresh)) {
        unawaited(_inbox.refresh(InboxTab.fresh));
      }
      if (_inbox.outlet == null && _inbox.outletFailure == null) {
        unawaited(_inbox.refreshOutlet());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The home shell turns tickers off for tabs that are not showing.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible && _inbox.available) {
      unawaited(_inbox.refresh(_tab, quiet: _inbox.lists[_tab] != null));
    }
    _visible = visible;
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging || !_inbox.available) return;
    unawaited(_inbox.refresh(_tab, quiet: _inbox.lists[_tab] != null));
    setState(() {});
  }

  void _tick() {
    if (!mounted || !_visible || !_inbox.available) return;
    if (_tab == InboxTab.fresh) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    unawaited(_inbox.refresh(_tab, quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final org = services.session.membership?.organization;
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final appBar = AppBar(
      toolbarHeight: 68,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            org?.name ?? l.commonOrders,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            l.ordersSubtitle,
            style: text.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
    if (!_inbox.available) {
      return Scaffold(
        appBar: appBar,
        body: EmptyView(
          icon: Icons.delivery_dining_outlined,
          title: l.ordersNotConnected,
          message: inboxUnavailableText(l, _inbox.unavailableReason),
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: ListenableBuilder(
        listenable: _inbox,
        builder: (context, _) => LayoutBuilder(
          builder: (context, box) => Column(
            children: [
              // The store status and any notices sit above the list. On a
              // short screen (a phone held sideways) they scroll within
              // their own band rather than pushing the list off the page.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: box.maxHeight * 0.6),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    children: [const OutletBar(), ..._banners(context)],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.border)),
                ),
                child: TabBar(
                  controller: _tabs,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  indicatorColor: t.ink,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: t.ink,
                  unselectedLabelColor: t.inkMuted,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: kScriptFontFallback,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontFamilyFallback: kScriptFontFallback,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: [
                    for (final tab in InboxTab.values)
                      Tab(
                        // Tall enough for a two-line Hindi label.
                        height: 56,
                        child: _TabLabel(
                          label: l.inboxTabLabel(tab),
                          count: _inbox.lists[tab]?.length,
                          urgent: tab == InboxTab.fresh,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    for (final tab in InboxTab.values) _OrderList(tab: tab),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _banners(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final outlet = _inbox.outlet;
    final failure = _inbox.outletFailure;
    final banners = <Widget>[
      if (failure != null)
        NoticeBanner(
          icon: Icons.cloud_off_rounded,
          tone: t.danger,
          message: failureText(l, failure),
          action: TextButton(
            onPressed: _inbox.refreshOutlet,
            child: Text(l.ordersRetry),
          ),
        ),
      if (outlet != null && !outlet.setUp)
        NoticeBanner(
          icon: Icons.storefront_outlined,
          message: l.ordersNotSetUp,
        ),
      if (outlet != null && outlet.missedInARow > 0)
        NoticeBanner(
          icon: Icons.warning_amber_rounded,
          tone: t.warning,
          message: l.ordersMissedInARow(count: outlet.missedInARow),
        ),
    ];
    return [
      for (final b in banners) ...[const SizedBox(height: 10), b],
    ];
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, this.count, this.urgent = false});

  final String label;
  final int? count;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final n = count ?? 0;
    final hot = urgent && n > 0;
    // The label wraps to a second line when the language needs the room (a
    // longer Hindi word), instead of shrinking or being cut off.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, textAlign: TextAlign.center, maxLines: 2)),
        if (n > 0) ...[
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: hot ? t.info : t.surfaceMuted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$n',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: hot ? Colors.white : t.inkSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One tab's list with its loading, empty and failed states.
class _OrderList extends StatelessWidget {
  const _OrderList({required this.tab});

  final InboxTab tab;

  static (IconData, String, String) _empty(AppLocalizations l, InboxTab tab) =>
      switch (tab) {
        InboxTab.fresh => (
          Icons.notifications_none_rounded,
          l.ordersEmptyNewTitle,
          l.ordersEmptyNewMessage,
        ),
        InboxTab.preparing => (
          Icons.soup_kitchen_outlined,
          l.ordersEmptyPreparingTitle,
          l.ordersEmptyPreparingMessage,
        ),
        InboxTab.ready => (
          Icons.shopping_bag_outlined,
          l.ordersEmptyReadyTitle,
          l.ordersEmptyReadyMessage,
        ),
        InboxTab.past => (
          Icons.history_rounded,
          l.ordersEmptyPastTitle,
          l.ordersEmptyPastMessage,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final inbox = AppScope.of(context).inbox;
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final rows = inbox.lists[tab];
    final failure = inbox.failures[tab];
    final loading = inbox.loading.contains(tab);

    if (rows == null) {
      if (failure != null && !loading) {
        return FailureView(failure: failure, onRetry: () => inbox.refresh(tab));
      }
      return LoadingView(label: l.ordersLoading);
    }

    return RefreshIndicator(
      color: t.ink,
      onRefresh: () => inbox.refresh(tab, quiet: true),
      child: LayoutBuilder(
        builder: (context, c) {
          if (rows.isEmpty) {
            final (icon, title, message) = _empty(l, tab);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: NoticeBanner(
                      icon: Icons.cloud_off_rounded,
                      tone: t.danger,
                      message: failureText(l, failure),
                    ),
                  ),
                SizedBox(
                  height: c.maxHeight * 0.85,
                  child: EmptyView(icon: icon, title: title, message: message),
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: rows.length + (failure != null ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (failure != null) {
                if (i == 0) {
                  return NoticeBanner(
                    icon: Icons.cloud_off_rounded,
                    tone: t.danger,
                    message: l.ordersShowingLastList(
                      message: failureText(l, failure),
                    ),
                  );
                }
                i -= 1;
              }
              return OrderCard(
                order: rows[i],
                showCountdown: tab == InboxTab.fresh,
              );
            },
          );
        },
      ),
    );
  }
}

/// An order in a list: number, age, customer, items, total and status.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.showCountdown = false});

  final DeliveryOrder order;
  final bool showCountdown;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final outlet = AppScope.of(context).inbox.outlet;
    final o = order;
    final who = [
      firstName(l, o.customerName),
      if (o.area != null && o.area!.trim().isNotEmpty) o.area!,
    ].join(' · ');
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(Routes.deliveryOrder(o.id)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: o.status == DeliveryStatus.placed
                  ? t.info.withValues(alpha: 0.45)
                  : t.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.displayNo,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: t.ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${timeAgo(l, o.placedAt)} · $who',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: t.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    rupees(o.total),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: t.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                itemsSummary(o),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14.5, color: t.ink, height: 1.35),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // A wrap, so a longer status word and the count move onto
                  // a second line instead of overflowing.
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip.delivery(context, o.status),
                        Text(
                          o.prepMinutes != null &&
                                  o.status == DeliveryStatus.accepted
                              ? l.ordersItemsPrep(
                                  count: o.itemCount,
                                  minutes: o.prepMinutes!,
                                )
                              : itemCountLabel(l, o.itemCount),
                          style: TextStyle(fontSize: 13, color: t.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (showCountdown && o.status == DeliveryStatus.placed)
                    MiniCountdown(
                      deadline: acceptDeadline(o, outlet),
                      window: acceptWindow(o, outlet),
                    )
                  else
                    Icon(Icons.chevron_right_rounded, color: t.inkMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
