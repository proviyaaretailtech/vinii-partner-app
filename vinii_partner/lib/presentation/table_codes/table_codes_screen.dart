import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../application/table_codes_controller.dart';
import '../../core/failure.dart';
import '../../domain/pos_order.dart';
import '../../domain/staff.dart';
import '../../l10n/failure_text.dart';
import '../../l10n/l10n.dart';
import '../../l10n/script_fonts.dart';
import '../pos/pos_widgets.dart' show showNotAvailableDialog;
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/state_views.dart';
import 'code_exporter.dart';

/// Table QR codes: one code per table. A guest scans it and lands in the
/// storefront already set to that table.
///
/// Every restaurant table is listed under its floor section with the code it
/// really has (`<storefront address>/t/<code>`). A table without a code says
/// so; an admin or manager can issue one. Replacing a code is allowed only
/// after a strong warning, because every printed sticker stops working.
class TableCodesScreen extends StatefulWidget {
  const TableCodesScreen({
    super.key,
    this.exporter = const DeviceCodeExporter(),
  });

  /// How a card is saved or printed. Tests stand in for the device.
  final CodeExporter exporter;

  @override
  State<TableCodesScreen> createState() => _TableCodesScreenState();
}

class _TableCodesScreenState extends State<TableCodesScreen> {
  late final TableCodesController _c;
  late final bool _canView;

