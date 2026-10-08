import 'package:flutter/material.dart';

import '../theme/staff_theme.dart';

/// The VINII mark: a rounded tile with a "V" and the brand-green dot.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.inverted = false});

  final double size;

  /// Dark tile on light backgrounds (sign-in), light tile on dark (splash).
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    // On a dark page an ink tile disappears; flip to the light tile.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final light = !inverted || dark;
    final bg = light ? Colors.white : ViniiColors.ink;
    final fg = light ? ViniiColors.ink : Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              'V', // i18n-ignore: brand mark letter
              style: TextStyle(
                color: fg,
                fontSize: size * 0.52,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
          Positioned(
            right: size * 0.16,
            top: size * 0.16,
            child: Container(
              width: size * 0.16,
              height: size * 0.16,
              decoration: const BoxDecoration(
                color: ViniiColors.brandGreen,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
