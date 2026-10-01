import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../application/outlet_mode.dart';
import '../../core/failure.dart';
import '../../core/time_format.dart';
import '../../domain/staff.dart';
import '../theme/staff_theme.dart';
import '../widgets/state_views.dart';

/// The store's status: Open, Paused or Closed for today.
///
/// One card whose colour, icon and words all say the same thing: VINII green
/// with dark text when open (the approved POS reference), amber when paused,
/// red when closed. State is never colour alone. Under it, three buttons
/// switch between the states; only roles with [Capability.toggleOutlet] get
/// them, everyone else sees the state with a lock.
///
/// Pausing asks for how long, because a restaurant that forgets to turn it
/// back on silently loses an evening of orders. Closing for today asks once
/// and then stays off until the next 9:00 AM. Both go through One Local's
/// `accepting` and `back_at`; "closed" is read back by [outletModeOf].
class OutletBar extends StatefulWidget {
  const OutletBar({super.key});

  @override
  State<OutletBar> createState() => _OutletBarState();
}

class _OutletBarState extends State<OutletBar> {
  bool _saving = false;

  Future<void> _choose(OutletMode target, OutletMode current) async {
    if (_saving) return;
    // Pause can be chosen again to change how long; the others only once.
    if (target == current && target != OutletMode.paused) return;
    final inbox = AppScope.of(context).inbox;
    DateTime? backAt;
    String done;
    switch (target) {
      case OutletMode.open:
        done = 'Open. Accepting orders again.';
      case OutletMode.paused:
        final choice = await showModalBottomSheet<_Pause>(
          context: context,
          isScrollControlled: true,
          constraints: const BoxConstraints(maxWidth: 560),
          builder: (context) => const _PauseSheet(),
        );
        if (choice == null || !mounted) return;
        backAt = choice.backAt;
        done = backAt == null
            ? 'Paused until you turn it back on.'
            : 'Paused. Back at ${_when(backAt)}.';
      case OutletMode.closed:
        final opening = nextOpening();
        final sure = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          constraints: const BoxConstraints(maxWidth: 560),
          builder: (context) => _CloseSheet(opening: opening),
        );
        if (sure != true || !mounted) return;
        backAt = opening;
        done = 'Closed for today. Opens ${_when(opening)}.';
    }
    setState(() => _saving = true);
    try {
      await inbox.setAccepting(target == OutletMode.open, backAt: backAt);
      if (mounted) showDone(context, done);
    } on AppFailure catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppScope.of(context).inbox,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final services = AppScope.of(context);
    final inbox = services.inbox;
    final t = ViniiTokens.of(context);
    final outlet = inbox.outlet;
    final canToggle = services.session.can(Capability.toggleOutlet);

    if (outlet == null) {
      return _StatusCard(
        background: t.surfaceMuted,
        foreground: t.ink,
        border: t.border,
        icon: Icons.storefront_outlined,
        title: inbox.outletFailure == null ? 'Checking…' : 'Status unknown',
        subtitle: inbox.outletFailure == null
            ? 'Asking One Local whether you are open'
            : 'Could not reach One Local',
      );
    }

    final mode = outletModeOf(outlet);
    final (bg, icon, title, subtitle) = switch (mode) {
      OutletMode.open => (
        ViniiColors.brandGreen,
        Icons.check_circle_rounded,
        'Open',
        'Accepting orders. New ones ring on this phone.',
      ),
      OutletMode.paused => (
        t.warning,
        Icons.pause_circle_rounded,
        'Paused',
        outlet.backAt != null
            ? 'Back at ${_when(outlet.backAt!)}'
            : 'Until you turn it back on',
      ),
      OutletMode.closed => (
        t.danger,
        Icons.do_not_disturb_on_rounded,
        'Closed',
        outlet.backAt != null
            ? 'Closed for today. Opens ${_when(outlet.backAt!)}'
            : 'Closed for today',
      ),
    };
    final fg = _readableOn(bg);

