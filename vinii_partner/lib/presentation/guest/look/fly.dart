import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/guest_theme.dart';
import 'motion.dart';

/// Flies a small chip (a price, a count) along an arc from one place on
/// screen to another, then removes itself. Used when a dish is added: the
/// price leaves the card and lands in the budget, so the guest sees what
/// their choice cost where it counts.
///
/// [from] and [to] are global coordinates. Completes when the chip lands;
/// completes at once under reduced motion or if there is no overlay. Callers
/// must never depend on it for correctness: it is only the picture of a
/// change that has already happened.
Future<void> flyChip(
  BuildContext context, {
  required Offset from,
  required Offset to,
  required String label,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null || reducedMotion(context)) return Future.value();
  final landed = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _FlyingChip(
      from: from,
      to: to,
      label: label,
      onLanded: () {
        entry.remove();
        if (!landed.isCompleted) landed.complete();
      },
    ),
  );
  overlay.insert(entry);
  return landed.future;
}

class _FlyingChip extends StatefulWidget {
  const _FlyingChip({
    required this.from,
    required this.to,
    required this.label,
    required this.onLanded,
  });

  final Offset from;
  final Offset to;
  final String label;
  final VoidCallback onLanded;

  @override
  State<_FlyingChip> createState() => _FlyingChipState();
}

class _FlyingChipState extends State<_FlyingChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 560),
        )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onLanded();
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    // Global to the overlay's own space.
    final box = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final from = box?.globalToLocal(widget.from) ?? widget.from;
    final to = box?.globalToLocal(widget.to) ?? widget.to;
    final ctrl = Offset((from.dx + to.dx) / 2 + 36, to.dy - 70);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_c.value);
          final u = 1 - t;
          final pos = from * (u * u) + ctrl * (2 * u * t) + to * (t * t);
          final scale = 1 - 0.38 * t;
          final fade = _c.value > 0.82 ? (1 - _c.value) / 0.18 : 1.0;
          return Stack(
            children: [
              Positioned(
                left: pos.dx,
                top: pos.dy,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: Opacity(
                    opacity: fade.clamp(0, 1),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: p.accent,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.label,
                          style: p.price(15, color: p.onAccent),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
