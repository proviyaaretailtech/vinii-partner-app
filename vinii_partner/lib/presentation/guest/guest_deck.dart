import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../domain/guest_catalog.dart';
import '../theme/guest_theme.dart';
import '../widgets/chips.dart';
import '../widgets/food_art.dart';
import 'guest_effects.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';

/// Board 1 #4–#5, Board 2 #6 & #15: the swipe deck. Right (or the green ♥)
/// adds one to the order, left (or the red ✕) skips, up opens the details.
/// Cards already swiped stay out of the deck for this visit.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({super.key, required this.items, required this.categoryName});

  final List<GuestItem> items;
  final String categoryName;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this)
    ..addListener(() => setState(() {}));
  Animation<Offset>? _flight;
  Offset _drag = Offset.zero;
  Size _size = const Size(320, 480);
  String? _toast;
  Timer? _toastTimer;

  Offset get _offset => _flight?.value ?? _drag;
  bool get _busy => _anim.isAnimating;

  @override
  void dispose() {
    _toastTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _animateTo(Offset end, Curve curve, int ms) {
    _flight = Tween(
      begin: _offset,
      end: end,
    ).animate(CurvedAnimation(parent: _anim, curve: curve));
    _anim.duration = Duration(milliseconds: ms);
    return _anim.forward(from: 0);
  }

  Future<void> _springBack() async {
    await _animateTo(Offset.zero, Curves.elasticOut, 650);
    if (!mounted) return;
    setState(() {
      _drag = Offset.zero;
      _flight = null;
    });
  }

  Future<void> _decide(GuestItem item, {required bool add}) async {
    if (_busy) return;
    final s = GuestScope.read(context);
    if (add) {
      addWithHaptic(context, item);
      _showToast('Added · ${item.item.name}');
    }
    await _animateTo(
      Offset((add ? 1 : -1) * _size.width * 1.6, _offset.dy + 80),
      Curves.easeInCubic,
      300,
    );
    if (!mounted) return;
    s.markSeen(item.item.id, skippedIt: !add);
    setState(() {
      _drag = Offset.zero;
      _flight = null;
    });
  }

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _panEnd(DragEndDetails d, GuestItem top) {
    final v = d.velocity.pixelsPerSecond;
    if (_drag.dx > _size.width * 0.28 || v.dx > 900) {
      unawaited(_decide(top, add: true));
    } else if (_drag.dx < -_size.width * 0.28 || v.dx < -900) {
      unawaited(_decide(top, add: false));
    } else if (_drag.dy < -_size.height * 0.16 || v.dy < -900) {
      unawaited(_springBack());
      unawaited(GuestFlow.openItem(context, top));
    } else {
      unawaited(_springBack());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final left = [
      for (final i in widget.items)
        if (!s.seen.contains(i.item.id)) i,
    ];
    if (left.isEmpty) {
      return _EndOfDeck(items: widget.items, categoryName: widget.categoryName);
    }
    final artisan = p.scriptFamily != null;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: LayoutBuilder(
              builder: (context, c) {
                _size = c.biggest;
                final progress = (_offset.dx.abs() / (_size.width * 0.4)).clamp(
                  0.0,
                  1.0,
                );
                final shown = left.take(3).toList();
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = shown.length - 1; i >= 0; i--)
                      i == 0 ? _top(shown[0]) : _back(shown[i], i, progress),
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _toast == null
                              ? const SizedBox.shrink()
                              : _Toast(key: ValueKey(_toast), text: _toast!),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        artisan
            ? Text('Swipe right to add', style: p.hero(20, color: p.inkMuted))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 18, color: p.danger),
                  const SizedBox(width: 8),
                  Text(
                    'Swipe right to add',
                    style: p.body(13.5, weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: p.accent),
                ],
              ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BigButton(
              key: const ValueKey('deck-skip'),
              icon: Icons.close_rounded,
              color: p.danger,
              tooltip: 'Skip',
              onTap: () => _decide(left.first, add: false),
            ),
            const SizedBox(width: 22),
            RoundIcon(
              icon: Icons.keyboard_arrow_up_rounded,
              size: 46,
              tooltip: 'Details',
              onTap: () => GuestFlow.openItem(context, left.first),
            ),
            const SizedBox(width: 22),
            _BigButton(
              key: const ValueKey('deck-add'),
              icon: Icons.favorite_rounded,
              color: p.success,
              tooltip: 'Add to order',
              onTap: () => _decide(left.first, add: true),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _top(GuestItem item) {
    final o = _offset;
    final angle = o.dx / _size.width * 0.35;
    return Positioned.fill(
      key: ValueKey('deck-card-${item.item.id}'),
      child: GestureDetector(
        onTap: () => GuestFlow.openItem(context, item),
        onPanUpdate: _busy ? null : (d) => setState(() => _drag += d.delta),
        onPanEnd: _busy ? null : (d) => _panEnd(d, item),
        child: Transform.translate(
          offset: o,
          child: Transform.rotate(
            angle: angle,
            alignment: const Alignment(0, 0.9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DishCard(item: item),
                if (o.dx.abs() > 16)
                  _Stamp(
                    add: o.dx > 0,
                    strength: (o.dx.abs() / 110).clamp(0, 1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _back(GuestItem item, int depth, double progress) {
    final d = depth - progress;
    return Positioned.fill(
      key: ValueKey('deck-card-${item.item.id}'),
      child: IgnorePointer(
        child: Transform.translate(
          offset: Offset(0, 18 * d),
          child: Transform.rotate(
            angle: (depth.isOdd ? -0.045 : 0.05) * d,
            child: Transform.scale(
              scale: 1 - 0.06 * d,
              child: Opacity(
                opacity: (1 - 0.25 * d).clamp(0, 1),
                child: DishCard(item: item, interactive: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One dish, full-bleed: photo, like heart, name, big price and tag pills
/// over a gradient scrim.
class DishCard extends StatelessWidget {
  const DishCard({super.key, required this.item, this.interactive = true});
  final GuestItem item;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final i = item.item;
    final qty = s.qtyOf(i.id);
    final liked = s.liked.contains(i.id);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.5 : 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FoodArt(name: i.name, imageUrl: i.imageUrl, radius: 0),
            const PhotoScrim(strength: 0.92, top: true),
            Positioned(
              top: 14,
              left: 14,
              child: Row(
                children: [
                  FoodTypeMark(i.foodType, size: 16),
                  if (qty > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: p.success,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'In order ×$qty',
                        style: p.body(
                          12,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (s.features.likes)
              Positioned(
                top: 10,
                right: 10,
                child: RoundIcon(
                  icon: liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: liked ? p.danger : Colors.white,
                  background: Colors.black.withValues(alpha: 0.35),
                  tooltip: liked ? 'Saved for later' : 'Save for later',
                  onTap: interactive ? () => s.toggleLike(i.id) : null,
                ),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in item.tags.take(3))
                          TagChip(t, onImage: true),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    i.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: p.display(28, color: Colors.white),
                  ),
                  if ((i.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      i.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: p.body(
                        13.5,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        rupees(i.price),
                        style: p.price(26, color: Colors.white),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.keyboard_double_arrow_up_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      Text(
                        ' Details',
                        style: p.body(
                          12.5,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.add, required this.strength});
  final bool add;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final c = add ? p.success : p.danger;
    return Align(
      alignment: add
          ? const Alignment(-0.8, -0.75)
          : const Alignment(0.8, -0.75),
      child: Opacity(
        opacity: strength,
        child: Transform.rotate(
          angle: add ? -0.25 : 0.25,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: c, width: 3.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              add ? 'ADD' : 'SKIP',
              style: p.display(28, color: c).copyWith(letterSpacing: 3),
            ),
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: color.withValues(alpha: 0.5),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 66,
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    ),
  );
}

class _Toast extends StatelessWidget {
  const _Toast({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: p.success,
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: p.body(13, weight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// "You've seen every dish in Mains" — with a way back into the deck.
class _EndOfDeck extends StatelessWidget {
  const _EndOfDeck({required this.items, required this.categoryName});
  final List<GuestItem> items;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              "You've seen every dish in $categoryName",
              textAlign: TextAlign.center,
              style: p.display(24),
            ),
            const SizedBox(height: 8),
            Text(
              s.lines.isEmpty
                  ? 'Go round again, or try another category.'
                  : '${s.itemCount} in your order so far.',
              textAlign: TextAlign.center,
              style: p.body(14.5, color: p.inkMuted),
            ),
            const SizedBox(height: 24),
            if (s.lines.isNotEmpty) ...[
              GuestButton(
                label: 'View order (${s.itemCount})',
                trailingArrow: true,
                onTap: () => GuestFlow.toOrder(context),
              ),
              const SizedBox(height: 12),
            ],
            GuestButton(
              label: 'Start over',
              icon: Icons.replay_rounded,
              style: GuestButtonStyle.outline,
              onTap: () => s.resetSeen(items.map((i) => i.item.id)),
            ),
          ],
        ),
      ),
    );
  }
}
