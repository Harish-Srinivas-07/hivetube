import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_sizes.dart';
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
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge,
        toolbarHeight: AppSizes.appBarHeight,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.pillBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.pillBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.pillBorder,
          borderSide: BorderSide(color: AppColors.primary, width: AppSpacing.borderWidth),
        ),
        hintStyle: AppTextStyles.body.copyWith(color: colors.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceVariant,
        selectedColor: colors.textPrimary,
        labelStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        elevation: 0,
        pressElevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: AppSpacing.borderWidth,
        space: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        indicatorColor: AppColors.transparent,
        selectedIconTheme: IconThemeData(color: colors.textPrimary, size: AppSizes.icon),
        unselectedIconTheme: IconThemeData(color: colors.textSecondary, size: AppSizes.icon),
        selectedLabelTextStyle: AppTextStyles.label.copyWith(color: colors.textPrimary),
        unselectedLabelTextStyle: AppTextStyles.label.copyWith(color: colors.textSecondary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        thumbColor: AppColors.primary,
        inactiveTrackColor: colors.surfaceVariant,
        trackHeight: AppSizes.seekBarHeight,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: AppSizes.seekBarThumb / 2),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: AppSizes.seekBarThumbPressed / 2),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTopBorder),
        elevation: 0,
        modalElevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSizes.buttonHeight, AppSizes.buttonHeight),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSizes.buttonHeight, AppSizes.buttonHeight),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizes.buttonHeight, AppSizes.buttonHeight),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppSizes.touchMin, AppSizes.touchMin),
          iconSize: AppSizes.icon,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceVariant,
        contentTextStyle: text.bodyMedium?.copyWith(color: colors.textPrimary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        iconColor: colors.textSecondary,
        style: ListTileStyle.list,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
