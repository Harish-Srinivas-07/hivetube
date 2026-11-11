import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class HiveLogo extends StatelessWidget {
  const HiveLogo({super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(
        width: AppSpacing.logoMark,
        height: AppSpacing.logoMark,
        child: CustomPaint(painter: _HiveMark()),
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
  );
}

class _HiveMark extends CustomPainter {
  const _HiveMark();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final outline = Path()
      ..moveTo(w * AppSpacing.logoMiddle, h * AppSpacing.logoTop)
      ..lineTo(w * AppSpacing.logoRight, h * AppSpacing.logoSide)
      ..lineTo(w * AppSpacing.logoRight, h * AppSpacing.logoRight)
      ..lineTo(w * AppSpacing.logoMiddle, h * AppSpacing.logoBottom)
      ..lineTo(w * AppSpacing.logoSide, h * AppSpacing.logoRight)
      ..lineTo(w * AppSpacing.logoSide, h * AppSpacing.logoSide)
      ..close();
    canvas.drawPath(
      outline,
      Paint()
        ..color = AppColors.primary
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = w * AppSpacing.logoCorner
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(outline, Paint()..color = AppColors.primary);
    final play = Path()
      ..moveTo(w * AppSpacing.logoPlayLeft, h * AppSpacing.logoPlayTop)
      ..lineTo(w * AppSpacing.logoPlayRight, h * AppSpacing.logoMiddle)
      ..lineTo(w * AppSpacing.logoPlayLeft, h * AppSpacing.logoPlayBottom)
      ..close();
    canvas.drawPath(play, Paint()..color = AppColors.onPrimary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
