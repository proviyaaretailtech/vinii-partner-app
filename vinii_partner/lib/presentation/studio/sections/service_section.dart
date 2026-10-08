import 'package:flutter/material.dart';

import '../../../application/studio_controller.dart';
import '../../../core/time_format.dart';
import '../../../domain/storefront.dart';
import '../../../l10n/l10n.dart';
import '../../menu/panel.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/state_views.dart';
import '../studio_sections.dart';

/// How guests order: which ways are offered and in what order, what a
/// "table" is called, and when pre-orders can be picked up.
class ServiceSection extends StatefulWidget {
  const ServiceSection({super.key, required this.controller});
  final StudioController controller;

  @override
  State<ServiceSection> createState() => _ServiceSectionState();
}

class _ServiceSectionState extends State<ServiceSection> {
  // i18n-ignore: stored merchant default (these exact words are saved as the
  // storefront's table label and shown to guests as "Table 12")
  static const _presetLabels = ['Table', 'Room'];
  late bool _customLabel = !_presetLabels.contains(
    widget.controller.draft.tableLabel,
  );
  late final _labelText = TextEditingController(
    text: _customLabel ? widget.controller.draft.tableLabel : '',
  );

  StudioController get _c => widget.controller;

  @override
  void dispose() {
    _labelText.dispose();
    super.dispose();
  }

  void _toggle(GuestServiceMode m, bool on) {
    final modes = _c.draft.serviceModes;
    if (!on && modes.length == 1 && modes.contains(m)) {
      showDone(context, context.l10n.studioSvcKeepOne);
      return;
    }
    _c.edit(
      (d) => d.copyWith(
        serviceModes: on
            ? [...d.serviceModes.where((x) => x != m), m]
            : d.serviceModes.where((x) => x != m).toList(),
      ),
    );
  }

  void _reorder(List<GuestServiceMode> order, int from, int to) {
    final list = [...order];
    final moved = list.removeAt(from);
    list.insert(to, moved);
    _c.edit(
      (d) => d.copyWith(
        serviceModes: list.where(d.serviceModes.contains).toList(),
      ),
    );
  }

  void _pre(PreOrderSettings Function(PreOrderSettings p) change) =>
      _c.edit((d) => d.copyWith(preOrder: change(d.preOrder)));

  Future<void> _pickTime(String current, void Function(String hm) set) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(current.substring(0, 2)),
        minute: int.parse(current.substring(3)),
      ),
    );
    if (picked == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    set('${two(picked.hour)}:${two(picked.minute)}');
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final d = _c.draft;
    final order = [
      ...d.serviceModes,
      ...GuestServiceMode.values.where((m) => !d.serviceModes.contains(m)),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        PanelLabel(l.studioSvcWaysTitle, top: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(l.studioSvcWaysHint, style: text.bodyMedium),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) => _reorder(order, from, to),
          proxyDecorator: (child, index, animation) => Material(
            color: Colors.transparent,
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
          children: [
            for (var i = 0; i < order.length; i++)
              Padding(
                key: ValueKey(order[i].key),
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: t.inkMuted,
                          semanticLabel: l.studioHighDragToReorder,
                        ),
                      ),
                    ),
                    title: Text(
                      l.studioModeName(order[i]),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(_modeHint(l, order[i])),
                    trailing: Switch(
                      value: d.serviceModes.contains(order[i]),
                      onChanged: (v) => _toggle(order[i], v),
                    ),
                  ),
                ),
              ),
          ],
        ),
        PanelLabel(l.studioSvcTableTitle, top: 12),
        Panel(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in _presetLabels)
                  ChoiceChip(
                    label: Text(l),
                    selected: !_customLabel && d.tableLabel == l,
                    onSelected: (_) {
                      setState(() => _customLabel = false);
                      _c.edit((d) => d.copyWith(tableLabel: l));
                    },
                  ),
                ChoiceChip(
                  label: Text(l.studioSvcTableOther),
                  selected: _customLabel,
                  onSelected: (_) => setState(() => _customLabel = true),
                ),
              ],
            ),
            if (_customLabel) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _labelText,
                autofocus: _labelText.text.isEmpty,
                textCapitalization: TextCapitalization.words,
                onChanged: (v) {
                  if (v.trim().isNotEmpty) {
                    _c.edit((d) => d.copyWith(tableLabel: v.trim()));
                  }
                },
                decoration: InputDecoration(
                  labelText: l.studioSvcTableField,
                  hintText: l.studioSvcTableExamples,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              l.studioSvcTableSample(label: d.tableLabel),
              style: text.bodySmall,
            ),
          ],
        ),
        PanelLabel(l.studioModeName(GuestServiceMode.preOrder)),
        if (!d.offers(GuestServiceMode.preOrder))
          Panel(children: [Text(l.studioSvcPreOff, style: text.bodyMedium)])
        else
          _PreOrderPanel(
            settings: d.preOrder,
            onChanged: _pre,
            onPickTime: _pickTime,
          ),
      ],
    );
  }
}

