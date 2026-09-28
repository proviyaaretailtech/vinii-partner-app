import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/studio_controller.dart';
import '../../../core/money.dart';
import '../../../domain/storefront.dart';
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
    final f = _c.draft.features;
    final groups = <(String, List<_Flag>)>[
      (
        'Browsing the menu',
        [
          (
            title: 'Swipe cards',
            subtitle: 'Guests swipe through dishes like cards. Off: a simple scrolling list with Add buttons.',
            value: f.swipeDeck,
            set: (f, v) => f.copyWith(swipeDeck: v),
          ),
          (
            title: 'Save for later',
            subtitle: 'Guests heart dishes and come back to them.',
            value: f.likes,
            set: (f, v) => f.copyWith(likes: v),
          ),
          (
            title: "Chef's picks",
            subtitle: "A row of dishes you choose, at the top. Pick them in Chef's picks & offers.",
            value: f.chefsPicks,
            set: (f, v) => f.copyWith(chefsPicks: v),
          ),
          (
            title: 'Limited today',
            subtitle: 'Dishes on offer until a time you set, with a countdown.',
            value: f.limitedToday,
            set: (f, v) => f.copyWith(limitedToday: v),
          ),
        ],
      ),
      (
        'Groups',
        [
          (
            title: 'Split between people',
            subtitle: 'Guests say how many are eating; the budget and bill show each share.',
            value: f.splitParty,
            set: (f, v) => f.copyWith(splitParty: v),
          ),
          (
            title: 'Split the bill',
            subtitle: 'Guests see the bill divided equally when paying.',
            value: f.splitBill,
            set: (f, v) => f.copyWith(splitBill: v),
          ),
        ],
      ),
      (
        'After ordering',
        [
          (
            title: 'Live order tracking',
            subtitle:
                'Guests see when the kitchen starts and finishes their order.',
            value: f.liveTracking,
            set: (f, v) => f.copyWith(liveTracking: v),
          ),
          (
            title: 'Discover while waiting',
            subtitle: 'While the food cooks, guests can browse desserts and drinks to add.',
            value: f.discoverWhileWaiting,
            set: (f, v) => f.copyWith(discoverWhileWaiting: v),
          ),
          (
            title: 'Feedback',
            subtitle: 'Guests rate their meal. Feedback is collected once feedback storage exists; until then guests are not asked.',
            value: f.feedback,
            set: (f, v) => f.copyWith(feedback: v),
          ),
        ],
      ),
      (
        'Dish details',
        [
          (
            title: 'Ingredients',
            subtitle:
                'Shows the ingredients you add to a dish in the Menu tab.',
            value: f.showIngredients,
            set: (f, v) => f.copyWith(showIngredients: v),
          ),
          (
            title: 'Allergens',
            subtitle: 'Shows the allergens you mark on each dish.',
            value: f.showAllergens,
            set: (f, v) => f.copyWith(showAllergens: v),
          ),
          (
            title: 'Calories',
            subtitle: 'Shows the kcal you enter for a dish.',
            value: f.showNutrition,
            set: (f, v) => f.copyWith(showNutrition: v),
          ),
        ],
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const PanelLabel('Budget', top: 4),
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
          prefixText: '₹',
          isDense: true,
        ),
      ),
    );
    return Panel(
      padding: null,
      children: [
        SwitchListTile(
          title: const Text(
            'Budget',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Guests set how much they want to spend and see what fits.',
          ),
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
                    field('Minimum', _min, (v) => _budget(min: v)),
                    const SizedBox(width: 8),
                    field(
                      'Starts at',
                      _default,
                      (v) => _budget(defaultAmount: v),
                    ),
                    const SizedBox(width: 8),
                    field('Maximum', _max, (v) => _budget(max: v)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  valid
                      ? 'Guests start at ${rupees(b.defaultAmount)} and move in steps of ${rupees(b.step)}.'
                      : 'Keep minimum ≤ starts at ≤ maximum, and the minimum above ₹0.',
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
