import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/failure.dart';
import '../../core/money.dart';
import '../../core/time_format.dart';
import '../../domain/delivery_order.dart';
import '../../domain/staff.dart';
import '../../l10n/l10n.dart';
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/slide_to_confirm.dart';
import '../widgets/state_views.dart';
import 'order_widgets.dart';

/// PRT-004: one delivery order, everything the kitchen and the person
/// handing it over need, and the one next step for its status.
///
/// Steps after accepting cannot be undone, so they are slides, not taps
/// (partner PRD UI rules). Every action goes through [InboxController] so
/// the lists and the ringing stay in step with what happened here. If
/// another phone changed the order first, the server says so (409) and this
/// screen reloads to show the truth instead of guessing.
class DeliveryOrderScreen extends StatefulWidget {
  const DeliveryOrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<DeliveryOrderScreen> createState() => _DeliveryOrderScreenState();
}

class _DeliveryOrderScreenState extends State<DeliveryOrderScreen> {
  DeliveryOrder? _order;
  AppFailure? _failure;
  bool _loading = true;
  int? _prep;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final o = await AppScope.of(context).inbox.detail(widget.orderId);
      if (mounted) setState(() => _order = o);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _failure = e);
    } catch (e) {
      if (mounted) setState(() => _failure = asFailure(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Runs one inbox action and shows its outcome. Conflicts reload.
  Future<void> _act(
    Future<DeliveryOrder> Function(DeliveryOrder o) action,
    String done,
  ) async {
    final o = _order;
    if (o == null) return;
    try {
      final updated = await action(o);
      if (!mounted) return;
      setState(() => _order = _merge(o, updated));
      showDone(context, done);
    } on AppFailure catch (e) {
      if (!mounted) return;
      showFailure(context, e);
      if (e.isConflict) await _load();
    }
  }

  /// Action replies may leave out the timeline or phone; keep what we had.
  DeliveryOrder _merge(DeliveryOrder before, DeliveryOrder after) =>
      after.copyWith(
        events: after.events.isEmpty ? before.events : null,
        customerPhone: after.customerPhone ?? before.customerPhone,
      );

  Future<void> _reject() async {
    final reason = await showRejectSheet(context);
    if (reason == null || !mounted) return;
    final inbox = AppScope.of(context).inbox;
    await _act((o) => inbox.reject(o, reason), context.l10n.ordersRejectedDone);
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(o?.displayNo ?? l.commonOrder),
        actions: [
          IconButton(
            tooltip: l.commonRefresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: o == null
          ? (_failure != null && !_loading
                ? FailureView(failure: _failure!, onRetry: _load)
                : LoadingView(label: l.ordersLoadingOrder))
          : RefreshIndicator(
              onRefresh: _load,
              child: _Body(order: o),
            ),
      bottomNavigationBar: o == null
          ? null
          : ListenableBuilder(
              listenable: AppScope.of(context).inbox,
              builder: (context, _) =>
                  _actions(context, o) ?? const SizedBox.shrink(),
            ),
    );
  }

  Widget? _actions(BuildContext context, DeliveryOrder o) {
    final services = AppScope.of(context);
    final inbox = services.inbox;
    final s = services.session;
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final busy = inbox.busy.contains(o.id);

    Widget? child;
    switch (o.status) {
      case DeliveryStatus.placed:
        if (s.can(Capability.acceptOrders)) {
          final prep = _prep ?? defaultPrepMinutes(inbox.outlet);
          child = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.ordersReadyIn,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: t.inkSecondary,
                ),
              ),
              const SizedBox(height: 8),
              PrepTimeChips(
                value: prep,
                onChanged: (m) => setState(() => _prep = m),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: t.danger,
                          side: BorderSide(
                            color: t.danger.withValues(alpha: 0.4),
                          ),
                        ),
                        onPressed: busy ? null : _reject,
                        child: Text(l.ordersReject),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ViniiColors.brandGreen,
                          foregroundColor: ViniiColors.ink,
                        ),
                        onPressed: busy
                            ? null
                            : () => _act(
                                (x) => inbox.accept(x, prep),
                                l.ordersAcceptedDone(minutes: prep),
                              ),
                        child: busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: ViniiColors.ink,
                                ),
                              )
                            : Text(l.ordersAcceptWithPrep(minutes: prep)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      case DeliveryStatus.accepted:
        if (s.can(Capability.markReady)) {
          child = SlideToConfirm(
            label: l.ordersMarkReady,
            color: t.success,
            busy: busy,
            onConfirmed: () => _act(inbox.markReady, l.ordersMarkedReadyDone),
          );
        }
      case DeliveryStatus.packed:
        if (s.can(Capability.dispatchOrders)) {
          child = SlideToConfirm(
            label: l.ordersSlideOut,
            color: ViniiColors.purple,
            busy: busy,
            onConfirmed: () => _act(inbox.markOut, l.ordersOnTheWayDone),
          );
        }
      case DeliveryStatus.out:
        if (s.can(Capability.dispatchOrders)) {
          child = SlideToConfirm(
            label: l.ordersSlideDelivered(amount: rupees(o.total)),
            color: ViniiColors.brandGreen,
            busy: busy,
            onConfirmed: () => _act(
              inbox.markDelivered,
              l.ordersDeliveredDone(amount: rupees(o.total)),
            ),
          );
        }
      case DeliveryStatus.delivered:
      case DeliveryStatus.cancelled:
        return null;
    }

    child ??= Text(
      l.ordersViewOnlyRole,
      textAlign: TextAlign.center,
      style: TextStyle(color: t.inkMuted, fontSize: 13.5),
    );

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: child,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final o = order;
    final notes = o.notes?.trim();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _Header(order: o),
        if (o.status == DeliveryStatus.cancelled && o.cancelReason != null) ...[
          const SizedBox(height: 12),
          NoticeBanner(
            icon: Icons.cancel_outlined,
            tone: t.danger,
            message: l.ordersCancelledBanner(
              reason: cancelReasonLabel(l, o.cancelReason!),
            ),
          ),
        ],
        if (o.prepMinutes != null &&
            o.status != DeliveryStatus.placed &&
            o.status != DeliveryStatus.cancelled) ...[
          const SizedBox(height: 12),
          NoticeBanner(
            icon: Icons.timer_outlined,
            tone: t.warning,
            message: l.ordersPrepTimeBanner(minutes: o.prepMinutes!),
          ),
        ],
        const SizedBox(height: 12),
        _Customer(order: o),
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: l.ordersCustomerNote,
            color: t.tint(t.warning),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_rounded, color: t.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    notes,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: itemCountLabel(l, o.itemCount),
          child: Column(
            children: [for (final l in o.items) DeliveryLineRow(l)],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l.commonBill,
          child: Column(
            children: [
              AmountRow(l.commonSubtotal, rupees(o.subtotal)),
              AmountRow(l.ordersGst, rupees(o.gst)),
              AmountRow(l.ordersDeliveryFee, rupees(o.deliveryFee)),
              Divider(height: 18, color: t.border),
              AmountRow(l.commonTotal, rupees(o.total), strong: true),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.payments_outlined, size: 18, color: t.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      orderPaymentLabel(l, o.payment),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: t.success,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (o.events.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: l.ordersTimeline,
            child: _Timeline(events: o.events),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final o = order;
    final outlet = AppScope.of(context).inbox.outlet;
    return SectionCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A wrap, not a row: a longer status word moves under the
                // number instead of overflowing.
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      o.displayNo,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    StatusChip.delivery(context, o.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l.ordersPlacedLine(
                    time: clockTime(o.placedAt),
                    ago: timeAgo(l, o.placedAt),
                    channel: o.channel,
                  ),
                  style: TextStyle(color: t.inkSecondary, fontSize: 13.5),
                ),
              ],
            ),
          ),
          if (o.status == DeliveryStatus.placed)
            MiniCountdown(
              deadline: acceptDeadline(o, outlet),
              window: acceptWindow(o, outlet),
            ),
        ],
      ),
    );
  }
}

