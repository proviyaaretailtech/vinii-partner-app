import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/data/live/live_backend.dart';
import 'package:vinii_partner/data/local_prefs.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/domain/staff.dart';

import 'support/harness.dart';

/// The exact requests the live data layer makes, checked against a stand-in
/// server. Nothing here reaches a real database: the Supabase client is
/// given a fake HTTP client.
class _Server {
  final requests = <http.Request>[];

  /// What to answer for a request path (`/rest/v1/...`) and method.
  final answers = <String, (int, Object?)>{};

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final (status, body) =
        answers['${r.method} ${r.url.path}'] ??
        answers[r.url.path] ??
        (200, <Object?>[]);
    return http.Response(
      jsonEncode(body),
      status,
      request: r,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  http.Request get last => requests.last;
  Map<String, dynamic> get body =>
      jsonDecode(last.body) as Map<String, dynamic>;
}

const _orderRow = {
  'id': 'o-1',
  'display_no': 'ORD-1',
  'status': 'sent_to_kitchen',
  'channel': 'dine_in',
  'placed_by': 'pos',
  'updated_at': '2026-10-02T10:00:00+00:00',
  'created_at': '2026-10-02T09:59:00+00:00',
  'subtotal': 1000,
  'discount': 0,
  'gst_pct': 5,
  'gst_amount': 50,
  'service_charge': 0,
  'round_off': 0,
  'total': 1050,
  'table_id': 't-1',
  'lines': [
    {
      'menu_item_id': 'i-1',
      'name': 'Chicken Biryani',
      'qty': 1,
      'unit_price': 1000,
    },
  ],
};

PosOrderDraft _draft({bool waive = false, String? reason}) => PosOrderDraft(
  idempotencyKey: 'key-1',
  serviceType: ServiceType.takeaway,
  lines: const [
    CartLine(itemId: 'i-1', name: 'Chicken Biryani', unitPrice: 1000),
  ],
  waiveServiceCharge: waive,
  waiveReason: reason,
);

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
  group('placing an order', () {
    test('a removed service charge is sent with its reason', () async {
      final (live, server) = await _live();
      server.answers['/rest/v1/rpc/pos_place_order'] = (200, _orderRow);

      await live.pos.placeOrder(_draft(waive: true, reason: ' Regular guest '));

      final p = server.body['p'] as Map<String, dynamic>;
      expect(p['waive_service_charge'], isTrue);
      expect(p['waive_reason'], 'Regular guest');
      expect(p['idempotency_key'], 'key-1');
      expect(p.containsKey('total'), isFalse, reason: 'intent, not facts');
    });

    test('without a removal, neither key is sent at all', () async {
      final (live, server) = await _live();
      server.answers['/rest/v1/rpc/pos_place_order'] = (200, _orderRow);

      await live.pos.placeOrder(_draft());

      final p = server.body['p'] as Map<String, dynamic>;
      expect(p.containsKey('waive_service_charge'), isFalse);
      expect(p.containsKey('waive_reason'), isFalse);
    });

    test('a removal with no reason sends the flag only', () async {
      final (live, server) = await _live();
      server.answers['/rest/v1/rpc/pos_place_order'] = (200, _orderRow);

      await live.pos.placeOrder(_draft(waive: true, reason: '  '));

      final p = server.body['p'] as Map<String, dynamic>;
      expect(p['waive_service_charge'], isTrue);
      expect(p.containsKey('waive_reason'), isFalse);
    });
  });

