import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/presentation/guest/guest_effects.dart';

void main() {
  const origin = Offset(200, 300);

  test('confetti starts at its origin', () {
    final at = confettiAt(origin, -pi / 2, 500, 0);
    expect(at.dx, closeTo(origin.dx, 1e-9));
    expect(at.dy, closeTo(origin.dy, 1e-9));
  });

  test(
    'a piece fired upward rises first, then falls past where it started',
    () {
      final early = confettiAt(origin, -pi / 2, 600, 0.25);
      expect(early.dy, lessThan(origin.dy), reason: 'still rising');

      final late = confettiAt(origin, -pi / 2, 600, 3);
      expect(late.dy, greaterThan(origin.dy), reason: 'it came back down');
    },
  );

  test('every piece ends up falling, whatever way it was fired', () {
    for (final angle in [-0.3, -pi / 4, -pi / 2, -2.5]) {
      for (final speed in [260.0, 540.0, 820.0]) {
        final a = confettiAt(origin, angle, speed, 2.5);
        final b = confettiAt(origin, angle, speed, 3.0);
        expect(b.dy, greaterThan(a.dy), reason: 'angle $angle speed $speed');
        expect(a.dx.isFinite && a.dy.isFinite, isTrue);
      }
    }
  });
}
