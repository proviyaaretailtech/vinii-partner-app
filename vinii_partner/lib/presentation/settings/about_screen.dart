import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../config/app_config.dart';
import '../../l10n/l10n.dart';
import '../../l10n/labels.dart';
import '../shell/home_shell.dart' show AppTabLabels;
import '../theme/staff_theme.dart';

/// What support asks for: which build, which database, which configuration.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final s = services.session;
    final def = s.definition;
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final rows = [
      (l.aboutAppVersion, '${AppConfig.appVersion} (${AppConfig.buildNumber})'),
      (l.aboutEnvironment, services.config.appEnv),
      (l.aboutDatabase, services.config.databaseHost),
      (
        l.aboutOneLocalServer,
        services.config.partnerApiBaseUrl.isEmpty
            ? l.aboutNotSet
            : Uri.parse(services.config.partnerApiBaseUrl).host,
      ),
      (l.orgLabel, s.membership?.organization.name ?? '—'),
      (
        l.aboutRole,
        s.membership == null
            ? '—'
            : '${l.roleLabel(s.membership!.roleSlug, fallback: s.membership!.roleName)} '
                  '(${s.membership!.roleSlug})',
      ),
      (
        l.aboutConfiguration,
        def == null
            ? '—'
            : l.aboutConfigValue(
                version: def.configVersion,
                source: def.source,
              ),
      ),
      (l.aboutMinVersion, def?.minAppVersion ?? '—'),
      (l.aboutTabs, def == null ? '—' : def.tabs.map(l.appTabLabel).join(', ')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              l.aboutIntro,
              style: TextStyle(color: t.inkMuted, fontSize: 14, height: 1.4),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final (i, r) in rows.indexed) ...[
                  if (i > 0) Divider(height: 1, color: t.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            r.$1,
                            style: TextStyle(color: t.inkSecondary),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            r.$2,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(l.aboutFooter, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