  group('changing the bill of a saved order', () {
    final order = PlacedOrder(
      id: 'o-1',
      version: '2026-10-02T10:00:00+00:00',
      displayNo: 'ORD-1',
      status: PosStatus.sentToKitchen,
      serviceType: ServiceType.dineIn,
      createdAt: DateTime(2026, 10, 2, 10),
      lines: const [
        CartLine(itemId: 'i-1', name: 'Chicken Biryani', unitPrice: 1000),
      ],
      bill: BillSummary.stored(
        itemTotal: 1000,
        serviceCharge: 100,
        gst: 55,
        payable: 1155,
        gstPercent: 5,
      ),
    );

    test(
      'pos_adjust_bill gets the order, its version and the reason',
      () async {
        final (live, server) = await _live();
        server.answers['/rest/v1/rpc/pos_adjust_bill'] = (
          200,
          {
            ..._orderRow,
            'service_charge_waived': true,
            'service_charge_waived_amount': 100,
          },
        );

        final updated = await live.pos.adjustBill(
          order,
          waiveServiceCharge: true,
          reason: 'Complaint',
        );

        expect(server.last.url.path, '/rest/v1/rpc/pos_adjust_bill');
        expect(server.body['p'], {
          'order_id': 'o-1',
          'expected_updated_at': '2026-10-02T10:00:00+00:00',
          'waive_service_charge': true,
          'waive_reason': 'Complaint',
        });
        expect(updated.bill.serviceChargeWaived, isTrue);
        expect(updated.bill.waivedServiceCharge, 100);
      },
    );

    test('adding it back sends no reason', () async {
      final (live, server) = await _live();
      server.answers['/rest/v1/rpc/pos_adjust_bill'] = (200, _orderRow);

      await live.pos.adjustBill(order, waiveServiceCharge: false, reason: 'x');

      final p = server.body['p'] as Map<String, dynamic>;
      expect(p['waive_service_charge'], isFalse);
      expect(p.containsKey('waive_reason'), isFalse);
    });

    test('until the function exists, the phone says so plainly', () async {
      final (live, server) = await _live();
      server.answers['/rest/v1/rpc/pos_adjust_bill'] = (
        404,
        {
          'code': 'PGRST202',
          'message': 'Could not find the function public.pos_adjust_bill',
        },
      );

      await expectLater(
        live.pos.adjustBill(order, waiveServiceCharge: true),
        throwsA(
          isA<AppFailure>()
              .having((e) => e.kind, 'kind', FailureKind.notReady)
              .having(
                (e) => e.message,
                'message',
                contains('waiting for approval'),
              ),
        ),
      );
    });

    test('a stale version comes back as a conflict', () async {
      final (live, server) = await _live();
      server.answers['/rest/v1/rpc/pos_adjust_bill'] = (
        400,
        {
          'code': 'P0001',
          'message': 'POS_STALE: this order was changed on another phone',
        },
      );
      await expectLater(
        live.pos.adjustBill(order, waiveServiceCharge: true),
        throwsA(
          isA<AppFailure>().having((e) => e.isConflict, 'conflict', isTrue),
        ),
      );
    });
  });

  group('table codes', () {
    const table = TableCode(id: 't-1', label: '12', areaName: 'Indoor');

    test('issuing a code asks the server for it by table', () async {
      final (live, server) = await _live();
      server.answers['/rest/v1/rpc/pos_issue_table_qr'] = (
        200,
        {'id': 't-1', 'label': '12', 'qr_token': 'k3x9a1b2c4'},
      );

      final issued = await live.tableCodes.issueCode(table);

      expect(server.body, {
        'p': {'table_id': 't-1'},
      });
      expect(issued.qrToken, 'k3x9a1b2c4');
      expect(issued.areaName, 'Indoor', reason: 'the rest is kept');
    });

    test('replacing a code must say so', () async {
      final (live, server) = await _live();
      server.answers['/rest/v1/rpc/pos_issue_table_qr'] = (
        200,
        {'id': 't-1', 'qr_token': 'zzzzzzzzzz'},
      );
      await live.tableCodes.issueCode(table, replace: true);
      expect(server.body, {
        'p': {'table_id': 't-1', 'replace': true},
      });
    });

    test(
      'until the function exists, the phone points to the control panel',
      () async {
        final (live, server) = await _live();
        server.answers['/rest/v1/rpc/pos_issue_table_qr'] = (
          404,
          {'code': 'PGRST202', 'message': 'function not found'},
        );
        await expectLater(
          live.tableCodes.issueCode(table),
          throwsA(
            isA<AppFailure>()
                .having((e) => e.kind, 'kind', FailureKind.notReady)
                .having((e) => e.message, 'message', contains('control panel')),
          ),
        );
      },
    );

    test(
      'the list is read per organization and grouped by floor section',
      () async {
        final (live, server) = await _live();
        server.answers['/rest/v1/dining_tables'] = (
          200,
          [
            {
              'id': 't-3',
              'label': '12',
              'seats': 4,
              'area_id': 'a-2',
              'qr_token': null,
              'is_active': true,
              'sort_order': 0,
              'area': {'id': 'a-2', 'name': 'Rooftop', 'sort_order': 2},
            },
            {
              'id': 't-2',
              'label': '10',
              'seats': 2,
              'area_id': 'a-1',
              'qr_token': 'abcdefghij',
              'is_active': true,
              'sort_order': 0,
              'area': {'id': 'a-1', 'name': 'Indoor', 'sort_order': 1},
            },
            {
              'id': 't-1',
              'label': '2',
              'seats': 2,
              'area_id': 'a-1',
              'qr_token': 'k3x9a1b2c4',
              'is_active': false,
              'sort_order': 0,
              'area': {'id': 'a-1', 'name': 'Indoor', 'sort_order': 1},
            },
          ],
        );

        final tables = await live.tableCodes.list();

        expect(server.last.url.queryParameters['organization_id'], 'eq.org-1');
        expect([for (final t in tables) t.id], ['t-1', 't-2', 't-3']);
        expect(tables[0].isActive, isFalse);
        expect(tables[2].hasCode, isFalse);
        expect(
          tables[0].link('https://vinii.app/'),
          'https://vinii.app/t/k3x9a1b2c4',
        );
      },
    );
  });

