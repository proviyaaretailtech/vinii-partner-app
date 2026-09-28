import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../config/app_config.dart';
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
    final rows = [
      ('App version', '${AppConfig.appVersion} (${AppConfig.buildNumber})'),
      ('Environment', services.config.appEnv),
      ('Database', services.config.databaseHost),
      (
        'One Local server',
        services.config.partnerApiBaseUrl.isEmpty
            ? 'Not set'
            : Uri.parse(services.config.partnerApiBaseUrl).host,
      ),
      ('Organization', s.membership?.organization.name ?? '—'),
      (
        'Role',
        s.membership == null
            ? '—'
            : '${s.membership!.roleName} (${s.membership!.roleSlug})',
      ),
      (
        'Configuration',
        def == null ? '—' : '${def.configVersion} · from ${def.source}',
      ),
      ('Minimum version', def?.minAppVersion ?? '—'),
      ('Tabs', def == null ? '—' : def.tabs.map((e) => e.label).join(', ')),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          Text(
            'VINII Partner shows only what is in your organization\'s database. It has no sample data.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
