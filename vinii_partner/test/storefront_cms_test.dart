import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/application/studio_changes.dart';
import 'package:vinii_partner/domain/organization.dart';
import 'package:vinii_partner/domain/storefront.dart';
import 'package:vinii_partner/presentation/guest/guest_app.dart';
import 'package:vinii_partner/presentation/theme/guest_theme.dart';

import 'guest_runtime_test.dart'
    show RecordingGateway, menu, noBudget, pumpGuest, settle, storefront;

/// The fields the VINII OS storefront CMS adds to a definition. Values are
/// made up for these tests; the app itself ships none.
const org = Organization(
  id: 'org-1',
  name: 'Test Bistro',
  slug: 'test-bistro',
  type: 'restaurant',
);

Map<String, dynamic> cmsDocument() {
  final starter = StorefrontDefinition.starter(org).toJson();
  final doc = {
    ...starter,
    'brand': {
      ...starter['brand'] as Map<String, dynamic>,
      'logo_url': 'org-1/logo.png',
      'cover_url': 'https://cdn.example.com/cover.jpg',
      // Brand keys this app has never heard of.
      'instagram': '@testbistro',
      'badges': ['veg-friendly', 'family'],
    },
    'theme': {
      'colors': {
        'on_accent': '#FFFFFF',
        'background': '#101418',
        'surface': '#1A2027',
        'text': '#F5F5F5',
        'muted': '#9AA4AE',
        'success': '#22C55E',
        'danger': '#EF4444',
      },
      'buttons': {'shape': 'square', 'style': 'outline'},
      'fonts': {'heading': 'kaushan-script', 'body': 'poppins'},
      'radius_scale': 1.2,
    },
    'media': {
      'hero': 'org-1/hero.webp',
      'categories': {
        'c-mains': 'org-1/mains.jpg',
        'c-dess': 'https://cdn.example.com/desserts.jpg',
      },
    },
    'copy': {
      'en': {'cart.place': 'Send to kitchen', 'welcome.cta': "Let's eat"},
      'hi': {'cart.place': 'ऑर्डर भेजें'},
      'ta': {'cart.place': 'Anuppu'},
    },
    'default_language': 'hi',
    // Top-level keys from a newer CMS.
    'seo': {'title': 'Test Bistro', 'noindex': false},
    'announcement': 'Closed on Mondays',
  };
  return jsonDecode(jsonEncode(doc)) as Map<String, dynamic>;
}

/// What the phone would send to the database for [d].
Map<String, dynamic> wire(StorefrontDefinition d) =>
    jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>;

const cmsKeys = [
  'theme',
  'media',
  'copy',
  'default_language',
  'seo',
  'announcement',
];

