// Staff gallery: NOT part of the app and never built into it.
//
// Boots the real VINII Partner app (ViniiPartnerApp and AppServices) on the
// test FakeBackend, filled with clearly synthetic fixtures, so the staff
// screens can be reviewed in a browser without a login, a database or any
// real restaurant's rows. Nothing here is read from or written to Supabase,
// and every name below is invented for the gallery.
//
//   flutter run -d web-server --web-port 8093 -t tool/gallery/staff.dart
//
// Query parameters:
//   ?role=org_owner|org_admin|manager|biller|captain|kitchen|viewer
//        who is signed in (default org_owner), to review permission gating
//   ?outlet=open|paused|closed      the store status to start with
//   ?service=0                      start with no service charge
//   ?cart=1                         start Sell with an order already built
//   ?lang=en|hi                     the app language (default: the browser's)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vinii_partner/app/app.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/application/sell_cart.dart';
import 'package:vinii_partner/config/app_config.dart';
import 'package:vinii_partner/data/local_prefs.dart';
import 'package:vinii_partner/domain/pos_order.dart';

import 'staff_fixtures.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final role = galleryRoleNames.containsKey(q['role'])
      ? q['role']!
      : 'org_owner';

  // A clean phone every time the gallery is opened.
  final store = await SharedPreferences.getInstance();
  await store.clear();
  final prefs = LocalPrefs(store);
  await prefs.setIntroSeen();
  await prefs.setRingEnabled(false);
  final lang = q['lang'];
  if (lang == 'en' || lang == 'hi') await prefs.setLocaleCode(lang!);

  const org = galleryOrg;
  final backend = staffGalleryBackend(
    role: role,
    outlet: q['outlet'],
    service: q['service'] != '0',
  );
  final services = AppServices(
    config: const AppConfig(
      appEnv: 'gallery',
      supabaseUrl: 'https://gallery.invalid',
      supabasePublishableKey: 'gallery-not-a-key',
      partnerApiBaseUrl: 'https://gallery.invalid',
      storefrontBaseUrl: 'https://vinii.app',
    ),
    prefs: prefs,
    backend: backend,
  );
  if (q['cart'] == '1') {
    // An order already on the go: two biryanis, a tikka, two lassis, at T2.
    final dish = {for (final i in staffGalleryMenu.items) i.id: i};
    services.feature(
        () => SellCart(
          menuRepository: backend.menu,
          pos: backend.pos,
          prefs: prefs,
          orgId: org.id,
        ),
      )
      ..charges = backend.billCharges
      ..add(dish['i-biryani-c']!, qty: 2)
      ..add(dish['i-tikka']!)
      ..add(dish['i-lassi']!, qty: 2)
      ..setTable(const DiningTable(id: 'tb2', label: 'T2', seats: 4))
      ..setGuestCount(3);
  }
  await services.locale.restore(); // the saved language, before the first frame
  runApp(ViniiPartnerApp(services: services));
}