    return _StatusCard(
      background: bg,
      foreground: fg,
      border: bg,
      icon: icon,
      title: title,
      subtitle: subtitle,
      busy: _saving,
      locked: !canToggle,
      choices: canToggle
          ? [
              const _Choice(
                OutletMode.open,
                'Open',
                Icons.check_circle_rounded,
                flex: 3,
              ),
              const _Choice(
                OutletMode.paused,
                'Pause',
                Icons.pause_circle_rounded,
                flex: 3,
              ),
              const _Choice(
                OutletMode.closed,
                'Close today',
                Icons.do_not_disturb_on_rounded,
                flex: 4,
              ),
            ]
          : null,
      selected: mode,
      onChoose: (m) => _choose(m, mode),
    );
  }
}

/// Dark text on the bright states, white on red: whichever reads better.
Color _readableOn(Color bg) =>
    bg.computeLuminance() > 0.19 ? ViniiColors.ink : Colors.white;

/// "3:30 PM", or "tomorrow 9:00 AM" when it is not today.
String _when(DateTime at) {
  final now = DateTime.now();
  final local = at.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return clockTime(local);
  if (diff == 1) return 'tomorrow ${clockTime(local)}';
  return '${shortDay(local)}, ${clockTime(local)}';
}

class _Choice {
  const _Choice(this.mode, this.label, this.icon, {required this.flex});
  final OutletMode mode;
  final String label;
  final IconData icon;
  final int flex;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.busy = false,
    this.locked = false,
    this.choices,
    this.selected,
    this.onChoose,
  });

  final Color background;
  final Color foreground;
  final Color border;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final bool locked;
  final List<_Choice>? choices;
  final OutletMode? selected;
  final ValueChanged<OutletMode>? onChoose;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      label: 'Store status: $title. $subtitle',
      child: AnimatedContainer(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 28,
                  child: busy
                      ? Padding(
                          padding: const EdgeInsets.all(3),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: foreground,
                          ),
                        )
                      : Icon(icon, size: 28, color: foreground),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          color: foreground.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (locked) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: foreground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only a manager can change this.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (choices != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Row(
                    children: [
                      for (final (i, c) in choices!.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          flex: c.flex,
                          child: _ModeButton(
                            choice: c,
                            selected: c.mode == selected,
                            background: background,
                            foreground: foreground,
                            onTap: busy ? null : () => onChoose?.call(c.mode),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.choice,
    required this.selected,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final _Choice choice;
  final bool selected;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? background : foreground;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: choice.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? foreground : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: Key('outlet-${choice.mode.name}'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? foreground
                      : foreground.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(choice.icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      choice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chosen pause. [backAt] null means "until I turn it back on".
class _Pause {
  const _Pause(this.backAt);
  final DateTime? backAt;
}

class _PauseSheet extends StatelessWidget {
  const _PauseSheet();

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final choices = <(String, IconData, _Pause)>[
      (
        '30 minutes',
        Icons.timer_outlined,
        _Pause(now.add(const Duration(minutes: 30))),
      ),
      (
        '1 hour',
        Icons.hourglass_bottom_rounded,
        _Pause(now.add(const Duration(hours: 1))),
      ),
      (
        '2 hours',
        Icons.hourglass_full_rounded,
        _Pause(now.add(const Duration(hours: 2))),
      ),
      (
        'Until I turn it back on',
        Icons.pause_circle_outline_rounded,
        const _Pause(null),
      ),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Pause new orders', style: text.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Customers will not be able to order from you on One Local. '
              'Orders you already accepted are not affected.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final (label, icon, pause) in choices)
              ListTile(
                minTileHeight: 56,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(icon, color: t.inkSecondary),
                title: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: pause.backAt == null
                    ? null
                    : Text('Back at ${_when(pause.backAt!)}'),
                trailing: Icon(Icons.chevron_right_rounded, color: t.inkMuted),
                onTap: () => Navigator.pop(context, pause),
              ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep accepting'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseSheet extends StatelessWidget {
  const _CloseSheet({required this.opening});

  /// When the store opens again by itself.
  final DateTime opening;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Close for today?', style: text.titleLarge),
            const SizedBox(height: 6),
            Text(
              'You stop getting delivery orders now and start again '
              '${_when(opening)}. Orders you already accepted are not '
              'affected.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('outlet-close-confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: t.danger,
                foregroundColor: _readableOn(t.danger),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Close for today'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep open'),
            ),
          ],
        ),
      ),
    );
  }
}
