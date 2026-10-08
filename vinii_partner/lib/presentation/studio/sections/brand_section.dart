import 'package:flutter/material.dart';

import '../../../application/studio_controller.dart';
import '../../../domain/storefront.dart';
import '../../../l10n/l10n.dart';
import '../../menu/panel.dart';
import '../../theme/guest_theme.dart';

/// The restaurant's name and the words on the welcome screen.
///
/// Every field starts with what the restaurant has written — for a new
/// storefront that is only its real name and city. The template's example
/// wording is shown greyed out as a hint and is never saved, so a
/// storefront never says something its owner did not write.
class BrandSection extends StatefulWidget {
  const BrandSection({super.key, required this.controller});
  final StudioController controller;

  @override
  State<BrandSection> createState() => _BrandSectionState();
}

class _BrandSectionState extends State<BrandSection> {
  late final StorefrontBrand _start = widget.controller.draft.brand;
  late final _name = TextEditingController(text: _start.displayName);
  late final _tagline = TextEditingController(text: _start.tagline);
  late final _location = TextEditingController(text: _start.locationLine);
  late final _heroTitle = TextEditingController(text: _start.heroTitle);
  late final _heroText = TextEditingController(text: _start.heroSubtitle);

  @override
  void dispose() {
    for (final c in [_name, _tagline, _location, _heroTitle, _heroText]) {
      c.dispose();
    }
    super.dispose();
  }

  void _edit(StorefrontBrand Function(StorefrontBrand b) change) =>
      widget.controller.edit((d) => d.copyWith(brand: change(d.brand)));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = widget.controller.draft;
    final t = d.template;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        PanelLabel(l.studioBrandWelcomeScreen, top: 4),
        _WelcomePreview(definition: d),
        PanelLabel(l.studioBrandNamePlace),
        Panel(
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => _edit((b) => b.copyWith(displayName: v)),
              decoration: InputDecoration(
                labelText: l.studioBrandDisplayName,
                helperText: l.studioBrandDisplayNameHelp,
                errorText: d.brand.displayName.trim().isEmpty
                    ? l.studioBrandNameRequired
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagline,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => _edit((b) => b.copyWith(tagline: v)),
              decoration: InputDecoration(
                labelText: l.studioBrandTagline,
                // i18n-ignore: template example wording, guest-facing and never saved
                hintText: t.defaultTagline,
                helperText: l.studioBrandTaglineHelp,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => _edit((b) => b.copyWith(locationLine: v)),
              decoration: InputDecoration(
                labelText: l.studioBrandLocationLine,
                hintText: l.studioBrandLocationHint,
                helperText: l.studioBrandLocationHelp,
              ),
            ),
          ],
        ),
        PanelLabel(l.studioBrandWelcomeWords),
        Panel(
          children: [
            TextField(
              controller: _heroTitle,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              minLines: 1,
              onChanged: (v) => _edit((b) => b.copyWith(heroTitle: v)),
              decoration: InputDecoration(
                labelText: l.studioBrandHeroTitle,
                // i18n-ignore: template example wording, guest-facing and never saved
                hintText: t.defaultHeroTitle,
                hintMaxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _heroText,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              onChanged: (v) => _edit((b) => b.copyWith(heroSubtitle: v)),
              decoration: InputDecoration(
                labelText: l.studioBrandHeroText,
                // i18n-ignore: template example wording, guest-facing and never saved
                hintText: t.defaultHeroSubtitle,
                hintMaxLines: 3,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              // i18n-ignore: template name
              l.studioBrandExampleNote(template: t.label),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

/// The welcome headline in the template's own type and colours, updated as
/// the person types.
class _WelcomePreview extends StatelessWidget {
  const _WelcomePreview({required this.definition});
  final StorefrontDefinition definition;

  @override
  Widget build(BuildContext context) {
    final d = definition;
    final p = GuestPalette.from(d);
    final b = d.brand;
    final headline = b.heroTitle.trim();
    final sub = b.heroSubtitle.trim();
    final place = [
      if (b.tagline.trim().isNotEmpty) b.tagline.trim(),
      if (b.locationLine.trim().isNotEmpty) b.locationLine.trim(),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            b.displayName.trim().isEmpty ? ' ' : b.displayName.trim(),
            style: p.display(18, weight: FontWeight.w800),
          ),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(place, style: p.body(12.5, color: p.inkMuted)),
          ],
          const SizedBox(height: 18),
          Text(
            headline.isEmpty ? d.template.defaultHeroTitle : headline,
            style: p.hero(
              28,
              color: headline.isEmpty
                  ? p.inkMuted.withValues(alpha: 0.45)
                  : p.ink,
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(sub, style: p.body(14, color: p.inkMuted)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: p.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              if (headline.isEmpty)
                Expanded(
                  child: Text(
                    context.l10n.studioBrandExampleHeadline,
                    style: p.body(11.5, color: p.inkMuted),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
