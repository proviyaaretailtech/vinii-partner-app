import '../../core/failure.dart';
import '../../domain/pos_order.dart';
import '../backend.dart';
import 'errors.dart';
import 'live_backend.dart';

/// Swiggy, Zomato and the other sales channels: `channel_integrations`
/// (OS migration 0010). `is_accepting` is the channel's ON/OFF switch; the
/// VINII control panel writes the same column the same way.
///
/// The database lets any member update these rows (contract gap G2). The app
/// limits the switches to owners, admins and managers
/// (`Capability.toggleChannels`) until the database checks roles (§4.5).
class LiveChannels implements ChannelsRepository {
  LiveChannels(this.b);
  final LiveBackend b;

  static const _columns =
      'id, channel, display_name, is_connected, is_accepting';

  @override
  Future<List<SalesChannel>> list() async {
    try {
      final rows = await b.client
          .from('channel_integrations')
          .select(_columns)
          .eq('organization_id', b.org.id)
          .order('channel', ascending: true);
      return [for (final r in rows) _channel(r)];
    } catch (e) {
      throw fromSupabase(
        e,
        notReady: 'Sales channels are not set up in this database yet.',
      );
    }
  }

  @override
  Future<SalesChannel> setAccepting(
    SalesChannel channel,
    bool accepting,
  ) async {
    try {
      final rows = await b.client
          .from('channel_integrations')
          // Switching ON clears the "opens again at" time; switching OFF from
          // the phone has no end time, it stays off until switched back on.
          .update({'is_accepting': accepting, 'next_open_at': null})
          .eq('id', channel.id)
          .eq('organization_id', b.org.id)
          .select(_columns);
      if (rows.isEmpty) {
        throw const AppFailure(
          'That channel could not be changed. You may not have permission.',
          kind: FailureKind.forbidden,
        );
      }
      return _channel(rows.first);
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  SalesChannel _channel(Map<String, dynamic> r) {
    final key = '${r['channel']}';
    final name = '${r['display_name'] ?? ''}'.trim();
    return SalesChannel(
      id: '${r['id']}',
      key: key,
      name: name.isNotEmpty
          ? name
          : key.isEmpty
          ? 'Channel'
          : '${key[0].toUpperCase()}${key.substring(1)}',
      connected: r['is_connected'] == true,
      accepting: r['is_accepting'] != false,
    );
  }
}
