import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../application/sell_cart.dart';
import '../../core/failure.dart';
import '../../core/money.dart';
import '../../domain/billing.dart';
import '../../domain/menu.dart';
import '../../domain/pos_order.dart';
import '../../l10n/l10n.dart';
import '../../l10n/labels.dart';
import '../../l10n/script_fonts.dart';
import '../orders/order_widgets.dart' show AmountRow;
import '../theme/staff_theme.dart';
import '../widgets/chips.dart';
import '../widgets/state_views.dart';
import 'service_charge.dart';

/// Pieces shared by the Sell, Checkout and POS order screens.

/// The one Sell cart for this organization, from the feature store (it is
/// dropped on sign-out and organization switch).
SellCart sellCartOf(BuildContext context) {
  final services = AppScope.of(context);
  return services.feature(
    () => SellCart(
      menuRepository: services.backend.menu,
      pos: services.backend.pos,
      prefs: services.prefs,
      orgId: services.session.membership?.organization.id ?? '',
    ),
  );
}

/// Why the order cannot be sent yet, in the reader's language.
extension SellBlockerText on AppLocalizations {
  String sellBlockerText(SellBlocker b) => switch (b) {
    SellBlocker.empty => sellBlockerEmpty,
    SellBlocker.noTable => sellBlockerNoTable,
    SellBlocker.noPhone => sellBlockerNoPhone,
  };
}

/// Dine-in · Takeaway · Delivery.
class ServiceTypeSelector extends StatelessWidget {
  const ServiceTypeSelector({super.key, required this.cart});

  final SellCart cart;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ServiceType>(
        // A label that does not fit its segment (a longer language, a big
        // text size) wraps onto a second line instead of being cut short.
        segments: [
          for (final (type, icon) in const [
            (ServiceType.dineIn, Icons.table_restaurant_outlined),
            (ServiceType.takeaway, Icons.shopping_bag_outlined),
            (ServiceType.delivery, Icons.delivery_dining_outlined),
          ])
            ButtonSegment(
              value: type,
              label: Text(
                l.serviceTypeLabel(type),
                textAlign: TextAlign.center,
              ),
              icon: Icon(icon, size: 16),
            ),
        ],
        selected: {cart.serviceType},
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: t.ink,
          selectedForegroundColor: t.page,
          foregroundColor: t.ink,
          backgroundColor: t.surface,
          side: BorderSide(color: t.border),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontFamilyFallback: kScriptFontFallback,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
          visualDensity: const VisualDensity(vertical: 1),
        ),
        onSelectionChanged: (s) => cart.setServiceType(s.first),
      ),
    );
  }
}

/// "Table 12 ▾" — opens the table picker.
class TableChip extends StatelessWidget {
  const TableChip({super.key, required this.cart});

