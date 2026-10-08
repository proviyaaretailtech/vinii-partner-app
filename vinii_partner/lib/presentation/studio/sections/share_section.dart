import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/app_scope.dart';
import '../../../application/studio_controller.dart';
import '../../../l10n/l10n.dart';
import '../../menu/panel.dart';
import '../../theme/staff_theme.dart';
import '../../widgets/state_views.dart';
import '../studio_sections.dart';

/// The storefront's address and a QR code for it. The QR is always black
/// on white, whatever the app's theme, because that is what phone cameras
/// read most reliably from a printed card.
class ShareSection extends StatelessWidget {
  const ShareSection({super.key, required this.controller});
  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final address = storefrontAddress(
      AppScope.of(context).config.storefrontBaseUrl,
      controller.org.slug,
    );
    final published = controller.state?.published != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (!published) ...[
          NoticeBanner(
            icon: Icons.visibility_off_outlined,
            tone: t.warning,
            message: l.studioShareNotPublished,
          ),
          const SizedBox(height: 12),
        ],
        Panel(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.border),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: address,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                    semanticsLabel: l.studioShareQrSemantics(address: address),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.org.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.studioShareScan,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              address,
              textAlign: TextAlign.center,
              style: text.titleSmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: address));
                  if (context.mounted) showDone(context, l.studioAddressCopied);
                },
                icon: const Icon(Icons.copy_rounded),
                label: Text(l.studioCopyAddress),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Panel(
          children: [
            _Line(icon: Icons.print_outlined, text: l.studioSharePrintLine),
            const SizedBox(height: 12),
            _Line(
              icon: Icons.table_restaurant_outlined,
              text: l.studioSharePerTableLine,
            ),
            const SizedBox(height: 12),
            _Line(icon: Icons.language_rounded, text: l.studioShareLiveLine),
          ],
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: t.inkSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
