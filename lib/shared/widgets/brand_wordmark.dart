import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/brand.dart';

/// Logotipo tipográfico "Carajás360 · SERVIÇOS LOCAIS".
class BrandWordmark extends StatelessWidget {
  final double size;
  final bool onDark;
  const BrandWordmark({super.key, this.size = 24, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final dark = onDark || Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: AppInfo.name,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: 'Carajás',
                  style: TextStyle(color: dark ? Colors.white : Brand.green)),
              TextSpan(
                  text: '360',
                  style: TextStyle(color: dark ? Brand.gold : Brand.goldDeep)),
            ]),
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                height: 1),
          ),
          const SizedBox(height: 3),
          Text('SERVIÇOS LOCAIS',
              style: TextStyle(
                  fontSize: size * 0.36,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                  color: dark
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppColors.textLight)),
        ],
      ),
    );
  }
}
