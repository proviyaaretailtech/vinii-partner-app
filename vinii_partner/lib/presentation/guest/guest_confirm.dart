import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../domain/storefront.dart';
import '../theme/guest_theme.dart';
import 'guest_flow.dart';
import 'guest_preorder.dart';
import 'guest_widgets.dart';

/// Board 1 #11 / Board 2 #8: how the food reaches the party (only the
/// storefront's enabled modes, in its order), the table or pickup slot,
/// and "Place order". Placing goes through the gateway with the session's
/// idempotency key, which survives a failed attempt so "Try again" can
/// never make a second order.
class GuestConfirmScreen extends StatelessWidget {
  const GuestConfirmScreen({super.key});

  static IconData iconFor(GuestServiceMode m) => switch (m) {
    GuestServiceMode.dineIn => Icons.restaurant_rounded,
    GuestServiceMode.takeaway => Icons.shopping_bag_outlined,
    GuestServiceMode.preOrder => Icons.schedule_rounded,
    GuestServiceMode.delivery => Icons.delivery_dining_rounded,
  };

  Future<void> _place(BuildContext context) async {
    final s = GuestScope.read(context);
    try {
      await s.place();
      if (context.mounted) GuestFlow.placed(context);
    } catch (_) {
      // The session keeps the failure (shown below) and the same key.
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final modes = s.definition.serviceModes;
    final blocker = s.blocker;
    return GuestPage(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (blocker != null && s.lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                blocker,
                textAlign: TextAlign.center,
                style: p.body(13, color: p.inkMuted),
              ),
            ),
          GuestButton(
            key: const ValueKey('place-order'),
            label: s.placeError == null ? 'Place order' : 'Try again',
            trailingArrow: true,
            busy: s.placing,
            onTap: blocker == null ? () => _place(context) : null,
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          GuestTopBar(
            title: modes.length > 1 ? 'Select dining mode' : 'Checkout',
          ),
          const SizedBox(height: 8),
          if (modes.length > 1)
            for (final m in modes)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _ModeOption(mode: m, selected: s.mode == m),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: switch (s.mode) {
              GuestServiceMode.dineIn => const _TableCard(),
              GuestServiceMode.preOrder => const _SlotCard(),
              GuestServiceMode.delivery => const _DeliveryCard(),
              GuestServiceMode.takeaway => const _Note(
                icon: Icons.storefront_outlined,
                text: "We'll call your order number at the counter.",
              ),
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: GuestCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${s.itemCount} ${s.itemCount == 1 ? 'item' : 'items'}',
                      style: p.body(15, weight: FontWeight.w700),
                    ),
                  ),
                  Text('Estimated ', style: p.body(12.5, color: p.inkMuted)),
                  Text(rupees(s.estimate.payable), style: p.price(20)),
                ],
              ),
            ),
          ),
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

class _ModeOption extends StatelessWidget {
  const _ModeOption({required this.mode, required this.selected});
  final GuestServiceMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.read(context);
    final subtitle = switch (mode) {
      GuestServiceMode.dineIn => "We'll serve at your table",
      GuestServiceMode.takeaway => 'Pick up at the counter',
      GuestServiceMode.preOrder => 'Schedule a pickup for later',
      GuestServiceMode.delivery => mode.hint,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? p.success : p.border,
          width: selected ? 2 : 1,
        ),
        color: p.surface,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          HapticFeedback.selectionClick();
          s.update(() => s.mode = mode);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selected ? p.accent : p.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  GuestConfirmScreen.iconFor(mode),
                  color: selected ? p.onAccent : p.ink,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: p.body(16, weight: FontWeight.w700),
                    ),
                    Text(subtitle, style: p.body(13, color: p.inkMuted)),
                  ],
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Icon(Icons.check_circle_rounded, color: p.success),
              ),
            ],
          ),
        ),
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

/// "Table 12" when the phone was handed to a table; otherwise staff confirm
/// it (and, for a real order, the guest is asked to call them).
class _TableCard extends StatelessWidget {
  const _TableCard();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final s = GuestScope.of(context);
    final label = s.definition.tableLabel;
    if (s.tableName != null) {
      return GuestCard(
        child: Row(
          children: [
            Icon(Icons.table_restaurant_outlined, color: p.inkMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label number',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: p.body(14.5, color: p.inkMuted),
              ),
            ),
            Text(s.tableName!, style: p.body(16, weight: FontWeight.w800)),
          ],
        ),
      );
    }
    return _Note(
      icon: Icons.support_agent_rounded,
      text: s.gateway.isPreview
          ? '$label will be confirmed by our staff.'
          : '$label will be confirmed by our staff. Please call a staff '
                'member to place a dine-in order.',
    );
  }
}

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

/// Name, phone and a short address note — kept deliberately simple.
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard();

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
