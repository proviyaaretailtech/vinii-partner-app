import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/guest_similar.dart';
import '../../core/money.dart';
import '../../domain/guest_catalog.dart';
import '../../domain/menu.dart';
import '../../domain/storefront.dart';
import '../theme/guest_theme.dart';
import '../widgets/food_art.dart';
import 'guest_widgets.dart';
import 'look/look.dart';
import 'look/motion.dart';

/// "Tables like yours": a row of cards, one per recent order at a table with a
/// similar party, for the categories screen and the empty order. A card is a
/// few round pictures of the dishes, who it was and what it came to; no names.
/// Touching or holding it opens [showSimilarTableSheet] to see the whole order
/// and take all or some of it; a mouse resting on it shows what is in it.
///
/// Shows nothing at all when the restaurant's server shares nothing (no
/// source, no tables, or the party is not dining in): it never invents
/// activity. It asks for the tables once when it first appears, and again if
/// the party size changes.
class SimilarTablesStrip extends StatefulWidget {
  const SimilarTablesStrip({super.key, this.compact = false});

  /// A smaller version for the empty order page: the cards without a heading.
  final bool compact;

  @override
  State<SimilarTablesStrip> createState() => _SimilarTablesStripState();
}

class _SimilarTablesStripState extends State<SimilarTablesStrip> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = GuestScope.of(context);
    final similar = s.similar;
    if (similar == null || s.mode != GuestServiceMode.dineIn) return;
    final party = s.partySize;
    // The first time this page is built, when the party size changed, and
    // (quietly, on the next change to the order) when the tables have grown
    // old: SimilarTables itself says when a load is due.
    if (!similar.needsLoad(party)) return;
    // After the frame: loading tells its listeners, which may be this very
    // page, and a build is no time for that.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(similar.load(partySize: party));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = GuestScope.of(context);
    final similar = s.similar;
    if (similar == null || s.mode != GuestServiceMode.dineIn) {
      return const SizedBox.shrink();
    }
    final content = ListenableBuilder(
      listenable: similar,
      builder: (context, _) => similar.tables.isEmpty
          ? const SizedBox(width: double.infinity)
          : _Section(tables: similar.tables, compact: widget.compact),
    );
    // Whoever asked for less motion gets the row at once.
    if (reducedMotion(context)) return content;
    // The page below slides down to make room instead of jumping, because the
    // tables arrive a moment after the page does.
    return AnimatedSize(
      duration: GuestMotion.slow,
      curve: GuestMotion.arrive,
      alignment: Alignment.topCenter,
      child: content,
    );
  }
}

/// How wide a card is, and the least it is tall (it grows with the text).
const _cardWidth = 170.0;

class _Section extends StatelessWidget {
  const _Section({required this.tables, required this.compact});
  final List<SimilarTable> tables;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Column(
      key: const ValueKey('similar-strip'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A quiet label for the row, not a title: the pictures lead.
        if (!compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(Icons.groups_rounded, size: 16, color: p.inkMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Tables like yours',
                      key: const ValueKey('similar-heading'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: p.body(
                        13,
                        weight: FontWeight.w700,
                        color: p.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // A mouse can drag the row too; a finger always could.
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
            },
          ),
          // At most four cards, so all of them are built, and a screen reader
          // knows about every one. They are as tall as the tallest, which is
          // as tall as its words need, so larger text never clips a card.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, table) in tables.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    _TableCard(
                      key: ValueKey('similar-reveal-${table.id}'),
                      table: table,
                      index: i,
                      compact: compact,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        // Room before whatever comes next (the categories).
        if (!compact) const SizedBox(height: 12),
      ],
    );
  }
}

/// One table's order, in pictures: the first three dishes as small round
/// pictures lying a little over one another, and a bubble for how many more.
/// Under them, who it was and what it came to. No dish names: touch or hold
/// the card (or rest a mouse on it) to see what the order is.
class _TableCard extends StatelessWidget {
  const _TableCard({
    super.key,
    required this.table,
    required this.index,
    required this.compact,
  });
  final SimilarTable table;
  final int index;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final dishes = [for (final l in table.availableLines) l.dish!.item];
    final shown = dishes.take(3).toList();
    final more = dishes.length - shown.length;
    void open() => unawaited(showSimilarTableSheet(context, table));
    void hold() {
      unawaited(HapticFeedback.selectionClick());
      open();
    }

