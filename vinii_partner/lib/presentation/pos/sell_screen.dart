import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../application/sell_cart.dart';
import '../../core/money.dart';
import '../../domain/app_definition.dart';
import '../../domain/menu.dart';
import '../../domain/pos_order.dart';
import '../../domain/staff.dart';
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/food_art.dart';
import '../widgets/state_views.dart';
import 'open_orders_sheet.dart';
import 'pos_widgets.dart';
import 'ticket_view.dart';

/// The POS: tap dishes to add them, then send the order. Every dish comes
/// from the organization's menu rows; nothing is priced or invented here —
/// the totals are estimates until the POS saves the order.
///
/// On a phone it is one column: the order type and table, search, categories,
/// the dishes, and a bar at the bottom with the running total and Review. From
/// [Breakpoints.wide] up the menu fills the left and the order sits beside it,
/// always in view, so there is no separate review step.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  late final SellCart _cart = sellCartOf(context);
  final _search = TextEditingController();
  String _query = '';

  /// Selected category id; null is "All", [_otherKey] is uncategorised.
  String? _category;
  static const _otherKey = '__other__';

  /// Width of the order pane beside the menu on a wide screen.
  static const _ticketWidth = 400.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cart.load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
    final t = ViniiTokens.of(context);
    return ListenableBuilder(
      listenable: _cart,
      builder: (context, _) {
        final services = AppScope.of(context);
        final session = services.session;
        final cart = _cart;
        final canHand =
            session.can(Capability.handToGuest) &&
            cart.serviceType == ServiceType.dineIn &&
            cart.table != null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Sell'),
            actions: [
              if (canHand)
                IconButton(
                  tooltip: 'Hand to guest',
                  icon: const Icon(Icons.send_to_mobile_outlined),
                  onPressed: () =>
                      context.push(Routes.guest(tableId: cart.table!.id)),
                ),
              IconButton(
                tooltip: 'Open orders',
                icon: const Icon(Icons.receipt_long_outlined),
                onPressed: () => showOpenOrders(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: wide
              ? Row(
                  children: [
                    Expanded(child: _menuPane(context, showTop: false)),
                    VerticalDivider(width: 1, color: t.border),
                    SizedBox(
                      width: _ticketWidth,
                      child: ColoredBox(
                        color: t.page,
                        child: TicketView(cart: cart, embedded: true),
                      ),
                    ),
                  ],
                )
              : _menuPane(context, showTop: true),
          bottomNavigationBar: wide || cart.isEmpty
              ? null
              : _CartBar(cart: cart),
        );
      },
    );
  }

  /// Search, categories and the dishes. [showTop] adds the order type and the
  /// table above them; the wide layout has those in the order pane instead.
  Widget _menuPane(BuildContext context, {required bool showTop}) {
    final cart = _cart;
    final menu = cart.menu;
    if (menu == null) {
      if (cart.menuFailure != null && !cart.loadingMenu) {
        return FailureView(
          failure: cart.menuFailure!,
          onRetry: () => cart.load(force: true),
        );
      }
      return const LoadingView(label: 'Loading the menu…');
    }
    if (menu.items.isEmpty) {
      final session = AppScope.of(context).session;
      final hasMenuTab =
          session.definition?.tabs.contains(AppTab.menu) ?? false;
      return RefreshIndicator(
        onRefresh: () => cart.load(force: true),
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: c.maxHeight,
                child: EmptyView(
                  icon: Icons.restaurant_menu_rounded,
                  title: 'No menu items yet',
                  message: 'No menu items yet. Add dishes in the Menu tab.',
                  actionLabel: hasMenuTab ? 'Open the Menu tab' : null,
                  onAction: hasMenuTab ? () => context.go(Routes.menu) : null,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final categories = [...menu.categories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final known = {for (final c in categories) c.id};
    final withItems = {
      for (final i in menu.items)
        known.contains(i.categoryId) ? i.categoryId! : _otherKey,
    };
    final shown = categories.where((c) => withItems.contains(c.id)).toList();
    final hasOther = withItems.contains(_otherKey);
    final order = {for (final (i, c) in categories.indexed) c.id: i};

    final q = _query.trim().toLowerCase();
    final items =
        menu.items.where((i) {
          final cat = known.contains(i.categoryId) ? i.categoryId! : _otherKey;
          if (_category != null && cat != _category) return false;
          return q.isEmpty || i.name.toLowerCase().contains(q);
        }).toList()..sort((a, b) {
          final ca = order[a.categoryId] ?? 1 << 20;
          final cb = order[b.categoryId] ?? 1 << 20;
          if (ca != cb) return ca.compareTo(cb);
          final s = a.sortOrder.compareTo(b.sortOrder);
          return s != 0 ? s : a.name.compareTo(b.name);
        });

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final columns = width < 600 ? 2 : (width / 200).floor().clamp(3, 6);
        final cardWidth = (width - 32 - (columns - 1) * 12) / columns;
        return RefreshIndicator(
          onRefresh: () => cart.load(force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (showTop) SliverToBoxAdapter(child: _Top(cart: cart)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, showTop ? 12 : 8, 16, 0),
                  child: TextField(
                    key: const Key('sell-search'),
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search dishes',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    children: [
                      _CategoryChip(
                        label: 'All',
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      ),
                      for (final c in shown)
                        _CategoryChip(
                          label: c.name,
                          selected: _category == c.id,
                          onTap: () => setState(() => _category = c.id),
                        ),
                      if (hasOther)
                        _CategoryChip(
                          label: 'Other',
                          selected: _category == _otherKey,
                          onTap: () => setState(() => _category = _otherKey),
                        ),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    icon: Icons.search_off_rounded,
                    title: 'No dishes match',
                    message: 'Try another name or pick "All".',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: cardWidth / 1.3 + 82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _ItemCard(item: items[i], cart: cart),
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Top extends StatelessWidget {
  const _Top({required this.cart});

  final SellCart cart;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ServiceTypeSelector(cart: cart),
          const SizedBox(height: 12),
          if (cart.serviceType == ServiceType.dineIn)
            Row(
              children: [
                TableChip(cart: cart),
                const SizedBox(width: 12),
                if (cart.table == null)
                  Expanded(
                    child: Text(
                      'Dine-in orders need a table.',
                      style: TextStyle(color: t.inkSecondary, fontSize: 13),
                    ),
                  ),
              ],
            )
          else
            Text(
              cart.serviceType.hint,
              style: TextStyle(color: t.inkSecondary, fontSize: 13.5),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: t.ink,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? t.page : t.ink,
        ),
      ),
    );
  }
}

/// A dish: its picture, veg or non-veg mark, name and price. Tapping adds
/// one; once it is on the order a − 2 + stepper sits on the picture, so a
/// slip is corrected where it happened. Long-press sets a quantity and a
/// note for the kitchen.
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.cart});

  final MenuItem item;
  final SellCart cart;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final qty = cart.qtyOf(item.id);
    final soldOut = !item.isAvailable;
    void add() {
      HapticFeedback.selectionClick();
      cart.add(item);
    }

    return Semantics(
      button: true,
      label: soldOut
          ? '${item.name}, sold out'
          : '${item.name}, ${rupees(item.price)}${qty > 0 ? ', $qty in order' : ''}',
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            if (soldOut) {
              showDone(context, '${item.name} is sold out.');
              return;
            }
            add();
          },
          onLongPress: soldOut
              ? null
              : () => showLineSheet(context, item: item, cart: cart),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: qty > 0 ? t.ink : t.border,
                width: qty > 0 ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FoodArt(
                        name: item.name,
                        imageUrl: item.imageUrl,
                        radius: 0,
                        dim: soldOut,
                        animate: false,
                      ),
                      if (soldOut)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: t.danger,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Sold out',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: qty > 0
                              ? _TileStepper(
                                  qty: qty,
                                  onLess: () => cart.setQty(item.id, qty - 1),
                                  onMore: add,
                                )
                              : _AddButton(onTap: add, name: item.name),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.foodType != null) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: FoodTypeMark(item.foodType, size: 13),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  height: 1.25,
                                  color: soldOut ? t.inkMuted : t.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          rupees(item.price),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: soldOut ? t.inkMuted : t.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
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

/// "+" on a dish that is not on the order yet.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap, required this.name});

  final VoidCallback onTap;
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Semantics(
      container: true,
      button: true,
      label: 'Add $name',
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.surface,
                shape: BoxShape.circle,
                border: Border.all(color: t.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.add_rounded, size: 22, color: t.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// − 2 + on the picture of a dish that is on the order.
class _TileStepper extends StatelessWidget {
  const _TileStepper({
    required this.qty,
    required this.onLess,
    required this.onMore,
  });

  final int qty;
  final VoidCallback onLess;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    Widget button(IconData icon, String label, VoidCallback onTap) => Semantics(
      container: true,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 42,
          height: 44,
          child: Icon(icon, size: 22, color: t.page),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: t.ink,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
            'Less',
            onLess,
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.page,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          button(Icons.add_rounded, 'More', onMore),
        ],
      ),
    );
  }
}

/// The running total and the way on, always at the bottom of the phone.
class _CartBar extends StatelessWidget {
  const _CartBar({required this.cart});

  final SellCart cart;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final n = cart.itemCount;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${n == 1 ? '1 item' : '$n items'} · ${rupees(cart.estimate.payable)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: t.ink,
                        letterSpacing: -0.3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '(estimated)',
                      style: TextStyle(color: t.inkMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const Key('sell-review'),
                onPressed: () => context.push(Routes.sellCheckout),
                icon: const Icon(Icons.arrow_forward_rounded),
                iconAlignment: IconAlignment.end,
                label: const Text('Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
