import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../domain/guest_catalog.dart';
import '../../domain/pos_order.dart';
import '../../domain/storefront.dart';
import '../theme/guest_theme.dart';
import '../widgets/dish_art.dart';
import '../widgets/food_art.dart';
import 'guest_bill.dart';
import 'guest_flow.dart';
import 'guest_preorder.dart';
import 'guest_similar.dart';
import 'guest_widgets.dart';
import 'look/look.dart';
import 'look/motion.dart';

/// The icon for a way of ordering (dine in, takeaway, pre-order, delivery).
IconData modeIcon(GuestServiceMode m) => switch (m) {
  GuestServiceMode.dineIn => Icons.restaurant_rounded,
  GuestServiceMode.takeaway => Icons.shopping_bag_outlined,
  GuestServiceMode.preOrder => Icons.schedule_rounded,
  GuestServiceMode.delivery => Icons.delivery_dining_rounded,
};

/// Board 1 #9–#11 / Board 2 #7–#8, as ONE screen: "Your order". The dishes
/// with their steppers, the way the food reaches the party, a note for the
/// kitchen, a coupon code, the estimated bill against the table budget, and
/// "Place order". It used to be three near-identical screens (order, review,
/// checkout); they said the same things three times.
///
/// The table is never asked here: it comes from the QR code on the table (or
/// the table a staff member handed the phone to). Placing goes through the
/// gateway with the session's idempotency key, which survives a failed
/// attempt so "Try again" can never make a second order.
class GuestOrderScreen extends StatefulWidget {
  const GuestOrderScreen({super.key});

  @override
  State<GuestOrderScreen> createState() => _GuestOrderScreenState();
}

