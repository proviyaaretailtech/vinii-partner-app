import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../config/app_config.dart';
import '../widgets/state_views.dart';

/// The organization requires a newer build than this one
/// (`organizations.settings.app.min_app_version`). Nothing else is reachable,
/// so an old build can never write data in an old shape.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).session;
    final needed = s.definition?.minAppVersion ?? '';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: EmptyView(
                icon: Icons.system_update_rounded,
                title: 'Update VINII Partner',
                message:
                    '${s.membership?.organization.name ?? 'Your restaurant'} needs version $needed or newer. '
                    'This phone has ${AppConfig.appVersion}. Install the update from the store, then open the app again.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: s.reload,
                    child: const Text('I have updated — check again'),
                  ),
                  const SizedBox(height: 8),
                  if (s.activeMemberships.length > 1)
                    TextButton(
                      onPressed: s.switchOrganization,
                      child: const Text('Switch organization'),
                    ),
                  TextButton(
                    onPressed: () => s.signOut(),
                    child: const Text('Sign out'),
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
