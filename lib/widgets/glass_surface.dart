import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

// allowed: floating nav
class GlassSurface extends StatelessWidget {
  // allowed: floating nav
  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.fill,
    this.borderColor,
  });
  final Widget child;
  final BorderRadius borderRadius;
  final Color? fill;
  final Color? borderColor;
  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<HiveGlass>()!;
    return ClipRRect(
      borderRadius: borderRadius,
      // allowed: floating nav
      child: BackdropFilter(
        // allowed: floating nav
        filter: ImageFilter.blur(
          sigmaX: glass.blurSigma,
          sigmaY: glass.blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill ?? glass.glassFill,
            borderRadius: borderRadius,
            border: Border.all(
              color: borderColor ?? glass.glassBorder,
              width: AppSpacing.borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