class _GuestOrderScreenState extends State<GuestOrderScreen> {
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: GuestScope.read(context).notes);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _place() async {
    final s = GuestScope.read(context);
    s.notes = _notes.text;
    try {
      await s.place();
      if (mounted) GuestFlow.placed(context);
    } catch (_) {
      // The session keeps the failure (shown below) and the same key.
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final t = GuestCopy.of(context);
    final status = s.budgetStatus;
    final blocker = s.blocker;
    final modes = s.definition.serviceModes;
    final saved = s.features.likes
        ? <GuestItem>[
            for (final id in s.liked)
              if (s.catalog.item(id) != null && s.qtyOf(id) == 0)
                s.catalog.item(id)!,
          ]
        : const <GuestItem>[];
    return GuestPage(
      bottom: s.lines.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (blocker != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      blocker,
                      key: const ValueKey('place-blocker'),
                      textAlign: TextAlign.center,
                      style: p.body(13, color: p.inkMuted),
                    ),
                  ),
                GuestButton(
                  key: const ValueKey('place-order'),
                  label: s.placeError == null
                      ? '${t('cart.place')} · ${rupees(s.estimate.payable)}'
                      : 'Try again',
                  trailingArrow: true,
                  busy: s.placing,
                  onTap: blocker == null ? _place : null,
                ),
              ],
            ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GuestTopBar(
            title: t('cart.title'),
            trailing: [
              if (s.lines.isNotEmpty)
                TextButton(
                  onPressed: s.clearCart,
                  child: Text(
                    'Clear all',
                    style: p.body(14, weight: FontWeight.w700, color: p.danger),
                  ),
                ),
            ],
          ),
          if (s.lines.isNotEmpty && modes.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _ModeSwitch(modes: modes, selected: s.mode),
            ),
          _WhereLine(showMode: modes.length <= 1),
          const SizedBox(height: 12),
          if (s.lines.isEmpty) const _EmptyOrder(),
          for (final (n, l) in s.lines.indexed)
            _LineRow(key: ValueKey(l.itemId), line: l, index: n),
          if (saved.isNotEmpty) _Saved(items: saved),
          if (s.lines.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: switch (s.mode) {
                GuestServiceMode.preOrder => const _SlotCard(),
                GuestServiceMode.delivery => const _DeliveryFields(),
                GuestServiceMode.takeaway => const _Note(
                  icon: Icons.storefront_outlined,
                  text: "We'll call your order number at the counter.",
                ),
                GuestServiceMode.dineIn => const SizedBox.shrink(),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Special instructions (optional)',
                style: p.body(14, weight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                key: const ValueKey('guest-notes'),
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                maxLength: 240,
                onChanged: (v) => s.notes = v,
                style: p.body(15),
                decoration: InputDecoration(hintText: t('cart.notes_hint')),
              ),
            ),
            if (s.canUseCoupons)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: _CouponRow(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: GuestCard(
                child: BillLines(
                  bill: s.estimate,
                  estimated: true,
                  discountLabel: s.coupon == null
                      ? null
                      : 'Coupon ${s.coupon!.code}',
                ),
              ),
            ),
            if (status != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: GuestCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Table budget ${rupees(status.budget)}',
                        style: p.body(13, color: p.inkMuted),
                      ),
                      const SizedBox(height: 6),
                      BudgetBar(status: status),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: BudgetNote(status: status),
              ),
            ],
          ],
          if (s.placeError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: GuestCard(
                key: const ValueKey('place-error'),
                color: p.danger.withValues(alpha: 0.1),
                borderColor: p.danger.withValues(alpha: 0.35),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: p.danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.placeError!.message,
                        style: p.body(14, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Where the food goes, as a quiet fact: "Table 12 • Dine-in". The table is
/// from the QR code; without one (and not in a preview) the guest is told to
/// scan it, never asked to type a number.
class _WhereLine extends StatelessWidget {
  const _WhereLine({required this.showMode});

  /// Only when the restaurant offers a single way of ordering; with several,
  /// the switch above already says which one is chosen.
  final bool showMode;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final table = s.mode == GuestServiceMode.dineIn ? s.tableName : null;
    if (s.mode == GuestServiceMode.dineIn && table == null) {
      if (s.lines.isEmpty) return const SizedBox.shrink();
      final word = s.definition.tableLabel.toLowerCase();
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        child: Row(
          key: const ValueKey('qr-hint'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.qr_code_scanner_rounded, size: 20, color: p.inkMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                s.gateway.isPreview
                    ? 'In the live storefront, your $word comes from the QR '
                          'code on it.'
                    : 'Your $word comes from the QR code on it. Scan it to '
                          'order from your $word.',
                style: p.body(13.5, color: p.inkMuted).copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
    final parts = [?table, if (showMode) s.mode.label];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Text(
        parts.join(' • '),
        key: const ValueKey('where-line'),
        style: p.body(13, color: p.inkMuted),
      ),
    );
  }
}

/// "Dine-in · Pre-order · Takeaway": only the ways this restaurant offers.
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.modes, required this.selected});
  final List<GuestServiceMode> modes;
  final GuestServiceMode selected;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.read(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final m in modes)
            Expanded(
              child: Semantics(
                button: true,
                selected: m == selected,
                label: m.label,
                child: GestureDetector(
                  key: ValueKey('mode-${m.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    s.update(() => s.mode = m);
                  },
                  child: AnimatedContainer(
                    duration: GuestMotion.base,
                    curve: GuestMotion.arrive,
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: m == selected ? p.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            modeIcon(m),
                            size: 18,
                            color: m == selected ? p.onAccent : p.inkMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            m.label,
                            style: p.body(
                              14,
                              weight: FontWeight.w700,
                              color: m == selected ? p.onAccent : p.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyOrder extends StatelessWidget {
  const _EmptyOrder();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          child: Column(
            children: [
              SizedBox(
                height: 130,
                child: DishArt(
                  name: 'plate',
                  family: DishFamily.plate,
                  light: p.keyLight,
                  onDark: p.isDark,
                  animate: false,
                ),
              ),
              const SizedBox(height: 12),
              Text('Your order is empty', style: p.display(22)),
              const SizedBox(height: 20),
              GuestButton(
                label: 'Browse dishes',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SimilarTablesStrip(compact: true),
      ],
    );
  }
}

class _Saved extends StatelessWidget {
  const _Saved({required this.items});
  final List<GuestItem> items;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final t = GuestCopy.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              Icon(Icons.favorite_rounded, size: 18, color: p.danger),
              const SizedBox(width: 8),
              Text(
                'Saved for later',
                style: p.display(17, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (context, i) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = items[i];
              return GuestCard(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                onTap: () => GuestFlow.openItem(context, item),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 50,
                      child: FoodArt(
                        name: item.item.name,
                        imageUrl: item.item.imageUrl,
                        radius: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        item.item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: p.body(13, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RoundIcon(
                      icon: Icons.add_rounded,
                      size: 34,
                      tooltip: t('menu.add'),
                      background: p.accent,
                      color: p.onAccent,
                      onTap: () => addWithHaptic(context, item),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({super.key, required this.line, required this.index});
  final CartLine line;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final item = s.catalog.item(line.itemId);
    // Slide a dish away to remove it; the steppers still work as before.
    return Reveal(
      index: index,
      dx: 18,
      dy: 0,
      child: Dismissible(
        key: ValueKey('dismiss-${line.itemId}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => s.setQty(line.itemId, 0),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 28),
          color: p.danger.withValues(alpha: 0.18),
          child: Icon(Icons.delete_outline_rounded, color: p.danger),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 58,
                child: FoodArt(
                  name: line.name,
                  imageUrl: item?.item.imageUrl,
                  radius: 16,
                  animate: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: p.body(15, weight: FontWeight.w700),
                    ),
                    Text(
                      rupees(line.unitPrice),
                      style: p.body(13, color: p.inkMuted),
                    ),
                    // One tap to give everyone at the table the same dish.
                    if (s.hasParty && line.qty != s.partySize)
                      GestureDetector(
                        key: ValueKey('repeat-${line.itemId}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => s.setQty(line.itemId, s.partySize),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.groups_rounded,
                                size: 15,
                                color: p.isDark ? p.keyLight : p.ink,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'For all ${s.partySize}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: p.body(
                                    12.5,
                                    weight: FontWeight.w700,
                                    color: p.isDark ? p.keyLight : p.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              QtyStepper(
                qty: line.qty,
                compact: true,
                onChanged: (v) => s.setQty(line.itemId, v),
              ),
              SizedBox(
                width: 70,
                child: CountUp(
                  value: line.lineTotal,
                  format: rupees,
                  duration: GuestMotion.base,
                  textAlign: TextAlign.right,
                  style: p.price(15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Have a coupon code?" → a field and Apply → the code with what it saves
/// and a way to take it off. Only shown when the restaurant's server checks
/// coupons; the server decides every time (docs/GUEST_SERVER_CONTRACT.md).
class _CouponRow extends StatefulWidget {
  const _CouponRow();

  @override
  State<_CouponRow> createState() => _CouponRowState();
}

class _CouponRowState extends State<_CouponRow> {
  final _field = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final applied = s.coupon;
    if (applied != null) {
      return GuestCard(
        key: const ValueKey('coupon-applied'),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: p.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${applied.code} applied',
                    style: p.body(15, weight: FontWeight.w700),
                  ),
                  Text(
                    applied.label ?? 'You save ${rupees(applied.discount)}',
                    style: p.body(13, color: p.inkMuted),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const ValueKey('coupon-remove'),
              onPressed: () {
                _field.clear();
                s.removeCoupon();
              },
              child: Text(
                'Remove',
                style: p.body(14, weight: FontWeight.w700, color: p.danger),
              ),
            ),
          ],
        ),
      );
    }
    if (!_open && s.couponMessage == null) {
      return GuestCard(
        key: const ValueKey('coupon-open'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        onTap: () => setState(() => _open = true),
        child: Row(
          children: [
            Icon(Icons.confirmation_number_outlined, color: p.inkMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Have a coupon code?',
                style: p.body(15, weight: FontWeight.w600),
              ),
            ),
            Icon(Icons.add_rounded, color: p.inkMuted),
          ],
        ),
      );
    }
    return GuestCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('coupon-field'),
                  controller: _field,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9_\-]'),
                    ),
                    LengthLimitingTextInputFormatter(24),
                  ],
                  style: p.body(16, weight: FontWeight.w700),
                  decoration: const InputDecoration(hintText: 'Coupon code'),
                  onSubmitted: s.applyCoupon,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: GuestButton(
                  key: const ValueKey('coupon-apply'),
                  label: 'Apply',
                  dense: true,
                  busy: s.couponChecking,
                  onTap: () => s.applyCoupon(_field.text),
                ),
              ),
            ],
          ),
          if (s.couponMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 4),
              child: Text(
                s.couponMessage!,
                key: const ValueKey('coupon-message'),
                style: p.body(13.5, weight: FontWeight.w600, color: p.danger),
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    return GuestCard(
      child: Row(
        children: [
          Icon(icon, color: p.inkMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: p.body(14.5))),
        ],
      ),
    );
  }
}

/// The pickup time of a pre-order, with a way to change it.
class _SlotCard extends StatelessWidget {
  const _SlotCard();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final at = s.scheduledFor;
    return GuestCard(
      onTap: () => Navigator.of(context)
          .push(guestRoute<void>(const GuestPreOrderScreen(pickOnly: true))),
      child: Row(
        children: [
          Icon(Icons.event_rounded, color: p.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              at == null
                  ? 'Choose a pickup time'
                  : 'Pickup on ${DateFormat('EEE, d MMM').format(at)} • '
                        '${DateFormat('h:mm a').format(at)}',
              style: p.body(14.5, weight: FontWeight.w700),
            ),
          ),
          Text('Change', style: p.body(13.5, color: p.inkMuted)),
        ],
      ),
    );
  }
}

/// Name, phone and a short address note, kept deliberately simple.
class _DeliveryFields extends StatelessWidget {
  const _DeliveryFields();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.read(context);
    InputDecoration deco(String hint, IconData icon) =>
        InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 20));
    return Column(
      children: [
        TextFormField(
          initialValue: s.customerName,
          textCapitalization: TextCapitalization.words,
          style: p.body(15),
          decoration: deco('Your name', Icons.person_outline_rounded),
          onChanged: (v) => s.update(() => s.customerName = v),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: s.customerPhone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 10,
          style: p.body(15),
          decoration: deco('Phone number', Icons.phone_outlined),
          onChanged: (v) => s.update(() => s.customerPhone = v),
        ),
        TextFormField(
          initialValue: s.addressNote,
          minLines: 2,
          maxLines: 3,
          style: p.body(15),
          decoration: deco('Address or room number', Icons.home_outlined),
          onChanged: (v) => s.update(() => s.addressNote = v),
        ),
      ],
    );
  }
}
