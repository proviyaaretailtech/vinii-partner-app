import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../application/team_controller.dart';
import '../../domain/staff.dart';
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/state_views.dart';

/// Team: who works here, in which role, and what that role can do.
///
/// Everyone on the team can look. Only an organization admin can change a
/// role or suspend someone (the database allows nothing else); for everyone
/// else the list is read-only and says why. Invitations cannot be sent from
/// here, because each needs a secure link: the screen says where to send them
/// from instead of pretending.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  late final TeamController _c;
  late final bool _canView;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    final session = services.session;
    _canView = session.can(Capability.viewTeam);
    _c = TeamController(
      repository: services.backend.team,
      meUserId: session.user?.id ?? '',
      canManage: session.can(Capability.manageTeam),
    );
    if (_canView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.load();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: ListenableBuilder(listenable: _c, builder: _body),
    );
  }

  Widget _body(BuildContext context, Widget? _) {
    if (!_canView) {
      return const EmptyView(
        icon: Icons.lock_outline_rounded,
        title: 'Not available for your role',
        message: 'Ask an owner or admin about your team.',
      );
    }
    final people = _c.members;
    if (people == null) {
      if (_c.failure != null && !_c.loading) {
        return FailureView(
          failure: _c.failure!,
          onRetry: () => _c.load(force: true),
        );
      }
      return const LoadingView(label: 'Loading the team…');
    }
    final t = ViniiTokens.of(context);
    final visible = _c.visible;
    return RefreshIndicator(
      onRefresh: () => _c.load(force: true),
      child: LayoutBuilder(
        builder: (context, box) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: box.maxWidth > 760 ? (box.maxWidth - 728) / 2 : 16,
            vertical: 4,
          ),
          children: [
            _Summary(controller: _c),
            const SizedBox(height: 12),
            if (!_c.canManage) ...[
              const NoticeBanner(
                icon: Icons.lock_outline_rounded,
                message: 'Only an organization admin can change roles or suspend people.',
              ),
              const SizedBox(height: 12),
            ],
            if (people.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: EmptyView(
                  icon: Icons.groups_outlined,
                  title: 'No one is listed yet',
                  message: 'People you invite from the VINII control panel show up here once they accept.',
                ),
              )
            else ...[
              if (_c.showSearch) ...[
                TextField(
                  key: const Key('team-search'),
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or role',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _c.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              _c.setQuery('');
                            },
                          ),
                  ),
                  onChanged: _c.setQuery,
                ),
                const SizedBox(height: 8),
              ],
              if (_c.rolesPresent.length > 1) _RoleFilter(controller: _c),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: EmptyView(
                    icon: Icons.person_search_outlined,
                    title: 'Nobody matches',
                    message: 'Try another name, or show everyone.',
                    actionLabel: 'Show everyone',
                    onAction: () {
                      _search.clear();
                      _c.clearFilters();
                    },
                  ),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, m) in visible.indexed) ...[
                        if (i > 0) Divider(height: 1, color: t.border),
                        _MemberRow(
                          member: m,
                          me: _c.isMe(m),
                          busy: _c.busy.contains(m.id),
                          onTap: _c.canManage ? () => _manage(m) : null,
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              _RoleLegend(
                roles: sortRoles([for (final r in _c.rolesPresent) r.role]),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _manage(TeamMember member) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => _MemberSheet(controller: _c, memberId: member.id),
  );
}

/// "7 people · 6 active" and the way to add someone.
class _Summary extends StatelessWidget {
  const _Summary({required this.controller});

  final TeamController controller;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final total = controller.members?.length ?? 0;
    final active = controller.activeCount;
    final text = total == 0
        ? 'No one yet'
        : '${total == 1 ? '1 person' : '$total people'}'
              '${active == total ? '' : ' · $active active'}';
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: t.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (controller.canManage)
          FilledButton.icon(
            key: const Key('team-invite'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: const Text('Invite staff'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              constraints: const BoxConstraints(maxWidth: 560),
              builder: (context) => const _InviteSheet(),
            ),
          ),
      ],
    );
  }
}