class _PreOrderPanel extends StatelessWidget {
  const _PreOrderPanel({
    required this.settings,
    required this.onChanged,
    required this.onPickTime,
  });

  final PreOrderSettings settings;
  final void Function(PreOrderSettings Function(PreOrderSettings p)) onChanged;
  final Future<void> Function(String current, void Function(String hm) set)
  onPickTime;

  static const _slotChoices = [15, 30, 60, 90];
  static const _leadChoices = [30, 60, 90, 120, 180];

  static String _minutes(AppLocalizations l, int m) {
    if (m < 60) return l.studioSvcMinutes(minutes: m);
    final h = m ~/ 60, r = m % 60;
    return r == 0
        ? l.studioSvcHours(hours: h)
        : l.studioSvcHoursMinutes(hours: h, minutes: r);
  }

  static int _toMinutes(String hm) =>
      int.parse(hm.substring(0, 2)) * 60 + int.parse(hm.substring(3));

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final s = settings;
    final badHours =
        _toMinutes(s.closesAt) - _toMinutes(s.opensAt) < s.slotMinutes;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final bookable = s.slotsFor(today, now: now).toSet();
    return Panel(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.studioSvcBookAhead, style: text.titleSmall),
                  Text(
                    l.studioSvcBookDays(count: s.daysAhead),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton.outlined(
              tooltip: l.studioSvcFewerDays,
              onPressed: s.daysAhead > 1
                  ? () =>
                        onChanged((p) => p.copyWith(daysAhead: p.daysAhead - 1))
                  : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 40,
              child: Text(
                '${s.daysAhead}',
                textAlign: TextAlign.center,
                style: text.titleLarge,
              ),
            ),
            IconButton.outlined(
              tooltip: l.studioSvcMoreDays,
              onPressed: s.daysAhead < 14
                  ? () =>
                        onChanged((p) => p.copyWith(daysAhead: p.daysAhead + 1))
                  : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TimeBox(
                label: l.studioSvcOpensAt,
                value: s.opensAt,
                onTap: () => onPickTime(
                  s.opensAt,
                  (hm) => onChanged((p) => p.copyWith(opensAt: hm)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeBox(
                label: l.studioSvcClosesAt,
                value: s.closesAt,
                onTap: () => onPickTime(
                  s.closesAt,
                  (hm) => onChanged((p) => p.copyWith(closesAt: hm)),
                ),
              ),
            ),
          ],
        ),
        if (badHours) ...[
          const SizedBox(height: 8),
          Text(
            l.studioSvcBadHours,
            style: TextStyle(color: t.danger, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        Text(l.studioSvcSlotEvery, style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _slotChoices)
              ChoiceChip(
                label: Text(_minutes(l, m)),
                selected: s.slotMinutes == m,
                onSelected: (_) => onChanged((p) => p.copyWith(slotMinutes: m)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l.studioSvcLead, style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _leadChoices)
              ChoiceChip(
                label: Text(_minutes(l, m)),
                selected: s.leadMinutes == m,
                onSelected: (_) => onChanged((p) => p.copyWith(leadMinutes: m)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const PanelDivider(indent: 0),
        const SizedBox(height: 14),
        Text(l.studioSvcGuestPick, style: text.titleSmall),
        const SizedBox(height: 10),
        _SlotRow(
          day: l.commonToday,
          slots: s.allSlotsFor(today),
          isOpen: bookable.contains,
        ),
        const SizedBox(height: 12),
        _SlotRow(
          day: l.studioSvcTomorrow,
          slots: s.allSlotsFor(tomorrow),
          isOpen: (_) => true,
        ),
      ],
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final shown = wallClock(
      DateTime(
        2000,
        1,
        1,
        int.parse(value.substring(0, 2)),
        int.parse(value.substring(3)),
      ),
    );
    return Material(
      color: t.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 12, color: t.inkSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shown,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.schedule_rounded, color: t.inkMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.day,
    required this.slots,
    required this.isOpen,
  });

  final String day;
  final List<DateTime> slots;
  final bool Function(DateTime slot) isOpen;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(day, style: text.labelLarge),
        const SizedBox(height: 6),
        if (slots.isEmpty)
          Text(l.studioSvcNoSlots, style: text.bodySmall)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in slots)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isOpen(s) ? t.tint(t.success) : t.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    wallClock(s),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isOpen(s) ? t.ink : t.inkMuted,
                      decoration: isOpen(s) ? null : TextDecoration.lineThrough,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// The one line under a way to order, as the guest sees it. The names of the
/// ways (and of templates and category styles) are in `StudioLabels`
/// (studio_sections.dart); only these hints belong to this screen.
String _modeHint(AppLocalizations l, GuestServiceMode m) => switch (m) {
  GuestServiceMode.dineIn => l.studioSvcModeDineInHint,
  GuestServiceMode.takeaway => l.studioSvcModeTakeawayHint,
  GuestServiceMode.preOrder => l.studioSvcModePreOrderHint,
  GuestServiceMode.delivery => l.studioSvcModeDeliveryHint,
};
