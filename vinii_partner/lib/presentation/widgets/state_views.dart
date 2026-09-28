import 'package:flutter/material.dart';

import '../../core/failure.dart';
import '../theme/staff_theme.dart';

/// Every list and screen has four honest states: loading, empty, failed,
/// and (for missing database pieces) "not ready yet". These are them.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: t.ink),
          ),
          if (label != null) ...[
            const SizedBox(height: 14),
            Text(label!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: t.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: t.inkSecondary),
            ),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: text.titleLarge),
            if (message != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.failure, this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (failure.kind) {
      FailureKind.offline => (Icons.wifi_off_rounded, 'You are offline'),
      FailureKind.forbidden => (Icons.lock_outline_rounded, 'Not allowed'),
      FailureKind.notReady => (Icons.construction_rounded, 'Not available yet'),
      FailureKind.auth => (Icons.person_off_outlined, 'Signed out'),
      _ => (Icons.error_outline_rounded, 'Something went wrong'),
    };
    return EmptyView(
      icon: icon,
      title: title,
      message: failure.message,
      actionLabel: onRetry == null || failure.kind == FailureKind.notReady
          ? null
          : 'Try again',
      onAction: onRetry,
    );
  }
}

/// A slim banner at the top of a list: offline, not ready, a notice.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone,
    this.action,
  });

  final String message;
  final IconData icon;
  final Color? tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final c = tone ?? t.info;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: t.tint(c),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: t.ink, fontSize: 13.5, height: 1.35),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

/// Shows an [AppFailure] as a snackbar with the right words.
void showFailure(BuildContext context, Object error) {
  final f = error is AppFailure ? error : asFailure(error);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(f.message)));
}

void showDone(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}
