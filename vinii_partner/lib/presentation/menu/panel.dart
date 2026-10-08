import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/staff_theme.dart';

/// Small building blocks shared by the Menu and Studio screens, so both
/// read as one product: uppercase section labels above white cards with a
/// hairline border, the house style of the More tab.
class PanelLabel extends StatelessWidget {
  const PanelLabel(this.text, {super.key, this.trailing, this.top = 20});

  final String text;
  final Widget? trailing;

  /// Space above the label; the first label on a screen passes less.
  final double top;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A bordered card. [padding] null means the children lay out edge to edge
/// (list tiles with dividers); otherwise the card pads its content.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: padding == null
          ? column
          : Padding(padding: padding!, child: column),
    );
  }
}

/// A title and a one-line explanation at the top of a panel.
class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: text.bodySmall?.copyWith(height: 1.35)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

/// A hairline between rows inside a [Panel].
class PanelDivider extends StatelessWidget {
  const PanelDivider({super.key, this.indent = 16});
  final double indent;

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    indent: indent,
    color: ViniiTokens.of(context).border,
  );
}

/// A rounded icon on a soft tint of [color]: the leading mark of Studio
/// sections and menu callouts.
class TintIcon extends StatelessWidget {
  const TintIcon(this.icon, {super.key, this.color, this.size = 40});
  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final c = color ?? t.ink;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.tint(c),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.5, color: c),
    );
  }
}

/// Asks "leave without saving?" and returns true to leave. [title] and
/// [message] default to the standard wording in the reader's language; a
/// caller that passes its own must pass an already-translated sentence.
Future<bool> confirmDiscard(
  BuildContext context, {
  String? title,
  String? message,
}) async {
  final t = ViniiTokens.of(context);
  final l = context.l10n;
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title ?? l.menuDiscardTitle),
      content: Text(message ?? l.menuDiscardMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.menuKeepEditing),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: t.danger),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.menuDiscard),
        ),
      ],
    ),
  );
  return leave ?? false;
}
