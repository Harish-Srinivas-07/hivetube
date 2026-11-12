import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

class HiveLogo extends StatelessWidget {
  const HiveLogo({super.key});
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand/logo.png',
          width: AppSpacing.logoMark,
          height: AppSpacing.logoMark,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'HiveTube',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w800,
            fontVariations: const [FontVariation('wght', 800)],
          ),
        ),
      ],
    ),
  );
}
