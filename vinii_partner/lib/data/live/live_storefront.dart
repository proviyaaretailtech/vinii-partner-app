import '../../application/studio_controller.dart';
import '../../core/failure.dart';
import '../../domain/organization.dart';
import '../../domain/storefront.dart';
import '../backend.dart';
import 'errors.dart';
import 'live_backend.dart';

/// The storefront lives in VINII-owned tables (contract R4, §4.4):
/// `vinii_storefronts` holds the working draft and which version is live;
/// `vinii_storefront_versions` is the append-only list of published
/// definitions. Publishing is one server function that numbers the version
/// and checks the role. `organizations.settings` is never written.
///
/// Until those tables exist, the draft is kept on this phone and Studio says
/// that publishing waits for the database update.
class LiveStorefront implements StorefrontRepository {
  LiveStorefront(this.b);
  final LiveBackend b;

  /// English fallback for "the storefront tables are missing" (a note on the
  /// state and the message of a `notReady` failure); the screen translates
  /// both through the code below.
  static const _pending = storefrontDraftOnPhoneNote;
  static const _pendingCode = 'studio_publish_pending';

  @override
  Future<StorefrontState> load(Organization org) async {
    try {
      final results = await Future.wait([
        b.client
            .from('vinii_storefronts')
            .select('draft, published_version')
            .eq('organization_id', org.id)
            .maybeSingle(),
        b.client
            .from('vinii_storefront_versions')
            .select('version, definition, published_at, published_by_name')
            .eq('organization_id', org.id)
            .order('version', ascending: false)
            .limit(20),
      ]);
      final head = results[0] as Map<String, dynamic>?;
      final history = [
        for (final r in results[1] as List)
          if (r is Map && r['definition'] is Map)
            StorefrontVersion(
              version: (r['version'] as num).toInt(),
              definition: StorefrontDefinition.fromJson(
                Map<String, dynamic>.from(r['definition'] as Map),
                org: org,
              ),
              publishedAt:
                  DateTime.tryParse('${r['published_at']}')?.toLocal() ??
                  DateTime.now(),
              publishedBy: r['published_by_name'] as String?,
            ),
      ];
      final liveNo = (head?['published_version'] as num?)?.toInt();
      final published =
          history.where((v) => v.version == liveNo).firstOrNull ??
          history.firstOrNull;
      final draftJson = head?['draft'];
      return StorefrontState(
        draft: draftJson is Map
            ? StorefrontDefinition.fromJson(
                Map<String, dynamic>.from(draftJson),
                org: org,
              )
            : _localDraft(org),
        published: published,
        history: history,
      );
    } catch (e) {
      final f = fromSupabase(e, notReady: _pending, notReadyCode: _pendingCode);
      if (f.kind != FailureKind.notReady) throw f;
      return StorefrontState(draft: _localDraft(org), note: _pending);
    }
  }

  @override
  Future<void> saveDraft(Organization org, StorefrontDefinition draft) async {
    try {
      await b.client.from('vinii_storefronts').upsert({
        'organization_id': org.id,
        'draft': draft.toJson(),
        'updated_by': b.client.auth.currentUser?.id,
      }, onConflict: 'organization_id');
      await b.prefs.setStorefrontDraft(org.id, null);
    } catch (e) {
      final f = fromSupabase(e, notReady: _pending, notReadyCode: _pendingCode);
      if (f.kind != FailureKind.notReady) throw f;
      // Tables not there yet: keep the work on this phone rather than lose it.
      await b.prefs.setStorefrontDraft(org.id, draft.toJson());
    }
  }

  @override
  Future<void> discardDraft(Organization org) async {
    await b.prefs.setStorefrontDraft(org.id, null);
    try {
      await b.client
          .from('vinii_storefronts')
          .update({'draft': null})
          .eq('organization_id', org.id);
    } catch (e) {
      final f = fromSupabase(e);
      if (f.kind != FailureKind.notReady) throw f;
    }
  }

  @override
  Future<StorefrontVersion> publish(
    Organization org,
    StorefrontDefinition definition, {
    required String publishedBy,
  }) async {
    try {
      final current = await load(org);
      final res = await b.client.rpc(
        'vinii_publish_storefront',
        params: {
          'p': {
            'organization_id': org.id,
            'definition': definition.toJson(),
            // Refused (POS_STALE) if someone else published in the meantime.
            'expected_version': current.published?.version ?? 0,
          },
        },
      );
      final row = res is Map
          ? res
          : (res is List && res.isNotEmpty ? res.first as Map : const {});
      await b.prefs.setStorefrontDraft(org.id, null);
      return StorefrontVersion(
        version:
            (row['version'] as num?)?.toInt() ??
            (current.published?.version ?? 0) + 1,
        definition: definition,
        publishedAt:
            DateTime.tryParse('${row['published_at']}')?.toLocal() ??
            DateTime.now(),
        publishedBy: publishedBy,
      );
    } catch (e) {
      throw fromSupabase(e, notReady: _pending, notReadyCode: _pendingCode);
    }
  }

  StorefrontDefinition? _localDraft(Organization org) {
    final json = b.prefs.storefrontDraft(org.id);
    return json == null ? null : StorefrontDefinition.fromJson(json, org: org);
  }
}
