import 'package:flutter/material.dart';

import '../../application/sell_cart.dart';
import 'pos_widgets.dart';
import 'ticket_view.dart';

/// Review before the order is saved: quantities, notes, who it is for, and
/// the *estimated* bill, with "Send to kitchen" and "Save & hold" at the
/// bottom. The work is done by [TicketView], the same view that sits beside
/// the menu on a tablet or counter computer.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final SellCart _cart = sellCartOf(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review order')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: TicketView(cart: _cart),
        ),
      ),
    );
  }
}
