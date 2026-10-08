import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../l10n/l10n.dart';
import '../settings/language_screen.dart';
import '../theme/staff_theme.dart';

/// First launch on this phone only: what the app is for, in three pages.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = PageController();
  int _index = 0;

  /// The three pages, in order. The words come from the current language.
  static List<({IconData icon, String title, String body})> _pagesFor(
    AppLocalizations l,
  ) => [
    (
      icon: Icons.notifications_active_rounded,
      title: l.introOrdersTitle,
      body: l.introOrdersBody,
    ),
    (
      icon: Icons.point_of_sale_rounded,
      title: l.introPosTitle,
      body: l.introPosBody,
    ),
    (
      icon: Icons.storefront_rounded,
      title: l.introStorefrontTitle,
      body: l.introStorefrontBody,
    ),
  ];

  static const _pageCount = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pageCount - 1) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      AppScope.of(context).session.finishIntro();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final content = _pagesFor(l);
    final last = _index == _pageCount - 1;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
              child: Row(
                // The language can be chosen on the very first screen.
                children: [
                  const LanguageButton(),
                  const Spacer(),
                  TextButton(
                    onPressed: () => AppScope.of(context).session.finishIntro(),
                    child: Text(l.commonSkip),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _pageCount,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final c = content[i];
                  // Scrolls instead of overflowing when a longer language or a
                  // short screen leaves too little height.
                  return LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 132,
                              height: 132,
                              decoration: BoxDecoration(
                                color: dark ? Colors.white : ViniiColors.ink,
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    c.icon,
                                    size: 60,
                                    color: dark
                                        ? ViniiColors.ink
                                        : Colors.white,
                                  ),
                                  Positioned(
                                    right: 22,
                                    top: 22,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        color: ViniiColors.brandGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                            Text(
                              c.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              c.body,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: t.inkSecondary,
                                    height: 1.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pageCount; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? t.ink : t.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(last ? l.introGetStarted : l.commonNext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
