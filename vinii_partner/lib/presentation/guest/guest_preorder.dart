import 'package:flutter/material.dart';

import '../../core/time_format.dart';
import '../../l10n/l10n.dart';
import '../theme/guest_theme.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';

/// Board 2 #11: "Select date & time" for a pre-order. Days and slots come
/// from the storefront's [PreOrderSettings]; slots too soon (inside the
/// lead time) or already past are shown greyed, like the board.
class GuestPreOrderScreen extends StatefulWidget {
  const GuestPreOrderScreen({super.key, this.pickOnly = false});

  /// Opened from checkout to change the slot: "Continue" just goes back.
  final bool pickOnly;

  @override
  State<GuestPreOrderScreen> createState() => _GuestPreOrderScreenState();
}

class _GuestPreOrderScreenState extends State<GuestPreOrderScreen> {
  late final DateTime _today;
  late List<DateTime> _days;
  late DateTime _day;
  DateTime? _slot;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final s = GuestScope.read(context);
    final settings = s.definition.preOrder;
    _days = [
      for (var i = 0; i < settings.daysAhead; i++)
        DateTime(_today.year, _today.month, _today.day + i),
    ];
    final chosen = s.scheduledFor;
    _day = chosen == null
        ? _days.firstWhere(
            (d) => settings.slotsFor(d).isNotEmpty,
            orElse: () => _days.first,
          )
        : DateTime(chosen.year, chosen.month, chosen.day);
    _slot = chosen;
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final l = context.l10n;
    final settings = s.definition.preOrder;
    final all = settings.allSlotsFor(_day);
    final open = settings.slotsFor(_day).toSet();
    return GuestPage(
      bottom: GuestButton(
        label: l.commonContinue,
        trailingArrow: true,
        onTap: _slot == null
            ? null
            : () {
                s.update(() => s.scheduledFor = _slot);
                if (widget.pickOnly) {
                  Navigator.of(context).pop();
                } else {
                  GuestFlow.afterSlot(context);
                }
              },
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GuestTopBar(title: l.guestModePreOrder),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Text(l.guestPreTitle, style: p.display(28)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              l.guestPreSubtitle,
              style: p.body(14, color: p.inkMuted),
            ),
          ),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _days.length,
              separatorBuilder: (context, i) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final d = _days[i];
                final selected = d == _day;
                final any = settings.slotsFor(d).isNotEmpty;
                return _Chip(
                  selected: selected,
                  enabled: any,
                  onTap: () => setState(() {
                    _day = d;
                    if (_slot != null &&
                        DateTime(_slot!.year, _slot!.month, _slot!.day) != d) {
                      _slot = null;
                    }
                  }),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        i == 0 ? l.commonToday : dateFormat('EEE').format(d),
                        style: p.body(
                          12.5,
                          color: selected ? p.onAccent : p.inkMuted,
                        ),
                      ),
                      Text(
                        '${d.day}',
                        style: p.display(
                          22,
                          color: selected ? p.onAccent : p.ink,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(
              l.guestPreSlotsTitle,
              style: p.display(18, weight: FontWeight.w700),
            ),
          ),
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                l.guestPreNoSlots,
                style: p.body(14, color: p.inkMuted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  for (final t in all)
                    _Chip(
                      selected: t == _slot,
                      enabled: open.contains(t),
                      onTap: () => setState(() => _slot = t),
                      child: Center(
                        child: Text(
                          wallClock(t),
                          style: p.body(
                            14,
                            weight: FontWeight.w700,
                            color: t == _slot ? p.onAccent : p.ink,
                          ),
                        ),
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? p.accent : p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? p.accent : p.border),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: p.accent.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
