import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/core/money.dart';
import 'package:vinii_partner/data/live/errors.dart';
import 'package:vinii_partner/domain/app_definition.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/domain/delivery_order.dart';
import 'package:vinii_partner/domain/guest_catalog.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/organization.dart';
import 'package:vinii_partner/domain/storefront.dart';

import 'support/harness.dart';

void main() {
  group('bill maths matches the OS computeBill (Repo-1- bill.ts)', () {
    test(
      'the OS reference bill: ₹502 items, 5% service, 2.5+2.5% GST → ₹553',
      () {
        final bill = BillSummary.of([
          (unitPrice: 502, qty: 1),
        ], charges: const BillCharges(serviceChargePercent: 5));
        expect(bill.itemTotal, 502);
        expect(bill.serviceCharge, 25.10);
        expect(bill.taxable, 527.10);
        expect(bill.sgst, 13.18);
        expect(bill.cgst, 13.18);
        expect(bill.gross, 553.46);
        expect(bill.roundOff, -0.46);
        expect(bill.payable, 553);
      },
    );

    test('defaults: 2.5% + 2.5% GST, rounding on, no service charge', () {
      final bill = BillSummary.of([
        (unitPrice: 185, qty: 2),
        (unitPrice: 45, qty: 1),
      ]);
      expect(bill.itemTotal, 415);
      expect(bill.gst, 20.76); // 10.38 + 10.38, each rounded to paise first
      expect(bill.payable, 436);
      expect(bill.gstLabel, 'GST (5%)');
    });

    test('a discount never makes the bill negative', () {
      final bill = BillSummary.of([(unitPrice: 100, qty: 1)], discount: 500);
      expect(bill.discount, 100);
      expect(bill.payable, 0);
    });

    test('stored bills show the server figures, not a recomputation', () {
      final bill = BillSummary.stored(
        itemTotal: 415,
        gst: 20.75,
        payable: 435.75,
        gstPercent: 5,
      );
      expect(bill.payable, 435.75);
      expect(bill.sgst + bill.cgst, closeTo(20.75, 0.001));
    });

    test('budget status', () {
      const b = BudgetStatus(budget: 7000, spent: 1440);
      expect(b.percentUsed, 21);
      expect(b.remaining, 5560);
      expect(b.over, isFalse);
      expect(const BudgetStatus(budget: 1000, spent: 900).close, isTrue);
      expect(const BudgetStatus(budget: 1000, spent: 1200).over, isTrue);
      expect(b.perPerson(4), 1750);
    });

    test('rupees use Indian grouping and hide zero paise', () {
      expect(rupees(1440), '₹1,440');
      expect(rupees(123456), '₹1,23,456');
      expect(rupees(435.75), '₹435.75');
    });
  });

  group('storefront definition', () {
    const org = Organization(
      id: 'o',
      name: 'Mysore Dining Hall',
      slug: 'mysore-dining-hall',
      type: 'franchise',
      accentHex: '#b3282d',
    );

    test('the starter is blank apart from real facts', () {
      final s = StorefrontDefinition.starter(org);
      expect(s.brand.displayName, 'Mysore Dining Hall');
      expect(s.brand.heroTitle, isEmpty);
      expect(s.brand.tagline, isEmpty);
      expect(s.brand.heroSubtitle, isEmpty);
      expect(s.chefsPicks, isEmpty);
      expect(s.limitedToday, isEmpty);
      expect(s.items, isEmpty);
      expect(s.accentHex, '#b3282d');
      expect(s.serviceModes, [GuestServiceMode.dineIn]);
    });

    test('bakeries and cafés start on the artisan template', () {
      const bakery = Organization(
        id: 'b',
        name: 'Crumbs',
        slug: 'crumbs',
        type: 'bakery',
      );
      expect(
        StorefrontDefinition.starter(bakery).template,
        StorefrontTemplate.artisanDay,
      );
    });

    test('JSON round trip keeps everything', () {
      final def = StorefrontDefinition.starter(org).copyWith(
        template: StorefrontTemplate.artisanDay,
        brand: const StorefrontBrand(displayName: 'MDH', heroTitle: 'Hello'),
        serviceModes: const [
          GuestServiceMode.preOrder,
          GuestServiceMode.dineIn,
        ],
        features: const GuestFeatures(
          swipeDeck: false,
          budget: BudgetSettings(enabled: false, defaultAmount: 2000),
        ),
        categories: const [
          CategoryPresentation(categoryId: 'c1', visible: false, emoji: '🍛'),
        ],
        items: const {
          'i1': ItemPresentation(itemId: 'i1', tags: ['Spicy'], kcal: 420),
        },
        chefsPicks: const ['i1'],
        limitedToday: const [LimitedOffer(itemId: 'i1', endsAt: '21:30')],
        tableLabel: 'Room',
      );
      final back = StorefrontDefinition.fromJson(
        jsonDecode(jsonEncode(def.toJson())) as Map<String, dynamic>,
        org: org,
      );
      expect(back.toJson(), def.toJson());
    });

    test('unknown keys are ignored and bad values fall back safely', () {
      final def = StorefrontDefinition.fromJson({
        'schema_version': 9,
        'template': 'neon_future',
        'accent': 'red',
        'service_modes': ['teleport'],
        'features': {
          'budget': {'min': 5000, 'max': 100, 'default': 1},
        },
        'pre_order': {'opens_at': '8am', 'days_ahead': 99},
        'something_new': {'a': 1},
      }, org: org);
      expect(def.template, StorefrontTemplate.bistroNight);
      expect(def.accentHex, StorefrontTemplate.bistroNight.defaultAccent);
      expect(def.serviceModes, [GuestServiceMode.dineIn]);
      expect(
        def.features.budget.max,
        greaterThanOrEqualTo(def.features.budget.min),
      );
      expect(def.preOrder.opensAt, '08:00');
      expect(def.preOrder.daysAhead, 30);
    });

    test('pre-order slots: 08:00–17:00 in hours gives 8:00 … 16:00, respecting notice', () {
      const p = PreOrderSettings(leadMinutes: 90);
      final day = DateTime(2026, 9, 28);
      expect(p.allSlotsFor(day).map((d) => d.hour), [
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
      ]);
      final bookable = p.slotsFor(day, now: DateTime(2026, 9, 28, 10, 15));
      expect(
        bookable.first.hour,
        12,
      ); // 10:15 + 90 min = 11:45 → first slot 12:00
    });
  });

  group('application definition', () {
    test('a kitchen login sees Orders, Menu and More', () {
      final def = resolveAppDefinition(membership: membershipAs('kitchen'));
      expect(def.tabs, [AppTab.orders, AppTab.menu, AppTab.more]);
    });

    test('an owner sees every tab; a disabled module hides its tab', () {
      expect(
        resolveAppDefinition(membership: membershipAs('org_owner')).tabs,
        AppTab.values,
      );
      final def = resolveAppDefinition(
        membership: membershipAs('org_owner'),
        orgModules: const {'pos': false},
      );
      expect(def.tabs.contains(AppTab.sell), isFalse);
      expect(def.source, 'org_modules');
    });

    test('the Storefront tab is the menu module\'s "publishing" part', () {
      final def = resolveAppDefinition(
        membership: membershipAs('org_owner'),
        roleVisibility: const {'menu': false},
      );
      expect(def.tabs.contains(AppTab.menu), isFalse);
      expect(def.tabs.contains(AppTab.storefront), isFalse);
    });

    test(
      'role visibility and the Master tab order are honoured; More stays last',
      () {
        const org = Organization(
          id: 'o',
          name: 'X',
          slug: 'x',
          settings: {
            'app': {
              'tabs': ['menu', 'orders'],
              'min_app_version': '2.0.0',
              'config_version': 17,
            },
          },
        );
        final def = resolveAppDefinition(
          membership: membershipAs('manager', org: org),
          roleVisibility: const {'pos': false},
        );
        expect(def.tabs, [
          AppTab.menu,
          AppTab.orders,
          AppTab.storefront,
          AppTab.more,
        ]);
        expect(def.minAppVersion, '2.0.0');
        expect(def.configVersion, '17');
      },
    );

    test('version comparison is numeric', () {
      expect(compareVersions('0.1.0', '0.1.0'), 0);
      expect(compareVersions('1.2.10', '1.2.9'), greaterThan(0));
      expect(compareVersions('0.1.0', '2.0.0'), lessThan(0));
    });
  });

  group('guest catalog', () {
    const cats = [
      MenuCategory(id: 'a', name: 'Mains', sortOrder: 1),
      MenuCategory(id: 'b', name: 'Drinks', sortOrder: 2),
    ];
    const items = [
      MenuItem(
        id: '1',
        categoryId: 'a',
        name: 'Biriyani',
        price: 185,
        isRecommended: true,
      ),
      MenuItem(
        id: '2',
        categoryId: 'a',
        name: 'Off today',
        price: 100,
        isAvailable: false,
      ),
      MenuItem(id: '3', categoryId: 'a', name: 'Free water', price: 0),
      MenuItem(id: '4', categoryId: 'b', name: 'Lassi', price: 60),
      MenuItem(id: '5', categoryId: 'b', name: 'Staff tea', price: 10),
    ];
    const org = Organization(id: 'o', name: 'X', slug: 'x');

    test('only sellable, visible items, in the storefront order', () {
      final def = StorefrontDefinition.starter(org).copyWith(
        categories: const [CategoryPresentation(categoryId: 'b')],
        items: const {'5': ItemPresentation(itemId: '5', hidden: true)},
      );
      final c = GuestCatalog(
        menu: const MenuSnapshot(categories: cats, items: items),
        definition: def,
      );
      expect(c.categories.map((x) => x.category.name), ['Drinks', 'Mains']);
      expect(c.allItems.map((i) => i.item.name), ['Lassi', 'Biriyani']);
      expect(c.item('1')!.tags, ['Bestseller']);
    });

    test('picks and offers skip missing items and ended offers', () {
      final def = StorefrontDefinition.starter(org).copyWith(
        chefsPicks: const ['1', 'gone', '2'],
        limitedToday: const [
          LimitedOffer(itemId: '4', endsAt: '10:00'),
          LimitedOffer(itemId: '1', endsAt: '23:00'),
        ],
      );
      final c = GuestCatalog(
        menu: const MenuSnapshot(categories: cats, items: items),
        definition: def,
        now: DateTime(2026, 9, 28, 12),
      );
      expect(c.chefsPicks.map((i) => i.item.id), ['1']);
      expect(c.limitedToday.map((o) => o.item.item.id), ['1']);
    });

    test('an offer end time that is not exactly HH:mm never crashes', () {
      final day = DateTime(2026, 9, 28, 12);
      DateTime ends(String at) =>
          LimitedOffer(itemId: 'x', endsAt: at).endsOn(day);
      expect(ends('21:30'), DateTime(2026, 9, 28, 21, 30));
      // A stray seconds part reads as the hour and minute.
      expect(ends('05:59:00'), DateTime(2026, 9, 28, 5, 59));
      expect(ends('9:05'), DateTime(2026, 9, 28, 9, 5));
      // Anything else reads as the default closing time, not an exception.
      expect(ends('soon'), DateTime(2026, 9, 28, 18));
      expect(ends(''), DateTime(2026, 9, 28, 18));
      expect(ends('99:99'), DateTime(2026, 9, 28, 23, 59));
    });
  });

  group('partner API contract (R6)', () {
    test('DeliveryOrder parses the saved /orders?tab=new sample', () {
      final rows = jsonDecode(
        File('test/fixtures/partner_orders_new.json').readAsStringSync(),
      ) as List;
      final o = DeliveryOrder.fromJson(rows.first as Map<String, dynamic>);
      expect(o.displayNo, 'OL-00029');
      expect(o.status, DeliveryStatus.placed);
      expect(o.posStatus, 'new'); // POS words kept separate, never translated
      expect(
        o.version,
        '2026-09-28T06:41:12.345678+00:00',
      ); // sent back unchanged
      expect(o.deadline, isNotNull);
      expect(o.items.length, 2);
      expect(o.itemCount, 3);
      expect(o.area, 'Ganj Golai');
      expect(o.total, 435.75);
      expect(o.customerPhone, isNull);
    });
  });

  group('database errors become plain words', () {
    test('front-door function errors keep their message and kind', () {
      final f = fromSupabase(
        const PostgrestException(
          message: 'POS_STALE: this order was changed on another phone',
        ),
      );
      expect(f.kind, FailureKind.conflict);
      expect(f.message, 'This order was changed on another phone.');
      expect(
        fromSupabase(
          const PostgrestException(message: 'POS_FORBIDDEN: not allowed'),
        ).kind,
        FailureKind.forbidden,
      );
    });

    test('a missing function or table means "not ready yet", with the caller\'s explanation', () {
      final f = fromSupabase(
        const PostgrestException(
          message: 'Could not find the function',
          code: 'PGRST202',
        ),
        notReady: 'Needs the POS order functions.',
      );
      expect(f.kind, FailureKind.notReady);
      expect(f.message, 'Needs the POS order functions.');
    });

    test('maybeSingle errors that lost their code are unwrapped', () {
      // What postgrest 2.9 maybeSingle() throws for a missing table.
      final f = fromSupabase(
        const PostgrestException(
          message: '{"code":"PGRST205","details":null,"hint":null,"message":"Could not find the table"}',
          code: '404',
        ),
        notReady: 'Not there yet.',
      );
      expect(f.kind, FailureKind.notReady);
      final g = fromSupabase(
        const PostgrestException(
          message: '{"code":"P0001","message":"POS_STALE: changed elsewhere"}',
          code: '400',
        ),
      );
      expect(g.kind, FailureKind.conflict);
      expect(g.message, 'Changed elsewhere.');
    });

    test('wrong password', () {
      final f = fromSupabase(
        const AuthException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        ),
      );
      expect(f.kind, FailureKind.auth);
    });
  });
}
