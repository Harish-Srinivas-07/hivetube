import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text_styles.dart';
import 'app_spacing.dart';

class HiveGlass extends ThemeExtension<HiveGlass> {
  const HiveGlass({
    required this.blurSigma,
    required this.glassFill,
    required this.glassBorder,
    required this.glow,
  });
  final double blurSigma;
  final Color glassFill, glassBorder;
  final Gradient glow;
  @override
  HiveGlass copyWith({
    double? blurSigma,
    Color? glassFill,
    Color? glassBorder,
    Gradient? glow,
  }) => HiveGlass(
    blurSigma: blurSigma ?? this.blurSigma,
    glassFill: glassFill ?? this.glassFill,
    glassBorder: glassBorder ?? this.glassBorder,
    glow: glow ?? this.glow,
  );
  @override
  HiveGlass lerp(covariant HiveGlass? other, double t) => other == null
      ? this
      : HiveGlass(
          blurSigma: blurSigma + (other.blurSigma - blurSigma) * t,
          glassFill: Color.lerp(glassFill, other.glassFill, t)!,
          glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
          glow: Gradient.lerp(glow, other.glow, t)!,
        );
}

abstract final class AppTheme {
  static final light = _build(AppColors.light, Brightness.light);
  static final dark = _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.primary,
      onSecondary: AppColors.onPrimary,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.surfaceVariant,
      onSurfaceVariant: colors.textSecondary,
      outline: colors.divider,
    );
    final text = TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      headlineMedium: AppTextStyles.headline,
      titleLarge: AppTextStyles.title,
      titleSmall: AppTextStyles.titleSmall,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.label,
      labelSmall: AppTextStyles.caption,
    ).apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary);
    return ThemeData(
      useMaterial3: true,
      extensions: [
        HiveGlass(
          blurSigma: AppSpacing.glassBlur,
          glassFill: colors.glassFill,
          glassBorder: colors.glassBorder,
          glow: RadialGradient(
            center: Alignment.topCenter,
            radius: AppSpacing.glowRadius,
            colors: [colors.glowTop, AppColors.transparent],
          ),
        ),
      ],
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: colors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceVariant,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide.none,
        ),
        hintStyle: AppTextStyles.body.copyWith(color: colors.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceVariant,
        selectedColor: AppColors.primary,
        labelStyle: text.labelLarge,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
      ),
      dividerTheme: DividerThemeData(color: colors.divider),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        indicatorColor: AppColors.transparent,
        selectedIconTheme: IconThemeData(color: colors.textPrimary),
        unselectedIconTheme: IconThemeData(color: colors.textSecondary),
        selectedLabelTextStyle: AppTextStyles.label.copyWith(
          color: colors.textPrimary,
        ),
        unselectedLabelTextStyle: AppTextStyles.label.copyWith(
          color: colors.textSecondary,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        inactiveTrackColor: colors.surfaceVariant,
      ),
    );
  }
}
