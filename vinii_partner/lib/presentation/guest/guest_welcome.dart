import 'package:flutter/material.dart';

import '../../domain/storefront.dart';
import '../theme/guest_theme.dart';
import 'guest_effects.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';

/// Board 1 #1 / Board 2 #2: the full-bleed welcome. Everything written here
/// is the merchant's own words; empty brand fields are simply left out.
/// The picture behind it is the CMS's welcome picture, else its cover,
/// else the restaurant's first dish photo, else a glow in the accent.
class GuestWelcomeScreen extends StatelessWidget {
  const GuestWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final t = GuestCopy.of(context);
    final brand = s.definition.brand;
    // The layout follows the template; the faces may be the CMS's.
    final artisan = p.template == StorefrontTemplate.artisanDay;
    final hasHero = brand.heroTitle.trim().isNotEmpty;
    final modes = s.definition.serviceModes;
    final cover =
        GuestScope.mediaUrlOf(context, s.definition.media.hero) ??
        GuestScope.mediaUrlOf(context, brand.coverUrl) ??
        s.catalog.allItems
            .where((i) => i.item.imageUrl != null)
            .firstOrNull
            ?.item
            .imageUrl;
    // Shown only when the restaurant wrote it; the screen never had one.
    final tableLine = s.tableName == null
        ? null
        : t.own('welcome.table_line', {'table': s.tableName!});

    return Scaffold(
      backgroundColor: p.isDark ? p.background : p.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _HeroBackdrop(url: cover),
          const PhotoScrim(strength: 0.92, top: true),
          SafeArea(
            child: GuestColumn(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: artisan
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    _BrandRow(artisan: artisan, showName: hasHero || artisan),
                    if (s.languages.length > 1) ...[
                      const SizedBox(height: 14),
                      const _LanguageSwitch(),
                    ],
                    const Spacer(),
                    _Rise(
                      delay: 0,
                      child: hasHero
                          ? _Headline(text: brand.heroTitle, artisan: artisan)
                          : Text(
                              brand.displayName,
                              textAlign: artisan
                                  ? TextAlign.center
                                  : TextAlign.start,
                              style: p.display(44, color: Colors.white),
                            ),
                    ),
                    if (brand.heroSubtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _Rise(
                        delay: 120,
                        child: Text(
                          brand.heroSubtitle,
                          textAlign: artisan
                              ? TextAlign.center
                              : TextAlign.start,
                          style: p.body(
                            16,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ),
                    ],
                    if (tableLine != null) ...[
                      const SizedBox(height: 14),
                      _Rise(
                        delay: 160,
                        child: Text(
                          tableLine,
                          textAlign: artisan
                              ? TextAlign.center
                              : TextAlign.start,
                          style: p.body(
                            15,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    _Rise(
                      delay: 220,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: modes.length == 2
                            ? Column(
                                children: [
                                  for (final (i, m) in modes.indexed) ...[
                                    if (i > 0) const SizedBox(height: 12),
                                    _ModePill(mode: m, primary: i == 0),
                                  ],
                                ],
                              )
                            : GuestButton(
                                key: const ValueKey('welcome-cta'),
                                label: t('welcome.cta'),
                                trailingArrow: true,
                                onImage: true,
                                onTap: () => GuestFlow.start(context),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    // The hero is always night-dark so the white headline reads; light
    // templates use their own ink (espresso) instead of pure black.
    final night = p.isDark ? p.background : p.ink;
    final glow = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.6, -0.5),
          radius: 1.3,
          colors: [
            p.accent.withValues(alpha: 0.55),
            Color.lerp(night, p.accent, 0.08)!,
            night,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
    );
    if (url == null) return glow;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.12, end: 1),
      duration: const Duration(seconds: 6),
      curve: Curves.easeOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => glow,
      ),
    );
  }
}

/// Logo + name + location pin (bistro), or the centred serif wordmark
/// with the tagline beneath (artisan).
class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.artisan, required this.showName});
  final bool artisan;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final brand = GuestScope.read(context).definition.brand;
    final muted = Colors.white.withValues(alpha: 0.72);
    if (artisan) {
      return Row(
        children: [
          const SizedBox(width: 40),
          Expanded(
            child: Column(
              children: [
                if (GuestLogo.hasPicture(context)) ...[
                  const GuestLogo(size: 56, initials: false),
                  const SizedBox(height: 10),
                ],
                Text(
                  brand.displayName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: p
                      .display(22, weight: FontWeight.w700, color: Colors.white)
                      .copyWith(letterSpacing: 3),
                ),
                if (brand.tagline.trim().isNotEmpty)
                  Text(
                    brand.tagline,
                    textAlign: TextAlign.center,
                    style: p.body(12.5, color: muted),
                  ),
                if (brand.locationLine.trim().isNotEmpty)
                  _Location(text: brand.locationLine, color: muted),
              ],
            ),
          ),
          const SizedBox(width: 40, child: GuestExitButton()),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GuestLogo(size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showName)
                Text(
                  brand.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.display(18, color: Colors.white),
                ),
              if (brand.tagline.trim().isNotEmpty)
                Text(
                  brand.tagline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.body(12.5, color: muted),
                ),
              if (brand.locationLine.trim().isNotEmpty)
                _Location(text: brand.locationLine, color: muted),
            ],
          ),
        ),
        const GuestExitButton(),
      ],
    );
  }
}

