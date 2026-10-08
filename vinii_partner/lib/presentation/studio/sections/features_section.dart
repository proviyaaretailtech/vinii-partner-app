import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/studio_controller.dart';
import '../../../core/money.dart';
import '../../../domain/storefront.dart';
import '../../../l10n/l10n.dart';
import '../../menu/panel.dart';
import '../../theme/staff_theme.dart';

typedef _Flag = ({
  String title,
  String subtitle,
  bool value,
  GuestFeatures Function(GuestFeatures f, bool v) set,
});

/// Switches for each part of the guest experience, each with one line on
/// what it does, so an owner can decide without trying every screen.
class FeaturesSection extends StatefulWidget {
  const FeaturesSection({super.key, required this.controller});
  final StudioController controller;

  @override
  State<FeaturesSection> createState() => _FeaturesSectionState();
}

class _FeaturesSectionState extends State<FeaturesSection> {
  late final BudgetSettings _b = widget.controller.draft.features.budget;
  late final _default = TextEditingController(text: '${_b.defaultAmount}');
  late final _min = TextEditingController(text: '${_b.min}');
  late final _max = TextEditingController(text: '${_b.max}');

  StudioController get _c => widget.controller;

  @override
  void dispose() {
    for (final c in [_default, _min, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(GuestFeatures Function(GuestFeatures f) change) =>
      _c.edit((d) => d.copyWith(features: change(d.features)));

  void _budget({int? defaultAmount, int? min, int? max}) => _set(
    (f) => f.copyWith(
      budget: f.budget.copyWith(
        defaultAmount: defaultAmount,
        min: min,
        max: max,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = _c.draft.features;
    final groups = <(String, List<_Flag>)>[
      (
        l.studioFeatGroupBrowse,
        [
          (
            title: l.studioFeatSwipeTitle,
            subtitle: l.studioFeatSwipeHint,
            value: f.swipeDeck,
            set: (f, v) => f.copyWith(swipeDeck: v),
          ),
          (
            title: l.studioFeatLikesTitle,
            subtitle: l.studioFeatLikesHint,
            value: f.likes,
            set: (f, v) => f.copyWith(likes: v),
          ),
          (
            title: l.studioFeatChefsPicksTitle,
            subtitle: l.studioFeatChefsPicksHint,
            value: f.chefsPicks,
            set: (f, v) => f.copyWith(chefsPicks: v),
          ),
          (
            title: l.studioFeatLimitedTitle,
            subtitle: l.studioFeatLimitedHint,
            value: f.limitedToday,
            set: (f, v) => f.copyWith(limitedToday: v),
          ),
        ],
      ),
      (
        l.studioFeatGroupGroups,
        [
          (
            title: l.studioFeatSplitPartyTitle,
            subtitle: l.studioFeatSplitPartyHint,
            value: f.splitParty,
            set: (f, v) => f.copyWith(splitParty: v),
          ),
          (
            title: l.studioFeatSplitBillTitle,
            subtitle: l.studioFeatSplitBillHint,
            value: f.splitBill,
            set: (f, v) => f.copyWith(splitBill: v),
          ),
        ],
      ),
      (
        l.studioFeatGroupAfter,
        [
          (
            title: l.studioFeatTrackingTitle,
            subtitle: l.studioFeatTrackingHint,
            value: f.liveTracking,
            set: (f, v) => f.copyWith(liveTracking: v),
          ),
          (
            title: l.studioFeatDiscoverTitle,
            subtitle: l.studioFeatDiscoverHint,
            value: f.discoverWhileWaiting,
            set: (f, v) => f.copyWith(discoverWhileWaiting: v),
          ),
          (
            title: l.studioFeatFeedbackTitle,
            subtitle: l.studioFeatFeedbackHint,
            value: f.feedback,
            set: (f, v) => f.copyWith(feedback: v),
          ),
        ],
      ),
      (
        l.studioFeatGroupDish,
        [
          (
            title: l.studioFeatIngredientsTitle,
            subtitle: l.studioFeatIngredientsHint,
            value: f.showIngredients,
            set: (f, v) => f.copyWith(showIngredients: v),
          ),
          (
            title: l.studioFeatAllergensTitle,
            subtitle: l.studioFeatAllergensHint,
            value: f.showAllergens,
            set: (f, v) => f.copyWith(showAllergens: v),
          ),
          (
            title: l.studioFeatCaloriesTitle,
            subtitle: l.studioFeatCaloriesHint,
            value: f.showNutrition,
            set: (f, v) => f.copyWith(showNutrition: v),
          ),
        ],
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        PanelLabel(l.studioFeatBudgetTitle, top: 4),
        _budgetPanel(f.budget),
        for (final g in groups) ...[
          PanelLabel(g.$1),
          Panel(
            padding: null,
            children: [
              for (var i = 0; i < g.$2.length; i++) ...[
                if (i > 0) const PanelDivider(),
                SwitchListTile(
                  title: Text(
                    g.$2[i].title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(g.$2[i].subtitle),
                  value: g.$2[i].value,
                  onChanged: (v) => _set((f) => g.$2[i].set(f, v)),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _budgetPanel(BudgetSettings b) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final valid =
        b.min > 0 && b.min <= b.defaultAmount && b.defaultAmount <= b.max;
    Widget field(
      String label,
      TextEditingController c,
      void Function(int v) apply,
    ) => Expanded(
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) apply(n);
        },
        decoration: InputDecoration(
          labelText: label,
          prefixText: '₹', // i18n-ignore: currency symbol
          isDense: true,
        ),
      ),
    );
    return Panel(
      padding: null,
      children: [
        SwitchListTile(
          title: Text(
            l.studioFeatBudgetTitle,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(l.studioFeatBudgetHint),
          value: b.enabled,
          onChanged: (v) =>
              _set((f) => f.copyWith(budget: f.budget.copyWith(enabled: v))),
        ),
        if (b.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    field(l.studioFeatBudgetMin, _min, (v) => _budget(min: v)),
                    const SizedBox(width: 8),
                    field(
                      l.studioFeatBudgetStart,
                      _default,
                      (v) => _budget(defaultAmount: v),
                    ),
                    const SizedBox(width: 8),
                    field(l.studioFeatBudgetMax, _max, (v) => _budget(max: v)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  valid
                      ? l.studioFeatBudgetSummary(
                          start: rupees(b.defaultAmount),
                          step: rupees(b.step),
                        )
                      : l.studioFeatBudgetInvalid,
                  style: valid
                      ? text.bodySmall
                      : TextStyle(color: t.danger, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
