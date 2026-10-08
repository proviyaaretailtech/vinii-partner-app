import 'package:flutter/foundation.dart';

import '../core/failure.dart';
import '../data/backend.dart';
import '../domain/staff.dart';

/// The roles a restaurant uses every day come first, then the rest by name.
const _everydayRoles = [
  'org_owner',
  'org_admin',
  'manager',
  'biller',
  'captain',
  'kitchen',
  'viewer',
];

/// [label] is how a role is named to the reader (the screen passes the
/// localised label); without it the server's role name orders the rest.
List<StaffRole> sortRoles(
  Iterable<StaffRole> roles, {
  String Function(StaffRole role)? label,
}) {
  int rank(StaffRole r) {
    final i = _everydayRoles.indexOf(r.slug);
    return i < 0 ? _everydayRoles.length : i;
  }

  String named(StaffRole r) => (label?.call(r) ?? r.name).toLowerCase();

  return roles.toList()..sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : named(a).compareTo(named(b));
  });
}

/// Why a change to a person cannot be made. A code the screen turns into
/// words in the reader's language; [english] is the fallback for logs and
/// tests, and [failure] is the same refusal as an error.
enum TeamBlock {
  /// Only an organization admin may change the team.
  notAdmin(
    'team_not_admin',
    'Only an organization admin can change the team.', // i18n-ignore: English fallback for logs/tests
  ),

  /// Nobody changes their own role.
  selfRole(
    'team_self_role',
    'You cannot change your own role.', // i18n-ignore: English fallback for logs/tests
  ),

  /// Nobody suspends themselves.
  selfSuspend(
    'team_self_suspend',
    'You cannot suspend yourself.', // i18n-ignore: English fallback for logs/tests
  ),

  /// The last active admin stays an admin.
  lastAdmin(
    'team_last_admin',
    'There must always be one active admin. Make someone else an admin first.', // i18n-ignore: English fallback for logs/tests
  );

  const TeamBlock(this.code, this.english);

  /// Key into `teamFailureTexts` (lib/l10n/failure_texts/team.dart).
  final String code;
  final String english;

  AppFailure get failure =>
      AppFailure(english, kind: FailureKind.rejected, code: code);
}

String _serverName(StaffRole r) => r.name;

/// The Team screen's state: who is on the team, which roles exist, the
/// filter and search, and the changes an organization admin may make.
///
/// Two guards protect the restaurant from a slip, whatever the screen shows:
/// nobody changes or suspends themselves, and the last active admin can
/// never be demoted or suspended (nobody would be left who can manage the
/// team). The database lets only an organization admin write `org_users`;
/// [canManage] mirrors that, and a refusal from the database is still shown
/// as "not allowed".
class TeamController extends ChangeNotifier {
  TeamController({
    required this.repository,
    required this.meUserId,
    required this.canManage,
  });

  final TeamRepository repository;

  /// The signed-in person's login id, to recognise "You" in the list.
  final String meUserId;
  final bool canManage;

  List<TeamMember>? members;
  List<StaffRole> roles = const [];
  AppFailure? failure;
  bool loading = false;

  /// Members being changed right now, so a row cannot be changed twice.
  final busy = <String>{};

  /// A role slug to show only that role, or null for everyone.
  String? roleFilter;
  String query = '';

  /// How a role is named to the reader, used to search and to order the
  /// filter. The screen sets this to the localised role label; until then the
  /// server's role name.
  String Function(StaffRole role) roleText = _serverName;

  bool _disposed = false;

