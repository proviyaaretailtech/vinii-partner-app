import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/l10n.dart';
import '../widgets/state_views.dart';

/// Signed in, but not an active member of any organization (never added,
/// removed, or suspended). Says who to ask, and offers sign-out.
class NoAccessScreen extends StatelessWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).session;
    final l = context.l10n;
    final suspended = s.memberships.where((m) => !m.active).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: EmptyView(
                icon: Icons.storefront_outlined,
                title: l.authNoAccessTitle,
                message: suspended.isEmpty
                    ? (s.user?.email == null
                          ? l.authNoAccessNotStaffAccount
                          : l.authNoAccessNotStaffEmail(email: s.user!.email))
                    : l.authNoAccessPaused(
                        names: suspended
                            .map((m) => m.organization.name)
                            .join(', '),
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
                    child: Text(l.authCheckAgain),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
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
