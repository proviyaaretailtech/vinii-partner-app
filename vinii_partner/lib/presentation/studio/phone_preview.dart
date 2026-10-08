import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../application/studio_controller.dart';
import '../../l10n/l10n.dart';
import '../guest/guest_app.dart';
import '../theme/guest_theme.dart';
import '../theme/staff_theme.dart';

/// The guest runtime at a real phone's size (390 × 844 logical pixels, with
/// a notch and home bar), scaled down into a phone frame. It lays out
/// exactly as on a guest's phone, so what Studio shows is what guests get.
///
/// Edits reach the running guest runtime in place (it restyles itself);
/// it restarts, like a guest opening the link afresh, whenever the saved
/// storefront changes (the controller's revision).
class PhoneScreen extends StatelessWidget {
  const PhoneScreen({super.key, required this.controller});

  final StudioController controller;

  static const virtualSize = Size(390, 844);
  static const safeArea = EdgeInsets.only(top: 47, bottom: 34);

  /// Tests switch this off so they never depend on the guest runtime's own
  /// screens and animations (another part of the app).
  static bool embedGuestApp = true;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final Widget guest = embedGuestApp && !c.fullPreviewOpen
        ? GuestApp(
            key: ValueKey('studio-preview-${c.revision}'),
            definition: c.draft,
            menu: c.menu,
            gateway: c.gateway,
            mediaBaseUrl: AppScope.of(context).config.mediaBaseUrl,
          )
        : _Stand(controller: c);
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox.fromSize(
        size: virtualSize,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: virtualSize,
            padding: safeArea,
            viewPadding: safeArea,
            viewInsets: EdgeInsets.zero,
            textScaler: TextScaler.noScaling,
          ),
          child: guest,
        ),
      ),
    );
  }
}

/// A phone frame around a non-interactive [PhoneScreen], for Studio's list.
class PhonePreviewFrame extends StatelessWidget {
  const PhonePreviewFrame({
    super.key,
    required this.controller,
    this.height = 460,
  });

  final StudioController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final scale = height / PhoneScreen.virtualSize.height;
    final width = PhoneScreen.virtualSize.width * scale;
    const bezel = 7.0;
    return Semantics(
      label: context.l10n.studioPreviewFrame,
      child: Container(
        width: width + bezel * 2,
        height: height + bezel * 2,
        padding: const EdgeInsets.all(bezel),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(48 * scale + bezel),
          border: Border.all(color: t.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(48 * scale),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: PhoneScreen(controller: controller),
                  ),
                ),
              ),
              // The notch, so the frame reads as a phone at a glance.
              Positioned(
                top: 11 * scale,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 120 * scale,
                    height: 34 * scale,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20 * scale),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the guest runtime while the full-screen preview is open
/// (only one runs at a time) and in tests: the template's colours and the
/// restaurant's name, nothing invented.
class _Stand extends StatelessWidget {
  const _Stand({required this.controller});
  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.from(controller.draft);
    return ColoredBox(
      color: p.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            controller.draft.brand.displayName,
            textAlign: TextAlign.center,
            style: p.display(34),
          ),
        ),
      ),
    );
  }
}
