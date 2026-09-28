import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../application/inbox_controller.dart';
import '../../core/failure.dart';
import '../../core/money.dart';
import '../../core/time_format.dart';
import '../../domain/delivery_order.dart';
import '../../domain/staff.dart';
import '../theme/staff_theme.dart';
import '../widgets/rings.dart';
import '../widgets/state_views.dart';
import 'order_widgets.dart';

/// PRT-003, the new-order alert (PRD §5): full screen over any tab while
/// the phone rings, with a 60-second countdown to accept.
///
/// The home shell opens it for [InboxController.currentAlert] and waits for
/// it to close, then opens the next one. So this screen must close itself
/// exactly once, whatever ends it: accepted, rejected, silenced, time up,
/// or answered on another phone (the order leaves the alert queue).
///
/// It is deliberately dark and loud whatever the app theme: it has to win
/// attention in a busy kitchen from across the counter.
class NewOrderAlertScreen extends StatefulWidget {
  const NewOrderAlertScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<NewOrderAlertScreen> createState() => _NewOrderAlertScreenState();
}

class _NewOrderAlertScreenState extends State<NewOrderAlertScreen> {
  late final InboxController _inbox = AppScope.of(context).inbox;
  DeliveryOrder? _order;
  int? _prep;

  /// Seen in the alert queue at least once, so leaving it means it was
  /// answered elsewhere (or expired), not that it was never there.
  bool _queued = false;

  /// This phone's accept or reject is in flight.
  bool _acting = false;

  /// Closing has started; queue changes no longer matter.
  bool _closing = false;
  bool _popped = false;
  Timer? _closeTimer;
  ({IconData icon, String title, String message})? _ending;

