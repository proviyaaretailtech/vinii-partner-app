import '../../core/failure.dart';
import '../../domain/billing.dart';
import '../../domain/pos_order.dart';
import '../backend.dart';
import 'errors.dart';
import 'live_backend.dart';

/// POS orders. Reads are selects filtered by organization. Writes go only
/// through the POS-owned front-door functions (contract R1–R3, §4.1 of
/// docs/PLATFORM_CONTRACT_ALIGNMENT.md); there is no fallback that writes
/// order rows directly.
class LivePos implements PosRepository {
  LivePos(this.b);
  final LiveBackend b;

  static const _notReady =
      'Taking orders from the phone needs the POS order functions, a database update '
      'waiting for approval. Until then, take this order at the POS counter.';

  static const _orderColumns =
      'id, display_no, status, channel, placed_by, updated_at, created_at, customer_name, '
      'subtotal, discount, gst_pct, gst_amount, service_charge, round_off, total, table_id, '
      'table:dining_tables(id, label, seats), '
      'order_items(menu_item_id, name, qty, unit_price, notes, status), payments(amount)';

  @override
  Future<List<DiningTable>> tables() async {
    final orgId = b.org.id;
    try {
      final results = await Future.wait([
        b.client
            .from('dining_tables')
            .select('id, label, seats, sort_order, area:dining_areas(name)')
            .eq('organization_id', orgId)
            .eq('is_active', true)
            .order('sort_order', ascending: true)
            .order('label', ascending: true),
        b.client
            .from('orders')
            .select('table_id')
            .eq('organization_id', orgId)
            .not('table_id', 'is', null)
            .not('status', 'in', '(paid,cancelled)'),
      ]);
      final busy = {for (final r in results[1]) '${r['table_id']}'};
      return [
        for (final r in results[0])
          DiningTable(
            id: '${r['id']}',
            label: '${r['label']}',
            seats: (r['seats'] as num?)?.toInt() ?? 4,
            area: r['area'] is Map
                ? (r['area'] as Map)['name'] as String?
                : null,
            occupied: busy.contains('${r['id']}'),
          ),
      ];
    } catch (e) {
      throw fromSupabase(
        e,
        notReady: 'Tables are not set up in this database yet.',
      );
    }
  }

  @override
  Future<BillCharges> billCharges() async {
    try {
      final row = await b.client
          .from('org_bill_settings')
          .select('sgst_pct, cgst_pct, service_charge_pct, round_off_enabled')
          .eq('organization_id', b.org.id)
          .maybeSingle();
      return BillCharges.fromRow(row);
    } catch (e) {
      final f = fromSupabase(e);
      // No bill settings table or row: the OS defaults apply (2.5% + 2.5%).
      if (f.kind == FailureKind.notReady || f.kind == FailureKind.forbidden) {
        return BillCharges.defaults;
      }
      throw f;
    }
  }

  @override
  Future<PlacedOrder> placeOrder(PosOrderDraft draft) async {
    if (draft.lines.isEmpty) {
      throw const AppFailure(
        'Add at least one item.',
        kind: FailureKind.rejected,
      );
    }
    if (draft.serviceType == ServiceType.dineIn && draft.table == null) {
      throw const AppFailure(
        'Choose a table for a dine-in order.',
        kind: FailureKind.rejected,
      );
    }
    try {
      final res = await b.client.rpc(
        'pos_place_order',
        params: {
          'p': {
            'organization_id': b.org.id,
            'idempotency_key': draft.idempotencyKey,
            'service_type': draft.serviceType.channel,
            'table_id': draft.table?.id,
            'guest_count': draft.guestCount,
            'customer_name': _blankToNull(draft.customerName),
            'customer_phone': _blankToNull(draft.customerPhone),
            'notes': _blankToNull(draft.notes),
            'scheduled_for': draft.scheduledFor?.toUtc().toIso8601String(),
            'placed_by': draft.placedBy.name,
            'fire_kot': draft.fireKitchenTicket,
            // Only when a manager removed it; the server checks the role and
            // records who did it (contract §4.5).
            if (draft.waiveServiceCharge) ...{
              'waive_service_charge': true,
              'waive_reason': ?_blankToNull(draft.waiveReason),
            },
            // Intent only: ids and quantities. The server prices from the menu.
            'lines': [
              for (final l in draft.lines)
                {
                  'menu_item_id': l.itemId,
                  'qty': l.qty,
                  'notes': _blankToNull(l.notes),
                },
            ],
          },
        },
      );
      return _order(_asMap(res), fallbackTable: draft.table);
    } catch (e) {
      throw fromSupabase(e, notReady: _notReady);
    }
  }

  @override
  Future<PlacedOrder> recordPayment(
    PlacedOrder order,
    PaymentMethod method,
    double amount, {
    required String idempotencyKey,
    String? reference,
  }) async {
    if (amount <= 0) {
      throw const AppFailure(
        'Enter the amount received.',
        kind: FailureKind.rejected,
      );
    }
    try {
      final res = await b.client.rpc(
        'pos_record_payment',
        params: {
          'p': {
            'order_id': order.id,
            'method': method.dbValue,
            'amount': amount,
            'idempotency_key': idempotencyKey,
            'reference': _blankToNull(reference),
            'expected_updated_at': order.version,
          },
        },
      );
      return _order(_asMap(res), fallbackTable: order.table);
    } catch (e) {
      throw fromSupabase(
        e,
        notReady:
            'Recording payments from the phone needs the POS payment function, a database update '
            'waiting for approval. Settle this bill at the POS counter.',
      );
    }
  }

