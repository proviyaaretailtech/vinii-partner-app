import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../domain/app_definition.dart';
import '../../domain/delivery_order.dart';

/// The signed-in frame: bottom navigation built from this person's
/// application definition (only the tabs their organization and role
/// allow), and the new-order alert that opens over any tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _alertOpen = false;
  late final _inbox = AppScope.of(context).inbox;

  @override
  void initState() {
    super.initState();
    _inbox.addListener(_maybeShowAlert);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowAlert());
  }

  @override
  void dispose() {
    _inbox.removeListener(_maybeShowAlert);
    super.dispose();
  }

  Future<void> _maybeShowAlert() async {
    final next = _inbox.currentAlert;
    if (_alertOpen || next == null || !mounted) return;
    _alertOpen = true;
    await context.push(Routes.alert(next.id));
    _alertOpen = false;
    // Another order may have arrived while the first was on screen.
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowAlert());
    }
  }

  static const _icons = {
    AppTab.orders: (Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    AppTab.sell: (Icons.point_of_sale_outlined, Icons.point_of_sale_rounded),
    AppTab.menu: (
      Icons.restaurant_menu_outlined,
      Icons.restaurant_menu_rounded,
    ),
    AppTab.storefront: (Icons.storefront_outlined, Icons.storefront_rounded),
    AppTab.more: (Icons.person_outline_rounded, Icons.person_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final def = services.session.definition;
    if (def == null) return const SizedBox.shrink();
    final current = AppTab.values[widget.shell.currentIndex];
    final selected = def.tabs.indexOf(current).clamp(0, def.tabs.length - 1);
    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: ListenableBuilder(
        listenable: services.inbox,
        builder: (context, _) {
          final waiting = services.inbox.lists[InboxTab.fresh]?.length ?? 0;
          return NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (i) {
              final tab = def.tabs[i];
              final branch = AppTab.values.indexOf(tab);
              widget.shell.goBranch(
                branch,
                initialLocation: branch == widget.shell.currentIndex,
              );
            },
            destinations: [
              for (final tab in def.tabs)
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: tab == AppTab.orders && waiting > 0,
                    label: Text('$waiting'),
                    child: Icon(_icons[tab]!.$1),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: tab == AppTab.orders && waiting > 0,
                    label: Text('$waiting'),
                    child: Icon(_icons[tab]!.$2),
                  ),
                  label: tab.label,
                ),
            ],
          );
        },
      ),
    );
  }
}