class _Location extends StatelessWidget {
  const _Location({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_outlined, size: 14, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: p.body(12.5, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The giant headline. Bistro: bold sans with the second half in the
/// accent. Artisan: the handwritten script, centred.
class _Headline extends StatelessWidget {
  const _Headline({required this.text, required this.artisan});
  final String text;
  final bool artisan;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    if (artisan) {
      return Text(
        text,
        textAlign: TextAlign.center,
        style: p.hero(46, color: Colors.white),
      );
    }
    final words = text.trim().split(RegExp(r'\s+'));
    final cut = words.length < 3 ? words.length : words.length ~/ 2;
    final first = words.take(cut).join(' ');
    final rest = words.skip(cut).join(' ');
    final base = p.display(40, color: Colors.white).copyWith(height: 1.05);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: first),
          if (rest.isNotEmpty)
            TextSpan(
              text: '\n$rest',
              style: base.copyWith(color: p.accent),
            ),
        ],
      ),
    );
  }
}

/// "Order now · Dine-in at Table 12" / "Pre-order · Schedule for later".
class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode, required this.primary});
  final GuestServiceMode mode;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.read(context);
    final (title, hint) = switch (mode) {
      GuestServiceMode.dineIn => (
        'Order now',
        s.tableName == null ? 'Dine-in' : 'Dine-in at ${s.tableName}',
      ),
      GuestServiceMode.preOrder => ('Pre-order', 'Schedule for later'),
      _ => (mode.label, mode.hint),
    };
    // An outlined main button sits on the dark welcome picture: white.
    final outline = primary && p.buttonOutline;
    final bg = outline
        ? Colors.transparent
        : primary
        ? p.accent
        : p.isDark
        ? p.surfaceAlt
        : p.background;
    final fg = outline
        ? Colors.white
        : primary
        ? p.onAccent
        : p.ink;
    return Material(
      color: bg,
      shape: p.buttonShape(
        outline
            ? const BorderSide(color: Colors.white, width: 1.8)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => GuestFlow.start(context, chosen: mode),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: p.body(16, weight: FontWeight.w800, color: fg),
              ),
              Flexible(
                child: Text(
                  '  ·  $hint',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.body(14, color: fg.withValues(alpha: 0.72)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// English · हिन्दी · मराठी — only the languages the restaurant wrote guest
/// text in (English is always readable). Glass chips over the picture.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final current = s.languages.contains(s.language)
        ? s.language
        : CopyLanguage.en;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: p.template == StorefrontTemplate.artisanDay
          ? WrapAlignment.center
          : WrapAlignment.start,
      children: [
        for (final l in s.languages)
          Semantics(
            button: true,
            selected: l == current,
            label: l.label,
            child: GestureDetector(
              key: ValueKey('guest-language-${l.key}'),
              onTap: () => s.setLanguage(l),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: l == current
                      ? Colors.white
                      : Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  l.nativeName,
                  style: p.body(
                    12.5,
                    weight: FontWeight.w700,
                    color: l == current ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Content rises and fades in, staggered by [delay] ms.
class _Rise extends StatelessWidget {
  const _Rise({required this.delay, required this.child});
  final int delay;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 700 + delay),
    curve: Interval(delay / (700 + delay), 1, curve: Curves.easeOutCubic),
    builder: (context, v, child) => Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
    ),
    child: child,
  );
}
