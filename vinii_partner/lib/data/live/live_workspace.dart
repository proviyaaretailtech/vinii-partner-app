import '../../core/failure.dart';
import '../../domain/app_definition.dart';
import '../../domain/organization.dart';
import '../../domain/staff.dart';
import '../backend.dart';
import 'errors.dart';
import 'live_backend.dart';

/// Memberships (`org_users` → `roles`, `organizations`) and the resolved
/// application definition (`org_modules`, `role_module_access`,
/// `organizations.settings.app`). Read-only: configuration belongs to the
/// Master (contract R5).
class LiveWorkspace implements WorkspaceRepository {
  LiveWorkspace(this.b);
  final LiveBackend b;

  static const _blockedOrgStatuses = {
    'suspended',
    'archived',
    'closed',
    'churned',
    'inactive',
  };

  @override
  Future<List<Membership>> memberships(StaffUser user) async {
    try {
      // Only rows the database lets this person see. Until the multi-org fix
      // (contract G1) someone in two organizations sees one of them — the
      // same one the database would let them work in — so the app never
      // offers an organization it cannot open.
      final rows = await b.client
          .from('org_users')
          .select(
            'status, role:roles(slug, name), organization:organizations(id, name, slug, type, status, theme, settings)',
          )
          .eq('user_id', user.id);
      final result = <Membership>[];
      for (final row in rows) {
        final org = row['organization'];
        final role = row['role'];
        if (org is! Map || role is! Map) continue;
        final theme = org['theme'] is Map ? org['theme'] as Map : const {};
        final settings = org['settings'] is Map
            ? Map<String, dynamic>.from(org['settings'] as Map)
            : <String, dynamic>{};
        result.add(
          Membership(
            organization: Organization(
              id: '${org['id']}',
              name: '${org['name']}',
              slug: '${org['slug']}',
              type: '${org['type'] ?? 'restaurant'}',
              accentHex: theme['accent'] as String?,
              settings: settings,
            ),
            roleSlug: '${role['slug']}',
            roleName: '${role['name']}',
            active:
                row['status'] == 'active' &&
                !_blockedOrgStatuses.contains('${org['status']}'),
          ),
        );
      }
      result.sort(
        (x, y) => x.organization.name.toLowerCase().compareTo(
          y.organization.name.toLowerCase(),
        ),
      );
      return result;
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<void> activate(Organization org) async {
    b.activeOrganization = org;
  }

  @override
  Future<AppDefinition> appDefinition(Membership membership) async {
    final orgId = membership.organization.id;
    Map<String, bool>? orgModules;
    try {
      final rows = await b.client
          .from('org_modules')
          .select('module_key, enabled')
          .eq('organization_id', orgId);
      orgModules = {
        for (final r in rows) '${r['module_key']}': r['enabled'] == true,
      };
    } catch (e) {
      // Not readable here (older database): fall back to what the role may use.
      final f = fromSupabase(e);
      if (f.kind == FailureKind.offline) throw f;
    }

    final visibility = <String, bool>{};
    try {
      final rows = await b.client
          .from('role_module_access')
          .select(
            'organization_id, module_key, visible, role:roles!inner(slug)',
          )
          .eq('role.slug', membership.roleSlug)
          .or('organization_id.is.null,organization_id.eq.$orgId');
      // Platform defaults first, then the organization's overrides win.
      for (final r in rows.where((r) => r['organization_id'] == null)) {
        visibility['${r['module_key']}'] = r['visible'] != false;
      }
      for (final r in rows.where((r) => r['organization_id'] != null)) {
        visibility['${r['module_key']}'] = r['visible'] != false;
      }
    } catch (e) {
      final f = fromSupabase(e);
      if (f.kind == FailureKind.offline) throw f;
    }

    return resolveAppDefinition(
      membership: membership,
      orgModules: orgModules,
      roleVisibility: visibility,
    );
  }
}
