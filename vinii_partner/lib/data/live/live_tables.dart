import '../../core/failure.dart';
import '../../domain/pos_order.dart';
import '../backend.dart';
import 'errors.dart';
import 'live_backend.dart';

/// Tables and their QR codes: `dining_tables` (with `qr_token`) grouped by
/// `dining_areas`. Reading is a plain select; issuing a code goes through the
/// proposed `pos_issue_table_qr` function (contract §4.5), never a direct
/// write, because a code is a secret the server must generate, check for
/// collisions (it is unique across every restaurant) and attribute.
class LiveTables implements TablesRepository {
  LiveTables(this.b);
  final LiveBackend b;

  static const _notReady =
      'Issuing table codes from the phone needs a database update that is '
      'waiting for approval. Until then, issue codes from the VINII control '
      'panel.';

  @override
  Future<List<TableCode>> list() async {
    try {
      final rows = await b.client
          .from('dining_tables')
          .select(
            'id, label, seats, area_id, qr_token, is_active, sort_order, '
            'area:dining_areas(id, name, sort_order)',
          )
          .eq('organization_id', b.org.id);
      final tables = <({TableCode table, int areaOrder})>[
        for (final r in rows)
          (
            table: TableCode(
              id: '${r['id']}',
              label: '${r['label']}',
              seats: (r['seats'] as num?)?.toInt() ?? 4,
              areaId: r['area_id'] as String?,
              areaName: r['area'] is Map
                  ? (r['area'] as Map)['name'] as String?
                  : null,
              isActive: r['is_active'] != false,
              qrToken: _token(r['qr_token']),
              sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
            ),
            areaOrder: r['area'] is Map
                ? ((r['area'] as Map)['sort_order'] as num?)?.toInt() ?? 0
                : 1 << 20,
          ),
      ];
      // Sections in floor order (tables without one last), tables in floor
      // order inside each, so the screen can group by walking the list.
      tables.sort((x, y) {
        final byArea = x.areaOrder.compareTo(y.areaOrder);
        if (byArea != 0) return byArea;
        final byAreaName = (x.table.areaName ?? '').toLowerCase().compareTo(
          (y.table.areaName ?? '').toLowerCase(),
        );
        if (byAreaName != 0) return byAreaName;
        final bySort = x.table.sortOrder.compareTo(y.table.sortOrder);
        if (bySort != 0) return bySort;
        return naturalLabelCompare(x.table.label, y.table.label);
      });
      return [for (final t in tables) t.table];
    } catch (e) {
      throw fromSupabase(
        e,
        notReady: 'Tables are not set up in this database yet.',
      );
    }
  }

  @override
  Future<TableCode> issueCode(TableCode table, {bool replace = false}) async {
    try {
      final res = await b.client.rpc(
        'pos_issue_table_qr',
        params: {
          'p': {'table_id': table.id, if (replace) 'replace': true},
        },
      );
      final row = res is List && res.isNotEmpty ? res.first : res;
      if (row is! Map) {
        throw const AppFailure(
          'The server sent a table in a shape this app does not understand.',
        );
      }
      final token = _token(row['qr_token']);
      if (token == null) {
        throw const AppFailure(
          'The server did not send back a code. Try again.',
        );
      }
      return TableCode(
        id: table.id,
        label: table.label,
        seats: table.seats,
        areaId: table.areaId,
        areaName: table.areaName,
        isActive: table.isActive,
        qrToken: token,
        sortOrder: table.sortOrder,
      );
    } catch (e) {
      throw fromSupabase(e, notReady: _notReady);
    }
  }

  String? _token(Object? v) {
    final s = v == null ? null : '$v'.trim();
    return s == null || s.isEmpty ? null : s;
  }
}

/// "2" before "12", and "T2" before "T12": numbers inside labels compare as
/// numbers.
int naturalLabelCompare(String a, String b) {
  final pa = RegExp(r'\d+|\D+').allMatches(a.toLowerCase()).toList();
  final pb = RegExp(r'\d+|\D+').allMatches(b.toLowerCase()).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final x = pa[i].group(0)!, y = pb[i].group(0)!;
    final nx = int.tryParse(x), ny = int.tryParse(y);
    final c = nx != null && ny != null ? nx.compareTo(ny) : x.compareTo(y);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}