  final SellCart cart;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final table = cart.table;
    final missing = table == null;
    return Material(
      color: missing ? t.tint(t.warning) : t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: missing ? t.warning : t.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () async {
          final picked = await showTablePicker(context, selected: table);
          if (picked != null) cart.setTable(picked);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.table_restaurant_rounded,
                  size: 18,
                  color: missing ? t.warning : t.ink,
                ),
                const SizedBox(width: 8),
                Text(
                  missing ? l.posChooseTable : table.nameIn(l),
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
                Icon(Icons.arrow_drop_down_rounded, color: t.inkSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The restaurant's tables (`dining_tables`), busy ones marked. Loaded each
/// time it opens, so occupancy is current.
Future<DiningTable?> showTablePicker(
  BuildContext context, {
  DiningTable? selected,
}) => showModalBottomSheet<DiningTable>(
  context: context,
  isScrollControlled: true,
  builder: (context) => _TableSheet(selected: selected),
);

class _TableSheet extends StatefulWidget {
  const _TableSheet({this.selected});
  final DiningTable? selected;

  @override
  State<_TableSheet> createState() => _TableSheetState();
}

class _TableSheetState extends State<_TableSheet> {
  List<DiningTable>? _tables;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failure = null);
    try {
      final rows = await AppScope.of(context).backend.pos.tables();
      if (mounted) setState(() => _tables = rows);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _failure = e);
    } catch (e) {
      if (mounted) setState(() => _failure = asFailure(e));
    }
  }

  Widget _tableTile(BuildContext context, DiningTable table) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final chosen = table.id == widget.selected?.id;
    final bg = chosen
        ? t.ink
        : table.occupied
        ? t.tint(t.warning)
        : t.surface;
    final fg = chosen ? t.page : t.ink;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(context, table),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: chosen
                  ? t.ink
                  : table.occupied
                  ? t.warning.withValues(alpha: 0.5)
                  : t.border,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  table.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.posSeats(count: table.seats),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: chosen ? t.page : t.inkSecondary,
                  ),
                ),
                if (table.occupied) ...[
                  const SizedBox(height: 4),
                  Text(
                    l.posTableOccupied,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: chosen ? t.page : t.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final tables = _tables;
    Widget body;
    if (_failure != null) {
      body = SizedBox(
        height: 280,
        child: FailureView(failure: _failure!, onRetry: _load),
      );
    } else if (tables == null) {
      body = const SizedBox(height: 200, child: LoadingView());
    } else if (tables.isEmpty) {
      body = SizedBox(
        height: 280,
        child: EmptyView(
          icon: Icons.table_restaurant_outlined,
          title: l.posNoTablesTitle,
          message: l.posNoTablesMessage,
        ),
      );
    } else {
      // Sections follow the floor plan when tables belong to one.
      final groups = <String?, List<DiningTable>>{};
      for (final table in tables) {
        (groups[table.area] ??= []).add(table);
      }
      final named = groups.length > 1 || groups.keys.first != null;
      body = Flexible(
        child: CustomScrollView(
          shrinkWrap: true,
          slivers: [
            for (final entry in groups.entries) ...[
              if (named)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Text(
                      entry.key ?? l.posOtherTables,
                      style: TextStyle(
                        color: t.inkSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  // The tile grows with the text size (a longer language, a big
                  // font) instead of squeezing its words.
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 120,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: math.max(
                      110,
                      26 + MediaQuery.textScalerOf(context).scale(84),
                    ),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _tableTile(context, entry.value[i]),
                    childCount: entry.value.length,
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      );
    }
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.posChooseTableTitle, style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text(l.posTablesHelp, style: text.bodyMedium),
                ],
              ),
            ),
            body,
          ],
        ),
      ),
    );
  }
}

/// − 2 + — big enough for a thumb in a hurry (each button is 44 pixels).
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.qty,
    required this.onChanged,
    this.min = 0,
  });

  final int qty;
  final ValueChanged<int> onChanged;
  final int min;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    Widget button(IconData icon, String label, VoidCallback? onTap) =>
        Semantics(
          button: true,
          label: label,
          enabled: onTap != null,
          child: InkResponse(
            radius: 24,
            onTap: onTap,
            child: SizedBox.square(
              dimension: 44,
              child: Icon(
                icon,
                size: 22,
                color: onTap == null ? t.inkMuted : t.ink,
              ),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            qty - 1 <= 0 && min == 0
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            l.sellLess,
            qty > min ? () => onChanged(qty - 1) : null,
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: t.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          button(Icons.add_rounded, l.sellMore, () => onChanged(qty + 1)),
        ],
      ),
    );
  }
}

/// The phone's bill preview. Always labelled as an estimate: the POS
/// prices the order from the menu and its bill settings (contract R2).
class EstimatedBill extends StatelessWidget {
  const EstimatedBill({super.key, required this.bill, this.serviceCharge});

