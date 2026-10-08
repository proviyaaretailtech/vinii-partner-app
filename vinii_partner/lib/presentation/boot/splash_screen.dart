import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../application/session_controller.dart';
import '../../core/failure.dart';
import '../../l10n/failure_text.dart';
import '../../l10n/l10n.dart';
import '../theme/staff_theme.dart';
import 'brand_mark.dart';

/// The loader. Shows what is happening ("Finding your restaurants…"), and
/// when booting cannot finish, says why in plain words with one way out.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final session = services.session;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: ViniiColors.pageDark,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            final stage = session.stage;
            return Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  const Center(child: BrandMark(size: 72)),
                  const SizedBox(height: 22),
                  const Text(
                    'VINII Partner', // i18n-ignore: brand name
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.bootTagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF9A9AA3),
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(flex: 2),
                  switch (stage) {
                    SessionStage.notConfigured => _Problem(
                      icon: Icons.settings_suggest_outlined,
                      title: l.bootNotConnectedTitle,
                      message: l.bootNotConnectedBody(
                        settings: services.config.missingSettings.join(
                          ' ${l.uiAnd} ',
                        ),
                      ),
                    ),
                    SessionStage.bootError => _Problem(
                      icon: session.bootFailure?.kind == FailureKind.offline
                          ? Icons.wifi_off_rounded
                          : Icons.error_outline_rounded,
                      title: session.bootFailure?.kind == FailureKind.offline
                          ? l.bootNoConnection
                          : l.bootCouldNotStart,
                      message: session.bootFailure == null
                          ? l.bootSomethingWrong
                          : failureText(l, session.bootFailure!),
                      action: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: ViniiColors.brandGreen,
                          foregroundColor: ViniiColors.ink,
                        ),
                        onPressed: session.boot,
                        child: Text(l.commonTryAgain),
                      ),
                      secondary: session.user == null
                          ? null
                          : TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                              ),
                              onPressed: () => session.signOut(),
                              child: Text(l.commonSignOut),
                            ),
                    ),
                    _ => Column(
                      children: [
                        const SizedBox.square(
                          dimension: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: ViniiColors.brandGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          switch (session.bootStep) {
                            BootStep.starting => l.bootStepStarting,
                            BootStep.connecting => l.bootStepConnecting,
                            BootStep.findingRestaurants => l.bootStepFinding,
                            BootStep.opening => l.bootStepOpening(
                              name: session.bootOrgName,
                            ),
                          },
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB4B4BC),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  },
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.secondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: ViniiColors.surfaceDark,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ViniiColors.borderDark),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, color: const Color(0xFFFBBF24), size: 28),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          style: const TextStyle(
            color: Color(0xFFB4B4BC),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 18), action!],
        if (secondary != null) ...[const SizedBox(height: 4), secondary!],
      ],
    ),
  );
}
