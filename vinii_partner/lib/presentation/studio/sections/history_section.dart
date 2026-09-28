import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/app_scope.dart';
import '../../../application/studio_controller.dart';
import '../../../core/failure.dart';
import '../../../domain/staff.dart';
import '../../../domain/storefront.dart';
import '../../menu/panel.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/chips.dart';
import '../../widgets/state_views.dart';

/// Every published version, newest first. Restoring an old one publishes
/// it again as a new number, so history only grows and nothing is lost.
class HistorySection extends StatelessWidget {
  const HistorySection({super.key, required this.controller});
  final StudioController controller;

  Future<void> _restore(BuildContext context, StorefrontVersion v) async {
    final live = controller.state?.published?.version ?? 0;
    final next = live + 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make version ${v.version} live again?'),
        content: Text(
          'Guests will see version ${v.version} again. It is published as '
          'version $next, so nothing is lost.'
          '${controller.hasUnpublishedChanges ? ' Your unpublished changes in Studio are replaced by it.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final by = AppScope.of(context).session.user?.displayName ?? 'Staff';
    try {
      final published = await controller.restore(v, publishedBy: by);
      if (context.mounted) {
        showDone(
          context,
          'Version ${v.version} is live again as version ${published.version}',
        );
      }
    } on AppFailure catch (e) {
      if (!context.mounted) return;
      if (e.kind == FailureKind.notReady) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restoring is not available yet'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showFailure(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final state = controller.state;
    final history = state?.history ?? const <StorefrontVersion>[];
    final live = state?.published?.version;
    final canRestore = AppScope.of(context).session
        .can(Capability.publishStorefront);
    if (history.isEmpty) {
      return const EmptyView(
        icon: Icons.history_rounded,
        title: 'Nothing published yet',
        message: 'Each time you publish, a numbered copy is kept here so you can always go back.',
      );
    }
    final format = DateFormat('d MMM y, h:mm a');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: history.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              canRestore
                  ? 'Restore an older version to make it live again.'
                  : 'Owners and admins can restore an older version.',
              style: text.bodyMedium,
            ),
          );
        }
        final v = history[i - 1];
        final isLive = v.version == live;
        return Panel(
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Version ${v.version}', style: text.titleMedium),
                      if (isLive)
                        StatusChip(
                          label: 'Live',
                          color: t.success,
                          icon: Icons.circle,
                        ),
                    ],
                  ),
                ),
                if (canRestore && !isLive)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: controller.busy
                        ? null
                        : () => _restore(context, v),
                    child: const Text('Restore'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                format.format(v.publishedAt),
                if (v.publishedBy != null) 'by ${v.publishedBy}',
              ].join(' · '),
              style: text.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              '${v.definition.brand.displayName} · ${v.definition.template.label}',
              style: text.bodySmall,
            ),
          ],
        );
      },
    );
  }
}
