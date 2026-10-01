import 'package:flutter/material.dart';

import '../theme/staff_theme.dart';

/// A setting you switch ON or OFF: the whole row is the target, the state is
/// a word as well as a colour, and the title says what the switch does.
class SettingSwitchRow extends StatelessWidget {
  const SettingSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;

  /// Null makes the row read-only.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final enabled = onChanged != null;
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        child: InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: enabled ? t.ink : t.inkSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: t.inkSecondary,
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 30,
                    child: Text(
                      value ? 'ON' : 'OFF',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: value ? t.success : t.inkSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Transform.scale(
                    scale: 1.2,
                    child: Switch(value: value, onChanged: onChanged),
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

/// The house style for one-of-several choices: tall enough for a thumb, the
/// chosen one filled with ink. Null [onChanged] makes it read-only.
class ChoiceSegments<T> extends StatelessWidget {
  const ChoiceSegments({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// Value and its label, in order.
  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final readOnly = onChanged == null;
    // A read-only choice keeps its look, so the value in force can be read;
    // it just does not respond.
    return SizedBox(
      width: double.infinity,
      child: IgnorePointer(
        ignoring: readOnly,
        child: Opacity(
          opacity: readOnly ? 0.78 : 1,
          child: SegmentedButton<T>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: [
              for (final (value, label) in options)
                ButtonSegment<T>(
                  value: value,
                  label: Text(label, maxLines: 1, softWrap: false),
                ),
            ],
            selected: {?selected},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) onChanged?.call(s.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: t.ink,
              selectedForegroundColor: t.page,
              foregroundColor: t.ink,
              backgroundColor: t.surface,
              disabledForegroundColor: t.inkMuted,
              disabledBackgroundColor: t.surfaceMuted,
              side: BorderSide(color: t.border),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 48),
              textStyle: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