void main() {
  group('storefront definition keeps what the CMS wrote', () {
    test('theme, media, copy and unknown keys survive a round trip', () {
      final doc = cmsDocument();
      final def = StorefrontDefinition.fromJson(doc, org: org);

      // The typed views read the CMS fields…
      expect(def.theme.colors['background'], '#101418');
      expect(def.theme.buttonShape, StorefrontButtonShape.square);
      expect(def.theme.buttonStyle, StorefrontButtonStyle.outline);
      expect(def.theme.headingFont, StorefrontFont.kaushanScript);
      expect(def.theme.bodyFont, StorefrontFont.poppins);
      expect(def.media.hero, 'org-1/hero.webp');
      expect(def.media.categories['c-mains'], 'org-1/mains.jpg');
      expect(def.copy.own(CopyLanguage.hi, 'cart.place'), 'ऑर्डर भेजें');
      expect(def.defaultLanguage, CopyLanguage.hi);
      expect(def.brand.logoUrl, 'org-1/logo.png');
      expect(def.brand.extra['instagram'], '@testbistro');
      expect(def.extra.keys, containsAll(['seo', 'announcement']));

      // …and writing it back changes nothing, byte for byte.
      final back = wire(def);
      expect(back, doc);
      for (final k in cmsKeys) {
        expect(jsonEncode(back[k]), jsonEncode(doc[k]), reason: k);
      }
      expect(
        jsonEncode(back['brand']),
        jsonEncode(doc['brand']),
        reason: 'brand',
      );
    });

    test('a phone edit keeps every CMS field', () {
      final doc = cmsDocument();
      final def = StorefrontDefinition.fromJson(doc, org: org);
      final edited = def.copyWith(
        template: StorefrontTemplate.artisanDay,
        accentHex: '#E4572E',
        brand: def.brand.copyWith(heroTitle: 'Dinner at our place'),
      );
      final back = wire(edited);
      for (final k in cmsKeys) {
        expect(jsonEncode(back[k]), jsonEncode(doc[k]), reason: k);
      }
      final brand = back['brand'] as Map<String, dynamic>;
      expect(brand['hero_title'], 'Dinner at our place');
      expect(brand['instagram'], '@testbistro');
      expect(brand['badges'], ['veg-friendly', 'family']);
      expect(brand['logo_url'], 'org-1/logo.png');
      expect(back['template'], 'artisan_day');
    });

    test('values this app cannot use are carried, not dropped', () {
      final def = StorefrontDefinition.fromJson({
        'template': 'bistro_night',
        'theme': 'midnight',
        'default_language': 'ta',
        'copy': {
          'en': {
            'menu.add': '   Add it   ',
            'cart.place': 'x' * 40,
            'menu.search': '   ',
            'promo.banner': 'Hello',
          },
        },
      }, org: org);
      expect(def.theme.isEmpty, isTrue);
      expect(def.guestLanguage, CopyLanguage.en);
      // The guest view is clean: trimmed, capped, known keys only.
      expect(def.copy.own(CopyLanguage.en, 'menu.add'), 'Add it');
      expect(def.copy.own(CopyLanguage.en, 'cart.place'), 'x' * 22);
      expect(def.copy.own(CopyLanguage.en, 'menu.search'), isNull);
      expect(def.copy.own(CopyLanguage.en, 'promo.banner'), isNull);
      // The stored JSON is untouched.
      final out = wire(def);
      expect(out['theme'], 'midnight');
      expect(out['default_language'], 'ta');
      final en = (out['copy'] as Map)['en'] as Map;
      expect(en['promo.banner'], 'Hello');
      expect(en['cart.place'], 'x' * 40);
    });

    test('theme view: valid colours upper-cased, no script body text', () {
      final t = StorefrontTheme.fromJson({
        'colors': {'background': '#abcdef', 'text': 'red', 'glow': '#000000'},
        'buttons': {'shape': 'leaf', 'style': 'outline'},
        'fonts': {'heading': 'comic-sans', 'body': 'kaushan-script'},
      });
      expect(t.colors, {'background': '#ABCDEF'});
      expect(t.buttonShape, isNull);
      expect(t.buttonStyle, StorefrontButtonStyle.outline);
      expect(t.headingFont, isNull);
      expect(t.bodyFont, isNull);
      expect(StorefrontFont.fromId('source-serif-4')!.family, 'Source Serif 4');
      expect(StorefrontFont.fromId('dm-sans')!.family, 'DM Sans');
    });

    test('a definition without CMS fields writes none', () {
      final out = wire(StorefrontDefinition.starter(org));
      for (final k in cmsKeys) {
        expect(out.containsKey(k), isFalse, reason: k);
      }
    });

    test('the publish summary names CMS changes too', () {
      final a = StorefrontDefinition.fromJson(cmsDocument(), org: org);
      final b = a.copyWith(
        theme: StorefrontTheme(buttonShape: StorefrontButtonShape.pill),
        media: StorefrontMedia(hero: 'org-1/new-hero.webp'),
        copy: StorefrontCopy({
          CopyLanguage.en: {'cart.place': 'Order'},
        }),
        defaultLanguage: CopyLanguage.mr,
      );
      expect(describeStorefrontChanges(a, a), isEmpty);
      expect(describeStorefrontChanges(a, b), [
        'Colours, buttons and fonts',
        'Pictures',
        'Guest text',
        'Guests start in मराठी (Marathi)',
      ]);
    });
  });

  group('copy registry', () {
    final copy = StorefrontCopy({
      CopyLanguage.en: {
        'cart.place': 'Send it',
        'welcome.table_line': 'Hello {table}, {guest}',
      },
      CopyLanguage.hi: {'welcome.cta': 'शुरू करें'},
    });

    test("fallback order: guest's language → English → registry", () {
      expect(copyText(copy, 'welcome.cta', CopyLanguage.hi), 'शुरू करें');
      expect(copyText(copy, 'cart.place', CopyLanguage.hi), 'Send it');
      expect(copyText(copy, 'bill.ask', CopyLanguage.hi), 'Ask for the bill');
      expect(copyText(null, 'cart.place'), 'Place order');
      expect(copyText(copy, 'no.such.key'), 'no.such.key');
      expect(ownCopyText(copy, 'bill.ask', CopyLanguage.hi), isNull);
      expect(ownCopyText(copy, 'cart.place', CopyLanguage.mr), 'Send it');
    });

    test('{table} placeholders are filled; unknown ones stay', () {
      expect(
        copyText(copy, 'welcome.table_line', CopyLanguage.en, {
          'table': 'Table 12',
        }),
        'Hello Table 12, {guest}',
      );
      expect(
        copyText(null, 'welcome.table_line', CopyLanguage.en, {
          'table': 'Table 4',
        }),
        "You're at Table 4",
      );
    });

    test('guests can switch only to languages with text', () {
      expect(copy.guestLanguages, [CopyLanguage.en, CopyLanguage.hi]);
      expect(StorefrontCopy.empty.guestLanguages, [CopyLanguage.en]);
    });

    // Same keys, defaults and caps as the CMS, when its source is checked
    // out next to this one.
    final ts = File(
      '../../Repo-1--experience-cms/apps/web/src/lib/storefront-copy.ts',
    );
    test('matches the CMS registry (storefront-copy.ts)', () {
      final entries = RegExp(
        r'\{ key: "([^"]+)", label: "[^"]*", fallback: "([^"]*)", max: (\d+) \}',
      ).allMatches(ts.readAsStringSync()).toList();
      expect(entries, hasLength(copyKeys.length));
      for (final m in entries) {
        final k = copyKey(m[1]!);
        expect(k, isNotNull, reason: m[1]);
        expect(k!.fallback, m[2], reason: m[1]);
        expect(k.max, int.parse(m[3]!), reason: m[1]);
      }
    }, skip: ts.existsSync() ? false : 'CMS source not checked out here');
  });

  group('pictures', () {
    test('mediaUrl: https as is, bucket paths under /media, none without a '
        'base', () {
      const base = 'https://os.example.com/';
      expect(mediaUrl(null, base), isNull);
      expect(mediaUrl('  ', base), isNull);
      expect(
        mediaUrl('https://cdn.example.com/a.jpg', ''),
        'https://cdn.example.com/a.jpg',
      );
      expect(
        mediaUrl('http://cdn.example.com/a.jpg', base),
        'http://cdn.example.com/a.jpg',
      );
      expect(
        mediaUrl('org-1/logo.png', base),
        'https://os.example.com/media/org-1/logo.png',
      );
      expect(
        mediaUrl('/org-1/logo.png', 'https://os.example.com//'),
        'https://os.example.com/media/org-1/logo.png',
      );
      expect(mediaUrl('org-1/logo.png', ''), isNull);
    });
  });

  group('guest palette', () {
    setUp(() => GuestPalette.remoteFonts = false);
    const bistro = StorefrontDefinition(
      template: StorefrontTemplate.bistroNight,
      accentHex: '#F5B82E',
      brand: StorefrontBrand(displayName: 'Test Bistro'),
    );

    test('template defaults: pill on Bistro Night, rounded elsewhere', () {
      final p = GuestPalette.from(bistro);
      expect(p.background, const Color(0xFF0B0B0C));
      expect(p.buttonRadius, 999);
      expect(p.buttonShape(), isA<StadiumBorder>());
      expect(p.buttonOutline, isFalse);
      expect(p.displayFace, StorefrontFont.plusJakartaSans);
      final artisan = GuestPalette.from(
        bistro.copyWith(template: StorefrontTemplate.artisanDay),
      );
      expect(artisan.buttonRadius, 14);
      expect(artisan.displayFace, StorefrontFont.playfairDisplay);
    });

    test('theme colours override the template; the accent stays the '
        "definition's", () {
      final p = GuestPalette.from(
        bistro.copyWith(
          theme: StorefrontTheme(
            colors: const {
              'background': '#FFFFFF',
              'surface': '#F0F0F0',
              'text': '#101010',
              'muted': '#555555',
              'success': '#00AA00',
              'danger': '#CC0000',
              'on_accent': '#FFFFFF',
            },
            buttonShape: StorefrontButtonShape.square,
            buttonStyle: StorefrontButtonStyle.outline,
          ),
        ),
      );
      expect(p.background, const Color(0xFFFFFFFF));
      expect(p.surface, const Color(0xFFF0F0F0));
      expect(p.ink, const Color(0xFF101010));
      expect(p.inkMuted, const Color(0xFF555555));
      expect(p.success, const Color(0xFF00AA00));
      expect(p.danger, const Color(0xFFCC0000));
      expect(p.surfaceAlt, const Color(0xFF222226));
      expect(p.accent, const Color(0xFFF5B82E));
      expect(p.onAccent, const Color(0xFFFFFFFF));
      expect(p.isDark, isFalse);
      expect(p.buttonRadius, 6);
      expect(p.buttonOutline, isTrue);
      final shape = p.buttonShape() as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(6));
    });

    test('button text is chosen by contrast unless the CMS sets it', () {
      expect(readableOn('#F5B82E'), '#111115');
      expect(readableOn('#2B211B'), '#FFFFFF');
      expect(
        GuestPalette.from(bistro.copyWith(accentHex: '#2B211B')).onAccent,
        const Color(0xFFFFFFFF),
      );
      expect(GuestPalette.from(bistro).onAccent, const Color(0xFF111115));
    });

    test('a heading face sets the headings; script faces at one weight', () {
      final p = GuestPalette.from(
        bistro.copyWith(
          theme: StorefrontTheme(
            headingFont: StorefrontFont.kaushanScript,
            bodyFont: StorefrontFont.poppins,
            buttonShape: StorefrontButtonShape.rounded,
          ),
        ),
      );
      expect(p.displayFace, StorefrontFont.kaushanScript);
      expect(p.display(20).fontWeight, FontWeight.w400);
      expect(p.display(20).letterSpacing, 0);
      expect(p.buttonRadius, 14);
      expect(GuestPalette.from(bistro).display(20).letterSpacing, -0.8);
    });
  });

  group('guest runtime', () {
    testWidgets('uses the CMS start text, accent, button shape and language', (
      tester,
    ) async {
      final def = storefront(features: noBudget).copyWith(
        accentHex: '#7C3AED',
        theme: StorefrontTheme(buttonShape: StorefrontButtonShape.square),
        copy: StorefrontCopy({
          CopyLanguage.en: {
            'welcome.cta': "Let's eat",
            'menu.title': 'Pick a mood',
          },
          CopyLanguage.hi: {'welcome.cta': 'चलो खाएं'},
        }),
      );
      await pumpGuest(tester, definition: def, gateway: RecordingGateway());
      expect(find.text("Let's eat"), findsOneWidget);
      expect(find.text('Start exploring'), findsNothing);

      final cta = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const ValueKey('welcome-cta')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(cta.color, const Color(0xFF7C3AED));
      expect(
        (cta.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(6),
      );

      await tester.tap(find.byKey(const ValueKey('guest-language-hi')));
      await settle(tester, ms: 300);
      expect(find.text('चलो खाएं'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('guest-language-en')));
      await settle(tester, ms: 300);

      await tester.tap(find.text("Let's eat"));
      await settle(tester);
      expect(find.text('Pick a mood'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('starts in the default language; no switch without text', (
      tester,
    ) async {
      await pumpGuest(
        tester,
        definition: storefront().copyWith(
          defaultLanguage: CopyLanguage.hi,
          copy: StorefrontCopy({
            CopyLanguage.hi: {'welcome.cta': 'शुरू करें'},
          }),
        ),
        gateway: RecordingGateway(),
      );
      expect(find.text('शुरू करें'), findsOneWidget);

      await pumpGuest(
        tester,
        definition: storefront(),
        gateway: RecordingGateway(),
      );
      expect(find.byKey(const ValueKey('guest-language-en')), findsNothing);
    });

    Finder networkImage(String url) => find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is NetworkImage &&
          (w.image as NetworkImage).url == url,
    );

    Future<void> pumpWithMedia(WidgetTester tester, String base) async {
      GuestPalette.remoteFonts = false;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final def = storefront(features: noBudget).copyWith(
        brand: const StorefrontBrand(
          displayName: 'Test Bistro',
          logoUrl: 'org-1/logo.png',
        ),
        media: StorefrontMedia(
          hero: 'org-1/hero.webp',
          categories: const {
            'c-mains': 'org-1/mains.jpg',
            'c-dess': 'https://cdn.example.com/desserts.jpg',
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GuestApp(
            definition: def,
            menu: menu,
            gateway: RecordingGateway(),
            mediaBaseUrl: base,
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('shows the logo, welcome and category pictures', (
      tester,
    ) async {
      await pumpWithMedia(tester, 'https://os.example.com');
      expect(
        networkImage('https://os.example.com/media/org-1/logo.png'),
        findsOneWidget,
      );
      expect(
        networkImage('https://os.example.com/media/org-1/hero.webp'),
        findsOneWidget,
      );
      await tester.tap(find.text('Start exploring'));
      await settle(tester);
      expect(
        networkImage('https://os.example.com/media/org-1/mains.jpg'),
        findsOneWidget,
      );
      expect(
        networkImage('https://cdn.example.com/desserts.jpg'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a media base, bucket pictures fall back to art', (
      tester,
    ) async {
      await pumpWithMedia(tester, '');
      expect(find.byKey(const ValueKey('guest-logo-image')), findsNothing);
      expect(find.text('TB'), findsOneWidget); // the initials mark
      await tester.tap(find.text('Start exploring'));
      await settle(tester);
      expect(
        find.byKey(const ValueKey('category-picture-c-mains')),
        findsNothing,
      );
      // A full https picture still shows.
      expect(
        networkImage('https://cdn.example.com/desserts.jpg'),
        findsOneWidget,
      );
    });
  });
}
