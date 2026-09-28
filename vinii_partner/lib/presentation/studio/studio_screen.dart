import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../application/studio_changes.dart';
import '../../application/studio_controller.dart';
import '../../core/failure.dart';
import '../../domain/guest_catalog.dart';
import '../../domain/organization.dart';
import '../../domain/staff.dart';
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
    try {
      await _c.saveDraft();
      if (!mounted) return;
      showDone(
        context,
        _c.state?.note != null ? 'Draft saved on this phone' : 'Draft saved',
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
    final by = AppScope.of(context).session.user?.displayName ?? 'Staff';
    try {
      final v = await _c.publish(publishedBy: by);
      if (mounted) showDone(context, 'Published version ${v.version}');
    } on AppFailure catch (e) {
      if (!mounted) return;
      if (e.kind == FailureKind.notReady) {
        await _explain('Publishing is not available yet', e.message);
      } else {
        showFailure(context, e);
      }
    }
  }

  Future<void> _discard() async {
    final t = ViniiTokens.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: Text(
          _c.state?.published == null
              ? 'Studio goes back to a blank storefront with your restaurant name.'
              : 'Studio goes back to what guests see now (version ${_c.state!.published!.version}).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep them'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: t.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _c.discardDraft();
      if (mounted) showDone(context, 'Changes discarded');
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
          child: const Text('OK'),
        ),
      ],
    ),
  );

  Future<void> _showProblems(List<String> problems) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          final t = ViniiTokens.of(context);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Almost ready to publish',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fix these first, so guests never land on a broken page:',
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
                          Expanded(child: Text(p)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
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
    final changes = describeStorefrontChanges(live?.definition, _c.draft);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final t = ViniiTokens.of(context);
        final text = Theme.of(context).textTheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Publish version $next?', style: text.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Every guest who opens your storefront sees this straight away.',
                  style: text.bodyMedium,
                ),
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
                            ? 'Nothing guests see has changed.'
                            : 'What guests will see change',
                        style: text.labelLarge,
                      ),
                      for (final line in changes) ...[
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
                            Expanded(child: Text(line)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Publish now'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Not yet'),
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
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'You have unsaved changes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Save them as a draft to keep working later, or discard them.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (canSave) ...[
                FilledButton(
                  onPressed: () => Navigator.pop(context, 'save'),
                  child: const Text('Save draft'),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton(
                onPressed: () => Navigator.pop(context, 'discard'),
                child: const Text('Discard changes'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Keep editing'),
              ),
            ],
          ),
        ),
      ),
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
        return PopScope(
          canPop: !loaded || !_c.dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onBlockedPop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Storefront Studio'),
              actions: [
                if (loaded)
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (v) => switch (v) {
                      'discard' => _discard(),
                      'preview' => context.push(Routes.storefrontPreview),
                      _ => _c.refresh(),
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'preview',
                        child: Text('Open full preview'),
                      ),
                      const PopupMenuItem(
                        value: 'refresh',
                        child: Text('Refresh'),
                      ),
                      if (canEdit)
                        PopupMenuItem(
                          value: 'discard',
                          enabled: _c.hasUnpublishedChanges && !_c.busy,
                          child: const Text('Discard changes'),
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
    if (!_c.loaded) {
      if (_c.failure != null && !_c.loading) {
        return FailureView(failure: _c.failure!, onRetry: _c.load);
      }
      return const LoadingView(label: 'Opening your storefront…');
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
              message: note,
            ),
            const SizedBox(height: 12),
          ],
          if (_c.failure != null) ...[
            NoticeBanner(
              icon: Icons.sync_problem_rounded,
              tone: t.warning,
              message: 'Could not refresh. ${_c.failure!.message}',
            ),
            const SizedBox(height: 12),
          ],
          if (!canEdit) ...[
            const NoticeBanner(
              icon: Icons.visibility_outlined,
              message: 'You can look around. Owners, admins, managers and marketing can change the storefront.',
            ),
            const SizedBox(height: 12),
          ],
          _StatusCard(controller: _c, address: _address),
          const PanelLabel('Live preview'),
          _PreviewCard(controller: _c, emptyMenu: emptyMenu),
          for (final group in _groups) ...[
            PanelLabel(group.$1),
            Panel(
              padding: null,
              children: [
                for (var i = 0; i < group.$2.length; i++) ...[
                  if (i > 0) const PanelDivider(indent: 72),
                  _SectionTile(
                    section: group.$2[i],
                    summary: group.$2[i].summary(_c, address: _address),
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
      <(String, List<StudioSection>, Color Function(ViniiTokens))>[
        ('Look', [StudioSection.look, StudioSection.brand], (t) => t.info),
        (
          'Ordering',
          [StudioSection.service, StudioSection.features],
          (t) => t.success,
        ),
        (
          'Menu',
          [StudioSection.categories, StudioSection.highlights],
          (t) => t.warning,
        ),
        (
          'Share',
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
                      child: const Text('Save draft'),
                    ),
                  ),
                  if (canPublish) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: canPublishNow ? _publish : null,
                        child: const Text('Publish'),
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
    final c = controller;
    final live = c.state?.published;
    final name = c.draft.brand.displayName.trim();
    final accent = c.draft.accentHex;
    final status = live == null
        ? 'Not published yet'
        : [
            'Live',
            'version ${live.version}',
            'published ${DateFormat('d MMM').format(live.publishedAt)}'
                '${live.publishedBy == null ? '' : ' by ${live.publishedBy}'}',
          ].join(' · ');
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
                    label: 'Not live yet',
                    color: t.inkSecondary,
                    icon: Icons.visibility_off_outlined,
                  )
                : StatusChip(
                    label: 'Live',
                    color: t.success,
                    icon: Icons.circle,
                  ),
            if (c.hasUnpublishedChanges)
              StatusChip(
                label: c.dirty ? 'Unsaved changes' : 'Unpublished changes',
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
              tooltip: 'Copy address',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: address));
                if (context.mounted) showDone(context, 'Address copied');
              },
            ),
          ],
        ),
        Text(
          'This web address works once the VINII guest website is live. Until then, try it in the preview below.',
          style: text.bodySmall,
        ),
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
    return Panel(
      children: [
        Text(
          'This is what guests see on their phone. Every change shows here straight away.',
          style: text.bodyMedium,
        ),
        if (emptyMenu) ...[
          const SizedBox(height: 12),
          NoticeBanner(
            icon: Icons.no_food_outlined,
            tone: t.warning,
            message: 'No dishes guests can order yet. Add dishes with a price in the Menu tab.',
            action: TextButton(
              onPressed: () => context.go(Routes.menu),
              child: const Text('Menu'),
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
          label: const Text('Open full preview'),
        ),
        const SizedBox(height: 6),
        Text(
          'Try ordering in the full preview. Nothing is sent to the kitchen.',
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
      section.title,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => context.push(Routes.storefrontSection(section.key)),
  );
}
