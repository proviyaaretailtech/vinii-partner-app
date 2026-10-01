import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../application/guest_gateway.dart';
import '../../core/failure.dart';
import '../../domain/menu.dart';
import '../../domain/pos_order.dart';
import '../../domain/staff.dart';
import '../../domain/storefront.dart';
import '../widgets/state_views.dart';
import 'guest_app.dart';

final guestRootRoutes = <RouteBase>[
  GoRoute(
    path: '/guest',
    builder: (context, state) =>
        GuestHostScreen(tableId: state.uri.queryParameters['table']),
  ),
];

/// Staff "Hand to guest": loads the organization's real menu, its PUBLISHED
/// storefront (never a draft) and the table, then gives the phone to the
/// guest runtime. Orders go through the POS front door marked as placed by
/// the guest (contract R10). The staff screens around it (loading, errors,
/// "publish first") use the staff look; the guest never sees them.
class GuestHostScreen extends StatefulWidget {
  const GuestHostScreen({super.key, this.tableId});

  /// Preselects the party's table (`/guest?table=<id>`).
  final String? tableId;

  @override
  State<GuestHostScreen> createState() => _GuestHostScreenState();
}

typedef _Loaded = ({
  MenuSnapshot menu,
  StorefrontDefinition? published,
  DiningTable? table,
});

class _GuestHostScreenState extends State<GuestHostScreen> {
  Future<_Loaded>? _load;
  GuestOrderGateway? _gateway;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = AppScope.of(context).session;
    if (session.can(Capability.handToGuest) && session.membership != null) {
      _load ??= _fetch();
    }
  }

  Future<_Loaded> _fetch() async {
    final services = AppScope.of(context);
    final backend = services.backend;
    final org = services.session.membership!.organization;
    _gateway ??= PosGuestGateway(backend.pos);
    final menu = backend.menu.load();
    final storefront = backend.storefront.load(org);
    final tables = widget.tableId == null
        ? Future.value(const <DiningTable>[])
        : backend.pos.tables();
    final MenuSnapshot m;
    final StorefrontState sf;
    final List<DiningTable> t;
    try {
      (m, sf, t) = await (menu, storefront, tables).wait;
    } on ParallelWaitError<
      (MenuSnapshot?, StorefrontState?, List<DiningTable>?),
      (AsyncError?, AsyncError?, AsyncError?)
    > catch (e) {
      // Show the first real reason, not the wrapper.
      final first = [e.errors.$1, e.errors.$2, e.errors.$3].nonNulls.first;
      throw asFailure(first.error);
    }
    return (
      menu: m,
      published: sf.published?.definition,
      table: t.where((x) => x.id == widget.tableId).firstOrNull,
    );
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.sell);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    if (!session.can(Capability.handToGuest) || session.membership == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyView(
          icon: Icons.lock_outline_rounded,
          title: 'Not allowed',
          message: 'Your role cannot hand this phone to guests.',
          actionLabel: 'Back',
          onAction: _leave,
        ),
      );
    }
    return FutureBuilder<_Loaded>(
      future: _load,
      builder: (context, snap) {
        if (snap.hasError) {
          final f = asFailure(snap.error!);
          return Scaffold(
            appBar: AppBar(),
            body: FailureView(
              failure: f,
              onRetry: () => setState(() => _load = _fetch()),
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: LoadingView(label: 'Getting the menu ready…'),
          );
        }
        final data = snap.data!;
        if (data.published == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyView(
              icon: Icons.storefront_outlined,
              title: 'Publish your storefront in Studio first',
              message:
                  'Guests see the published storefront. Open Storefront, '
                  'check the preview and publish it, then hand the phone over.',
              actionLabel: 'Back',
              onAction: _leave,
            ),
          );
        }
        return GuestApp(
          definition: data.published!,
          menu: data.menu,
          gateway: _gateway!,
          table: data.table,
          onExit: _leave,
          mediaBaseUrl: AppScope.of(context).config.mediaBaseUrl,
        );
      },
    );
  }
}
