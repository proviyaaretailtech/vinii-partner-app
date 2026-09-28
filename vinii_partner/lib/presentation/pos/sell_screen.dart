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

/// The phone POS: pick the service type (and table), tap dishes to add
/// them, then review. Every dish comes from the organization's menu rows;
/// nothing is priced or invented here — the bottom bar's total is an
/// estimate until the POS saves the order.
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
          body: _body(context),
          bottomNavigationBar: cart.isEmpty ? null : _CartBar(cart: cart),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
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

    final width = MediaQuery.sizeOf(context).width;
    final columns = width < 600 ? 2 : (width / 210).floor().clamp(3, 6);
    final cardWidth = (width - 32 - (columns - 1) * 12) / columns;

    return RefreshIndicator(
      onRefresh: () => cart.load(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Top(cart: cart)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
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
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? t.page : t.ink,
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.cart});

  final MenuItem item;
  final SellCart cart;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final qty = cart.qtyOf(item.id);
    final soldOut = !item.isAvailable;
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
            HapticFeedback.selectionClick();
            cart.add(item);
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
                      ),
                      if (qty > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 28),
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ViniiColors.brandGreen,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$qty',
                              style: const TextStyle(
                                color: ViniiColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
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
