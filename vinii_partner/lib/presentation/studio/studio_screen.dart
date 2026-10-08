import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../application/studio_changes.dart';
import '../../application/studio_controller.dart';
import '../../core/failure.dart';
import '../../core/time_format.dart';
import '../../domain/guest_catalog.dart';
import '../../domain/organization.dart';
import '../../domain/staff.dart';
import '../../domain/storefront.dart';
import '../../l10n/failure_text.dart';
import '../../l10n/l10n.dart';
import '../menu/panel.dart';
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/state_views.dart';
import 'phone_preview.dart';
import 'studio_scope.dart';
import 'studio_sections.dart';

/// Storefront Studio: where a restaurant shapes its own ordering website and
/// table app, sees it live in a phone, and publishes it.
///
/// Everything edits one working copy held by [StudioController]; nothing
/// reaches guests until "Publish", and nothing is stored until "Save
/// draft". A storefront that was never published starts blank apart from
/// the restaurant's real name, city and colour.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  late final StudioController _c = studioOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.ensureLoaded();
    });
  }

  bool _can(Capability c) => AppScope.of(context).session.can(c);

  String get _address => storefrontAddress(
    AppScope.of(context).config.storefrontBaseUrl,
    _c.org.slug,
  );

  Future<void> _save() async {
    final l = context.l10n;
    try {
      await _c.saveDraft();
      if (!mounted) return;
      showDone(
        context,
        _c.state?.note != null ? l.studioDraftSavedOnPhone : l.studioDraftSaved,
      );
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _publish() async {
    final problems = _c.publishProblems();
    if (problems.isNotEmpty) {
      await _showProblems(problems);
      return;
    }
    final ok = await _confirmPublish();
    if (ok != true || !mounted) return;
    final l = context.l10n;
    // i18n-ignore: stored publisher name when the account has none
    final by = AppScope.of(context).session.user?.displayName ?? 'Staff';
    try {
      final v = await _c.publish(publishedBy: by);
      if (mounted) {
        showDone(context, l.studioPublishedVersion(version: v.version));
      }
    } on AppFailure catch (e) {
      if (!mounted) return;
      if (e.kind == FailureKind.notReady) {
        await _explain(l.studioPublishUnavailable, failureText(l, e));
      } else {
        showFailure(context, e);
      }
    }
  }

  Future<void> _discard() async {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.studioDiscardTitle),
        content: Text(
          _c.state?.published == null
              ? l.studioDiscardBodyBlank
              : l.studioDiscardBodyLive(version: _c.state!.published!.version),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.studioDiscardKeep),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: t.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.studioDiscardConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _c.discardDraft();
      if (mounted) showDone(context, l.studioDiscarded);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _explain(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.commonOk),
        ),
      ],
    ),
  );

  Future<void> _showProblems(List<AppFailure> problems) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          final t = ViniiTokens.of(context);
          final l = context.l10n;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.studioProblemsTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.studioProblemsIntro,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  for (final p in problems)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 20,
                            color: t.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(failureText(l, p))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.commonOk),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Future<bool?> _confirmPublish() {
    final live = _c.state?.published;
    final next = (live?.version ?? 0) + 1;
    final changes = storefrontChanges(live?.definition, _c.draft);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final t = ViniiTokens.of(context);
        final l = context.l10n;
        final text = Theme.of(context).textTheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.studioConfirmTitle(next: next), style: text.titleLarge),
                const SizedBox(height: 6),
                Text(l.studioConfirmIntro, style: text.bodyMedium),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        changes.isEmpty
                            ? l.studioConfirmNoChange
                            : l.studioConfirmWhatChanges,
                        style: text.labelLarge,
                      ),
                      for (final change in changes) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: t.success,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_changeText(l, change))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l.studioConfirmNow),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l.studioConfirmLater),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Leaving Studio (system back) with edits nobody saved.
  Future<void> _onBlockedPop() async {
    final canSave = _can(Capability.editStorefront);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        final l = context.l10n;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.studioUnsavedTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  l.studioUnsavedBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                if (canSave) ...[
                  FilledButton(
                    onPressed: () => Navigator.pop(context, 'save'),
                    child: Text(l.studioSaveDraft),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'discard'),
                  child: Text(l.studioDiscardChanges),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.studioKeepEditing),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    if (choice == 'save') {
      await _save();
    } else {
      _c.revertEdits();
    }
    if (mounted && !_c.dirty && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final loaded = _c.loaded;
        final canEdit = _can(Capability.editStorefront);
        final l = context.l10n;
        return PopScope(
          canPop: !loaded || !_c.dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBlockedPop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(l.studioTitle),
              actions: [
                if (loaded)
                  PopupMenuButton<String>(
                    tooltip: l.commonMore,
                    onSelected: (v) => switch (v) {
                      'discard' => _discard(),
                      'preview' => context.push(Routes.storefrontPreview),
                      _ => _c.refresh(),
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'preview',
                        child: Text(l.studioOpenFullPreview),
                      ),
                      PopupMenuItem(
                        value: 'refresh',
                        child: Text(l.commonRefresh),
                      ),
                      if (canEdit)
                        PopupMenuItem(
                          value: 'discard',
                          enabled: _c.hasUnpublishedChanges && !_c.busy,
                          child: Text(l.studioDiscardChanges),
                        ),
                    ],
                  ),
              ],
            ),
            bottomNavigationBar: loaded && canEdit ? _bar() : null,
            body: _body(),
          ),
        );
      },
    );
  }

  Widget _body() {
    final l = context.l10n;
    if (!_c.loaded) {
      if (_c.failure != null && !_c.loading) {
        return FailureView(failure: _c.failure!, onRetry: _c.load);
      }
      return LoadingView(label: l.studioOpening);
    }
    final t = ViniiTokens.of(context);
    final canEdit = _can(Capability.editStorefront);
    final note = _c.state?.note;
    final emptyMenu = GuestCatalog(menu: _c.menu, definition: _c.draft).isEmpty;
    return RefreshIndicator(
      onRefresh: _c.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (note != null) ...[
            NoticeBanner(
              icon: Icons.construction_rounded,
              tone: t.warning,
              message: note == storefrontDraftOnPhoneNote
                  ? l.studioNoteDraftOnPhone
                  : note,
            ),
            const SizedBox(height: 12),
          ],
          if (_c.failure != null) ...[
            NoticeBanner(
              icon: Icons.sync_problem_rounded,
              tone: t.warning,
              message: l.studioRefreshFailed(
                reason: failureText(l, _c.failure!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!canEdit) ...[
            NoticeBanner(
              icon: Icons.visibility_outlined,
              message: l.studioReadOnlyHome,
            ),
            const SizedBox(height: 12),
          ],
          _StatusCard(controller: _c, address: _address),
          PanelLabel(l.studioLivePreviewLabel),
          _PreviewCard(controller: _c, emptyMenu: emptyMenu),
          for (final group in _groups) ...[
            PanelLabel(group.$1(l)),
            Panel(
              padding: null,
              children: [
                for (var i = 0; i < group.$2.length; i++) ...[
                  if (i > 0) const PanelDivider(indent: 72),
                  _SectionTile(
                    section: group.$2[i],
                    summary: group.$2[i].summary(l, _c, address: _address),
                    color: group.$3(t),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  static final _groups =
      <
        (
          String Function(AppLocalizations),
          List<StudioSection>,
          Color Function(ViniiTokens),
        )
      >[
        (
          (l) => l.studioGroupLook,
          [StudioSection.look, StudioSection.brand],
          (t) => t.info,
        ),
        (
          (l) => l.studioGroupOrdering,
          [StudioSection.service, StudioSection.features],
          (t) => t.success,
        ),
        (
          (l) => l.commonMenu,
          [StudioSection.categories, StudioSection.highlights],
          (t) => t.warning,
        ),
        (
          (l) => l.studioGroupShare,
          [StudioSection.share, StudioSection.history],
          (t) => t.inkSecondary,
        ),
      ];

  Widget _bar() {
    final t = ViniiTokens.of(context);
    final canPublish = _can(Capability.publishStorefront);
    final live = _c.state?.published;
    final canPublishNow =
        !_c.busy && (live == null || _c.hasUnpublishedChanges);
    final l = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_c.busy) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _c.dirty && !_c.busy ? _save : null,
                      child: Text(l.studioSaveDraft),
                    ),
                  ),
                  if (canPublish) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: canPublishNow ? _publish : null,
                        child: Text(l.studioPublish),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller, required this.address});
  final StudioController controller;
  final String address;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final c = controller;
    final live = c.state?.published;
    final name = c.draft.brand.displayName.trim();
    final accent = c.draft.accentHex;
    final status = live == null
        ? l.studioStatusNotPublished
        : live.publishedBy == null
        ? l.studioStatusLive(
            version: live.version,
            date: dayMonth(live.publishedAt),
          )
        : l.studioStatusLiveBy(
            version: live.version,
            date: dayMonth(live.publishedAt),
            by: live.publishedBy!,
          );
    return Panel(
      children: [
        Row(
          children: [
            _AccentDot(hex: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? c.org.name : name,
                    style: text.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(status, style: text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            live == null
                ? StatusChip(
                    label: l.studioChipNotLive,
                    color: t.inkSecondary,
                    icon: Icons.visibility_off_outlined,
                  )
                : StatusChip(
                    label: l.studioLive,
                    color: t.success,
                    icon: Icons.circle,
                  ),
            if (c.hasUnpublishedChanges)
              StatusChip(
                label: c.dirty ? l.studioChipUnsaved : l.studioChipUnpublished,
                color: t.warning,
                icon: Icons.edit_note_rounded,
              ),
          ],
        ),
        const SizedBox(height: 14),
        const PanelDivider(indent: 0),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.link_rounded, size: 20, color: t.inkSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                address.replaceFirst(RegExp(r'^https?://'), ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: t.ink),
              ),
            ),
            IconButton(
              tooltip: l.studioCopyAddress,
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: address));
                if (context.mounted) showDone(context, l.studioAddressCopied);
              },
            ),
          ],
        ),
        Text(l.studioAddressNote, style: text.bodySmall),
      ],
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.hex});
  final String hex;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final color = parseHexColor(hex) ?? t.ink;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Icon(Icons.storefront_rounded, color: onColor(color), size: 22),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.controller, required this.emptyMenu});
  final StudioController controller;
  final bool emptyMenu;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Panel(
      children: [
        Text(l.studioPreviewIntro, style: text.bodyMedium),
        if (emptyMenu) ...[
          const SizedBox(height: 12),
          NoticeBanner(
            icon: Icons.no_food_outlined,
            tone: t.warning,
            message: l.studioPreviewNoDishes,
            action: TextButton(
              onPressed: () => context.go(Routes.menu),
              child: Text(l.commonMenu),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: LayoutBuilder(
            builder: (context, box) {
              // Never wider than the card on a small phone.
              final maxH = (box.maxWidth - 14) * 844 / 390;
              final h = maxH < 460 ? maxH : 460.0;
              return PhonePreviewFrame(controller: controller, height: h);
            },
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.push(Routes.storefrontPreview),
          icon: const Icon(Icons.open_in_full_rounded),
          label: Text(l.studioOpenFullPreview),
        ),
        const SizedBox(height: 6),
        Text(
          l.studioPreviewTryNote,
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.summary,
    required this.color,
  });

  final StudioSection section;
  final String summary;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
    leading: TintIcon(section.icon, color: color),
    title: Text(
      context.l10n.studioSectionTitle(section),
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => context.push(Routes.storefrontSection(section.key)),
  );
}

/// One line of the publish confirmation, in the reader's language. What the
/// restaurant typed (its name, its table word) is shown as it is.
String _changeText(AppLocalizations l, StorefrontChange c) => switch (c.kind) {
  StorefrontChangeKind.firstPublish => l.studioChangeFirst,
  StorefrontChangeKind.template => l.studioChangeTemplate(
    // i18n-ignore: template name
    from: (c.from as StorefrontTemplate).label,
    // i18n-ignore: template name
    to: (c.to as StorefrontTemplate).label,
  ),
  StorefrontChangeKind.accent => l.studioChangeAccent(
    from: '${c.from}',
    to: '${c.to}',
  ),
  StorefrontChangeKind.theme => l.studioChangeTheme,
  StorefrontChangeKind.categoryStyle => l.studioChangeCategoryStyle(
    from: l.studioStyleName(c.from as CategoryStyle),
    to: l.studioStyleName(c.to as CategoryStyle),
  ),
  StorefrontChangeKind.name => l.studioChangeName(name: '${c.to}'),
  StorefrontChangeKind.tagline => l.studioBrandTagline,
  StorefrontChangeKind.locationLine => l.studioBrandLocationLine,
  StorefrontChangeKind.heroTitle => l.studioBrandHeroTitle,
  StorefrontChangeKind.heroSubtitle => l.studioBrandHeroText,
  StorefrontChangeKind.logo => l.studioChangeLogo,
  StorefrontChangeKind.pictures => l.studioChangePictures,
  StorefrontChangeKind.guestText => l.studioChangeGuestText,
  StorefrontChangeKind.guestLanguage => l.studioChangeGuestLanguage(
    // i18n-ignore: language name in its own script
    language: (c.to as CopyLanguage).label,
  ),
  StorefrontChangeKind.serviceModes => l.studioChangeModes(
    modes: (c.to as List<GuestServiceMode>).map(l.studioModeName).join(', '),
  ),
  StorefrontChangeKind.tableLabel => l.studioChangeTableLabel(label: '${c.to}'),
  StorefrontChangeKind.preOrder => l.studioChangePreOrder,
  StorefrontChangeKind.features => l.studioSectionFeatures,
  StorefrontChangeKind.categories => l.studioChangeCategories,
  StorefrontChangeKind.itemDetails => l.studioChangeItems(count: c.count),
  StorefrontChangeKind.chefsPicks => l.studioChangeChefsPicks,
  StorefrontChangeKind.limitedToday => l.studioChangeLimited,
};
