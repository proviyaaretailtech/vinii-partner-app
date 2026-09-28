/// Bill arithmetic — a line-for-line port of the OS's single definition of
/// what a guest owes (Repo-1- `apps/web/src/lib/bill.ts`, `computeBill`).
///
/// The POS, the captain's phone, the guest's phone, the printed bill and the
/// reports must agree to the paisa, so this app does not invent its own
/// maths. Order of operations (an Indian restaurant bill):
///
///   items − discount → + service charge → taxable
///   taxable + SGST + CGST              → gross
///   gross + round-off                  → payable
///
/// Service charge is taxed. Every intermediate is rounded to paise so the
/// displayed lines always add up.
library;

/// `org_bill_settings` for the organization. [defaults] are the OS's
/// `DEFAULT_CHARGES`, used when the organization has no row.
class BillCharges {
  const BillCharges({
    this.sgstPercent = 2.5,
    this.cgstPercent = 2.5,
    this.serviceChargePercent = 0,
    this.roundOff = true,
  });

  static const defaults = BillCharges();

  final double sgstPercent;
  final double cgstPercent;
  final double serviceChargePercent;
  final bool roundOff;

  double get gstPercent => sgstPercent + cgstPercent;

  factory BillCharges.fromRow(Map<String, dynamic>? row) {
    if (row == null) return defaults;
    double n(Object? v, double fb) =>
        v == null ? fb : double.tryParse('$v') ?? fb;
    return BillCharges(
      sgstPercent: n(row['sgst_pct'], 2.5),
      cgstPercent: n(row['cgst_pct'], 2.5),
      serviceChargePercent: n(row['service_charge_pct'], 0),
      roundOff: row['round_off_enabled'] != false,
    );
  }
}

/// JavaScript's `Math.round`: halves go up (towards +∞), unlike Dart's
/// `round()`, which goes away from zero. Matters for negative round-offs.
double _jsRound(num n) => (n + 0.5).floorToDouble();

/// Rounds to paise the way the OS does: `Math.round((n + EPSILON) * 100) / 100`.
double money(num n) => _jsRound((n + 2.220446049250313e-16) * 100) / 100;

class BillSummary {
  const BillSummary._({
    required this.itemTotal,
    required this.discount,
    required this.serviceCharge,
    required this.taxable,
    required this.sgst,
    required this.cgst,
    required this.gross,
    required this.roundOff,
    required this.payable,
    required this.charges,
  });

  factory BillSummary.of(
    Iterable<({num unitPrice, int qty})> lines, {
    BillCharges charges = BillCharges.defaults,
    num discount = 0,
  }) {
    final itemTotal = money(
      lines.fold<num>(0, (sum, l) => sum + l.qty * l.unitPrice),
    );
    // A discount can never exceed the food: a negative bill is a refund.
    final disc = money(discount.clamp(0, itemTotal));
    final net = money(itemTotal - disc);
    final serviceCharge = money(net * charges.serviceChargePercent / 100);
    final taxable = money(net + serviceCharge);
    final sgst = money(taxable * charges.sgstPercent / 100);
    final cgst = money(taxable * charges.cgstPercent / 100);
    final gross = money(taxable + sgst + cgst);
    final roundOff = charges.roundOff ? money(_jsRound(gross) - gross) : 0.0;
    return BillSummary._(
      itemTotal: itemTotal,
      discount: disc,
      serviceCharge: serviceCharge,
      taxable: taxable,
      sgst: sgst,
      cgst: cgst,
      gross: gross,
      roundOff: roundOff,
      payable: money(gross + roundOff),
      charges: charges,
    );
  }

  /// A bill as the server stored it on the order row. Saved orders always
  /// show these figures, never a recomputation, so the phone and the POS
  /// print the same total. The row keeps one GST amount; it is split
  /// half-and-half into SGST and CGST for display.
  factory BillSummary.stored({
    required num itemTotal,
    num discount = 0,
    num serviceCharge = 0,
    required num gst,
    num roundOff = 0,
    required num payable,
    required double gstPercent,
  }) {
    final sgst = money(gst / 2);
    final taxable = money(itemTotal - discount + serviceCharge);
    return BillSummary._(
      itemTotal: money(itemTotal),
      discount: money(discount),
      serviceCharge: money(serviceCharge),
      taxable: taxable,
      sgst: sgst,
      cgst: money(gst - sgst),
      gross: money(taxable + gst),
      roundOff: money(roundOff),
      payable: money(payable),
      charges: BillCharges(
        sgstPercent: gstPercent / 2,
        cgstPercent: gstPercent / 2,
      ),
    );
  }

  final double itemTotal;
  final double discount;
  final double serviceCharge;
  final double taxable;
  final double sgst;
  final double cgst;
  final double gross;
  final double roundOff;
  final double payable;
  final BillCharges charges;

  double get gst => money(sgst + cgst);

  /// "GST (5%)"
  String get gstLabel {
    final p = charges.gstPercent;
    return 'GST (${p % 1 == 0 ? p.toInt() : p}%)';
  }
}

/// A table budget ("Dining with friends? Set a budget"). Pure maths so the
/// guest screens and tests agree on "21% used" and "₹5,560 remaining".
class BudgetStatus {
  const BudgetStatus({required this.budget, required this.spent});

  final double budget;
  final double spent;

  double get remaining => budget - spent;
  double get fraction =>
      budget <= 0 ? 0 : (spent / budget).clamp(0, 1.5).toDouble();
  int get percentUsed => budget <= 0 ? 0 : (spent / budget * 100).round();
  bool get over => spent > budget;

  /// Within 85% counts as "getting close" — the ring turns amber.
  bool get close => !over && fraction >= 0.85;

  double perPerson(int people) => people <= 0 ? budget : budget / people;
}
