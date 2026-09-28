import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../application/studio_controller.dart';
import '../../domain/staff.dart';
import '../theme/staff_theme.dart';
import '../widgets/state_views.dart';
import 'sections/brand_section.dart';
import 'sections/categories_section.dart';
import 'sections/features_section.dart';
import 'sections/highlights_section.dart';
import 'sections/history_section.dart';
import 'sections/look_section.dart';
import 'sections/service_section.dart';
import 'sections/share_section.dart';
import 'studio_scope.dart';
import 'studio_sections.dart';

/// One part of Studio (`/storefront/section/<key>`). Edits go straight into
/// the shared working copy, so the preview in Studio already shows them when
/// the person comes back; saving and publishing happen on Studio's main
/// screen, in one place.
class StudioSectionScreen extends StatefulWidget {
  const StudioSectionScreen({super.key, required this.sectionKey});

  final String sectionKey;

  @override
  State<StudioSectionScreen> createState() => _StudioSectionScreenState();
}

class _StudioSectionScreenState extends State<StudioSectionScreen> {
  late final StudioController _c = studioOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final section = StudioSection.fromKey(widget.sectionKey);
    if (section == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Storefront Studio')),
        body: EmptyView(
          icon: Icons.help_outline_rounded,
          title: 'This part of Studio does not exist',
          actionLabel: 'Back to Studio',
          onAction: () => context.go(Routes.storefront),
        ),
      );
    }
    final canEdit = AppScope.of(context).session.can(Capability.editStorefront);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final loaded = _c.loaded;
        return Scaffold(
          appBar: AppBar(
            title: Text(section.title),
            actions: [
              if (loaded && section.edits)
                IconButton(
                  tooltip: 'Open full preview',
                  icon: const Icon(Icons.phone_iphone_rounded),
                  onPressed: () => context.push(Routes.storefrontPreview),
                ),
            ],
          ),
          bottomNavigationBar: loaded && section.edits && canEdit
              ? _DoneBar(dirty: _c.dirty)
              : null,
          body: !loaded
              ? (_c.failure != null && !_c.loading
                    ? FailureView(failure: _c.failure!, onRetry: _c.load)
                    : const LoadingView())
              : _content(section, canEdit),
        );
      },
    );
  }

  Widget _content(StudioSection section, bool canEdit) {
    final body = switch (section) {
      StudioSection.look => LookSection(controller: _c),
      StudioSection.brand => BrandSection(controller: _c),
      StudioSection.service => ServiceSection(controller: _c),
      StudioSection.features => FeaturesSection(controller: _c),
      StudioSection.categories => CategoriesSection(controller: _c),
      StudioSection.highlights => HighlightsSection(controller: _c),
      StudioSection.share => ShareSection(controller: _c),
      StudioSection.history => HistorySection(controller: _c),
    };
    if (!section.edits || canEdit) return body;
    // Read-only: the same screen, but nothing can be changed.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: NoticeBanner(
            icon: Icons.visibility_outlined,
            message: 'You can look, but only owners, admins, managers and marketing can change this.',
          ),
        ),
        Expanded(child: AbsorbPointer(child: body)),
      ],
    );
  }
}

class _DoneBar extends StatelessWidget {
  const _DoneBar({required this.dirty});
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dirty
                      ? 'Changes show in the preview. Save or publish them in Studio.'
                      : 'Changes show in the preview straight away.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
