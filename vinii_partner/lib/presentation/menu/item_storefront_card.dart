import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/failure.dart';
import '../../domain/storefront.dart';
import '../../l10n/failure_text.dart';
import '../../l10n/l10n.dart';
import '../theme/staff_theme.dart';
import 'menu_labels.dart';
import 'panel.dart';

/// Allergens restaurants most often need to declare. Custom ones can be
/// added; these are just the quick picks. The English word is what gets
/// stored on the dish (guests and later translations read it); the chip the
/// staff member sees is translated by `allergenLabel`.
// i18n-ignore: stored values, shown through allergenLabel
const commonAllergens = [
  'Gluten',
  'Dairy',
  'Egg',
  'Nuts',
  'Tree nuts',
  'Peanuts',
  'Soy',
  'Sesame',
  'Shellfish',
  'Fish',
  'Mustard',
];

/// The guest-only details of one dish (tags, ingredients, allergens,
/// calories, hidden). They live in the storefront draft, not on the POS
/// row, so they never change what the cashier sees and only reach guests
/// once someone publishes in Studio.
class ItemStorefrontCard extends StatefulWidget {
  const ItemStorefrontCard({
    super.key,
    required this.enabled,
    required this.loading,
    required this.failure,
    required this.tags,
    required this.ingredients,
    required this.allergens,
    required this.hidden,
    required this.kcal,
    required this.onChanged,
    this.onRetry,
  });

  /// False for people who may look at the storefront but not change it.
  final bool enabled;
  final bool loading;
  final AppFailure? failure;
  final List<String> tags;
  final List<String> ingredients;
  final List<String> allergens;
  final bool hidden;
  final TextEditingController kcal;

  /// Called with the new values after any change.
  final void Function({
    List<String>? tags,
    List<String>? ingredients,
    List<String>? allergens,
    bool? hidden,
  })
  onChanged;
  final VoidCallback? onRetry;

  @override
  State<ItemStorefrontCard> createState() => _ItemStorefrontCardState();
}

class _ItemStorefrontCardState extends State<ItemStorefrontCard> {
  final _ingredient = TextEditingController();
  final _allergen = TextEditingController();

  @override
  void dispose() {
    _ingredient.dispose();
    _allergen.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final v = _ingredient.text.trim();
    if (v.isEmpty) return;
    final exists = widget.ingredients.any(
      (i) => i.toLowerCase() == v.toLowerCase(),
    );
    if (!exists) widget.onChanged(ingredients: [...widget.ingredients, v]);
    _ingredient.clear();
  }

  void _addAllergen() {
    final v = _allergen.text.trim();
    if (v.isEmpty) return;
    final exists = widget.allergens.any(
      (a) => a.toLowerCase() == v.toLowerCase(),
    );
    if (!exists) widget.onChanged(allergens: [...widget.allergens, v]);
    _allergen.clear();
  }

  List<String> _toggle(List<String> list, String v, bool on) =>
      on ? [...list, v] : list.where((x) => x != v).toList();

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    if (widget.loading) {
      return const Panel(
        children: [
          SizedBox(
            height: 64,
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          ),
        ],
      );
    }
    if (widget.failure != null) {
      return Panel(
        children: [
          Text(l.menuStorefrontLoadFailedTitle, style: text.titleSmall),
          const SizedBox(height: 4),
          Text(failureText(l, widget.failure!), style: text.bodyMedium),
          if (widget.onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onRetry,
                child: Text(l.commonTryAgain),
              ),
            ),
          ],
        ],
      );
    }
    final customAllergens = widget.allergens
        .where((a) => !commonAllergens.contains(a))
        .toList();
    final on = widget.enabled;
    return Panel(
      children: [
        PanelHeader(title: l.menuTagsTitle, subtitle: l.menuTagsHint),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in storefrontTags)
              FilterChip(
                label: Text(l.storefrontTagLabel(tag)),
                selected: widget.tags.contains(tag),
                onSelected: on
                    ? (v) =>
                          widget.onChanged(tags: _toggle(widget.tags, tag, v))
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 20),
        PanelHeader(
          title: l.menuIngredientsTitle,
          subtitle: l.menuIngredientsHint,
        ),
        const SizedBox(height: 10),
        if (on)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ingredient,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addIngredient(),
                  decoration: InputDecoration(
                    hintText: l.menuIngredientHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: l.menuIngredientAdd,
                onPressed: _addIngredient,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        if (widget.ingredients.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in widget.ingredients)
                InputChip(
                  label: Text(i),
                  onDeleted: on
                      ? () => widget.onChanged(
                          ingredients: widget.ingredients
                              .where((x) => x != i)
                              .toList(),
                        )
                      : null,
                ),
            ],
          ),
        ] else if (!on)
          Text(l.menuNoneAdded, style: text.bodySmall),
        const SizedBox(height: 20),
        PanelHeader(title: l.menuAllergensTitle, subtitle: l.menuAllergensHint),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in [...commonAllergens, ...customAllergens])
              FilterChip(
                label: Text(l.allergenLabel(a)),
                selected: widget.allergens.contains(a),
                onSelected: on
                    ? (v) => widget.onChanged(
                        allergens: _toggle(widget.allergens, a, v),
                      )
                    : null,
              ),
          ],
        ),
        if (on) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _allergen,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _addAllergen(),
                  decoration: InputDecoration(
                    hintText: l.menuAllergenAnother,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: l.menuAllergenAdd,
                onPressed: _addAllergen,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: widget.kcal,
          enabled: on,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          onChanged: (_) => widget.onChanged(),
          decoration: InputDecoration(
            labelText: l.menuCalories,
            suffixText: 'kcal', // i18n-ignore: unit symbol
            helperText: l.menuCaloriesHint,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.menuHideFromStorefront),
          subtitle: Text(l.menuHideFromStorefrontHint),
          value: widget.hidden,
          onChanged: on ? (v) => widget.onChanged(hidden: v) : null,
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule_send_outlined, size: 16, color: t.inkMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                on ? l.menuStorefrontPublishNote : l.menuStorefrontReadOnlyNote,
                style: text.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
