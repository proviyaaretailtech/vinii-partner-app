import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../core/failure.dart';
import '../../domain/delivery_order.dart';
import '../backend.dart';
import 'live_backend.dart';

/// Marketplace delivery orders through One Local's partner API
/// (`/api/partner/*`). One Local owns these orders; the phone only asks it to
/// act (contract R4). Status words are One Local's (`placed`, `accepted`,
/// `packed`, `out`…) and are never translated into POS words (R6).
class PartnerApiInbox implements DeliveryInbox {
  PartnerApiInbox(this.b, {http.Client? client})
    : _http = client ?? http.Client();

  final LiveBackend b;
  final http.Client _http;

  String get _base => b.config.partnerApiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  @override
  bool get available => _base.isNotEmpty;

  @override
  String? get unavailableReason => available
      ? null
      : 'Delivery orders come from One Local. This build does not have the One Local server address '
            '(PARTNER_API_BASE_URL), so it cannot show them.';

  static const _uuid = Uuid();

  /// Caller headers and x-request-id come from the shared [CallerClient].
  /// Writes also carry an idempotency key (contract R7).
  Future<Map<String, String>> _headers({required bool write}) async {
    final token = b.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw const AppFailure(
        'Your session has ended. Sign in again.',
        kind: FailureKind.auth,
      );
    }
    return {
      if (write) 'idempotency-key': _uuid.v4(),
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<Object?> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    if (!available) {
      throw AppFailure(unavailableReason!, kind: FailureKind.notReady);
    }
    final uri = Uri.parse('$_base/api/partner$path');
    final http.Response res;
    try {
      final req = http.Request(method, uri)
        ..headers.addAll(await _headers(write: method != 'GET'));
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(
        await _http.send(req).timeout(const Duration(seconds: 15)),
      );
    } on TimeoutException {
      throw const AppFailure(
        'One Local is not answering. Check the connection and try again.',
        kind: FailureKind.offline,
      );
    } catch (e) {
      throw asFailure(e);
    }
    Object? json;
    try {
      json = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      json = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    final detail = json is Map && json['detail'] is String
        ? json['detail'] as String
        : null;
    final text = detail == null
        ? null
        : '${detail[0].toUpperCase()}${detail.substring(1)}${detail.endsWith('.') ? '' : '.'}';
    throw switch (res.statusCode) {
      401 => AppFailure(
        text ?? 'Your session has ended. Sign in again.',
        kind: FailureKind.auth,
      ),
      403 => AppFailure(
        text ?? 'You do not have permission to do that.',
        kind: FailureKind.forbidden,
      ),
      404 => AppFailure(
        text ?? 'That order no longer exists.',
        kind: FailureKind.rejected,
      ),
      409 => AppFailure(
        text ?? 'Someone else changed this order first.',
        kind: FailureKind.conflict,
      ),
      400 || 413 => AppFailure(
        text ?? 'That request was not accepted.',
        kind: FailureKind.rejected,
      ),
      426 => AppFailure(
        text ?? 'Update the app to keep taking orders.',
        kind: FailureKind.notReady,
      ),
      503 => AppFailure(
        text ?? 'One Local is not connected to its database yet.',
        kind: FailureKind.notReady,
      ),
      _ => AppFailure(
        text ??
            'One Local could not do that (error ${res.statusCode}). Please try again.',
      ),
    };
  }

  Map<String, dynamic> _map(Object? v) => v is Map
      ? Map<String, dynamic>.from(v)
      : (throw const AppFailure('One Local sent an unexpected reply.'));

  /// The partner server works out the restaurant from the login. If it is not
  /// the organization chosen in this app, refuse rather than show another
  /// restaurant's orders.
  void _checkSameOrganization(Map<String, dynamic> me) {
    final person = me['person'];
    final serverOrg = person is Map ? '${person['organization_id']}' : null;
    if (serverOrg != null && serverOrg != 'null' && serverOrg != b.org.id) {
      final name = me['restaurant'] is Map
          ? '${(me['restaurant'] as Map)['name']}'
          : 'another restaurant';
      throw AppFailure(
        'One Local links this login to $name, not ${b.org.name}. Delivery orders can be handled for one '
        'restaurant per login until One Local supports more.',
        kind: FailureKind.notReady,
      );
    }
  }

  @override
  Future<OutletStatus> outlet() async {
    final me = _map(await _send('GET', '/me'));
    _checkSameOrganization(me);
    return OutletStatus.fromJson(_map(me['restaurant']));
  }

  @override
  Future<OutletStatus> setAccepting(bool accepting, {DateTime? backAt}) async =>
      OutletStatus.fromJson(
        _map(
          await _send('PATCH', '/outlet', {
            'accepting': accepting,
            if (!accepting && backAt != null)
              'back_at': backAt.toUtc().toIso8601String(),
          }),
        ),
      );

  @override
  Future<List<DeliveryOrder>> list(InboxTab tab) async {
    final rows = await _send('GET', '/orders?tab=${tab.apiName}');
    return [
      for (final r in (rows is List ? rows : const []))
        if (r is Map) DeliveryOrder.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  @override
  Future<DeliveryOrder> detail(String orderId) async => DeliveryOrder.fromJson(
    _map(await _send('GET', '/orders/${Uri.encodeComponent(orderId)}')),
  );

  Future<DeliveryOrder> _act(
    DeliveryOrder o,
    String action, [
    Map<String, Object?> extra = const {},
  ]) async => DeliveryOrder.fromJson(
    _map(
      await _send('POST', '/orders/${Uri.encodeComponent(o.id)}/$action', {
        'version': o.version,
        ...extra,
      }),
    ),
  );

  @override
  Future<DeliveryOrder> accept(
    DeliveryOrder order, {
    required int prepMinutes,
  }) => _act(order, 'accept', {'prep_minutes': prepMinutes});

  @override
  Future<DeliveryOrder> reject(DeliveryOrder order, {required String reason}) =>
      _act(order, 'reject', {'reason': reason});

  @override
  Future<DeliveryOrder> markReady(DeliveryOrder order) => _act(order, 'ready');

  @override
  Future<DeliveryOrder> markOut(DeliveryOrder order) => _act(order, 'out');

  @override
  Future<DeliveryOrder> markDelivered(DeliveryOrder order) =>
      _act(order, 'delivered');

  @override
  Future<String> sendTestOrder() async =>
      '${_map(await _send('POST', '/test-order', const {}))['order_id']}';
}
