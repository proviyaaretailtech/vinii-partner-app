import '../../core/failure.dart';
import '../../domain/staff.dart';
import '../backend.dart';
import 'errors.dart';
import 'live_backend.dart';

/// The team: `org_users` joined to `roles`.
///
/// Any member may read the list. Only an organization admin may change it
/// (`org_users` policies use `is_org_admin`, which checks the slug
/// `org_admin`); everyone else's update is silently filtered to zero rows by
/// row security, which is reported as "not allowed" rather than success.
/// Invitations cannot be created from here: `org_invites` has no policy for
/// signed-in users, so the VINII control panel sends them.
class LiveTeam implements TeamRepository {
  LiveTeam(this.b);
  final LiveBackend b;

  static const _columns =
      'id, user_id, email, full_name, status, '
      'role:roles(id, slug, name, description)';

  @override
  Future<List<TeamMember>> members() async {
    try {
      final rows = await b.client
          .from('org_users')
          .select(_columns)
          .eq('organization_id', b.org.id);
      final people = [for (final r in rows) ?_member(r)]
        ..sort(
          (x, y) => x.displayName.toLowerCase().compareTo(
            y.displayName.toLowerCase(),
          ),
        );
      return people;
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<List<StaffRole>> roles() async {
    try {
      final rows = await b.client
          .from('roles')
          .select('id, slug, name, description')
          .order('name', ascending: true);
      return [for (final r in rows) _role(r)];
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<TeamMember> setRole(TeamMember member, StaffRole role) =>
      _update(member, {'role_id': role.id});

  @override
  Future<TeamMember> setStatus(TeamMember member, {required bool active}) =>
      _update(member, {'status': active ? 'active' : 'suspended'});

  Future<TeamMember> _update(
    TeamMember member,
    Map<String, Object?> changes,
  ) async {
    try {
      final rows = await b.client
          .from('org_users')
          .update(changes)
          .eq('id', member.id)
          .eq('organization_id', b.org.id)
          .select(_columns);
      final saved = rows.isEmpty ? null : _member(rows.first);
      if (saved == null) {
        throw const AppFailure(
          'Only an organization admin can change the team.', // i18n-ignore: English fallback for logs/tests
          kind: FailureKind.forbidden,
          code: 'team_not_admin',
        );
      }
      return saved;
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  StaffRole _role(Map<String, dynamic> r) => StaffRole(
    id: '${r['id']}',
    slug: '${r['slug']}',
    name: '${r['name']}',
    description: _clean(r['description']),
  );

  TeamMember? _member(Map<String, dynamic> r) {
    final role = r['role'];
    if (role is! Map) return null;
    return TeamMember(
      id: '${r['id']}',
      userId: '${r['user_id']}',
      email: '${r['email']}',
      fullName: _clean(r['full_name']),
      role: _role(Map<String, dynamic>.from(role)),
      active: r['status'] == 'active',
    );
  }

  String? _clean(Object? v) {
    final s = v == null ? null : '$v'.trim();
    return s == null || s.isEmpty ? null : s;
  }
}