class _RoleFilter extends StatelessWidget {
  const _RoleFilter({required this.controller});

  final TeamController controller;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final total = controller.members?.length ?? 0;
    Widget chip(String label, bool selected, VoidCallback onTap, Key key) =>
        ChoiceChip(
          key: key,
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
          selectedColor: t.ink,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? t.page : t.ink,
          ),
          materialTapTargetSize: MaterialTapTargetSize.padded,
        );
    final chips = [
      chip(
        'Everyone ($total)',
        controller.roleFilter == null,
        () => controller.setRoleFilter(null),
        const Key('team-filter-all'),
      ),
      for (final r in controller.rolesPresent)
        chip(
          '${r.role.name} (${r.count})',
          controller.roleFilter == r.role.slug,
          () => controller.setRoleFilter(r.role.slug),
          Key('team-filter-${r.role.slug}'),
        ),
    ];
    final chosen = controller.filteredRole;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A phone scrolls the chips sideways; a wider screen shows them all.
        LayoutBuilder(
          builder: (context, box) => box.maxWidth < 600
              ? SizedBox(
                  height: 48,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final c in chips)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: c,
                          ),
                      ],
                    ),
                  ),
                )
              : Wrap(spacing: 8, runSpacing: 4, children: chips),
        ),
        if (chosen != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
            child: Text.rich(
              key: const Key('team-filter-summary'),
              TextSpan(
                children: [
                  TextSpan(
                    text: chosen.name,
                    style: TextStyle(color: t.ink, fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: ': ${chosen.summary}',
                    style: TextStyle(color: t.inkSecondary),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
      ],
    );
  }
}

/// What each role in use can do, once, instead of repeated on every row.
class _RoleLegend extends StatelessWidget {
  const _RoleLegend({required this.roles});

  final List<StaffRole> roles;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Card(
      key: const Key('team-roles-legend'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What each role can do',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final r in roles)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: r.name,
                        style: TextStyle(
                          color: t.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: '  ${r.summary}',
                        style: TextStyle(color: t.inkSecondary),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.me,
    required this.busy,
    required this.onTap,
  });

  final TeamMember member;
  final bool me;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final m = member;
    final showEmail = m.displayName != m.email;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: m.active ? t.ink : t.surfaceMuted,
                  child: Text(
                    m.initials,
                    style: TextStyle(
                      color: m.active ? t.page : t.inkSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              m.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: m.active ? t.ink : t.inkSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          if (me) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: t.surfaceMuted,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'You',
                                style: TextStyle(
                                  color: t.inkSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (showEmail)
                        Text(
                          m.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.inkSecondary, fontSize: 13),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        m.role.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.all(4),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      )
                    else
                      StatusChip(
                        label: m.active ? 'Active' : 'Suspended',
                        color: m.active ? t.success : t.warning,
                        icon: m.active
                            ? Icons.check_circle_outline_rounded
                            : Icons.pause_circle_outline_rounded,
                      ),
                    if (onTap != null) ...[
                      const SizedBox(height: 6),
                      Icon(Icons.chevron_right_rounded, color: t.inkMuted),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The admin's choices for one person: change role, suspend or reactivate.
class _MemberSheet extends StatelessWidget {
  const _MemberSheet({required this.controller, required this.memberId});

  final TeamController controller;
  final String memberId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final m = controller.members
            ?.where((x) => x.id == memberId)
            .firstOrNull;
        if (m == null) return const SizedBox.shrink();
        final t = ViniiTokens.of(context);
        final text = Theme.of(context).textTheme;
        final noRole = controller.whyNoRoleChange(m);
        final noSuspend = m.active ? controller.whyNoSuspend(m) : null;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(m.displayName, style: text.titleLarge),
                if (m.displayName != m.email) ...[
                  const SizedBox(height: 2),
                  Text(m.email, style: text.bodyMedium),
                ],
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: m.role.name,
                        style: TextStyle(
                          color: t.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(text: ' · ${m.role.summary}'),
                    ],
                  ),
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 12),
                _Action(
                  key: const Key('team-change-role'),
                  icon: Icons.badge_outlined,
                  title: 'Change role',
                  subtitle: noRole ?? 'Now ${m.role.name}',
                  enabled: noRole == null,
                  onTap: () => _pickRole(context, m),
                ),
                const Divider(height: 1),
                if (m.active)
                  _Action(
                    key: const Key('team-suspend'),
                    icon: Icons.pause_circle_outline_rounded,
                    title: 'Suspend',
                    subtitle: noSuspend ?? 'They cannot use this restaurant until you reactivate them.',
                    enabled: noSuspend == null,
                    danger: true,
                    onTap: () => _suspend(context, m),
                  )
                else
                  _Action(
                    key: const Key('team-reactivate'),
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Reactivate',
                    subtitle: 'Let them use this restaurant again.',
                    enabled: true,
                    onTap: () => _reactivate(context, m),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickRole(BuildContext context, TeamMember m) async {
    final role = await showModalBottomSheet<StaffRole>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => _RolePicker(controller: controller, member: m),
    );
    if (role == null || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.setRole(m, role);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${m.displayName} is now ${role.name}.')),
        );
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _suspend(BuildContext context, TeamMember m) async {
    final t = ViniiTokens.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Suspend ${m.displayName}?'),
        content: Text(
          '${m.displayName} will not be able to use this restaurant until you '
          'reactivate them. Nothing is deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('team-suspend-confirm'),
            style: TextButton.styleFrom(foregroundColor: t.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.setActive(m, false);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${m.displayName} is suspended.')),
        );
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _reactivate(BuildContext context, TeamMember m) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reactivate ${m.displayName}?'),
        content: Text(
          '${m.displayName} will be able to use this restaurant again, as '
          '${m.role.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('team-reactivate-confirm'),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.setActive(m, true);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${m.displayName} is active again.')),
        );
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final color = !enabled ? t.inkMuted : (danger ? t.danger : t.ink);
    return ListTile(
      minTileHeight: 64,
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
      subtitle: Text(subtitle),
      trailing: enabled
          ? Icon(Icons.chevron_right_rounded, color: t.inkMuted)
          : Icon(Icons.lock_outline_rounded, size: 18, color: t.inkMuted),
      onTap: enabled ? onTap : null,
    );
  }
}

/// Every role with what it can do; choose one, then confirm.
class _RolePicker extends StatefulWidget {
  const _RolePicker({required this.controller, required this.member});

  final TeamController controller;
  final TeamMember member;

  @override
  State<_RolePicker> createState() => _RolePickerState();
}

class _RolePickerState extends State<_RolePicker> {
  late StaffRole? _chosen = widget.member.role;

  List<StaffRole> get _roles => sortRoles(widget.controller.roles);

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final m = widget.member;
    final chosen = _chosen;
    final changed = chosen != null && chosen.slug != m.role.slug;
    final why = chosen == null
        ? null
        : widget.controller.whyNoRoleChange(m, to: chosen);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Change role for ${m.displayName}',
                style: text.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final r in _roles)
                    InkWell(
                      key: Key('team-role-${r.slug}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _chosen = r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                r.slug == chosen?.slug
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: r.slug == chosen?.slug
                                    ? t.ink
                                    : t.inkMuted,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.slug == m.role.slug
                                        ? '${r.name} (now)'
                                        : r.name,
                                    style: TextStyle(
                                      color: t.ink,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.summary,
                                    style: TextStyle(
                                      color: t.inkSecondary,
                                      fontSize: 13.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (why != null) ...[
                    Text(
                      why,
                      style: TextStyle(color: t.danger, fontSize: 13.5),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    key: const Key('team-role-confirm'),
                    onPressed: changed && why == null
                        ? () => Navigator.pop(context, chosen)
                        : null,
                    child: Text(
                      changed
                          ? 'Make ${chosen.name}'
                          : 'Choose a different role',
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why staff cannot be invited from the phone, and where to do it.
class _InviteSheet extends StatelessWidget {
  const _InviteSheet();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Invite staff', style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Invitations are sent from the VINII control panel, under Users & '
              'Roles, because each person needs a secure link to set up their '
              'own login.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Once they accept, they appear here and you can set their role.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
