import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
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
    this.blurSigma,
    this.borderWidth,
    this.border,
  });
  final Widget child;
  final BorderRadius borderRadius;
  final Color? fill;
  final Color? borderColor;
  final double? blurSigma;
  final double? borderWidth;
  final Border? border;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = theme.brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final glass = theme.extension<HiveGlass>();
    return ClipRRect(
      borderRadius: borderRadius,
      // allowed: floating nav
      child: BackdropFilter(
        // allowed: floating nav
        filter: ImageFilter.blur(
          sigmaX: blurSigma ?? glass?.blurSigma ?? AppSpacing.glassBlur,
          sigmaY: blurSigma ?? glass?.blurSigma ?? AppSpacing.glassBlur,
          tileMode: TileMode.clamp,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill ?? glass?.glassFill ?? fallback.glassFill,
            borderRadius: borderRadius,
            border:
                border ??
                Border.all(
                  color: borderColor ?? glass?.glassBorder ?? fallback.glassBorder,
                  width: borderWidth ?? AppSpacing.borderWidth,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}