  final BillSummary bill;
  final ServiceChargeLine? serviceCharge;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    return Column(
      children: [
        BillLines(
          bill: bill,
          totalLabel: l.posBillEstimatedTotal,
          serviceCharge: serviceCharge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: t.inkMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.posEstimatedNote,
                style: TextStyle(fontSize: 12.5, color: t.inkMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Item total → service charge → SGST → CGST → round-off → total, the order
/// the OS prints them.
///
/// The service charge row shows its percentage. [serviceCharge] adds the
/// Remove / Add back actions for people who may take the charge off; without
/// it the row is read-only, and a removed charge still shows struck through.
class BillLines extends StatelessWidget {
  const BillLines({
    super.key,
    required this.bill,
    this.totalLabel,
    this.serviceCharge,
  });

  final BillSummary bill;

  /// The label of the last line; "Total" in the reader's language when null.
  final String? totalLabel;
  final ServiceChargeLine? serviceCharge;

  ServiceChargeLine? get _serviceLine {
    if (serviceCharge != null) return serviceCharge;
    if (bill.serviceCharge > 0) {
      return ServiceChargeLine(
        percent: bill.servicePercent,
        amount: bill.serviceCharge,
        waived: false,
      );
    }
    if (bill.serviceChargeWaived && bill.waivedServiceCharge > 0) {
      return ServiceChargeLine(
        percent: bill.servicePercent,
        amount: bill.waivedServiceCharge,
        waived: true,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    String pct(double p) => '${p % 1 == 0 ? p.toInt() : p}%';
    final service = _serviceLine;
    return Column(
      children: [
        AmountRow(l.posBillItems, rupees(bill.itemTotal)),
        if (bill.discount > 0)
          AmountRow(l.commonDiscount, '− ${rupees(bill.discount)}'),
        if (service != null) ServiceChargeRow(service),
        AmountRow(
          l.posBillSgst(percent: pct(bill.charges.sgstPercent)),
          rupees(bill.sgst),
        ),
        AmountRow(
          l.posBillCgst(percent: pct(bill.charges.cgstPercent)),
          rupees(bill.cgst),
        ),
        if (bill.roundOff != 0)
          AmountRow(
            l.posBillRoundOff,
            bill.roundOff < 0
                ? '− ${rupees(-bill.roundOff)}'
                : rupees(bill.roundOff),
          ),
        Divider(height: 18, color: t.border),
        AmountRow(
          totalLabel ?? l.commonTotal,
          rupees(bill.payable),
          strong: true,
        ),
      ],
    );
  }
}

/// A POS write the database cannot take yet (the front-door functions are
/// waiting for approval). Said plainly, and nothing on screen is lost.
Future<void> showNotAvailableDialog(BuildContext context, String message) =>
    showDialog<void>(
      context: context,
      builder: (context) {
        final t = ViniiTokens.of(context);
        final l = context.l10n;
        return AlertDialog(
          icon: Icon(Icons.construction_rounded, color: t.warning, size: 32),
          title: Text(l.failureTitleNotReady),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.commonOk),
            ),
          ],
        );
      },
    );

/// Long-press on a dish: set how many and add a kitchen note.
Future<void> showLineSheet(
  BuildContext context, {
  required MenuItem item,
  required SellCart cart,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => _LineSheet(item: item, cart: cart),
);

class _LineSheet extends StatefulWidget {
  const _LineSheet({required this.item, required this.cart});
  final MenuItem item;
  final SellCart cart;

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  late int _qty = widget.cart.qtyOf(widget.item.id).clamp(1, 999);
  late final _note = TextEditingController(
    text: widget.cart.lineFor(widget.item.id)?.notes ?? '',
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final item = widget.item;
    final inCart = widget.cart.qtyOf(item.id) > 0;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  FoodTypeMark(item.foodType, size: 16),
                  if (item.foodType != null) const SizedBox(width: 8),
                  Expanded(child: Text(item.name, style: text.titleLarge)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l.sellPriceEach(price: rupees(item.price)),
                style: TextStyle(color: t.inkSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.commonQuantity,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: t.ink,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  QtyStepper(
                    qty: _qty,
                    min: 1,
                    onChanged: (v) => setState(() => _qty = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                maxLength: 140,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.sellKitchenNoteLabel,
                  hintText: l.sellNoteHint,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  widget.cart.setLine(item, qty: _qty, note: _note.text);
                  Navigator.pop(context);
                },
                child: Text(
                  inCart
                      ? l.sellLineUpdate(total: rupees(item.price * _qty))
                      : l.sellLineAdd(total: rupees(item.price * _qty)),
                  textAlign: TextAlign.center,
                ),
              ),
              if (inCart) ...[
                const SizedBox(height: 4),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: t.danger),
                  onPressed: () {
                    widget.cart.setLine(item, qty: 0);
                    Navigator.pop(context);
                  },
                  child: Text(
                    l.sellRemoveFromOrder,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