class _Customer extends StatelessWidget {
  const _Customer({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final o = order;
    final phone = o.customerPhone?.trim();
    final place = o.address ?? o.area;
    return SectionCard(
      title: l.commonCustomer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: t.surfaceMuted,
                child: Text(
                  firstName(l, o.customerName).substring(0, 1).toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w800, color: t.ink),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  customerDisplayName(l, o.customerName),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
              ),
            ],
          ),
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 18, color: t.inkSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    phone,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.ordersCopyNumber,
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: phone));
                    if (context.mounted) {
                      showDone(context, l.ordersNumberCopied);
                    }
                  },
                ),
              ],
            ),
          ],
          if (place != null && place.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: t.inkSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    place,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: t.ink,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A vertical stepper of `order_events`, oldest first.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<OrderEvent> events;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
    return Column(
      children: [
        for (final (i, e) in sorted.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: i == sorted.length - 1 ? t.ink : t.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.ink, width: 2),
                        ),
                      ),
                      if (i < sorted.length - 1)
                        Expanded(child: Container(width: 2, color: t.border)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < sorted.length - 1 ? 16 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                orderEventLabel(l, e),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: t.ink,
                                ),
                              ),
                            ),
                            Text(
                              clockTime(e.at),
                              style: TextStyle(color: t.inkMuted, fontSize: 13),
                            ),
                          ],
                        ),
                        if (e.message != null && e.message!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              e.message!,
                              style: TextStyle(
                                color: t.inkSecondary,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
