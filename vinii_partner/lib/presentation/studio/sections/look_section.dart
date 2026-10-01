import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/studio_controller.dart';
import '../../../domain/organization.dart';
import '../../../domain/storefront.dart';
import '../../menu/panel.dart';
import '../../theme/guest_theme.dart';
import '../../theme/staff_theme.dart';

/// Hand-picked accents that read well on all three templates. Swatches,
/// not data: the storefront only stores the one the restaurant picks.
const curatedAccents = [
  '#F5B82E',
  '#F28C28',
  '#E4572E',
  '#D62828',
  '#C2185B',
  '#7C3AED',
  '#2563EB',
  '#0F766E',
  '#16A34A',
  '#65A30D',
  '#6D4C41',
  '#2B211B',
];

/// What the VINII OS storefront CMS has set beyond the template, in a few
/// words, so a person knows why the preview looks the way it does. Read
/// only: the phone has no editors for these.
List<String> cmsLookSummary(StorefrontDefinition d) {
  final theme = d.theme;
  final shape = theme.buttonShape, style = theme.buttonStyle;
  final pictures = [
    d.brand.logoUrl,
    d.brand.coverUrl,
    d.media.hero,
    ...d.media.categories.values,
  ].where((r) => r != null && r.trim().isNotEmpty).length;
  final languages = d.copy.texts.keys.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  String plural(int n, String one) => n == 1 ? '1 $one' : '$n ${one}s';
  return [
    if (theme.colors.isNotEmpty) plural(theme.colors.length, 'custom colour'),
    if (shape != null || style != null)
      [
        if (shape != null) shape.key,
        if (style == StorefrontButtonStyle.outline) 'outlined',
        'buttons',
      ].join(' '),
    if (theme.headingFont != null) '${theme.headingFont!.family} headings',
    if (theme.bodyFont != null) '${theme.bodyFont!.family} text',
    if (pictures > 0) plural(pictures, 'picture'),
    if (languages.isNotEmpty)
      'guest text in ${languages.map((l) => l.nativeName).join(', ')}',
  ];
}

/// Template, accent colour and category style: the storefront's look.
class LookSection extends StatelessWidget {
  const LookSection({super.key, required this.controller});
  final StudioController controller;

  void _template(StorefrontTemplate t) => controller.edit((d) {
    // A restaurant that never picked its own accent follows the template's.
    final custom =
        d.accentHex.toUpperCase() != d.template.defaultAccent.toUpperCase();
    return d.copyWith(
      template: t,
      accentHex: custom ? d.accentHex : t.defaultAccent,
    );
  });

