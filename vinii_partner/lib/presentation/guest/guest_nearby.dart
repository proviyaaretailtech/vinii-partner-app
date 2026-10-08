import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../application/guest_nearby.dart';
import '../../application/guest_session.dart';
import '../../application/guest_social.dart';
import '../../domain/guest_catalog.dart';
import '../../l10n/l10n.dart';
import '../theme/guest_theme.dart';
import '../widgets/food_art.dart';
import 'guest_flow.dart';
import 'guest_widgets.dart';
import 'look/look.dart';
import 'look/motion.dart';

/// Wraps a guest page and floats the nearby-order alert near its top
/// ("Table 7 just ordered Chicken Biryani — Add"). With no feed (the
/// restaurant's server shares nothing) it is just [child].
///
/// The alert is one compact card: the dish's picture, who ordered it, and an
/// Add button that puts one portion in this guest's own order. It never
/// blocks the page: only the card itself takes taps, and the guest can close
/// it at any time. The session owns the feed, so this widget starts it and
/// stops nothing.
class NearbyAlertHost extends StatefulWidget {
  const NearbyAlertHost({
    super.key,
    required this.child,
    this.topOffset = 58,
    this.endInset = 0,
  });
  final Widget child;

  /// How far below the top of the page the alert floats, to clear the page's
  /// own header.
  final double topOffset;

  /// Width at the right edge that the page keeps for something else, such as
  /// the live order beside the deck on a wide screen. The card is centred in
  /// what is left, so it sits over the page's main column and not over the
  /// gap beside it. Ignored when it would leave too little room.
  final double endInset;

  @override
  State<NearbyAlertHost> createState() => _NearbyAlertHostState();
}

class _NearbyAlertHostState extends State<NearbyAlertHost> {
  /// How long "Added" stays on the button before the card leaves.
  static const _addedFor = Duration(milliseconds: 1000);

  NearbyFeed? _started;

  /// The alert whose dish was just added. The feed has already closed it; the
  /// card stays a moment longer so the guest sees it worked.
  NearbyOrder? _confirming;
  Timer? _confirmTimer;

  GuestSession? _session(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GuestScope>()?.notifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final feed = _session(context)?.nearbyFeed;
    if (feed == null || identical(feed, _started)) return;
    _started = feed;
    // After the frame, so a feed that answers at once never changes state in
    // the middle of a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) feed.start();
    });
  }

  @override
  void dispose() {
    _confirmTimer?.cancel();
    super.dispose();
  }

  void _add(NearbyFeed feed, NearbyOrder order, GuestItem item) {
    if (_confirming?.id == order.id) return;
    addWithHaptic(context, item);
    _confirmTimer?.cancel();
    _confirmTimer = Timer(_addedFor, () {
      if (mounted) setState(() => _confirming = null);
    });
    setState(() => _confirming = order);
    if (feed.current?.id == order.id) feed.added();
  }

  void _dismiss(NearbyFeed feed, NearbyOrder order) {
    _confirmTimer?.cancel();
    if (_confirming != null) setState(() => _confirming = null);
    if (feed.current?.id == order.id) feed.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session(context);
    final feed = session?.nearbyFeed;
    if (session == null || feed == null) return widget.child;
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: ListenableBuilder(
            listenable: feed,
            builder: (context, _) => _overlay(context, session, feed),
          ),
        ),
      ],
    );
  }

  Widget _overlay(BuildContext context, GuestSession session, NearbyFeed feed) {
    final order = feed.current ?? _confirming;
    final item = order == null ? null : session.catalog.item(order.itemId);
    final reduced = reducedMotion(context);
    final Widget card;
    if (order == null || item == null) {
      card = const SizedBox.shrink(key: ValueKey('nearby-none'));
    } else {
      final who = order.who.trim();
      card = KeyedSubtree(
        key: ValueKey('nearby-${order.id}'),
        child: _AlertCard(
          key: const ValueKey('nearby-alert'),
          who: who.isEmpty ? context.l10n.guestNearbyTableNearYou : who,
          name: item.item.name,
          qty: order.qty,
          imageUrl: item.item.imageUrl,
          added: _confirming?.id == order.id,
          addLabel:
              GuestCopy.of(context).own('menu.add') ?? context.l10n.commonAdd,
          onOpen: () => unawaited(GuestFlow.openItem(context, item)),
          onAdd: () => _add(feed, order, item),
          onDismiss: () => _dismiss(feed, order),
        ),
      );
    }
    final inset = MediaQuery.sizeOf(context).width - widget.endInset >= 360
        ? widget.endInset
        : 0.0;
    // Only the card is a hit target: everything around it is empty space the
    // page underneath still receives taps through.
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(right: inset),
        child: GuestColumn(
          fill: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, widget.topOffset, 20, 0),
            child: AnimatedSwitcher(
              duration: reduced ? GuestMotion.fast : GuestMotion.base,
              reverseDuration: GuestMotion.fast,
              switchInCurve: GuestMotion.arrive,
              // The exit runs the animation backwards, so the curve is flipped
              // to make it start slowly and finish quickly.
              switchOutCurve: GuestMotion.depart.flipped,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, animation) {
                final fade = FadeTransition(
                  opacity: animation,
                  // The live region must exist from the first frame, not only
                  // once it is visible, or it would not be announced.
                  alwaysIncludeSemantics: true,
                  child: child,
                );
                if (reduced) return fade;
                return SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -0.35),
                    end: Offset.zero,
                  ).animate(animation),
                  child: fade,
                );
              },
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}

