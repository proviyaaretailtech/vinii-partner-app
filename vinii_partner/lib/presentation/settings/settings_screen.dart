import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../application/session_controller.dart';
import '../../core/failure.dart';
import '../../domain/staff.dart';
import '../../l10n/l10n.dart';
import '../../l10n/labels.dart';
import '../orders/order_widgets.dart' show inboxUnavailableText;
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/state_views.dart';
import 'channels_card.dart';

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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.commonMore)),
      body: RefreshIndicator(
        onRefresh: s.reload,
        // On a tablet or counter computer the column stays readable instead
        // of stretching across the screen.
        child: LayoutBuilder(
          builder: (context, box) => ListView(
            padding: EdgeInsets.fromLTRB(
              box.maxWidth > 720 ? (box.maxWidth - 688) / 2 : 16,
              4,
              box.maxWidth > 720 ? (box.maxWidth - 688) / 2 : 16,
              32,
            ),
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
              _Label(l.orgLabel),
              _Card(
                children: [
                  ListTile(
                    leading: OrgAvatar(m.organization, size: 40),
                    title: Text(
                      m.organization.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      l.roleLabel(m.roleSlug, fallback: m.roleName),
                    ),
                  ),
                  if (s.activeMemberships.length > 1) ...[
                    Divider(height: 1, color: t.border),
                    ListTile(
                      leading: const Icon(Icons.swap_horiz_rounded),
                      title: Text(l.orgSwitch),
                      subtitle: Text(
                        l.orgRestaurantsOnLogin(
                          count: s.activeMemberships.length,
                        ),
                      ),
                      onTap: s.switchOrganization,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              ..._restaurantSection(context, s),
              if (s.can(Capability.toggleChannels)) ...[
                _Label(l.settingsSalesChannels),
                const ChannelsCard(),
                const SizedBox(height: 16),
              ],
              if (s.can(Capability.viewOrders)) ...[
                _Label(l.settingsAlertsLabel),
                _AlertsCard(),
                const SizedBox(height: 16),
              ],
              _Label(l.settingsAppearance),
              _Card(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ValueListenableBuilder(
                      valueListenable: services.themeMode,
                      builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text(l.settingsThemeAuto),
                            icon: const Icon(Icons.brightness_auto_rounded),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(l.settingsThemeLight),
                            icon: const Icon(Icons.light_mode_rounded),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(l.settingsThemeDark),
                            icon: const Icon(Icons.dark_mode_rounded),
                          ),
                        ],
                        selected: {mode},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) =>
                            services.setThemeMode(v.first),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Card(
                children: [
                  ListTile(
                    minTileHeight: 64,
                    leading: const Icon(Icons.translate_rounded),
                    title: Text(
                      context.l10n.languageTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: ListenableBuilder(
                      listenable: services.locale,
                      builder: (context, _) => Text(
                        context.l10n.languageSettingsSubtitle(
                          language: services.locale.active.nativeName,
                        ),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(Routes.language),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Card(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: Text(l.settingsAbout),
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
                label: Text(l.commonSignOut),
                onPressed: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bill & GST, Team and Table QR codes: each only for the roles that may
  /// open it. Nothing is listed when a role has none of them.
  List<Widget> _restaurantSection(BuildContext context, SessionController s) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final entries = <(IconData, String, String, String)>[
      if (s.can(Capability.viewBillSettings))
        (
          Icons.receipt_long_outlined,
          l.settingsBillGst,
          l.settingsBillGstHint,
          Routes.billSettings,
        ),
      if (s.can(Capability.viewTeam))
        (
          Icons.groups_outlined,
          l.settingsTeam,
          l.settingsTeamHint,
          Routes.team,
        ),
      if (s.can(Capability.viewTableCodes))
        (
          Icons.qr_code_2_rounded,
          l.settingsTableQr,
          l.settingsTableQrHint,
          Routes.tableCodes,
        ),
    ];
    if (entries.isEmpty) return const [];
    return [
      _Label(l.settingsYourRestaurant),
      _Card(
        children: [
          for (final (i, e) in entries.indexed) ...[
            if (i > 0) Divider(height: 1, color: t.border),
            ListTile(
              minTileHeight: 64,
              leading: Icon(e.$1),
              title: Text(
                e.$2,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(e.$3),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(e.$4),
            ),
          ],
        ],
      ),
      const SizedBox(height: 16),
    ];
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final s = AppScope.of(context).session;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final t = ViniiTokens.of(context);
        final l = context.l10n;
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
                    l.settingsSignOutTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.settingsSignOutBody,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, 'here'),
                    child: Text(l.settingsSignOutHere),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, 'everywhere'),
                    child: Text(l.settingsSignOutEverywhere),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.commonCancel),
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
    final l = context.l10n;
    final inbox = services.inbox;
    return _Card(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_rounded),
          title: Text(l.settingsRingTitle),
          subtitle: Text(l.settingsRingSubtitle),
          value: services.prefs.ringEnabled,
          onChanged: (v) async {
            await services.prefs.setRingEnabled(v);
            setState(() {});
          },
        ),
        Divider(height: 1, color: t.border),
        ListTile(
          leading: const Icon(Icons.music_note_rounded),
          title: Text(l.settingsRingTest),
          onTap: services.ring.test,
        ),
        if (services.session.can(Capability.sendTestOrder)) ...[
          Divider(height: 1, color: t.border),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: Text(l.settingsTestOrder),
            subtitle: Text(
              inbox.available
                  ? l.settingsTestOrderHint
                  : inboxUnavailableText(l, inbox.unavailableReason),
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
                  showDone(context, context.l10n.settingsTestOrderSent);
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
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: ViniiTokens.of(context).ink,
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
