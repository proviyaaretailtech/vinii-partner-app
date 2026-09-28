import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../core/failure.dart';
import '../../domain/staff.dart';
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/state_views.dart';

/// More: who is signed in, which organization, alerts, appearance, about,
/// and the way out (sign out of this phone, or of every device).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final s = services.session;
    final t = ViniiTokens.of(context);
    final m = s.membership!;
    final user = s.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: RefreshIndicator(
        onRefresh: s.reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _Card(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: t.ink,
                        child: Text(
                          user.initials,
                          style: TextStyle(
                            color: t.page,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _Label('Organization'),
            _Card(
              children: [
                ListTile(
                  leading: OrgAvatar(m.organization, size: 40),
                  title: Text(
                    m.organization.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(m.roleName),
                ),
                if (s.activeMemberships.length > 1) ...[
                  Divider(height: 1, color: t.border),
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded),
                    title: const Text('Switch organization'),
                    subtitle: Text(
                      '${s.activeMemberships.length} restaurants on this login',
                    ),
                    onTap: s.switchOrganization,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (s.can(Capability.viewOrders)) ...[
              const _Label('New-order alerts'),
              _AlertsCard(),
              const SizedBox(height: 16),
            ],
            const _Label('Appearance'),
            _Card(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ValueListenableBuilder(
                    valueListenable: services.themeMode,
                    builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Auto'),
                          icon: Icon(Icons.brightness_auto_rounded),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_rounded),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_rounded),
                        ),
                      ],
                      selected: {mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) => services.setThemeMode(v.first),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Card(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About this app'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.about),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: t.danger,
                side: BorderSide(color: t.danger.withValues(alpha: 0.4)),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
              onPressed: () => _confirmSignOut(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final s = AppScope.of(context).session;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final t = ViniiTokens.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sign out?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This phone stops ringing for new orders until someone signs in again.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, 'here'),
                    child: const Text('Sign out of this phone'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'everywhere'),
                    child: const Text('Sign out of every device'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (choice == null) return;
    try {
      await s.signOut(everywhere: choice == 'everywhere');
    } on AppFailure catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }
}

class _AlertsCard extends StatefulWidget {
  @override
  State<_AlertsCard> createState() => _AlertsCardState();
}

class _AlertsCardState extends State<_AlertsCard> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final t = ViniiTokens.of(context);
    final inbox = services.inbox;
    return _Card(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_rounded),
          title: const Text('Ring for new orders'),
          subtitle: const Text('Vibration always stays on'),
          value: services.prefs.ringEnabled,
          onChanged: (v) async {
            await services.prefs.setRingEnabled(v);
            setState(() {});
          },
        ),
        Divider(height: 1, color: t.border),
        ListTile(
          leading: const Icon(Icons.music_note_rounded),
          title: const Text('Test the ring'),
          onTap: services.ring.test,
        ),
        if (services.session.can(Capability.sendTestOrder)) ...[
          Divider(height: 1, color: t.border),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Send a test order'),
            subtitle: Text(
              inbox.available
                  ? 'Creates a marked test order for this restaurant on One Local, to check the ring end to end'
                  : inbox.unavailableReason ?? '',
            ),
            enabled: inbox.available && !_sending,
            trailing: _sending
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: () async {
              setState(() => _sending = true);
              try {
                await inbox.sendTestOrder();
                if (context.mounted) {
                  showDone(
                    context,
                    'Test order sent. It will ring in a few seconds.',
                  );
                }
              } on AppFailure catch (e) {
                if (context.mounted) showFailure(context, e);
              } finally {
                if (mounted) setState(() => _sending = false);
              }
            },
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: ViniiTokens.of(context).inkMuted,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}
