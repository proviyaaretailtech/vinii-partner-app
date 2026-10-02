import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/pos_order.dart';

/// What the server said about a coupon code for this cart.
@immutable
class CouponResult {
  const CouponResult.valid({
    required this.code,
    required this.discount,
    this.label,
  }) : valid = true,
       message = null;

  const CouponResult.invalid({this.code = '', required String this.message})
    : valid = false,
      discount = 0,
      label = null;

  final bool valid;

  /// The code as the server knows it (trimmed, upper case).
  final String code;

  /// Rupees off the food, as the SERVER worked it out for this cart. The
  /// phone only shows it; the order is priced again when it is placed.
  final double discount;

  /// A short description for the guest ("10% off, up to ₹100"), when given.
  final String? label;

  /// Why a code does not apply, in the guest's words (when [valid] is false).
  final String? message;
}

/// Coupon codes at checkout. The phone sends the code and the cart (intent,
/// ids and quantities) and the SERVER decides: whether the code exists, is
/// in date, fits this order, and how much it takes off. Null on every real
/// gateway until the server function exists (docs/GUEST_SERVER_CONTRACT.md),
/// and then the coupon row is not shown at all.
abstract class GuestCoupons {
  const GuestCoupons();

  /// Checks [code] against [lines]. Throws only for a broken connection;
  /// a code that does not apply comes back as [CouponResult.invalid].
  Future<CouponResult> check({
    required String code,
    required List<CartLine> lines,
    required ServiceType serviceType,
  });
}
