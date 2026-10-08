import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../config/app_config.dart';
import '../../l10n/l10n.dart';
import '../widgets/state_views.dart';

/// The organization requires a newer build than this one
/// (`organizations.settings.app.min_app_version`). Nothing else is reachable,
/// so an old build can never write data in an old shape.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).session;
    final l = context.l10n;
    final needed = s.definition?.minAppVersion ?? '';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: EmptyView(
                icon: Icons.system_update_rounded,
                title: l.bootUpdateTitle,
                message: s.membership == null
                    ? l.bootUpdateBodyDefault(
                        needed: needed,
                        current: AppConfig.appVersion,
                      )
                    : l.bootUpdateBodyOrg(
                        org: s.membership!.organization.name,
                        needed: needed,
                        current: AppConfig.appVersion,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: s.reload,
                    child: Text(l.bootUpdateCheckAgain),
                  ),
                  const SizedBox(height: 8),
                  if (s.activeMemberships.length > 1)
                    TextButton(
                      onPressed: s.switchOrganization,
                      child: Text(l.orgSwitch),
                    ),
                  TextButton(
                    onPressed: () => s.signOut(),
                    child: Text(l.commonSignOut),
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
