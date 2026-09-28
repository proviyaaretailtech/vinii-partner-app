import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/failure.dart';
import '../../core/time_format.dart';
import '../../domain/staff.dart';
import '../theme/staff_theme.dart';
import '../widgets/state_views.dart';

/// "Accepting orders" — the restaurant's switch for One Local.
///
/// On, it is VINII green with dark text (the approved POS reference). Off,
/// it says "Paused" and when it comes back on by itself. Only roles with
/// [Capability.toggleOutlet] get the switch; everyone else sees the state.
/// Turning it off always asks for how long, because a restaurant that
/// forgets to turn it back on silently loses a whole evening of orders.
class OutletBar extends StatefulWidget {
  const OutletBar({super.key});

  @override
  State<OutletBar> createState() => _OutletBarState();
}

class _OutletBarState extends State<OutletBar> {
  bool _saving = false;

  Future<void> _toggle(bool on) async {
    final inbox = AppScope.of(context).inbox;
    DateTime? backAt;
    if (!on) {
      final choice = await showModalBottomSheet<_Pause>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _PauseSheet(),
      );
      if (choice == null || !mounted) return;
      backAt = choice.backAt;
    }
    setState(() => _saving = true);
    try {
      await inbox.setAccepting(on, backAt: backAt);
      if (mounted) {
        showDone(
          context,
          on
              ? 'Accepting orders again.'
              : backAt == null
              ? 'Paused until you turn it back on.'
              : 'Paused. Back at ${_when(backAt)}.',
        );
      }
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
      return _Shell(
        color: t.surfaceMuted,
        border: t.border,
        leading: Icon(Icons.storefront_outlined, color: t.inkMuted),
        title: inbox.outletFailure == null ? 'Checking…' : 'Status unknown',
        subtitle: inbox.outletFailure == null
            ? 'Asking One Local whether you are open'
            : 'Could not reach One Local',
        titleColor: t.ink,
        subtitleColor: t.inkSecondary,
      );
    }

    final on = outlet.accepting;
    final fg = on ? ViniiColors.ink : t.ink;
    final Widget trailing;
    if (_saving) {
      trailing = SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
      );
    } else if (canToggle) {
      trailing = Switch(
        value: on,
        onChanged: _toggle,
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? ViniiColors.brandGreen
              : t.inkMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ViniiColors.ink : t.page,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? ViniiColors.ink : t.border,
        ),
      );
    } else {
      trailing = Icon(Icons.lock_outline_rounded, size: 18, color: fg);
    }

    return Semantics(
      toggled: on,
      label: on ? 'Accepting orders' : 'Paused',
      child: _Shell(
        color: on ? ViniiColors.brandGreen : t.surface,
        border: on ? ViniiColors.brandGreen : t.border,
        leading: _Dot(color: on ? ViniiColors.ink : t.danger),
        title: on ? 'Accepting orders' : 'Paused',
        subtitle: on
            ? 'New orders ring on this phone'
            : outlet.backAt != null
            ? 'Back at ${_when(outlet.backAt!)}'
            : 'Customers cannot order from you on One Local',
        titleColor: fg,
        subtitleColor: on
            ? ViniiColors.ink.withValues(alpha: 0.72)
            : t.inkSecondary,
        trailing: trailing,
        onTap: canToggle && !_saving ? () => _toggle(!on) : null,
      ),
    );
  }
}

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

class _Shell extends StatelessWidget {
  const _Shell({
    required this.color,
    required this.border,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
    this.trailing,
    this.onTap,
  });

  final Color color;
  final Color border;
  final Widget leading;
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 0,
          spreadRadius: 4,
        ),
      ],
    ),
  );
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
    var nine = DateTime(now.year, now.month, now.day, 9);
    if (!nine.isAfter(now)) {
      nine = DateTime(now.year, now.month, now.day + 1, 9);
    }
    final nineLabel = nine.day == now.day
        ? 'Until this morning (9 AM)'
        : 'Until tomorrow morning (9 AM)';
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
      (nineLabel, Icons.wb_twilight_rounded, _Pause(nine)),
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