  @override
  Future<List<PlacedOrder>> openOrders() async {
    final now = DateTime.now();
    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).toUtc().toIso8601String();
    try {
      final rows = await b.client
          .from('orders')
          .select(_orderColumns)
          .eq('organization_id', b.org.id)
          .gte('created_at', startOfDay)
          .not('status', 'in', '(paid,cancelled)')
          .order('created_at', ascending: false)
          .limit(100);
      return [for (final r in rows) _order(r)];
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<PlacedOrder> refresh(String orderId) async {
    try {
      final row = await b.client
          .from('orders')
          .select(_orderColumns)
          .eq('id', orderId)
          .eq('organization_id', b.org.id)
          .single();
      return _order(row);
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<PlacedOrder> setStatus(
    PlacedOrder order,
    PosStatus status, {
    String? reason,
  }) async {
    try {
      final res = await b.client.rpc(
        'pos_set_order_status',
        params: {
          'p': {
            'order_id': order.id,
            'to': status.dbValue,
            'expected_updated_at': order.version,
            'reason': ?reason,
          },
        },
      );
      return _order(_asMap(res), fallbackTable: order.table);
    } catch (e) {
      throw fromSupabase(
        e,
        notReady:
            'Changing order status from the phone needs the POS status function, a database update '
            'waiting for approval.',
      );
    }
  }

  @override
  Future<PlacedOrder> adjustBill(
    PlacedOrder order, {
    required bool waiveServiceCharge,
    String? reason,
  }) async {
    try {
      final res = await b.client.rpc(
        'pos_adjust_bill',
        params: {
          'p': {
            'order_id': order.id,
            'expected_updated_at': order.version,
            'waive_service_charge': waiveServiceCharge,
            'waive_reason': ?(waiveServiceCharge ? _blankToNull(reason) : null),
          },
        },
      );
      return _order(_asMap(res), fallbackTable: order.table);
    } catch (e) {
      throw fromSupabase(
        e,
        notReady:
            'Changing the service charge on a saved order needs a database update '
            'that is waiting for approval. Until then, remove it before the order '
            'is sent, or change the bill at the POS counter.',
      );
    }
  }

  Map<String, dynamic> _asMap(Object? res) {
    if (res is Map) return Map<String, dynamic>.from(res);
    if (res is List && res.isNotEmpty && res.first is Map) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    throw const AppFailure(
      'The server sent an order in a shape this app does not understand.',
    );
  }

  PlacedOrder _order(Map<String, dynamic> r, {DiningTable? fallbackTable}) {
    double n(Object? v) => double.tryParse('$v') ?? 0;
    final rawLines = (r['order_items'] ?? r['lines']) as List? ?? const [];
    final lines = [
      for (final l in rawLines)
        if (l is Map && l['status'] != 'cancelled')
          CartLine(
            itemId: '${l['menu_item_id'] ?? ''}',
            name: '${l['name']}',
            unitPrice: n(l['unit_price']),
            qty: (l['qty'] as num?)?.toInt() ?? 1,
            notes: l['notes'] as String?,
          ),
    ];
    final paid = r.containsKey('paid')
        ? n(r['paid'])
        : ((r['payments'] as List?) ?? const []).fold<double>(
            0,
            (s, p) => s + (p is Map ? n(p['amount']) : 0),
          );
    final table = r['table'] is Map
        ? DiningTable(
            id: '${(r['table'] as Map)['id']}',
            label: '${(r['table'] as Map)['label']}',
            seats: ((r['table'] as Map)['seats'] as num?)?.toInt() ?? 4,
          )
        : (r['table_id'] != null && fallbackTable?.id == r['table_id']
              ? fallbackTable
              : null);
    return PlacedOrder(
      id: '${r['id']}',
      version: '${r['updated_at']}',
      displayNo: '${r['display_no']}',
      status: PosStatus.fromDb(r['status'] as String?),
      serviceType: switch (r['channel']) {
        'dine_in' => ServiceType.dineIn,
        'pickup' => ServiceType.takeaway,
        _ => ServiceType.delivery,
      },
      createdAt:
          DateTime.tryParse('${r['created_at']}')?.toLocal() ?? DateTime.now(),
      lines: lines,
      // The stored figures, never a recomputation.
      bill: BillSummary.stored(
        itemTotal: n(r['subtotal']),
        discount: n(r['discount']),
        serviceCharge: n(r['service_charge']),
        gst: n(r['gst_amount']),
        roundOff: n(r['round_off']),
        payable: n(r['total']),
        gstPercent: n(r['gst_pct']),
        // Present once the database records a removed service charge (§4.5).
        waivedServiceCharge: n(r['service_charge_waived_amount']),
        serviceChargeWaived: r['service_charge_waived'] == true,
      ),
      table: table,
      paidAmount: paid,
      customerName: r['customer_name'] as String?,
      placedBy:
          PlacedBy.values.where((p) => p.name == r['placed_by']).firstOrNull ??
          PlacedBy.pos,
    );
  }

  String? _blankToNull(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
}