  @override
  Widget build(BuildContext context) {
    final d = controller.draft;
    final text = Theme.of(context).textTheme;
    final brandColor = parseHexColor(controller.org.accentHex);
    final brand = brandColor == null ? null : toHexColor(brandColor);
    final swatches = <({String hex, String? label})>[
      (hex: d.template.defaultAccent.toUpperCase(), label: 'Template'),
      if (brand != null) (hex: brand, label: 'Your brand'),
      for (final h in curatedAccents) (hex: h, label: null),
    ];
    final seen = <String>{};
    final unique = [
      for (final s in swatches)
        if (seen.add(s.hex)) s,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const PanelLabel('Template', top: 4),
        for (final t in StorefrontTemplate.values) ...[
          _TemplateCard(
            template: t,
            selected: d.template == t,
            palette: GuestPalette.from(
              d.copyWith(
                template: t,
                accentHex: d.template == t ? d.accentHex : t.defaultAccent,
              ),
            ),
            onTap: () => _template(t),
          ),
          const SizedBox(height: 10),
        ],
        PanelLabel(
          'Accent colour',
          trailing: Text(
            d.accentHex.toUpperCase(),
            style: text.labelLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Panel(
          children: [
            Text(
              'Buttons, highlights and the budget ring use this colour.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final s in unique)
                  _Swatch(
                    hex: s.hex,
                    label: s.label,
                    selected: d.accentHex.toUpperCase() == s.hex,
                    onTap: () =>
                        controller.edit((d) => d.copyWith(accentHex: s.hex)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _HexField(
              key: ValueKey(d.accentHex.toUpperCase()),
              hex: d.accentHex,
              onChanged: (hex) =>
                  controller.edit((d) => d.copyWith(accentHex: hex)),
            ),
          ],
        ),
        const PanelLabel('Category style'),
        Row(
          children: [
            for (final s in CategoryStyle.values) ...[
              if (s != CategoryStyle.values.first) const SizedBox(width: 10),
              Expanded(
                child: _StyleCard(
                  style: s,
                  selected: d.categoryStyle == s,
                  onTap: () =>
                      controller.edit((d) => d.copyWith(categoryStyle: s)),
                ),
              ),
            ],
          ],
        ),
        const PanelLabel('More in VINII OS'),
        _CmsNote(summary: cmsLookSummary(d)),
      ],
    );
  }
}

/// Colours, fonts, pictures and guest text are edited in the VINII OS
/// storefront CMS, on the same draft; a save here keeps them.
class _CmsNote extends StatelessWidget {
  const _CmsNote({required this.summary});
  final List<String> summary;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Panel(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.desktop_windows_outlined, color: t.inkSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Colours, fonts, pictures and all guest text can also be '
                'edited in the VINII OS storefront CMS. Both edit the same '
                'draft, and saving here keeps what was set there.',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Set there now: ${summary.join(' · ')}.',
            key: const ValueKey('cms-look-summary'),
            style: text.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final StorefrontTemplate template;
  final bool selected;
  final GuestPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final p = palette;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? t.ink : t.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // A tiny storefront in the template's own colours and type.
                Container(
                  width: 86,
                  height: 104,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aa', style: p.hero(24)),
                      const Spacer(),
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: p.border),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 14,
                        width: 44,
                        decoration: BoxDecoration(
                          color: p.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.label, style: text.titleMedium),
                      const SizedBox(height: 4),
                      Text(template.description, style: text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? t.ink : t.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.hex,
    required this.selected,
    required this.onTap,
    this.label,
  });

  final String hex;
  final String? label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final color = parseHexColor(hex)!;
    return Semantics(
      label: label == null ? 'Colour $hex' : '$label colour $hex',
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 52,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? t.ink : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.border),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: onColor(color),
                        )
                      : null,
                ),
              ),
              if (label != null) ...[
                const SizedBox(height: 4),
                Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: t.inkSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Any colour, typed as six hex digits. Only a complete, valid colour is
/// applied, so the stored accent is always `#RRGGBB`.
class _HexField extends StatefulWidget {
  const _HexField({super.key, required this.hex, required this.onChanged});
  final String hex;
  final ValueChanged<String> onChanged;

  @override
  State<_HexField> createState() => _HexFieldState();
}

class _HexFieldState extends State<_HexField> {
  late final _text = TextEditingController(
    text: widget.hex.replaceFirst('#', '').toUpperCase(),
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _apply() {
    final v = _text.text.trim().toUpperCase();
    if (parseHexColor(v) != null) widget.onChanged('#$v');
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    textCapitalization: TextCapitalization.characters,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
      LengthLimitingTextInputFormatter(6),
    ],
    onSubmitted: (_) => _apply(),
    onChanged: (v) {
      if (v.length == 6) _apply();
    },
    decoration: const InputDecoration(
      labelText: 'Custom colour',
      prefixText: '# ',
      helperText: 'Six characters, like the code from your logo file',
      isDense: true,
    ),
  );
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final CategoryStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? t.ink : t.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  style == CategoryStyle.grid
                      ? Icons.grid_view_rounded
                      : Icons.view_carousel_rounded,
                  color: selected ? t.ink : t.inkSecondary,
                ),
                const SizedBox(height: 10),
                Text(style.label, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(style.hint, style: text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