  /// The organisation's name, or null when it is not known (the card then
  /// says "Restaurant" in the reader's language).
  late final String? _restaurantName;
  late final String _baseUrl;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    final session = services.session;
    _canView = session.can(Capability.viewTableCodes);
    _restaurantName = session.membership?.organization.name;
    _baseUrl = services.config.storefrontBaseUrl;
    _c = TableCodesController(
      repository: services.backend.tableCodes,
      canIssue: session.can(Capability.issueTableCodes),
    );
    if (_canView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.load();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _restaurant(AppLocalizations l) =>
      _restaurantName ?? l.tableRestaurantFallback;

  /// What the picture's file name is built from: Latin, whatever language the
  /// words on the card are in ("table 12" -> test-kitchen-table-12-qr.png).
  // i18n-ignore: file name, not shown to anyone
  String _fileLabel(TableCode t) =>
      RegExp(r'^\d+$').hasMatch(t.label) ? 'table ${t.label}' : t.label;

  CodeCard _card(AppLocalizations l, TableCode t) => CodeCard(
    tableName: t.nameIn(l),
    restaurant: _restaurant(l),
    link: t.link(_baseUrl)!,
    scanLine: l.tableCardScan,
    fileLabel: _fileLabel(t),
  );

  Future<void> _printAll() async {
    final l = context.l10n;
    final cards = [for (final t in _c.printable) _card(l, t)];
    if (cards.isEmpty || _printing) return;
    setState(() => _printing = true);
    try {
      await widget.exporter.printSheet(
        l.tablePrintTitle(restaurant: _restaurant(l)),
        cards,
      );
    } on AppFailure catch (e) {
      if (mounted) showFailure(context, e);
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _save(TableCode t) async {
    final l = context.l10n;
    try {
      await widget.exporter.saveImage(_card(l, t));
      if (mounted) {
        showDone(context, l.tableImageSaved(table: t.nameIn(l)));
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _copy(TableCode t) async {
    final l = context.l10n;
    await Clipboard.setData(ClipboardData(text: t.link(_baseUrl)!));
    if (mounted) showDone(context, l.tableLinkCopied(table: t.nameIn(l)));
  }

  Future<void> _issue(TableCode t) async {
    final l = context.l10n;
    try {
      await _c.issue(t);
      if (mounted) {
        showDone(context, l.tableCodeIssued(table: t.nameIn(l)));
      }
    } on AppFailure catch (e) {
      if (!mounted) return;
      if (e.kind == FailureKind.notReady) {
        await showNotAvailableDialog(context, failureText(l, e));
      } else {
        showFailure(context, e);
      }
    }
  }

  Future<void> _replace(TableCode t) async {
    final l = context.l10n;
    final tokens = ViniiTokens.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: tokens.danger, size: 32),
        title: Text(l.tableReplaceTitle(table: t.nameIn(l))),
        content: Text(l.tableReplaceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.tableReplaceKeep),
          ),
          FilledButton(
            key: const Key('replace-code-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: tokens.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 48),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.tableReplaceConfirm),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      await _c.issue(t, replace: true);
      if (mounted) {
        showDone(context, l.tableCodeReplaced(table: t.nameIn(l)));
      }
    } on AppFailure catch (e) {
      if (!mounted) return;
      if (e.kind == FailureKind.notReady) {
        await showNotAvailableDialog(context, failureText(l, e));
      } else {
        showFailure(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tableScreenTitle),
        actions: [
          if (_canView)
            ListenableBuilder(
              listenable: _c,
              builder: (context, _) {
                if (_c.tables?.isNotEmpty != true) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  // A word and an icon when there is room beside the title;
                  // just the icon (the word becomes its tooltip) on a narrow
                  // phone or with large text, where the word would squeeze
                  // the title (Hindi is longer).
                  child: _printAllAction(context, l),
                );
              },
            ),
        ],
      ),
      body: ListenableBuilder(listenable: _c, builder: _body),
    );
  }

  Widget _printAllAction(BuildContext context, AppLocalizations l) {
    final onPressed = _c.printable.isEmpty || _printing ? null : _printAll;
    final icon = _printing
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          )
        : const Icon(Icons.print_outlined);
    double widthOf(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final theme = Theme.of(context);
    final word = widthOf(l.tablePrintAll, theme.textTheme.labelLarge);
    final title = widthOf(l.tableScreenTitle, theme.appBarTheme.titleTextStyle);
    final leading = Navigator.of(context).canPop() ? 56.0 : 16.0;
    // screen - leading - title - button (icon, gap, label, padding) - margins
    final room =
        MediaQuery.sizeOf(context).width - leading - title - word - 50 - 24;
    if (room < 0) {
      return Tooltip(
        message: l.tablePrintAll,
        child: TextButton(
          key: const Key('print-all'),
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.zero,
          ),
          child: Semantics(label: l.tablePrintAll, child: icon),
        ),
      );
    }
    return TextButton.icon(
      key: const Key('print-all'),
      onPressed: onPressed,
      icon: icon,
      label: Text(l.tablePrintAll),
    );
  }

  Widget _body(BuildContext context, Widget? _) {
    final l = context.l10n;
    if (!_canView) {
      return EmptyView(
        icon: Icons.lock_outline_rounded,
        title: l.tableBlockedTitle,
        message: l.tableBlockedMessage,
      );
    }
    final tables = _c.tables;
    if (tables == null) {
      if (_c.failure != null && !_c.loading) {
        return FailureView(
          failure: _c.failure!,
          onRetry: () => _c.load(force: true),
        );
      }
      return LoadingView(label: l.tableLoading);
    }
    if (tables.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _c.load(force: true),
        child: LayoutBuilder(
          builder: (context, box) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: box.maxHeight,
                child: EmptyView(
                  icon: Icons.table_restaurant_outlined,
                  title: l.tableEmptyTitle,
                  message: l.tableEmptyMessage,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final t = ViniiTokens.of(context);
    final text = Theme.of(context).textTheme;
    final groups = _c.groups;
    final showNames = groups.length > 1 || groups.first.name != null;
    return RefreshIndicator(
      onRefresh: () => _c.load(force: true),
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 12.0;
          final inner = box.maxWidth - 32;
          final columns = (inner / 380).floor().clamp(1, 3);
          final cardWidth = (inner - gap * (columns - 1)) / columns;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text(
                l.tableIntro(
                  withCode: _c.withCodes.length,
                  total: tables.length,
                ),
                style: text.bodyMedium,
              ),
              for (final g in groups) ...[
                if (showNames)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
                    child: Text(
                      l.tableGroupHeader(
                        name: g.name ?? l.posOtherTables,
                        count: g.tables.length,
                      ),
                      style: TextStyle(
                        color: t.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 12),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final table in g.tables)
                      SizedBox(
                        width: cardWidth,
                        child: _TableCard(
                          table: table,
                          link: table.link(_baseUrl),
                          busy: _c.busy.contains(table.id),
                          canIssue: _c.canIssue,
                          onPreview: () =>
                              context.push(Routes.guest(tableId: table.id)),
                          onCopy: () => _copy(table),
                          onSave: () => _save(table),
                          onIssue: () => _issue(table),
                          onReplace: () => _replace(table),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One table: its code, its name and what can be done with it. The three
/// everyday actions sit in a row of equal tiles under the code; replacing a
/// code is rare and destructive, so it is a quiet link beside the code, not a
/// fourth tile.
class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.link,
    required this.busy,
    required this.canIssue,
    required this.onPreview,
    required this.onCopy,
    required this.onSave,
    required this.onIssue,
    required this.onReplace,
  });

  final TableCode table;
  final String? link;
  final bool busy;
  final bool canIssue;
  final VoidCallback onPreview;
  final VoidCallback onCopy;
  final VoidCallback onSave;
  final VoidCallback onIssue;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = ViniiTokens.of(context);
    final hasCode = link != null;
    return Card(
      key: Key('table-${table.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TableCodeImage(table: table, link: link),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // A wrap, not a row: the "Not in use" chip drops under
                      // the name when both do not fit side by side.
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            table.nameIn(l),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: table.isActive ? t.ink : t.inkSecondary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (!table.isActive)
                            StatusChip(
                              label: l.tableNotInUse,
                              color: t.inkMuted,
                              icon: Icons.block_rounded,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.tableSeats(count: table.seats),
                        style: TextStyle(color: t.inkSecondary, fontSize: 13.5),
                      ),
                      const SizedBox(height: 6),
                      if (hasCode) ...[
                        Text(
                          link!.replaceFirst(RegExp(r'^https?://'), ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: t.inkMuted,
                            fontSize: 12.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (canIssue)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _ActionButton(
                              key: Key('replace-${table.id}'),
                              icon: Icons.refresh_rounded,
                              label: l.tableNewCode,
                              color: t.inkSecondary,
                              onPressed: busy ? null : onReplace,
                            ),
                          ),
                      ] else ...[
                        Text(
                          l.tableNoCode,
                          key: Key('no-code-${table.id}'),
                          style: TextStyle(
                            color: t.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (canIssue)
                          FilledButton.tonal(
                            key: Key('issue-${table.id}'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            onPressed: busy ? null : onIssue,
                            child: busy
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : Text(l.tableIssueCode),
                          )
                        else
                          Text(
                            l.tableIssueHint,
                            style: TextStyle(
                              color: t.inkSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (hasCode) ...[
              const SizedBox(height: 12),
              // The tiles share one height: a label that wraps to a third line
              // in Hindi makes all three taller instead of being cut off.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (table.isActive) ...[
                      Expanded(
                        child: _TileAction(
                          key: Key('preview-${table.id}'),
                          icon: Icons.phone_iphone_rounded,
                          label: l.commonPreview,
                          onPressed: onPreview,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _TileAction(
                        key: Key('copy-${table.id}'),
                        icon: Icons.link_rounded,
                        label: l.tableCopyLink,
                        onPressed: onCopy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TileAction(
                        key: Key('save-${table.id}'),
                        icon: Icons.download_rounded,
                        label: l.tableSaveImage,
                        onPressed: onSave,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The code itself on white (a code must be dark on light to scan, in light
/// and dark mode alike), or a blank place where it will be.
class TableCodeImage extends StatelessWidget {
  const TableCodeImage({
    super.key,
    required this.table,
    required this.link,
    this.size = 104,
  });

  final double size;

  final TableCode table;
  final String? link;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final qrLabel = l.tableQrSemantics(table: table.nameIn(l));
    if (link == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: t.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        child: Icon(Icons.qr_code_2_rounded, size: 44, color: t.inkMuted),
      );
    }
    return Semantics(
      label: qrLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        child: QrImageView(
          data: link!,
          version: QrVersions.auto,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          padding: const EdgeInsets.all(6),
          backgroundColor: Colors.white,
          gapless: true,
          semanticsLabel: qrLabel,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: color,
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: kScriptFontFallback,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// An everyday action as a tall tile: the icon above its words.
class _TileAction extends StatelessWidget {
  const _TileAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Material(
          color: t.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: t.ink),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: t.ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