    return Reveal(
      index: index,
      dx: 18,
      dy: 0,
      child: Pressable(
        hoverScale: 1.03,
        // A mouse resting on the card shows what the order is, in a word
        // each; tapping or holding it opens the whole thing.
        child: Tooltip(
          message: similarPeek(table),
          triggerMode: TooltipTriggerMode.manual,
          excludeFromSemantics: true,
          waitDuration: const Duration(milliseconds: 350),
          // Measured from the middle of the card: half its height, and a gap.
          verticalOffset: (compact ? 30 : 36) + 6,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: p.body(
            12.5,
            weight: FontWeight.w600,
            color: p.isDark ? p.ink : p.background,
          ),
          decoration: ShapeDecoration(
            color: p.isDark ? p.surfaceAlt : p.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: p.hairline),
            ),
            shadows: p.lift(0.5),
          ),
          child: Semantics(
            key: ValueKey('similar-card-${table.id}'),
            button: true,
            // Every word the card leaves out, for someone who cannot see it.
            label: similarSpoken(table),
            hint: 'See what they ordered',
            onTap: open,
            onLongPress: hold,
            excludeSemantics: true,
            child: GestureDetector(
              onLongPress: hold,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: _cardWidth,
                  maxWidth: _cardWidth,
                  minHeight: compact ? 60 : 72,
                ),
                child: GuestCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: compact ? 6 : 8.5,
                  ),
                  onTap: open,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Dishes(
                        dishes: shown,
                        more: more,
                        size: compact ? 28 : 34,
                      ),
                      SizedBox(height: compact ? 3 : 5),
                      // Who and what it came to, side by side; one above the
                      // other only when the words are too big for the card.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_alt_rounded,
                                size: 13,
                                color: p.inkMuted,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  similarShortLabel(table),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _tight(
                                    p.body(
                                      12.5,
                                      weight: FontWeight.w600,
                                      color: p.inkMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            rupees(table.total),
                            maxLines: 1,
                            style: _tight(p.price(13.5)),
                          ),
                        ],
                      ),
                    ],
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

/// Round pictures of dishes lying over one another like faces in a group, the
/// first one on top, and a bubble ("+2") beside them for the dishes there was
/// no room for.
class _Dishes extends StatelessWidget {
  const _Dishes({required this.dishes, required this.more, required this.size});
  final List<MenuItem> dishes;
  final int more;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    // Each picture lies over the one before by about a third of itself, and
    // is cut out of it by a ring the colour of the card.
    final step = size * 0.64;
    final ring = Color.lerp(p.surface, p.keyLight, p.isDark ? 0.07 : 0.06)!;
    final stackWidth = (dishes.length - 1) * step + size;
    return ExcludeSemantics(
      child: SizedBox(
        key: const ValueKey('similar-dishes'),
        width: more > 0 ? stackWidth + 6 + size : stackWidth,
        height: size,
        child: Stack(
          children: [
            if (more > 0)
              Positioned(
                left: stackWidth + 6,
                child: Container(
                  key: const ValueKey('similar-more'),
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.surfaceAlt,
                    border: Border.all(color: p.hairline),
                  ),
                  child: Text(
                    '+$more',
                    maxLines: 1,
                    style: p.price(size * 0.34, color: p.ink),
                  ),
                ),
              ),
            // Painted from the last to the first, so the first is on top.
            for (var i = dishes.length - 1; i >= 0; i--)
              Positioned(
                left: i * step,
                child: Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ring,
                  ),
                  child: ClipOval(
                    child: FoodArt(
                      name: dishes[i].name,
                      imageUrl: dishes[i].imageUrl,
                      radius: 0,
                      animate: false,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lines set close, so a few of them make a card no taller than it needs.
TextStyle _tight(TextStyle s) => s.copyWith(height: 1.2);

String _people(int n) => n == 1 ? '1 person' : '$n people';

/// Whether the server's name for the table already says how many sat there
/// ("A table of 4"), so the party is not said twice.
bool _namesParty(String who, int n) =>
    RegExp('\\b(?:of|for)\\s+$n\\b', caseSensitive: false).hasMatch(who);

/// "Table 5 · 4": the server's name for the table, then how many sat there
/// when the server shares it (the card's people icon says what the 4 is).
String similarShortLabel(SimilarTable t) {
  final n = t.partySize;
  if (n == null || n < 1 || _namesParty(t.who, n)) return t.who;
  return '${t.who} · $n';
}

/// The dishes of a table, one to a line with how many ("2 × Chicken Biryani"):
/// what a mouse resting on its card shows.
String similarPeek(SimilarTable t) => [
  for (final l in t.distinctLines.where((l) => l.available))
    '${l.qty} × ${l.dish!.item.name}',
].join('\n');

/// Everything the card shows and leaves out, in words, for a screen reader:
/// the table, its party, every dish with how many, and the total.
String similarSpoken(SimilarTable t) {
  final n = t.partySize;
  final who = n == null || n < 1 || _namesParty(t.who, n)
      ? t.who
      : '${t.who}, ${_people(n)}';
  final dishes = [
    for (final l in t.distinctLines.where((l) => l.available))
      l.qty == 1 ? l.dish!.item.name : '${l.qty} ${l.dish!.item.name}',
  ].join(', ');
  return '$who. $dishes. Total ${rupees(t.total)}';
}

/// How long ago, in the few words a glance needs.
@visibleForTesting
String similarAgo(Duration age) {
  final minutes = age.inMinutes;
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return '$minutes min ago';
  if (age.inHours < 24) return '${age.inHours} hr ago';
  final days = age.inDays;
  return days == 1 ? '1 day ago' : '$days days ago';
}

/// The server's name for a table inside a sentence ("a table of 4" rather than
/// "A table of 4" in "What … ordered").
String _inSentence(String who) =>
    who.startsWith('A ') ? 'a ${who.substring(2)}' : who;

/// What another table ordered, to look at and to take from: every dish that
/// can still be had, ticked, with its picture, its price and how many they
/// had. The guest unticks what they do not want, changes how many of any
/// dish, and takes the rest in one tap ("Add 3 dishes · ₹1,090"), or adds a
/// single dish with its own "Add" and stays to look at the others. The total
/// and the big button follow the choice.
///
/// A sheet over the runtime's own page, so it sees the party's session. The
/// dishes that went off the menu since are shown, dimmed, and never counted
/// or added.
Future<void> showSimilarTableSheet(
  BuildContext context,
  SimilarTable table,
) async {
  final p = GuestPalette.of(context);
  final size = MediaQuery.sizeOf(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: false,
    useSafeArea: true,
    // The sheet draws its own handle, inside its own light.
    showDragHandle: false,
    // Lit a little on a dark page, like the dish sheet, so it rises off the
    // page instead of sitting as a flat slab.
    backgroundColor: p.isDark ? p.surfaceLit : p.surface,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: p.hairline),
    ),
    clipBehavior: Clip.antiAlias,
    // A phone-width panel on a wide screen, never taller than the screen.
    constraints: BoxConstraints(maxWidth: 480, maxHeight: size.height * 0.94),
    sheetAnimationStyle: reducedMotion(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: GuestMotion.base,
            curve: GuestMotion.arrive,
            reverseDuration: Duration(milliseconds: 200),
            reverseCurve: GuestMotion.depart,
          ),
    builder: (context) => _SimilarSheet(table: table),
  );
}

class _SimilarSheet extends StatefulWidget {
  const _SimilarSheet({required this.table});
  final SimilarTable table;

  @override
  State<_SimilarSheet> createState() => _SimilarSheetState();
}

/// The most portions of one dish this sheet lets a guest ask for, unless the
/// other table had more.
const _maxPortions = 20;

class _SimilarSheetState extends State<_SimilarSheet> {
  /// One row per dish: those that can be had first, the ones that are gone
  /// below them.
  late final List<SimilarLine> _rows;

  /// How many the other table had of each dish still on sale.
  final _asked = <String, int>{};

  /// The dishes ticked, and how many of each the guest wants.
  final _picked = <String>{};
  final _qty = <String, int>{};

  /// Dishes added one by one a moment ago, each until its timer runs out.
  final _justAdded = <String, Timer>{};
  bool _addedOne = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    final lines = widget.table.distinctLines;
    _rows = [
      ...lines.where((l) => l.available),
      ...lines.where((l) => !l.available),
    ];
    // Everything that can be had starts ticked, as many as the other table had.
    for (final l in _rows.where((l) => l.available)) {
      _asked[l.itemId] = l.qty;
      _qty[l.itemId] = l.qty;
      _picked.add(l.itemId);
    }
  }

  @override
  void dispose() {
    for (final t in _justAdded.values) {
      t.cancel();
    }
    super.dispose();
  }

  /// What the guest has chosen: the ticked dishes and how many of each.
  List<({String itemId, int qty})> get _picks => [
    for (final l in _rows)
      if (l.available && _picked.contains(l.itemId))
        (itemId: l.itemId, qty: _qty[l.itemId]!),
  ];

  /// Puts [picks] in the order and says how many portions went in.
  int _add(List<({String itemId, int qty})> picks) {
    final session = GuestScope.read(context);
    void add(GuestItem dish, int qty) => session.add(dish, qty: qty);
    final similar = session.similar;
    if (similar != null) return similar.copySelected(picks, add);
    // A sheet opened for a party with no tables source: the table's own
    // dishes are all there is to go by.
    final dishes = {
      for (final l in widget.table.availableLines) l.itemId: l.dish!,
    };
    var portions = 0;
    for (final pick in picks) {
      final dish = dishes[pick.itemId];
      if (dish == null || pick.qty < 1) continue;
      add(dish, pick.qty);
      portions += pick.qty;
    }
    return portions;
  }

  void _toggle(String id) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      if (!_picked.remove(id)) _picked.add(id);
    });
  }

