import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../application/studio_controller.dart';
import '../../domain/staff.dart';
import '../../l10n/l10n.dart';
import '../guest/guest_app.dart';
import '../widgets/state_views.dart';
import 'phone_preview.dart';
import 'studio_scope.dart';

/// Studio's full-screen preview: the guest runtime with the current working
/// copy, the real menu and bill settings, and a gateway that never sends an
/// order. A bar at the top says so, so nobody mistakes it for a real order.
class StudioPreviewScreen extends StatefulWidget {
  const StudioPreviewScreen({super.key});

  @override
  State<StudioPreviewScreen> createState() => _StudioPreviewScreenState();
}

class _StudioPreviewScreenState extends State<StudioPreviewScreen> {
  StudioController? _c;

  @override
  void initState() {
    super.initState();
    if (!AppScope.of(context).session.can(Capability.viewStorefront)) return;
    final c = _c = studioOf(context);
    // Deferred: listeners elsewhere must not rebuild while this route builds.
    scheduleMicrotask(() => c.fullPreviewOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.ensureLoaded();
    });
  }

  @override
  void dispose() {
    final c = _c;
    if (c != null) scheduleMicrotask(() => c.fullPreviewOpen = false);
    super.dispose();
  }

  void _close() {
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final l = context.l10n;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.commonPreview)),
        body: EmptyView(
          icon: Icons.lock_outline_rounded,
          title: l.failureTitleForbidden,
          message: l.studioPreviewNoAccess,
        ),
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.loaded) {
          return Scaffold(
            appBar: AppBar(title: Text(l.commonPreview)),
            body: c.failure != null && !c.loading
                ? FailureView(failure: c.failure!, onRetry: c.load)
                : LoadingView(label: l.studioPreviewOpening),
          );
        }
        // The preview label sits in its own bar above the guest runtime, so
        // it never covers the guest header (logo, back button, budget ring).
        return Scaffold(
          backgroundColor: Colors.black,
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Center(child: _PreviewPill(onClose: _close)),
                ),
              ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: PhoneScreen.embedGuestApp
                      ? GuestApp(
                          key: ValueKey('full-preview-${c.revision}'),
                          definition: c.draft,
                          menu: c.menu,
                          gateway: c.gateway,
                          mediaBaseUrl: AppScope.of(context)
                              .config
                              .mediaBaseUrl,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: 0.78),
    shape: const StadiumBorder(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 2, 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_outlined, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              context.l10n.studioPreviewPill,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.studioPreviewClose,
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    ),
  );
}
