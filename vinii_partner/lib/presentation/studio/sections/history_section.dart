import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../application/studio_controller.dart';
import '../../../core/failure.dart';
import '../../../core/time_format.dart';
import '../../../domain/staff.dart';
import '../../../domain/storefront.dart';
import '../../../l10n/failure_text.dart';
import '../../../l10n/l10n.dart';
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
    final l = context.l10n;
    final live = controller.state?.published?.version ?? 0;
    final next = live + 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.studioHistoryRestoreTitle(version: v.version)),
        content: Text(
          controller.hasUnpublishedChanges
              ? l.studioHistoryRestoreBodyUnpublished(
                  version: v.version,
                  next: next,
                )
              : l.studioHistoryRestoreBody(version: v.version, next: next),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.studioRestore),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    // i18n-ignore: stored publisher name when the account has none
    final by = AppScope.of(context).session.user?.displayName ?? 'Staff';
    try {
      final published = await controller.restore(v, publishedBy: by);
      if (context.mounted) {
        showDone(
          context,
          l.studioHistoryRestored(version: v.version, next: published.version),
        );
      }
    } on AppFailure catch (e) {
      if (!context.mounted) return;
      if (e.kind == FailureKind.notReady) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.studioHistoryRestoreUnavailable),
            content: Text(failureText(l, e)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.commonOk),
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
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final state = controller.state;
    final history = state?.history ?? const <StorefrontVersion>[];
    final live = state?.published?.version;
    final canRestore = AppScope.of(context).session
        .can(Capability.publishStorefront);
    if (history.isEmpty) {
      return EmptyView(
        icon: Icons.history_rounded,
        title: l.studioNothingPublished,
        message: l.studioHistoryEmptyMessage,
      );
    }
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
                  ? l.studioHistoryRestoreHint
                  : l.studioHistoryRestoreHintLocked,
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
                      Text(
                        l.studioVersionNumber(version: v.version),
                        style: text.titleMedium,
                      ),
                      if (isLive)
                        StatusChip(
                          label: l.studioLive,
                          color: t.success,
                          icon: Icons.circle,
                        ),
                    ],
                  ),
                ),
                if (canRestore && !isLive)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: controller.busy
                        ? null
                        : () => _restore(context, v),
                    child: Text(l.studioRestore),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                dayMonthYearTime(v.publishedAt),
                if (v.publishedBy != null)
                  l.studioPublishedBy(name: v.publishedBy!),
              ].join(' · '),
              style: text.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              // i18n-ignore: the restaurant's name and the template's name
              '${v.definition.brand.displayName} · ${v.definition.template.label}',
              style: text.bodySmall,
            ),
          ],
        );
      },
    );
  }
}
