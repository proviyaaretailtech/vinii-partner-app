import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../application/studio_controller.dart';
import '../../../core/money.dart';
import '../../../core/time_format.dart';
import '../../../domain/menu.dart';
import '../../../domain/storefront.dart';
import '../../../l10n/l10n.dart';
import '../../menu/panel.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/chips.dart';
import '../../widgets/food_art.dart';
import '../../widgets/state_views.dart';

/// "Chef's picks" (a row of up to six dishes) and "Limited today" (dishes
/// on offer until a time each day). Both pick from the real menu only.
class HighlightsSection extends StatelessWidget {
  const HighlightsSection({super.key, required this.controller});
  final StudioController controller;

  static const maxPicks = 6;

  Future<void> _addPick(BuildContext context) async {
    final d = controller.draft;
    final item = await pickMenuItem(
      context,
      controller.menu,
      title: context.l10n.studioHighPickTitle,
      exclude: d.chefsPicks.toSet(),
    );
    if (item == null) return;
    controller.edit((d) => d.copyWith(chefsPicks: [...d.chefsPicks, item.id]));
  }

  Future<void> _addOffer(BuildContext context) async {
    final d = controller.draft;
    final item = await pickMenuItem(
      context,
      controller.menu,
      title: context.l10n.studioHighOfferTitle,
      exclude: {for (final o in d.limitedToday) o.itemId},
    );
    if (item == null || !context.mounted) return;
    final ends = await _askTime(context, null);
    if (ends == null) return;
    controller.edit(
      (d) => d.copyWith(
        limitedToday: [
          ...d.limitedToday,
          LimitedOffer(itemId: item.id, endsAt: ends),
        ],
      ),
    );
  }

  Future<String?> _askTime(BuildContext context, String? current) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      helpText: context.l10n.studioHighEndsHelp,
      initialTime: current == null
          ? TimeOfDay(hour: (now.hour + 3).clamp(0, 23), minute: 0)
          : TimeOfDay(
              hour: int.parse(current.substring(0, 2)),
              minute: int.parse(current.substring(3)),
            ),
    );
    if (picked == null) return null;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(picked.hour)}:${two(picked.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final menu = controller.menu;
    final d = controller.draft;
    if (menu.items.isEmpty) {
      return EmptyView(
        icon: Icons.restaurant_menu_rounded,
        title: l.studioHighEmptyTitle,
        message: l.studioHighEmptyMessage,
        actionLabel: l.studioHighEmptyAction,
        onAction: () => context.go(Routes.menu),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        PanelLabel(
          l.studioFeatChefsPicksTitle,
          top: 4,
          trailing: Text(
            l.studioHighPicksCount(count: d.chefsPicks.length, max: maxPicks),
            style: text.bodySmall,
          ),
        ),
        if (!d.features.chefsPicks) ...[
          _OffBanner(
            message: l.studioHighChefsOff,
            onTurnOn: () => controller.edit(
              (d) =>
                  d.copyWith(features: d.features.copyWith(chefsPicks: true)),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Panel(
          padding: null,
          children: [
            if (d.chefsPicks.isEmpty)
              ListTile(
                title: Text(
                  l.studioHighNoPicks,
                  style: TextStyle(color: t.inkMuted),
                ),
                subtitle: Text(l.studioHighNoPicksHint),
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) => controller.edit((d) {
                  final list = [...d.chefsPicks];
                  final moved = list.removeAt(from);
                  list.insert(to, moved);
                  return d.copyWith(chefsPicks: list);
                }),
                children: [
                  for (var i = 0; i < d.chefsPicks.length; i++)
                    _PickedRow(
                      key: ValueKey('pick-${d.chefsPicks[i]}'),
                      item: menu.item(d.chefsPicks[i]),
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: t.inkMuted,
                            semanticLabel: l.studioHighDragToReorder,
                          ),
                        ),
                      ),
                      onRemove: () => controller.edit(
                        (d) => d.copyWith(
                          chefsPicks: [...d.chefsPicks]..removeAt(i),
                        ),
                      ),
                    ),
                ],
              ),
            const PanelDivider(indent: 0),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(l.studioHighAddDish),
              enabled: d.chefsPicks.length < maxPicks,
              onTap: () => _addPick(context),
            ),
          ],
        ),
        PanelLabel(l.studioFeatLimitedTitle),
        if (!d.features.limitedToday) ...[
          _OffBanner(
            message: l.studioHighLimitedOff,
            onTurnOn: () => controller.edit(
              (d) =>
                  d.copyWith(features: d.features.copyWith(limitedToday: true)),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Panel(
          padding: null,
          children: [
            if (d.limitedToday.isEmpty)
              ListTile(
                title: Text(
                  l.studioHighNoOffers,
                  style: TextStyle(color: t.inkMuted),
                ),
                subtitle: Text(l.studioHighNoOffersHint),
              ),
            for (var i = 0; i < d.limitedToday.length; i++) ...[
              if (i > 0) const PanelDivider(indent: 72),
              _PickedRow(
                item: menu.item(d.limitedToday[i].itemId),
                leading: const SizedBox(width: 8),
                trailing: ActionChip(
                  avatar: const Icon(Icons.schedule_rounded, size: 16),
                  label: Text(_until(l, d.limitedToday[i].endsAt)),
                  onPressed: () async {
                    final ends = await _askTime(
                      context,
                      d.limitedToday[i].endsAt,
                    );
                    if (ends == null) return;
                    controller.edit(
                      (d) => d.copyWith(
                        limitedToday: [
                          for (final o in d.limitedToday)
                            o.itemId == d.limitedToday[i].itemId
                                ? LimitedOffer(itemId: o.itemId, endsAt: ends)
                                : o,
                        ],
                      ),
                    );
                  },
                ),
                onRemove: () => controller.edit(
                  (d) => d.copyWith(
                    limitedToday: [...d.limitedToday]..removeAt(i),
                  ),
                ),
              ),
            ],
            const PanelDivider(indent: 0),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(l.studioHighAddDish),
              onTap: () => _addOffer(context),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(l.studioHighRepeatNote, style: text.bodySmall),
        ),
      ],
    );
  }

  static String _until(AppLocalizations l, String hm) => l.studioHighUntil(
    time: wallClock(
      DateTime(
        2000,
        1,
        1,
        int.parse(hm.substring(0, 2)),
        int.parse(hm.substring(3)),
      ),
    ),
  );
}

class _OffBanner extends StatelessWidget {
  const _OffBanner({required this.message, required this.onTurnOn});
  final String message;
  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) => NoticeBanner(
    icon: Icons.toggle_off_outlined,
    tone: ViniiTokens.of(context).warning,
    message: message,
    action: TextButton(
      onPressed: onTurnOn,
      child: Text(context.l10n.studioHighTurnOn),
    ),
  );
}

class _PickedRow extends StatelessWidget {
  const _PickedRow({
    super.key,
    required this.item,
    required this.leading,
    required this.onRemove,
    this.trailing,
  });

  /// Null when the dish was removed from the menu after it was picked.
  final MenuItem? item;
  final Widget leading;
  final Widget? trailing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final i = item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          leading,
          SizedBox.square(
            dimension: 44,
            child: i == null
                ? Container(
                    decoration: BoxDecoration(
                      color: t.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.no_food_outlined, color: t.inkMuted),
                  )
                : FoodArt(
                    name: i.name,
                    imageUrl: i.imageUrl,
                    radius: 12,
                    dim: !i.isAvailable,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i?.name ?? l.studioHighGone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: i == null ? t.inkMuted : t.ink,
                  ),
                ),
                Text(
                  i == null
                      ? l.studioHighGoneHint
                      : !i.isAvailable
                      ? l.studioHighSoldOutHint
                      : rupees(i.price),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: i == null || !i.isAvailable ? t.warning : t.inkMuted,
                  ),
                ),
                // Under the text rather than beside it, so a longer chip
                // (the end time in Hindi) does not squeeze the dish name.
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: trailing,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.commonRemove,
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, color: t.inkSecondary),
          ),
        ],
      ),
    );
  }
}