  group('bill settings', () {
    const version = '2026-10-02T08:15:30.123456+00:00';
    const row = {
      'organization_id': 'org-1',
      'legal_name': 'Test Kitchen',
      'sgst_pct': 2.5,
      'cgst_pct': 2.5,
      'service_charge_pct': 0,
      'round_off_enabled': true,
      'updated_at': version,
    };

    test(
      'a saved row is changed only if it is still the version loaded',
      () async {
        final (live, server) = await _live();
        server.answers['PATCH /rest/v1/org_bill_settings'] = (
          200,
          [
            {...row, 'service_charge_pct': 10, 'updated_at': 'later'},
          ],
        );

        final saved = await live.billSettings.save(
          const BillSettings(
            legalName: 'Test Kitchen',
            serviceChargePercent: 10,
            updatedAt: version,
          ),
        );

        expect(server.last.method, 'PATCH');
        expect(server.last.url.queryParameters['organization_id'], 'eq.org-1');
        expect(server.last.url.queryParameters['updated_at'], 'eq.$version');
        expect(server.body['service_charge_pct'], 10);
        expect(server.body.containsKey('organization_id'), isFalse);
        expect(saved.updatedAt, 'later');
      },
    );

    test('the first save creates the row and never replaces another', () async {
      final (live, server) = await _live();
      server.answers['POST /rest/v1/org_bill_settings'] = (201, [row]);

      await live.billSettings.save(
        const BillSettings(legalName: 'Test Kitchen'),
      );

      expect(server.last.method, 'POST');
      expect(server.last.url.queryParameters['on_conflict'], 'organization_id');
      expect(
        server.last.headers['Prefer'],
        contains('resolution=ignore-duplicates'),
      );
      expect(server.body['organization_id'], 'org-1');
    });

    test('nothing changed and a newer row exists: a conflict', () async {
      final (live, server) = await _live();
      server.answers['PATCH /rest/v1/org_bill_settings'] = (200, <Object?>[]);
      server.answers['GET /rest/v1/org_bill_settings'] = (
        200,
        {...row, 'updated_at': 'someone-elses'},
      );

      await expectLater(
        live.billSettings.save(const BillSettings(updatedAt: version)),
        throwsA(
          isA<AppFailure>().having((e) => e.isConflict, 'conflict', isTrue),
        ),
      );
    });

    test('nothing changed and no row is visible: not allowed', () async {
      final (live, server) = await _live();
      server.answers['PATCH /rest/v1/org_bill_settings'] = (200, <Object?>[]);
      server.answers['GET /rest/v1/org_bill_settings'] = (200, <Object?>[]);

      await expectLater(
        live.billSettings.save(const BillSettings(updatedAt: version)),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.forbidden,
          ),
        ),
      );
    });
  });

  group('the team and the channels', () {
    const member = TeamMember(
      id: 'u-9',
      userId: 'auth-9',
      email: 'asha@example.com',
      role: StaffRole(id: 'r-1', slug: 'biller', name: 'Biller / POS'),
    );

    test(
      'suspending changes the status of that person in this organization',
      () async {
        final (live, server) = await _live();
        server.answers['PATCH /rest/v1/org_users'] = (
          200,
          [
            {
              'id': 'u-9',
              'user_id': 'auth-9',
              'email': 'asha@example.com',
              'full_name': 'Asha',
              'status': 'suspended',
              'role': {'id': 'r-1', 'slug': 'biller', 'name': 'Biller / POS'},
            },
          ],
        );

        final saved = await live.team.setStatus(member, active: false);

        expect(server.body, {'status': 'suspended'});
        expect(server.last.url.queryParameters['id'], 'eq.u-9');
        expect(server.last.url.queryParameters['organization_id'], 'eq.org-1');
        expect(saved.active, isFalse);
      },
    );

    test('a role change by someone who is not an admin is not mistaken for success', () async {
      final (live, server) = await _live();
      server.answers['PATCH /rest/v1/org_users'] = (200, <Object?>[]);

      await expectLater(
        live.team.setRole(
          member,
          const StaffRole(id: 'r-2', slug: 'manager', name: 'Manager'),
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.forbidden,
          ),
        ),
      );
      expect(server.body, {'role_id': 'r-2'});
    });

    test('a channel is switched by its row', () async {
      final (live, server) = await _live();
      server.answers['PATCH /rest/v1/channel_integrations'] = (
        200,
        [
          {
            'id': 'c-1',
            'channel': 'swiggy',
            'display_name': 'Swiggy',
            'is_connected': true,
            'is_accepting': false,
          },
        ],
      );
      const swiggy = SalesChannel(
        id: 'c-1',
        key: 'swiggy',
        name: 'Swiggy',
        connected: true,
        accepting: true,
      );

      final off = await live.channels.setAccepting(swiggy, false);

      expect(server.body, {'is_accepting': false, 'next_open_at': null});
      expect(server.last.url.queryParameters['id'], 'eq.c-1');
      expect(off.accepting, isFalse);
    });
  });
}
