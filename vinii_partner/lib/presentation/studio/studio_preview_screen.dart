import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../application/studio_controller.dart';
import '../../domain/staff.dart';
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
    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preview')),
        body: const EmptyView(
          icon: Icons.lock_outline_rounded,
          title: 'Not allowed',
          message: 'Your role cannot see the storefront.',
        ),
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.loaded) {
          return Scaffold(
            appBar: AppBar(title: const Text('Preview')),
            body: c.failure != null && !c.loading
                ? FailureView(failure: c.failure!, onRetry: c.load)
                : const LoadingView(label: 'Opening the preview…'),
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
          const Flexible(
            child: Text(
              'Preview · orders are not sent',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close preview',
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
