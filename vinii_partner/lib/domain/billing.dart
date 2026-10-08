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
    this.waivedServiceCharge = 0,
    this.serviceChargeWaived = false,
  });

  /// [waiveServiceCharge] takes the service charge off this bill (a manager
  /// removing it at the final order). The amount that was taken off is kept
  /// in [waivedServiceCharge] so the screen can show it struck through.
  factory BillSummary.of(
    Iterable<({num unitPrice, int qty})> lines, {
    BillCharges charges = BillCharges.defaults,
    num discount = 0,
    bool waiveServiceCharge = false,
  }) {
    final itemTotal = money(
      lines.fold<num>(0, (sum, l) => sum + l.qty * l.unitPrice),
    );
    // A discount can never exceed the food: a negative bill is a refund.
    final disc = money(discount.clamp(0, itemTotal));
    final net = money(itemTotal - disc);
    final fullServiceCharge = money(net * charges.serviceChargePercent / 100);
    final serviceCharge = waiveServiceCharge ? 0.0 : fullServiceCharge;
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
      waivedServiceCharge: waiveServiceCharge ? fullServiceCharge : 0,
      serviceChargeWaived: waiveServiceCharge && fullServiceCharge > 0,
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
    num waivedServiceCharge = 0,
    bool serviceChargeWaived = false,
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
      waivedServiceCharge: money(waivedServiceCharge),
      serviceChargeWaived: serviceChargeWaived || waivedServiceCharge > 0,
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

  /// The service charge that was taken off this bill, or 0 when none was or
  /// when the server did not say how much.
  final double waivedServiceCharge;

  /// True when the service charge was removed from this bill.
  final bool serviceChargeWaived;

  double get gst => money(sgst + cgst);

  /// The service charge percentage this bill carries. A saved order does not
  /// keep the percentage, so it is worked back from the amounts.
  double get servicePercent {
    if (charges.serviceChargePercent > 0) return charges.serviceChargePercent;
    final base = money(itemTotal - discount);
    if (serviceCharge <= 0 || base <= 0) return 0;
    return (serviceCharge / base * 10000).round() / 100;
  }

  /// "5", "2.5": the GST percentage as a plain number, for a screen to put
  /// into its own translated sentence ("GST ({percent}%)").
  String get gstPercentText {
    final p = charges.gstPercent;
    return '${p % 1 == 0 ? p.toInt() : p}';
  }

  /// "GST (5%)"
  // i18n-ignore: English fallback for logs/tests; screens use gstPercentText
  String get gstLabel => 'GST ($gstPercentText%)';
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

/// The whole `org_bill_settings` row: the tax and charge rates that
/// [BillCharges] carries, plus what is printed at the top and bottom of a
/// bill. This is what the Bill & GST screen edits.
class BillSettings {
  const BillSettings({
    this.legalName = '',
    this.address = '',
    this.gstin = '',
    this.fssai = '',
    this.phone = '',
    this.sgstPercent = 2.5,
    this.cgstPercent = 2.5,
    this.serviceChargePercent = 0,
    this.roundOff = true,
    this.footerNote = '',
    this.updatedAt,
  });

  /// What a restaurant has before anyone saves: the OS's own defaults.
  static const defaults = BillSettings();

  final String legalName;
  final String address;
  final String gstin;
  final String fssai;
  final String phone;
  final double sgstPercent;
  final double cgstPercent;

  /// 0 means no service charge.
  final double serviceChargePercent;
  final bool roundOff;
  final String footerNote;

  /// `updated_at` exactly as the server sent it; null when the organization
  /// has no settings row yet. It goes back with a save, so a screen that has
  /// gone stale cannot overwrite what someone else saved meanwhile.
  final String? updatedAt;

  /// False until the first save creates the row.
  bool get exists => updatedAt != null;

  double get gstPercent => sgstPercent + cgstPercent;

  BillCharges get charges => BillCharges(
    sgstPercent: sgstPercent,
    cgstPercent: cgstPercent,
    serviceChargePercent: serviceChargePercent,
    roundOff: roundOff,
  );

  factory BillSettings.fromRow(Map<String, dynamic>? row) {
    if (row == null) return defaults;
    String text(Object? v) => v == null ? '' : '$v'.trim();
    double n(Object? v, double fallback) =>
        v == null ? fallback : double.tryParse('$v') ?? fallback;
    return BillSettings(
      legalName: text(row['legal_name']),
      address: text(row['address']),
      gstin: text(row['gstin']).toUpperCase(),
      fssai: text(row['fssai']),
      phone: text(row['phone']),
      sgstPercent: n(row['sgst_pct'], 2.5),
      cgstPercent: n(row['cgst_pct'], 2.5),
      serviceChargePercent: n(row['service_charge_pct'], 0),
      roundOff: row['round_off_enabled'] != false,
      footerNote: text(row['footer_note']),
      updatedAt: row['updated_at'] == null ? null : '${row['updated_at']}',
    );
  }

  /// The row to write. Empty text is stored as null, never as blank spaces.
  /// `updated_at` is left to the database trigger.
  Map<String, dynamic> toRow(String organizationId) {
    String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
    return {
      'organization_id': organizationId,
      'legal_name': orNull(legalName),
      'address': orNull(address),
      'gstin': orNull(gstin.toUpperCase()),
      'fssai': orNull(fssai),
      'phone': orNull(phone),
      'sgst_pct': sgstPercent,
      'cgst_pct': cgstPercent,
      'service_charge_pct': serviceChargePercent,
      'round_off_enabled': roundOff,
      'footer_note': orNull(footerNote),
    };
  }

  BillSettings copyWith({
    String? legalName,
    String? address,
    String? gstin,
    String? fssai,
    String? phone,
    double? sgstPercent,
    double? cgstPercent,
    double? serviceChargePercent,
    bool? roundOff,
    String? footerNote,
    String? updatedAt,
  }) => BillSettings(
    legalName: legalName ?? this.legalName,
    address: address ?? this.address,
    gstin: gstin ?? this.gstin,
    fssai: fssai ?? this.fssai,
    phone: phone ?? this.phone,
    sgstPercent: sgstPercent ?? this.sgstPercent,
    cgstPercent: cgstPercent ?? this.cgstPercent,
    serviceChargePercent: serviceChargePercent ?? this.serviceChargePercent,
    roundOff: roundOff ?? this.roundOff,
    footerNote: footerNote ?? this.footerNote,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Same values, ignoring which version of the row they came from.
  bool sameValuesAs(BillSettings o) =>
      legalName.trim() == o.legalName.trim() &&
      address.trim() == o.address.trim() &&
      gstin.trim().toUpperCase() == o.gstin.trim().toUpperCase() &&
      fssai.trim() == o.fssai.trim() &&
      phone.trim() == o.phone.trim() &&
      toPaiseOf(sgstPercent) == toPaiseOf(o.sgstPercent) &&
      toPaiseOf(cgstPercent) == toPaiseOf(o.cgstPercent) &&
      toPaiseOf(serviceChargePercent) == toPaiseOf(o.serviceChargePercent) &&
      roundOff == o.roundOff &&
      footerNote.trim() == o.footerNote.trim();

  /// Two decimals are all `numeric(5, 2)` keeps, so compare that way.
  static int toPaiseOf(double percent) => (percent * 100).round();
}

/// What is wrong with a field of the Bill & GST screen. A CODE, not a
/// sentence: the screen turns it into words in the reader's language.
enum BillProblem {
  /// The custom GST rate is not a number from 0 to 100 with one decimal.
  customRate,

  /// The service charge is ON but its percentage is not above 0 up to the
  /// highest allowed ([maxServiceChargePercent]).
  servicePercent,

  /// The GSTIN is not the standard 15-character shape.
  gstinShape,

  /// The FSSAI number is not 14 digits.
  fssaiDigits,

  /// The bill phone does not have 10 to 13 digits.
  phoneDigits,
}

/// The highest service charge the screen accepts, in percent.
const maxServiceChargePercent = 50.0;

final _gstinShape = RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');

/// Why a GSTIN cannot be saved, or null when it is fine (or left empty). The
/// standard 15-character shape: state code, PAN, entity number, "Z", check
/// character. Letters are upper-cased before the check.
BillProblem? gstinProblem(String raw) {
  final v = raw.trim().toUpperCase();
  if (v.isEmpty) return null;
  return _gstinShape.hasMatch(v) ? null : BillProblem.gstinShape;
}

/// An FSSAI licence number is 14 digits.
BillProblem? fssaiProblem(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  return RegExp(r'^\d{14}$').hasMatch(v) ? null : BillProblem.fssaiDigits;
}

/// A phone for the bill header: 10 to 13 digits (with or without +91).
BillProblem? billPhoneProblem(String raw) {
  if (raw.trim().isEmpty) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '').length;
  return digits >= 10 && digits <= 13 ? null : BillProblem.phoneDigits;
}

/// "2.5", "5", "7.5" — a percentage without trailing zeros (never "5.0").
String formatPercent(double p) {
  final fixed = p.toStringAsFixed(2);
  final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed.isEmpty ? '0' : trimmed;
}
