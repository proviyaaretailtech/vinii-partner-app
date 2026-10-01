import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The guest runtime's motion vocabulary, in one place so the whole surface
/// moves as one thing.
///
/// Arrivals ease out with an exponential curve (fast start, long soft stop);
/// only physical moments (a card released after a swipe, the success check)
/// use a spring. Everything honours the device's reduced-motion setting: the
/// state change still happens, it just stops travelling.
class GuestMotion {
  const GuestMotion._();

  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 460);
  static const hero = Duration(milliseconds: 760);

  /// cubic-bezier(0.16, 1, 0.3, 1): confident arrivals.
  static const arrive = Cubic(0.16, 1, 0.3, 1);

  /// Exits are quicker than entrances so nothing ever feels like waiting.
  static const depart = Cubic(0.7, 0, 0.84, 0);

  /// The most a stagger may add, however long the list.
  static const maxStagger = Duration(milliseconds: 270);

  /// How far one list position pushes the next one's start.
  static const staggerStep = Duration(milliseconds: 45);
}

/// True when the device asks for less motion. Decorative loops stop and
/// travel is replaced by an instant (or fade-only) change.
bool reducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Fades and lifts its child into place once, when first built.
///
/// [index] staggers siblings (capped, so a long list never makes anyone wait);
/// [delay] adds a deliberate pause for a focal sequence. No timers: one
/// controller, one interval.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.dy = 14,
    this.dx = 0,
    this.duration = GuestMotion.slow,
    this.scaleFrom = 1,
  });

  final Widget child;
  final int index;
  final Duration delay;

  /// Starting offset in logical pixels (positive = starts lower / to the right).
  final double dy;
  final double dx;
  final Duration duration;

  /// Starting scale; 1 means no scale.
  final double scaleFrom;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _curve;

  Duration get _lead {
    final stagger = GuestMotion.staggerStep * widget.index;
    final capped = stagger > GuestMotion.maxStagger
        ? GuestMotion.maxStagger
        : stagger;
    return widget.delay + capped;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final total = _lead + widget.duration;
    final c = AnimationController(vsync: this, duration: total);
    _c = c;
    _curve = CurvedAnimation(
      parent: c,
      curve: Interval(
        _lead.inMilliseconds / total.inMilliseconds,
        1,
        curve: GuestMotion.arrive,
      ),
    );
    if (reducedMotion(context)) {
      c.value = 1;
    } else {
      c.forward();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = _curve;
    if (curve == null) return widget.child;
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (context, child) {
        final v = curve.value;
        Widget out = Opacity(opacity: v.clamp(0, 1), child: child);
        if (widget.dy != 0 || widget.dx != 0) {
          out = Transform.translate(
            offset: Offset(widget.dx * (1 - v), widget.dy * (1 - v)),
            child: out,
          );
        }
        if (widget.scaleFrom != 1) {
          out = Transform.scale(
            scale: widget.scaleFrom + (1 - widget.scaleFrom) * v,
            child: out,
          );
        }
        return out;
      },
    );
  }
}

/// A number that counts to its new value instead of jumping, so totals,
/// budgets and prices feel alive when they change. [from] counts up from a
/// starting value on first build (for example 0 on a success screen); without
/// it the first build shows the value at once.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.from,
    this.duration = GuestMotion.hero,
    this.textAlign,
  });

  final num value;
  final String Function(num value) format;
  final TextStyle? style;
  final num? from;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) {
      return Text(format(value), style: style, textAlign: textAlign);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: from?.toDouble(), end: value.toDouble()),
      duration: duration,
      curve: GuestMotion.arrive,
      builder: (context, v, _) =>
          Text(format(v), style: style, textAlign: textAlign),
    );
  }
}

/// Presses in: scales to 0.97 while a finger or pointer is down, and gives a
/// light haptic on release. Uses raw pointer events, so it never competes
/// with the child's own tap handling.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.97,
    this.hoverScale = 1,
    this.haptic = false,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  /// How far it grows under a mouse pointer (1 for not at all). Only
  /// pointer devices ever see it; a finger has no hover.
  final double hoverScale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hover = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  void _over(bool v) {
    if (widget.hoverScale != 1 && _hover != v && mounted) {
      setState(() => _hover = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || reducedMotion(context)) return widget.child;
    return MouseRegion(
      onEnter: (_) => _over(true),
      onExit: (_) => _over(false),
      child: Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) {
          _set(false);
          if (widget.haptic) HapticFeedback.selectionClick();
        },
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down ? widget.scale : (_hover ? widget.hoverScale : 1),
          duration: GuestMotion.fast,
          curve: GuestMotion.arrive,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Reveals [child] from left to right as if it were being written, once.
/// For a handwritten headline: a soft-edged wipe follows the line of text.
/// Under reduced motion the text is simply there.
class WriteOn extends StatefulWidget {
  const WriteOn({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 400),
    this.duration = const Duration(milliseconds: 1500),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<WriteOn> createState() => _WriteOnState();
}

class _WriteOnState extends State<WriteOn> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final total = widget.delay + widget.duration;
    final c = AnimationController(vsync: this, duration: total);
    _c = c;
    _t = CurvedAnimation(
      parent: c,
      curve: Interval(
        widget.delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: Curves.easeInOutCubic,
      ),
    );
    if (reducedMotion(context)) {
      c.value = 1;
    } else {
      c.forward();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return widget.child;
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (context, child) {
        final v = t.value;
        if (v >= 1) return child!;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            // A soft edge 18% wide travels from just before the first letter
            // to just past the last.
            final edge = -0.18 + v * 1.36;
            return LinearGradient(
              colors: const [Colors.white, Colors.white, Colors.transparent],
              stops: [0, edge.clamp(0.0, 1.0), (edge + 0.18).clamp(0.0, 1.0)],
            ).createShader(rect);
          },
          child: child,
        );
      },
    );
  }
}

/// A short scale pop each time [trigger] changes: the beat a budget gives
/// when a dish's price lands in it. Nothing happens under reduced motion.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.trigger, required this.child});
  final ValueNotifier<int> trigger;
  final Widget child;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_go);
  }

  void _go() {
    if (!mounted || reducedMotion(context)) return;
    _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      old.trigger.removeListener(_go);
      widget.trigger.addListener(_go);
    }
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_go);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      // Up fast, back softly: 1 -> 1.045 -> 1.
      final t = _c.value;
      final bump = t < 0.35 ? t / 0.35 : 1 - (t - 0.35) / 0.65;
      return Transform.scale(
        scale: 1 + 0.045 * Curves.easeOut.transform(bump.clamp(0, 1)),
        child: child,
      );
    },
  );
}