/// A searchable list of the menu's dishes. Null when cancelled.
Future<MenuItem?> pickMenuItem(
  BuildContext context,
  MenuSnapshot menu, {
  required String title,
  Set<String> exclude = const {},
}) => showModalBottomSheet<MenuItem>(
  context: context,
  isScrollControlled: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    builder: (context, scroll) =>
        _ItemPicker(menu: menu, title: title, exclude: exclude, scroll: scroll),
  ),
);

class _ItemPicker extends StatefulWidget {
  const _ItemPicker({
    required this.menu,
    required this.title,
    required this.exclude,
    required this.scroll,
  });

  final MenuSnapshot menu;
  final String title;
  final Set<String> exclude;
  final ScrollController scroll;

  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final items =
        widget.menu.items
            .where((i) => !widget.exclude.contains(i.id))
            .where((i) => _q.isEmpty || i.name.toLowerCase().contains(_q))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: l.studioHighSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? EmptyView(
                  icon: Icons.search_off_rounded,
                  title: l.studioHighNoDishes,
                )
              : ListView.separated(
                  controller: widget.scroll,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, indent: 76, color: t.border),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return ListTile(
                      leading: SizedBox.square(
                        dimension: 44,
                        child: FoodArt(
                          name: item.name,
                          imageUrl: item.imageUrl,
                          radius: 12,
                          dim: !item.isAvailable,
                        ),
                      ),
                      title: Row(
                        children: [
                          if (item.foodType != null) ...[
                            FoodTypeMark(item.foodType, size: 12),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        item.isAvailable
                            ? rupees(item.price)
                            : l.studioHighPriceSoldOut(
                                price: rupees(item.price),
                              ),
                      ),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