/// The alert itself: picture, two lines of words, Add, and close.
class _AlertCard extends StatelessWidget {
  const _AlertCard({
    super.key,
    required this.who,
    required this.name,
    required this.qty,
    required this.imageUrl,
    required this.added,
    required this.addLabel,
    required this.onOpen,
    required this.onAdd,
    required this.onDismiss,
  });

  final String who;
  final String name;
  final int qty;
  final String? imageUrl;
  final bool added;
  final String addLabel;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final l = context.l10n;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: p.hairline),
    );
    final dish = _Dish(
      who: who,
      name: name,
      qty: qty,
      imageUrl: imageUrl,
      onOpen: onOpen,
    );
    final addButton = _AddButton(label: addLabel, added: added, onTap: onAdd);
    final closeButton = _CloseButton(onTap: onDismiss);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: added
          ? l.guestNearbyAddedLabel(name: name)
          : l.guestNearbyOrderedLabel(who: who, name: name, qty: qty),
      hint: l.guestNearbyOpenHint,
      onTap: onOpen,
      customSemanticsActions: {
        CustomSemanticsAction(label: l.guestNearbyAddToOrder): onAdd,
        CustomSemanticsAction(label: l.guestNearbyDismiss): onDismiss,
      },
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          color: p.surfaceLit,
          shadows: p.lift(0.7),
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
            child: LayoutBuilder(
              builder: (context, box) {
                // On a narrow phone, or with large text, the words would be
                // squeezed to a few letters: Add moves under them instead.
                final stacked =
                    box.maxWidth < 290 ||
                    MediaQuery.textScalerOf(context).scale(15) > 18;
                if (!stacked) {
                  return Row(
                    children: [
                      Expanded(child: dish),
                      const SizedBox(width: 8),
                      addButton,
                      closeButton,
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: dish),
                        closeButton,
                      ],
                    ),
                    // Under the words, not under the picture.
                    Padding(
                      padding: const EdgeInsets.only(left: _Dish.picture + 12),
                      child: addButton,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The dish's picture and who ordered it; tapping it opens the dish.
class _Dish extends StatelessWidget {
  const _Dish({
    required this.who,
    required this.name,
    required this.qty,
    required this.imageUrl,
    required this.onOpen,
  });

  /// The picture's side, in logical pixels.
  static const picture = 44.0;

  final String who;
  final String name;
  final int qty;
  final String? imageUrl;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final l = context.l10n;
    return InkWell(
      key: const ValueKey('nearby-open'),
      borderRadius: BorderRadius.circular(14),
      excludeFromSemantics: true,
      onTap: onOpen,
      // The words are said once, by the card's own label.
      child: ExcludeSemantics(
        child: Row(
          children: [
            SizedBox.square(
              dimension: picture,
              child: FoodArt(
                name: name,
                imageUrl: imageUrl,
                radius: 14,
                animate: false,
                dishScale: 0.9,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.guestNearbyJustOrdered(who: who),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: p.body(12.5, color: p.inkMuted),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: name),
                        // A no-break space keeps "×2" with the last word, so
                        // it never lands on a line of its own.
                        if (qty > 1)
                          TextSpan(
                            text: ' ×$qty',
                            style: const TextStyle(
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: p.body(15, weight: FontWeight.w700),
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

/// "Add" in the storefront's own button shape and style; "Added" for a moment
/// once it has been tapped. Both are 44px high and the same width, so the
/// words beside it do not move.
class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.label,
    required this.added,
    required this.onTap,
  });

  final String label;
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final l = context.l10n;
    final Color fill;
    final Color ink;
    BorderSide side = BorderSide.none;
    if (added) {
      fill = p.success.withValues(alpha: p.isDark ? 0.2 : 0.16);
      ink = p.readable(p.success);
    } else if (p.buttonOutline) {
      fill = Colors.transparent;
      ink = p.readable(p.accent);
      side = BorderSide(color: p.accent, width: 1.6);
    } else {
      fill = p.accent;
      ink = p.onAccent;
    }
    final shape = p.buttonShape(side);
    return Pressable(
      scale: 0.96,
      child: Semantics(
        button: true,
        enabled: !added,
        label: added ? l.guestNearbyAdded : label,
        onTap: added ? null : onTap,
        excludeSemantics: true,
        child: Material(
          key: const ValueKey('nearby-add'),
          color: fill,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onTap: added ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    added ? l.guestNearbyAdded : label,
                    textAlign: TextAlign.center,
                    style: p.body(14, weight: FontWeight.w800, color: ink),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final l = context.l10n;
    return Tooltip(
      message: l.guestNearbyDismiss,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: l.guestNearbyDismiss,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('nearby-close'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(Icons.close_rounded, size: 20, color: p.inkMuted),
          ),
        ),
      ),
    );
  }
}
