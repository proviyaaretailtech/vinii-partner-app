import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/failure.dart';
import '../../core/money.dart';
import '../../core/time_format.dart';
import '../../domain/pos_order.dart';
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/state_views.dart';

/// Today's POS orders that are not paid or cancelled, newest first — so a
/// cashier can find a held order or take the payment for a table.
Future<void> showOpenOrders(BuildContext context) async {
  final picked = await showModalBottomSheet<PlacedOrder>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _OpenOrdersSheet(),
  );
  if (picked != null && context.mounted) {
    await context.push(Routes.posOrder(picked.id), extra: picked);
  }
}

class _OpenOrdersSheet extends StatefulWidget {
  const _OpenOrdersSheet();

  @override
  State<_OpenOrdersSheet> createState() => _OpenOrdersSheetState();
}

class _OpenOrdersSheetState extends State<_OpenOrdersSheet> {
  List<PlacedOrder>? _orders;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failure = null);
    try {
      final rows = await AppScope.of(context).backend.pos.openOrders();
      if (mounted) setState(() => _orders = rows);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _failure = e);
    } catch (e) {
      if (mounted) setState(() => _failure = asFailure(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final orders = _orders;
    Widget body;
    if (_failure != null) {
      body = SizedBox(
        height: 300,
        child: FailureView(failure: _failure!, onRetry: _load),
      );
    } else if (orders == null) {
      body = const SizedBox(height: 220, child: LoadingView());
    } else if (orders.isEmpty) {
      body = const SizedBox(
        height: 300,
        child: EmptyView(
          icon: Icons.receipt_long_outlined,
          title: 'No open orders',
          message:
              "Today's unpaid orders show here, from this phone and the POS.",
        ),
      );
    } else {
      body = Flexible(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final o = orders[i];
            final where = o.table?.displayName ?? o.serviceType.label;
            return Material(
              color: t.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pop(context, o),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    o.displayNo,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: t.ink,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusChip.pos(context, o.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$where · ${clockTime(o.createdAt)}',
                              style: TextStyle(
                                color: t.inkSecondary,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        rupees(o.bill.payable),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: t.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(child: Text('Open orders', style: text.titleLarge)),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }
}
