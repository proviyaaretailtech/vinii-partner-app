import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/failure.dart';
import '../../domain/pos_order.dart';
import '../menu/panel.dart';
import '../theme/staff_theme.dart';
import '../widgets/setting_rows.dart';
import '../widgets/state_views.dart';

/// Swiggy, Zomato and the other places orders come from, each with its own
/// ON/OFF (`channel_integrations.is_accepting`). It lists only the channels
/// this restaurant really has; with none, it says so.
class ChannelsCard extends StatefulWidget {
  const ChannelsCard({super.key});

  @override
  State<ChannelsCard> createState() => _ChannelsCardState();
}

class _ChannelsCardState extends State<ChannelsCard> {
  List<SalesChannel>? _channels;
  AppFailure? _failure;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _failure = null);
    try {
      final rows = await AppScope.of(context).backend.channels.list();
      if (mounted) setState(() => _channels = rows);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _failure = e);
    } catch (e) {
      if (mounted) setState(() => _failure = asFailure(e));
    }
  }

  Future<void> _switch(SalesChannel channel, bool on) async {
    if (_busy.contains(channel.id)) return;
    setState(() => _busy.add(channel.id));
    try {
      final saved = await AppScope.of(context).backend.channels
          .setAccepting(channel, on);
      if (!mounted) return;
      setState(() {
        _channels = [
          for (final c in _channels ?? const <SalesChannel>[])
            c.id == saved.id ? saved : c,
        ];
      });
      _announce(saved, on);
    } on AppFailure catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(channel.id));
    }
  }

  /// Switching OFF can be undone from the message, because switching a
  /// channel off by accident costs orders.
  void _announce(SalesChannel channel, bool on) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            on
                ? '${channel.name} is ON.'
                : '${channel.name} is OFF. You will not get ${channel.name} '
                      'orders until you turn it on.',
          ),
          action: on
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () => _switch(channel, true),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final channels = _channels;
    final Widget body;
    if (_failure != null && channels == null) {
      body = Padding(
        padding: const EdgeInsets.all(12),
        child: NoticeBanner(
          icon: _failure!.kind == FailureKind.notReady
              ? Icons.construction_rounded
              : Icons.cloud_off_rounded,
          tone: _failure!.kind == FailureKind.notReady ? t.warning : t.danger,
          message: _failure!.message,
          action: _failure!.kind == FailureKind.notReady
              ? null
              : TextButton(onPressed: _load, child: const Text('Retry')),
        ),
      );
    } else if (channels == null) {
      body = const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    } else if (channels.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No sales channels are set up yet. Swiggy and Zomato show here once '
          'they are connected to this restaurant.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    } else {
      body = Column(
        children: [
          for (final (i, c) in channels.indexed) ...[
            if (i > 0) const PanelDivider(indent: 0),
            SettingSwitchRow(
              key: Key('channel-${c.key}'),
              title: c.name,
              subtitle: !c.connected
                  ? 'Not connected yet'
                  : c.accepting
                  ? 'Taking orders'
                  : 'Not taking orders',
              value: c.connected && c.accepting,
              onChanged: c.connected && !_busy.contains(c.id)
                  ? (on) => _switch(c, on)
                  : null,
            ),
          ],
        ],
      );
    }
    return Card(clipBehavior: Clip.antiAlias, child: body);
  }
}
