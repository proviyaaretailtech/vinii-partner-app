import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_scope.dart';
import '../../app/routes.dart';
import '../../application/sell_cart.dart';
import '../../core/failure.dart';
import '../../core/money.dart';
import '../../domain/pos_order.dart';
import '../orders/order_widgets.dart' show SectionCard;
import '../theme/staff_theme.dart';
import '../widgets/state_views.dart';
import 'pos_widgets.dart';

/// Review before the order is saved: quantities, notes, who it is for, and
/// the *estimated* bill. "Send to kitchen" saves it with a kitchen ticket;
/// "Save & hold" saves it without one (`fire_kot: false`).
///
/// Sending goes through [SellCart.place], which carries this phone's
/// idempotency key (contract R3). If the database is not ready for phone
/// orders yet, the cashier is told so plainly and nothing is cleared.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final SellCart _cart = sellCartOf(context);
  late final _name = TextEditingController(text: _cart.customerName);
  late final _phone = TextEditingController(text: _cart.customerPhone);
  late final _notes = TextEditingController(text: _cart.notes);

  /// Which button started the send, for its spinner.
  bool? _sendingFire;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _send({required bool fire}) async {
    final session = AppScope.of(context).session;
    final placedBy = session.membership?.roleSlug == 'captain'
        ? PlacedBy.captain
        : PlacedBy.pos;
    setState(() => _sendingFire = fire);
    try {
      final result = await _cart.place(
        fireKitchenTicket: fire,
        placedBy: placedBy,
      );
      if (!mounted) return;
      final order = result.order;
      if (result.earlierOrder) {
        await _showEarlierOrder(order);
        return;
      }
      showDone(
        context,
        fire
            ? '${order.displayNo} sent to the kitchen.'
            : '${order.displayNo} saved and held.',
      );
      context.go(Routes.posOrder(order.id), extra: order);
    } on AppFailure catch (e) {
      if (!mounted) return;
      // Stop the spinner first: the dialog waits for the cashier.
      setState(() => _sendingFire = null);
      if (e.kind == FailureKind.notReady) {
        await showNotAvailableDialog(context, e.message);
      } else {
        showFailure(context, e);
      }
    } finally {
      if (mounted) setState(() => _sendingFire = null);
    }
  }

  /// The pending key belonged to an earlier, unanswered send, and the server
  /// returned that order. Say so, and keep this cart for a fresh send.
  Future<void> _showEarlierOrder(PlacedOrder order) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('An earlier order went through'),
        content: Text(
          "This phone's earlier order was saved as ${order.displayNo}. "
          'Your cart is still here. Send it again to make a new order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Open ${order.displayNo}'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep this cart'),
          ),
        ],
      ),
    );
    if (open == true && mounted) {
      await context.push(Routes.posOrder(order.id), extra: order);
    }
  }

  Future<void> _editNote(CartLine line) async {
    final controller = TextEditingController(text: line.notes ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Note for ${line.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 140,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Less spicy, no onion',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved != null) _cart.setLineNote(line.itemId, saved);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cart,
      builder: (context, _) {
        final cart = _cart;
        return Scaffold(
          appBar: AppBar(title: const Text('Review order')),
          body: cart.isEmpty
              ? EmptyView(
                  icon: Icons.shopping_basket_outlined,
                  title: 'The order is empty',
                  message: 'Add dishes on the Sell screen.',
                  actionLabel: 'Back to the menu',
                  onAction: () => context.go(Routes.sell),
                )
              : _form(context, cart),
          bottomNavigationBar: cart.isEmpty ? null : _actions(context, cart),
        );
      },
    );
  }

  Widget _form(BuildContext context, SellCart cart) {
    final t = ViniiTokens.of(context);
    final dineIn = cart.serviceType == ServiceType.dineIn;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (cart.hasPendingSend) ...[
          const NoticeBanner(
            icon: Icons.sync_problem_rounded,
            message:
                'An earlier send from this phone did not get an answer. '
                'Sending again checks for it first, so nothing is made twice.',
          ),
          const SizedBox(height: 12),
        ],
        SectionCard(
          title: 'Order type',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ServiceTypeSelector(cart: cart),
              const SizedBox(height: 14),
              if (dineIn) ...[
                TableChip(cart: cart),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.group_outlined, size: 20, color: t.inkSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Guests',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: t.inkSecondary,
                      ),
                    ),
                    const Spacer(),
                    QtyStepper(
                      qty: cart.guestCount,
                      min: 1,
                      onChanged: cart.setGuestCount,
                    ),
                  ],
                ),
              ] else ...[
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Customer name (optional)',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  onChanged: cart.setCustomerName,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: InputDecoration(
                    labelText: cart.serviceType == ServiceType.delivery
                        ? 'Customer phone'
                        : 'Customer phone (optional)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    helperText: cart.serviceType == ServiceType.delivery
                        ? 'Needed so the rider can reach the customer.'
                        : null,
                  ),
                  onChanged: cart.setCustomerPhone,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: cart.itemCount == 1 ? '1 item' : '${cart.itemCount} items',
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
          child: Column(
            children: [
              for (final (i, line) in cart.lines.indexed) ...[
                if (i > 0) Divider(height: 1, color: t.border),
                _LineRow(
                  line: line,
                  onQty: (q) => cart.setQty(line.itemId, q),
                  onNote: () => _editNote(line),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Order note',
          child: TextField(
            controller: _notes,
            maxLines: 2,
            minLines: 1,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'For the whole order, e.g. Serve starters first',
            ),
            onChanged: cart.setNotes,
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Bill',
          child: EstimatedBill(bill: cart.estimate),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context, SellCart cart) {
    final t = ViniiTokens.of(context);
    final blocker = cart.blocker;
    final busy = cart.placing || _sendingFire != null;
    final enabled = blocker == null && !busy;
    Widget spinner(Color c) => SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: c),
    );
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (blocker != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: t.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        blocker,
                        style: TextStyle(
                          color: t.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: enabled ? () => _send(fire: false) : null,
                      child: _sendingFire == false
                          ? spinner(t.ink)
                          : const Text('Save & hold'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      onPressed: enabled ? () => _send(fire: true) : null,
                      child: _sendingFire == true
                          ? spinner(t.onAccent)
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Send to kitchen · ${rupees(cart.estimate.payable)}',
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.onQty,
    required this.onNote,
  });

  final CartLine line;
  final ValueChanged<int> onQty;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final note = line.notes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${rupees(line.unitPrice)} × ${line.qty} = ${rupees(line.lineTotal)}',
                  style: TextStyle(color: t.inkSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onNote,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          note == null
                              ? Icons.add_comment_outlined
                              : Icons.sticky_note_2_outlined,
                          size: 16,
                          color: note == null ? t.inkMuted : t.warning,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            note ?? 'Add note',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: note == null ? t.inkMuted : t.ink,
                              fontStyle: note == null
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                              fontWeight: FontWeight.w600,
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
          const SizedBox(width: 8),
          QtyStepper(qty: line.qty, onChanged: onQty),
        ],
      ),
    );
  }
}
