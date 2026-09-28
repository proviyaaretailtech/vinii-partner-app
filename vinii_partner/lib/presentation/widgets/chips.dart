import 'package:flutter/material.dart';

import '../../domain/delivery_order.dart';
import '../../domain/menu.dart';
import '../../domain/organization.dart';
import '../../domain/pos_order.dart';
import '../theme/staff_theme.dart';

/// A small rounded status label ("New", "Preparing", "Ready").
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  factory StatusChip.delivery(BuildContext context, DeliveryStatus s) {
    final t = ViniiTokens.of(context);
    final color = switch (s) {
      DeliveryStatus.placed => t.info,
      DeliveryStatus.accepted => t.warning,
      DeliveryStatus.packed => t.success,
      DeliveryStatus.out => ViniiColors.purple,
      DeliveryStatus.delivered => t.inkMuted,
      DeliveryStatus.cancelled => t.danger,
    };
    return StatusChip(label: s.label, color: color);
  }

  factory StatusChip.pos(BuildContext context, PosStatus s) {
    final t = ViniiTokens.of(context);
    final color = switch (s) {
      PosStatus.fresh || PosStatus.inBilling => t.info,
      PosStatus.sentToKitchen => t.warning,
      PosStatus.ready => t.success,
      PosStatus.awaitingPayment => ViniiColors.purple,
      PosStatus.paid || PosStatus.delivered => t.inkMuted,
      PosStatus.cancelled => t.danger,
    };
    return StatusChip(label: s.label, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: t.tint(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Indian veg / non-veg / egg mark: a square with a dot or triangle.
class FoodTypeMark extends StatelessWidget {
  const FoodTypeMark(this.type, {super.key, this.size = 14});
  final FoodType? type;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (type == null) return const SizedBox.shrink();
    final color = switch (type!) {
      FoodType.veg => const Color(0xFF16A34A),
      FoodType.nonVeg => const Color(0xFFB91C1C),
      FoodType.egg => const Color(0xFFD97706),
    };
    return Semantics(
      label: type!.label,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.18),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.4),
          borderRadius: BorderRadius.circular(3),
          color: Colors.white,
        ),
        child: type == FoodType.nonVeg
            ? CustomPaint(painter: _Triangle(color))
            : DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
      ),
    );
  }
}

class _Triangle extends CustomPainter {
  _Triangle(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(s.width / 2, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Triangle old) => old.color != color;
}

/// The organization's badge: its initials on its brand colour.
class OrgAvatar extends StatelessWidget {
  const OrgAvatar(this.org, {super.key, this.size = 44});
  final Organization org;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = ViniiTokens.of(context);
    final bg = org.accent ?? t.ink;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        org.initials,
        style: TextStyle(
          color: onColor(bg),
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
