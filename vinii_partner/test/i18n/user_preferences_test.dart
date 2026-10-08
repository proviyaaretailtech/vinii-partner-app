import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/data/live/live_backend.dart';
import 'package:vinii_partner/data/local_prefs.dart';
import 'package:vinii_partner/l10n/locale_controller.dart';
import 'package:vinii_partner/l10n/locales.dart';

import '../support/fake_fonts.dart';
import '../support/harness.dart';

/// The exact requests the language mirror makes to `public.user_preferences`
/// (OS migration 0131), against a stand-in server.
class _Server {
  final requests = <http.Request>[];
  int status = 200;
  Object? body = <Object?>[];

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    return http.Response(
      jsonEncode(body),
      status,
      request: r,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  http.Request get last => requests.last;
}

Future<(LiveBackend, _Server)> _live() async {
  SharedPreferences.setMockInitialValues({});
  final server = _Server();
  final client = SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test',
    httpClient: MockClient(server.handle),
  );
  final live = LiveBackend(testConfig, await LocalPrefs.open(), client: client)
    ..activeOrganization = testOrg;
  return (live, server);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saving upserts {user_id, locale} on user_id', () async {
    final (live, server) = await _live();
    await live.userPreferences.saveLocale('user-1', 'hi');

    expect(server.last.method, 'POST');
    expect(server.last.url.path, '/rest/v1/user_preferences');
    expect(server.last.url.queryParameters['on_conflict'], 'user_id');
    expect(
      server.last.headers['Prefer'],
      contains('resolution=merge-duplicates'),
    );
    expect(jsonDecode(server.last.body), {'user_id': 'user-1', 'locale': 'hi'});
  });

  test('loading reads only that person\'s locale', () async {
    final (live, server) = await _live();
    server.body = {'locale': 'hi'};
    final code = await live.userPreferences.loadLocale('user-1');

    expect(code, 'hi');
    expect(server.last.method, 'GET');
    expect(server.last.url.path, '/rest/v1/user_preferences');
    expect(server.last.url.queryParameters['select'], 'locale');
    expect(server.last.url.queryParameters['user_id'], 'eq.user-1');
  });

  test(
    'a server error surfaces as an AppFailure the controller swallows',
    () async {
      final (live, server) = await _live();
      server.status = 500;
      server.body = {'code': 'XX000', 'message': 'boom'};
      await expectLater(
        live.userPreferences.saveLocale('user-1', 'hi'),
        throwsA(isA<AppFailure>()),
      );

      // Through the controller: silent, flagged for the next launch.
      final prefs = await LocalPrefs.open();
      final controller = LocaleController(
        prefs: prefs,
        server: live.userPreferences,
        fonts: FakeScriptFonts(ready: true),
      );
      await controller.syncForUser('user-1');
      await controller.select(hindiLocale); // must not throw
      await Future<void>.delayed(Duration.zero);
      expect(controller.active, hindiLocale);
      expect(prefs.localeSyncPending, isTrue);
    },
  );
}
