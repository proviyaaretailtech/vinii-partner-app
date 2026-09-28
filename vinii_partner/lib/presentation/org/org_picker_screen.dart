import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/staff.dart';
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/state_views.dart';

/// For people on the staff of more than one organization: which one this
/// phone is working in. Everything after this is scoped to the choice.
class OrgPickerScreen extends StatefulWidget {
  const OrgPickerScreen({super.key});

  @override
  State<OrgPickerScreen> createState() => _OrgPickerScreenState();
}

class _OrgPickerScreenState extends State<OrgPickerScreen> {
  String? _opening;

  Future<void> _open(Membership m) async {
    setState(() => _opening = m.organization.id);
    await AppScope.of(context).session.chooseOrganization(m);
    if (mounted) setState(() => _opening = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final s = AppScope.of(context).session;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              Text(
                'Hi ${s.user?.displayName ?? ''}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a restaurant',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'You can switch any time from More.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (s.switchFailure != null) ...[
                NoticeBanner(
                  message: s.switchFailure!.message,
                  icon: Icons.error_outline_rounded,
                  tone: t.danger,
                ),
                const SizedBox(height: 14),
              ],
              for (final m in s.memberships) ...[
                _OrgCard(
                  membership: m,
                  opening: _opening == m.organization.id,
                  onTap: m.active && _opening == null ? () => _open(m) : null,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => s.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrgCard extends StatelessWidget {
  const _OrgCard({required this.membership, required this.opening, this.onTap});

  final Membership membership;
  final bool opening;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final org = membership.organization;
    return Material(
      color: t.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              OrgAvatar(org, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          membership.roleName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (!membership.active) ...[
                          const SizedBox(width: 8),
                          StatusChip(label: 'Paused', color: t.danger),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (opening)
                SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: t.ink,
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: t.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