  Future<void> load({bool force = false}) async {
    if (loading || (members != null && !force)) return;
    loading = true;
    failure = null;
    _notify();
    try {
      final (people, allRoles) = await (
        repository.members(),
        repository.roles(),
      ).wait;
      members = people;
      roles = allRoles;
      if (roleFilter != null && !people.any((m) => m.role.slug == roleFilter)) {
        roleFilter = null;
      }
    } on AppFailure catch (e) {
      failure = e;
    } catch (e) {
      failure = asFailure(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  // ── What is listed ─────────────────────────────────────────────────────

  /// Search appears once the team is too long to scan.
  bool get showSearch => (members?.length ?? 0) > 8;

  int get activeCount => (members ?? const []).where((m) => m.active).length;

  /// The roles people actually have, most common first, for the filter.
  List<({StaffRole role, int count})> get rolesPresent {
    final counts = <String, ({StaffRole role, int count})>{};
    for (final m in members ?? const <TeamMember>[]) {
      final c = counts[m.role.slug];
      counts[m.role.slug] = (role: m.role, count: (c?.count ?? 0) + 1);
    }
    return counts.values.toList()..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0
          ? byCount
          : roleText(a.role)
                .toLowerCase()
                .compareTo(roleText(b.role).toLowerCase());
    });
  }

  /// The role the filter is on, if any.
  StaffRole? get filteredRole => roleFilter == null
      ? null
      : rolesPresent.where((r) => r.role.slug == roleFilter).firstOrNull?.role;

  /// The filtered list: active people first, then suspended, each by name.
  List<TeamMember> get visible {
    final q = query.trim().toLowerCase();
    final list = [
      for (final m in members ?? const <TeamMember>[])
        if ((roleFilter == null || m.role.slug == roleFilter) &&
            (q.isEmpty ||
                m.displayName.toLowerCase().contains(q) ||
                m.email.toLowerCase().contains(q) ||
                m.role.name.toLowerCase().contains(q) ||
                roleText(m.role).toLowerCase().contains(q)))
          m,
    ];
    list.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return list;
  }

  bool get isFiltered => roleFilter != null || query.trim().isNotEmpty;

  void setRoleFilter(String? slug) {
    roleFilter = roleFilter == slug ? null : slug;
    _notify();
  }

  void setQuery(String v) {
    query = v;
    _notify();
  }

  void clearFilters() {
    roleFilter = null;
    query = '';
    _notify();
  }

  // ── Changing people ────────────────────────────────────────────────────

  bool isMe(TeamMember m) => m.userId == meUserId;

  int get _activeAdmins => (members ?? const <TeamMember>[])
      .where((m) => m.isAdmin && m.active)
      .length;

  /// Why this person's role cannot be changed to [to], or null when it can.
  TeamBlock? blockRoleChange(TeamMember m, {StaffRole? to}) {
    if (!canManage) return TeamBlock.notAdmin;
    if (isMe(m)) return TeamBlock.selfRole;
    if (m.isAdmin &&
        m.active &&
        to?.slug != 'org_admin' &&
        _activeAdmins <= 1) {
      return TeamBlock.lastAdmin;
    }
    return null;
  }

  /// Why this person cannot be suspended, or null when they can.
  TeamBlock? blockSuspend(TeamMember m) {
    if (!canManage) return TeamBlock.notAdmin;
    if (isMe(m)) return TeamBlock.selfSuspend;
    if (m.isAdmin && m.active && _activeAdmins <= 1) {
      return TeamBlock.lastAdmin;
    }
    return null;
  }

  /// [blockRoleChange] in English, for tests and logs.
  String? whyNoRoleChange(TeamMember m, {StaffRole? to}) =>
      blockRoleChange(m, to: to)?.english;

  /// [blockSuspend] in English, for tests and logs.
  String? whyNoSuspend(TeamMember m) => blockSuspend(m)?.english;

  Future<TeamMember> setRole(TeamMember member, StaffRole role) async {
    final block = blockRoleChange(member, to: role);
    if (block != null) throw block.failure;
    return _change(member, () => repository.setRole(member, role));
  }

  Future<TeamMember> setActive(TeamMember member, bool active) async {
    final block = active
        ? (canManage ? null : TeamBlock.notAdmin)
        : blockSuspend(member);
    if (block != null) throw block.failure;
    return _change(member, () => repository.setStatus(member, active: active));
  }

  Future<TeamMember> _change(
    TeamMember member,
    Future<TeamMember> Function() call,
  ) async {
    if (busy.contains(member.id)) {
      throw const AppFailure(
        'Already saving…', // i18n-ignore: English fallback for logs/tests
        kind: FailureKind.rejected,
        code: 'team_already_saving',
      );
    }
    busy.add(member.id);
    _notify();
    try {
      final saved = await call();
      members = [
        for (final m in members ?? const <TeamMember>[])
          m.id == saved.id ? saved : m,
      ];
      return saved;
    } finally {
      busy.remove(member.id);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