  void _setQty(String id, int qty) {
    final most = math.max(_maxPortions, _asked[id] ?? 1);
    setState(() {
      _qty[id] = math.max(1, math.min(qty, most));
      // Asking for a number of a dish is wanting it.
      _picked.add(id);
    });
  }

  /// "Add" on one row: that dish, as many as is set, straight into the order,
  /// and the sheet stays open for the next.
  void _addOne(String id) {
    final portions = _add([(itemId: id, qty: _qty[id] ?? 1)]);
    if (portions == 0) return;
    unawaited(HapticFeedback.lightImpact());
    _justAdded[id]?.cancel();
    _justAdded[id] = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _justAdded.remove(id));
    });
    setState(() {
      _addedOne = true;
      // That one is done: the big button is for the rest.
      _picked.remove(id);
    });
  }

  /// The big button: everything ticked, as many as is set, and the sheet goes.
  void _addPicked() {
    if (_closing) return;
    final picks = _picks;
    if (widget.table.portionsOf(picks) == 0) return;
    _closing = true;
    unawaited(HapticFeedback.mediumImpact());
    final portions = _add(picks);
    // Everything the confirmation needs is taken before the sheet goes.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final width = math.min(440.0, MediaQuery.sizeOf(context).width - 32);
    final reduced = reducedMotion(context);
    final text =
        'Added $portions ${portions == 1 ? 'dish' : 'dishes'} '
        'from ${_inSentence(widget.table.who)}';
    Navigator.of(context).pop();
    if (portions == 0 || messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('similar-added'),
          behavior: SnackBarBehavior.floating,
          // The confirmation draws itself, in the room's colours.
          backgroundColor: Colors.transparent,
          elevation: 0,
          clipBehavior: Clip.none,
          padding: EdgeInsets.zero,
          width: width,
          duration: const Duration(milliseconds: 2800),
          content: _Added(text: text),
        ),
        snackBarAnimationStyle: reduced ? AnimationStyle.noAnimation : null,
      );
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final table = widget.table;
    final picks = _picks;
    final portions = table.portionsOf(picks);
    final total = table.totalOf(picks);
    final party = table.partySize;
    final meta = [
      if (party != null && party >= 1 && !_namesParty(table.who, party))
        'A table of $party',
      similarAgo(DateTime.now().difference(table.orderedAt)),
    ].join(' · ');
    return Stack(
      children: [
        // The key light of the room falls on the sheet from its upper left.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.1,
                  colors: [
                    p.keyLight.withValues(alpha: p.isDark ? 0.15 : 0.30),
                    p.keyLight.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Column(
            key: const ValueKey('similar-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: MaterialLocalizations.of(context)
                    .modalBarrierDismissLabel,
                button: true,
                onTap: () => Navigator.of(context).pop(),
                excludeSemantics: true,
                child: SizedBox(
                  height: 28,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.inkMuted.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const SizedBox(width: 36, height: 4),
                    ),
                  ),
                ),
              ),
              // The title and the dishes scroll together when there is no room
              // for them all; the total and the buttons below stay in sight.
              Flexible(
                // Every row is built, however many there are, so a keyboard
                // and a screen reader can reach them all.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              container: true,
                              header: true,
                              child: Text(
                                'What ${_inSentence(table.who)} ordered',
                                key: const ValueKey('similar-title'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: p.display(24),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meta,
                              key: const ValueKey('similar-meta'),
                              style: p.body(14, color: p.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      for (final (i, line) in _rows.indexed)
                        Reveal(
                          index: i,
                          delay: const Duration(milliseconds: 80),
                          dy: 10,
                          child: line.available
                              ? _PickRow(
                                  key: ValueKey('similar-line-${line.itemId}'),
                                  line: line,
                                  qty: _qty[line.itemId]!,
                                  picked: _picked.contains(line.itemId),
                                  added: _justAdded.containsKey(line.itemId),
                                  onToggle: () => _toggle(line.itemId),
                                  onQty: (q) => _setQty(line.itemId, q),
                                  onAdd: () => _addOne(line.itemId),
                                )
                              : _GoneRow(
                                  key: ValueKey('similar-line-${line.itemId}'),
                                  line: line,
                                ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: p.hairline)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _TotalRow(portions: portions, total: total),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // A screen reader hears a button, not a line of text.
                    Semantics(
                      button: true,
                      enabled: portions > 0,
                      child: GuestButton(
                        key: const ValueKey('similar-add-all'),
                        label: portions == 0
                            ? 'Choose a dish'
                            : 'Add $portions '
                                  '${portions == 1 ? 'dish' : 'dishes'}'
                                  ' · ${rupees(total)}',
                        icon: portions > 0 ? Icons.add_rounded : null,
                        onTap: portions > 0 ? _addPicked : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        key: const ValueKey('similar-not-now'),
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: p.inkMuted,
                          // Never a smaller target than a finger needs.
                          minimumSize: const Size(120, 48),
                          textStyle: p.body(15, weight: FontWeight.w600),
                        ),
                        // Something went in already: this is "finished" now.
                        child: Text(_addedOne ? 'Done' : 'Not now'),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Total" and what the ticked dishes come to; they move as the ticks and the
/// counts do. If the words and the amount do not fit side by side (very large
/// text), the amount goes below.
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.portions, required this.total});
  final int portions;
  final double total;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final dishes = '$portions ${portions == 1 ? 'dish' : 'dishes'}';
    return Semantics(
      container: true,
      label: portions == 0
          ? 'Nothing chosen'
          : 'Total ${rupees(total)} for $dishes',
      excludeSemantics: true,
      child: Wrap(
        key: const ValueKey('similar-total'),
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total', style: p.body(15, weight: FontWeight.w700)),
              Text(
                portions == 0 ? 'Nothing chosen' : dishes,
                style: p.body(12.5, color: p.inkMuted),
              ),
            ],
          ),
          CountUp(
            key: const ValueKey('similar-total-amount'),
            value: total,
            // Whole rupees on the way, the exact amount (paise too) on arrival.
            format: (v) =>
                (v - total).abs() < 0.005 ? rupees(total) : rupees(v.round()),
            duration: GuestMotion.base,
            style: p.price(24),
          ),
        ],
      ),
    );
  }
}

/// One dish of the other table's order that can still be had: a tick, its
/// picture and name, what the portions come to, how many, and "Add" for this
/// dish alone. Tapping the row ticks or unticks it.
class _PickRow extends StatelessWidget {
  const _PickRow({
    super.key,
    required this.line,
    required this.qty,
    required this.picked,
    required this.added,
    required this.onToggle,
    required this.onQty,
    required this.onAdd,
  });
  final SimilarLine line;
  final int qty;
  final bool picked;
  final bool added;
  final VoidCallback onToggle;
  final ValueChanged<int> onQty;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final id = line.itemId;
    final dish = line.dish!.item;
    final price = rupees(fromPaise(toPaise(dish.price) * qty));
    final fade = reducedMotion(context) ? Duration.zero : GuestMotion.base;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      // Its own sheet of paper to ink on, above the sheet's light.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('similar-pick-$id'),
          onTap: onToggle,
          borderRadius: BorderRadius.circular(16),
          excludeFromSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                // The one thing a screen reader needs to know about the row:
                // what it is, how many, and whether it is chosen.
                Semantics(
                  container: true,
                  checked: picked,
                  label:
                      '${dish.name}, '
                      '${qty == 1 ? '1 portion' : '$qty portions'}, $price',
                  onTap: onToggle,
                  excludeSemantics: true,
                  child: _Tick(key: ValueKey('similar-tick-$id'), on: picked),
                ),
                const SizedBox(width: 10),
                AnimatedOpacity(
                  duration: fade,
                  opacity: picked ? 1 : 0.5,
                  child: SizedBox.square(
                    dimension: 48,
                    child: FoodArt(
                      name: dish.name,
                      imageUrl: dish.imageUrl,
                      radius: 14,
                      animate: false,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ExcludeSemantics(
                        child: AnimatedOpacity(
                          duration: fade,
                          opacity: picked ? 1 : 0.5,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  dish.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: p.body(15, weight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 56),
                                child: Text(
                                  price,
                                  textAlign: TextAlign.right,
                                  style: p.price(15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Side by side if they fit, one above the other if not.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 2,
                        children: [
                          Semantics(
                            container: true,
                            explicitChildNodes: true,
                            label: '${dish.name} quantity',
                            value: '$qty',
                            // A tap beside its buttons (or on a button that
                            // cannot go lower) is the stepper's, not the row's.
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {},
                              excludeFromSemantics: true,
                              child: QtyStepper(
                                key: ValueKey('similar-qty-$id'),
                                qty: qty,
                                min: 1,
                                compact: true,
                                onChanged: onQty,
                              ),
                            ),
                          ),
                          _AddPill(
                            key: ValueKey('similar-add-$id'),
                            name: dish.name,
                            added: added,
                            onTap: onAdd,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tick of a row: filled in the accent when the dish is chosen, an empty
/// box when not.
class _Tick extends StatelessWidget {
  const _Tick({super.key, required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return AnimatedContainer(
      duration: reducedMotion(context) ? Duration.zero : GuestMotion.fast,
      curve: GuestMotion.arrive,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: on ? p.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: on ? p.accent : p.inkMuted.withValues(alpha: 0.75),
          width: 1.6,
        ),
      ),
      child: on ? Icon(Icons.check_rounded, size: 16, color: p.onAccent) : null,
    );
  }
}

/// "+ Add" for one dish; "Added" for a moment after it was. A finger-sized
/// target around a smaller pill.
class _AddPill extends StatelessWidget {
  const _AddPill({
    super.key,
    required this.name,
    required this.added,
    required this.onTap,
  });
  final String name;
  final bool added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final tone = p.readable(p.success);
    final ink = added ? tone : p.ink;
    return Semantics(
      container: true,
      button: true,
      enabled: !added,
      liveRegion: added,
      label: added ? 'Added $name' : 'Add $name to my order',
      onTap: added ? null : onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          // While it says "Added" a tap still lands here and does nothing; it
          // must not fall through to the row and tick it again.
          onTap: added ? () {} : onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 44,
            // As wide as the pill, not as wide as the room there is.
            child: Center(
              widthFactor: 1,
              child: Ink(
                decoration: ShapeDecoration(
                  color: added
                      ? p.success.withValues(alpha: p.isDark ? 0.18 : 0.14)
                      : p.surfaceAlt,
                  shape: p.buttonShape(
                    BorderSide(
                      color: added
                          ? p.success.withValues(alpha: 0.5)
                          : p.hairline,
                    ),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 76,
                    minHeight: 34,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          added ? Icons.check_rounded : Icons.add_rounded,
                          size: 16,
                          color: ink,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          added ? 'Added' : 'Add',
                          style: p.body(
                            13,
                            weight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
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

/// A dish of the other table's order that is no longer on the menu: dimmed,
/// with nothing to choose, never counted and never added.
class _GoneRow extends StatelessWidget {
  const _GoneRow({super.key, required this.line});
  final SimilarLine line;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Semantics(
        container: true,
        label: 'No longer available, will not be added',
        excludeSemantics: true,
        child: Row(
          children: [
            // Where the tick of the other rows is, so the pictures line up.
            const SizedBox(width: 34),
            // The server shares only a dish's id, so one that left the menu
            // has no name to show.
            const SizedBox.square(
              dimension: 48,
              child: FoodArt(
                name: 'plate',
                radius: 14,
                animate: false,
                dim: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No longer available',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: p.body(14.5, weight: FontWeight.w600, color: p.inkMuted),
              ),
            ),
            const SizedBox(width: 8),
            Text('×${line.qty}', style: p.price(14, color: p.inkMuted)),
          ],
        ),
      ),
    );
  }
}

/// The short confirmation after "Add all": a check and the words, on a lit
/// surface edged with the accent's hairline.
class _Added extends StatelessWidget {
  const _Added({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: p.isDark ? p.surfaceLit : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.hairline),
        ),
        shadows: p.lift(0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 22, color: p.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: p.body(14.5, weight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