  @override
  void initState() {
    super.initState();
    final queued = _fromQueue();
    _queued = queued != null;
    _order =
        queued ??
        _inbox.lists[InboxTab.fresh]
            ?.where((o) => o.id == widget.orderId)
            .firstOrNull;
    _inbox.addListener(_onInbox);
    if (_order == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _end(
          icon: Icons.check_circle_outline_rounded,
          title: 'Already answered',
          message: 'This order is no longer waiting.',
        ),
      );
    }
  }

  DeliveryOrder? _fromQueue() =>
      _inbox.alertQueue.where((o) => o.id == widget.orderId).firstOrNull;

  void _onInbox() {
    if (!mounted) return;
    final q = _fromQueue();
    if (q != null) {
      // The poll brings a fresh version; actions must send the latest one.
      _queued = true;
      setState(() => _order = q);
      return;
    }
    if (_acting || _closing || !_queued) {
      setState(() {});
      return;
    }
    final o = _order;
    final expired =
        o != null && !DateTime.now().isBefore(acceptDeadline(o, _inbox.outlet));
    if (expired) {
      _timeUp();
    } else {
      _end(
        icon: Icons.devices_rounded,
        title: 'Answered on another phone',
        message: 'Someone else in the restaurant took care of this order.',
      );
    }
  }

  /// Shows why the alert is closing, then closes it after a moment.
  void _end({
    required IconData icon,
    required String title,
    required String message,
    Duration after = const Duration(seconds: 2),
  }) {
    if (_closing || !mounted) return;
    _closing = true;
    setState(() => _ending = (icon: icon, title: title, message: message));
    _closeTimer = Timer(after, _pop);
  }

  void _timeUp() {
    if (_closing || _acting || !mounted) return;
    _end(
      icon: Icons.timer_off_outlined,
      title: "Time's up",
      message: "The customer is told the restaurant didn't respond.",
    );
    _inbox.snooze(widget.orderId);
  }

  void _silence() {
    if (_closing) return;
    _closing = true;
    _inbox.snooze(widget.orderId);
    _pop();
  }

  /// Closes this screen once, including any sheet open on top of it.
  void _pop() {
    if (_popped || !mounted) return;
    _popped = true;
    _closeTimer?.cancel();
    final nav = Navigator.of(context);
    final me = ModalRoute.of(context);
    if (me != null && !me.isCurrent) nav.popUntil((r) => r == me);
    nav.pop();
  }

  Future<void> _answer(
    Future<DeliveryOrder> Function(DeliveryOrder o) action,
    String done,
  ) async {
    final o = _order;
    if (o == null || _acting || _closing) return;
    setState(() => _acting = true);
    try {
      await action(o);
      if (!mounted) return;
      _closing = true;
      showDone(context, done);
      _pop();
    } on AppFailure catch (e) {
      if (!mounted) return;
      showFailure(context, e);
      if (e.isConflict) {
        _closing = true;
        _pop();
      } else {
        setState(() => _acting = false);
      }
    }
  }

  Future<void> _accept(int prep) => _answer(
    (o) => _inbox.accept(o, prep),
    'Accepted ${_order?.displayNo ?? ''}. Ready in $prep min.',
  );

  Future<void> _reject() async {
    final reason = await showRejectSheet(context);
    if (reason == null || !mounted || _closing) return;
    await _answer(
      (o) => _inbox.reject(o, reason),
      'Rejected ${_order?.displayNo ?? ''}. The customer has been told.',
    );
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _inbox.removeListener(_onInbox);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppScope.of(context).session.membership?.organization.accent;
    return Theme(
      data: staffTheme(brightness: Brightness.dark, accent: accent),
      child: PopScope(
        canPop: false,
        // Back = silence. Popping without snoozing would reopen the alert.
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _silence();
        },
        child: Builder(builder: _scaffold),
      ),
    );
  }

  Widget _scaffold(BuildContext context) {
    final t = ViniiTokens.of(context);
    final o = _order;
    return Scaffold(
      backgroundColor: ViniiColors.pageDark,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _ending != null || o == null
              ? _Ending(
                  key: const ValueKey('ending'),
                  icon: _ending?.icon ?? Icons.hourglass_empty_rounded,
                  title: _ending?.title ?? 'One moment…',
                  message: _ending?.message ?? '',
                )
              : Column(
                  key: const ValueKey('alert'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(onSilence: _silence),
                    Expanded(
                      child: _Details(order: o, onTimeUp: _timeUp),
                    ),
                    _Actions(
                      order: o,
                      prep: _prep ?? defaultPrepMinutes(_inbox.outlet),
                      busy: _acting || _inbox.busy.contains(o.id),
                      onPrep: (m) => setState(() => _prep = m),
                      onAccept: _accept,
                      onReject: _reject,
                      tokens: t,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSilence});

  final VoidCallback onSilence;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ViniiColors.brandGreen.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: ViniiColors.brandGreen.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: ViniiColors.brandGreen,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'NEW ORDER · One Local',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ViniiColors.brandGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Spacer(),
          IconButton(
            tooltip: 'Silence',
            onPressed: onSilence,
            icon: Icon(Icons.volume_off_rounded, color: t.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.order, required this.onTimeUp});

  final DeliveryOrder order;
  final VoidCallback onTimeUp;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final outlet = AppScope.of(context).inbox.outlet;
    final o = order;
    final window = acceptWindow(o, outlet);
    final who = [
      firstName(o.customerName),
      if (o.area != null && o.area!.trim().isNotEmpty) o.area!,
    ].join(' · ');
    final notes = o.notes?.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Countdown(
              deadline: acceptDeadline(o, outlet),
              onDone: onTimeUp,
              builder: (context, left) {
                final color = countdownColor(context, left);
                return ProgressRing(
                  value: window.inMilliseconds == 0
                      ? 0
                      : left.inMilliseconds / window.inMilliseconds,
                  color: color,
                  trackColor: t.border,
                  size: 168,
                  stroke: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${left.inSeconds}',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1,
                          letterSpacing: -2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'seconds',
                        style: TextStyle(
                          color: t.inkSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            o.displayNo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: t.ink,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Placed ${clockTime(o.placedAt)} · $who',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.inkSecondary, fontSize: 15),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.border),
            ),
            child: Column(
              children: [
                for (final l in o.items) DeliveryLineRow(l),
                if (notes != null && notes.isNotEmpty) ...[
                  Divider(height: 16, color: t.border),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.sticky_note_2_rounded,
                        size: 18,
                        color: t.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notes,
                          style: TextStyle(
                            color: t.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Divider(height: 16, color: t.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${itemCountLabel(o.itemCount)} · total',
                              style: TextStyle(color: t.inkSecondary),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.payments_outlined,
                                  size: 16,
                                  color: t.success,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    o.payment,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: t.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        rupees(o.total),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: t.ink,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.order,
    required this.prep,
    required this.busy,
    required this.onPrep,
    required this.onAccept,
    required this.onReject,
    required this.tokens,
  });

  final DeliveryOrder order;
  final int prep;
  final bool busy;
  final ValueChanged<int> onPrep;
  final Future<void> Function(int prep) onAccept;
  final VoidCallback onReject;
  final ViniiTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final canAnswer = AppScope.of(context).session.can(Capability.acceptOrders);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: !canAnswer
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Only a manager or biller can accept orders. Ask them to answer '
                'this one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.inkSecondary),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ready in',
                  style: TextStyle(
                    color: t.inkSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                PrepTimeChips(value: prep, onChanged: onPrep, dark: true),
                const SizedBox(height: 14),
                SizedBox(
                  height: 64,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ViniiColors.brandGreen,
                      foregroundColor: ViniiColors.ink,
                      disabledBackgroundColor: ViniiColors.brandGreen
                          .withValues(alpha: 0.6),
                      disabledForegroundColor: ViniiColors.ink,
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: busy ? null : () => onAccept(prep),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: ViniiColors.ink,
                            ),
                          )
                        : Text('Accept · $prep min'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: t.danger),
                  onPressed: busy ? null : onReject,
                  child: const Text('Reject'),
                ),
              ],
            ),
    );
  }
}

class _Ending extends StatelessWidget {
  const _Ending({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: t.inkSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: t.ink,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: t.inkSecondary, fontSize: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
