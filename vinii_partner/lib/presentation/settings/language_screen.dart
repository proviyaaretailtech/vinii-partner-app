import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/l10n.dart';
import '../../l10n/locale_controller.dart';
import '../../l10n/locales.dart';
import '../theme/staff_theme.dart';

/// More > Language: one tile per language in the registry
/// (`lib/l10n/locales.dart`). Tapping a tile switches the whole app at once,
/// in place: nothing restarts and no screen loses its state. While Hindi's
/// font loads the current language stays on screen and that tile alone shows
/// a spinner.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.languageTitle)),
      body: LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth > 720 ? (box.maxWidth - 688) / 2 : 16.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(side, 4, side, 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Text(
                  l.languageIntro,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const LanguagePicker(),
            ],
          );
        },
      ),
    );
  }
}

/// The language tiles, shared by the Language screen, the first-run sheet and
/// the sign-in screen's language button.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).locale;
    final t = ViniiTokens.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final locales = selectableLocales;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, locale) in locales.indexed) ...[
                if (i > 0) Divider(height: 1, color: t.border),
                _LanguageTile(locale: locale, controller: controller),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.locale, required this.controller});

  final AppLocale locale;
  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = ViniiTokens.of(context);
    final selected = controller.active == locale;
    final loading = controller.pending == locale;
    final failed = controller.failed == locale;
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        value: loading ? l.languageLoading : null,
        child: InkWell(
          // Always tappable: tapping again while loading is harmless and the
          // last tap wins (LocaleController.select).
          onTap: () => controller.select(locale),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locale.nativeName,
                              style: TextStyle(
                                color: t.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            // The sample is written in that language itself,
                            // so a person can judge it before choosing.
                            Text(
                              locale.sample,
                              style: TextStyle(
                                color: t.inkSecondary,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // One fixed slot, so the row never jumps between the
                      // spinner, the check and nothing.
                      SizedBox.square(
                        dimension: 28,
                        child: Center(
                          child: loading
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : selected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: t.success,
                                  semanticLabel: l.languageCurrent,
                                )
                              : Icon(
                                  Icons.circle_outlined,
                                  color: t.border,
                                  size: 24,
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (failed) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: t.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.languageFailed(language: locale.nativeName),
                            style: TextStyle(
                              color: t.danger,
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: controller.retry,
                        child: Text(l.commonTryAgain),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small button that shows the current language and opens the picker in a
/// sheet. For screens without a Settings tab: the first-run intro and
/// sign-in.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).locale;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextButton.icon(
        icon: const Icon(Icons.translate_rounded, size: 20),
        label: Text(controller.active.nativeName),
        onPressed: () => showLanguageSheet(context),
      ),
    );
  }
}

Future<void> showLanguageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final l = context.l10n;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.languageTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                l.languageIntro,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const LanguagePicker(),
            ],
          ),
        ),
      );
    },
  );
}
