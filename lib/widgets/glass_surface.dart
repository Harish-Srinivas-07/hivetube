import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.fill,
  });
  final Widget child;
  final BorderRadius borderRadius;
  final Color? fill;
  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<HiveGlass>()!;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: glass.blurSigma,
          sigmaY: glass.blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill ?? glass.glassFill,
            borderRadius: borderRadius,
            border: Border.all(
              color: glass.glassBorder,
              width: AppSpacing.borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
