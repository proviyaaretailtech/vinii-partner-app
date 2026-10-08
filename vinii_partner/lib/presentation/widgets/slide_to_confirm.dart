import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../theme/staff_theme.dart';

/// "Slide to mark delivered" — for steps that cannot be undone (partner PRD
/// UI rules). A tap is not enough; the thumb must travel to the end.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.color,
    this.busy = false,
    this.enabled = true,
  });

  final String label;

  /// Called once the thumb reaches the end. The widget shows a spinner while
  /// [busy] and springs back if the future throws.
  final Future<void> Function() onConfirmed;
  final Color? color;
  final bool busy;
  final bool enabled;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with SingleTickerProviderStateMixin {
  double _drag = 0;
  bool _working = false;
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..addListener(() => setState(() => _drag = _from * (1 - _spring.value)));
  double _from = 0;

  static const _height = 60.0;
  static const _thumb = 52.0;

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  Future<void> _release(double max) async {
    if (_drag >= max * 0.92) {
      setState(() {
        _drag = max;
        _working = true;
      });
      await HapticFeedback.mediumImpact();
      try {
        await widget.onConfirmed();
      } finally {
        if (mounted) {
          _working = false;
          _springBack();
        }
      }
    } else {
      _springBack();
    }
  }

  void _springBack() {
    _from = _drag;
    _spring.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final color = widget.color ?? t.accent;
    final on = onColor(color);
    final busy = widget.busy || _working;
    return LayoutBuilder(
      builder: (context, c) {
        final max = c.maxWidth - _thumb - 8;
        final progress = max <= 0 ? 0.0 : (_drag / max).clamp(0.0, 1.0);
        return Semantics(
          button: true,
          label: widget.label,
          onTap: widget.enabled && !busy ? () => widget.onConfirmed() : null,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.45,
            child: Container(
              height: _height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(_height / 2),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Center(
                    child: Opacity(
                      opacity: 1 - progress,
                      // Room for the thumb on both sides, so a long label (or
                      // a longer language) wraps instead of hiding under it.
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _thumb + 8,
                        ),
                        child: Text(
                          busy ? context.l10n.uiSending : widget.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: on,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4 + _drag,
                    child: GestureDetector(
                      onHorizontalDragUpdate: !widget.enabled || busy
                          ? null
                          : (d) => setState(
                              () => _drag = (_drag + d.delta.dx).clamp(0, max),
                            ),
                      onHorizontalDragEnd: !widget.enabled || busy
                          ? null
                          : (_) => _release(max),
                      child: Container(
                        width: _thumb,
                        height: _thumb,
                        decoration: BoxDecoration(
                          color: on,
                          shape: BoxShape.circle,
                        ),
                        child: busy
                            ? Padding(
                                padding: const EdgeInsets.all(15),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: color,
                                ),
                              )
                            : Icon(Icons.arrow_forward_rounded, color: color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
