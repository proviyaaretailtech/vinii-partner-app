import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../widgets/state_views.dart';

/// Signed in, but not an active member of any organization (never added,
/// removed, or suspended). Says who to ask, and offers sign-out.
class NoAccessScreen extends StatelessWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).session;
    final suspended = s.memberships.where((m) => !m.active).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: EmptyView(
                icon: Icons.storefront_outlined,
                title: 'No restaurant yet',
                message: suspended.isEmpty
                    ? '${s.user?.email ?? 'This account'} is not on the staff of any restaurant. Ask your restaurant '
                          'admin to add you from the VINII OS, then check again.'
                    : 'Your access to ${suspended.map((m) => m.organization.name).join(', ')} is paused. Ask the '
                          'restaurant admin to turn it back on.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: s.reload,
                    child: const Text('Check again'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
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
