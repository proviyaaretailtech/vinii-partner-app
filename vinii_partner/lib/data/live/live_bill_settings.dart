import '../../core/failure.dart';
import '../../domain/billing.dart';
import '../backend.dart';
import 'errors.dart';
import 'live_backend.dart';

/// `org_bill_settings`: one row per organization, written with an upsert on
/// `organization_id` (OS migration 0010).
///
/// The database lets any member of the organization write this row (contract
/// gap G2: it checks membership, not role). The app limits editing to owners
/// and admins (`Capability.editBillSettings`), the same soft limit menu
/// editing has, until the database checks roles itself (contract §4.5).
class LiveBillSettings implements BillSettingsRepository {
  LiveBillSettings(this.b);
  final LiveBackend b;

  static const _columns =
      'organization_id, legal_name, address, gstin, fssai, phone, '
      'sgst_pct, cgst_pct, service_charge_pct, round_off_enabled, '
      'footer_note, updated_at';

  @override
  Future<BillSettings> load() async {
    try {
      final row = await b.client
          .from('org_bill_settings')
          .select(_columns)
          .eq('organization_id', b.org.id)
          .maybeSingle();
      return BillSettings.fromRow(row);
    } catch (e) {
      throw fromSupabase(
        e,
        notReady: 'Bill settings are not set up in this database yet.',
        notReadyCode: 'bill_not_ready',
      );
    }
  }

  @override
  Future<BillSettings> save(BillSettings settings) async {
    final values = settings.toRow(b.org.id);
    final expected = settings.updatedAt;
    try {
      final List<dynamic> rows;
      if (expected == null) {
        // First save: create the row. If someone created it while this
        // screen was open, "ignore duplicates" writes nothing and returns no
        // row, which is reported as a conflict below.
        rows = await b.client
            .from('org_bill_settings')
            .upsert(
              values,
              onConflict: 'organization_id',
              ignoreDuplicates: true,
            )
            .select(_columns);
      } else {
        // A saved row is changed only if it is still the version this screen
        // loaded, in one statement, so two people cannot overwrite each other.
        final changes = {...values}..remove('organization_id');
        rows = await b.client
            .from('org_bill_settings')
            .update(changes)
            .eq('organization_id', b.org.id)
            .eq('updated_at', expected)
            .select(_columns);
      }
      if (rows.isEmpty) throw await _whyNothingChanged(expected);
      return BillSettings.fromRow(Map<String, dynamic>.from(rows.first as Map));
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  /// A write that changed no row is either a newer version (someone else
  /// saved first) or a refusal by row security, which hides rows silently.
  Future<AppFailure> _whyNothingChanged(String? expected) async {
    final BillSettings now;
    try {
      now = await load();
    } on AppFailure catch (e) {
      return e;
    }
    if (now.exists && now.updatedAt != expected) {
      return const AppFailure(
        'Someone else saved these settings while you were editing. '
        'Reload to see their changes, then make yours again.',
        kind: FailureKind.conflict,
        code: 'bill_conflict',
      );
    }
    return const AppFailure(
      'These settings were not saved. You may not have permission to change them.',
      kind: FailureKind.forbidden,
      code: 'bill_not_saved',
    );
  }
}
