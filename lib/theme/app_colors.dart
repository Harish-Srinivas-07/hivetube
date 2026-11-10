import 'package:flutter/material.dart';

class AppColors {
  const AppColors._({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
  });

  static const transparent = Colors.transparent;
  static const primary = Color(0xFFFF0033);
  static const onPrimary = Color(0xFFFFFFFF);
  static const success = Color(0xFF2BA640);
  static const warning = Color(0xFFF5A623);
  static const error = Color(0xFFFF4E45);

  static const dark = AppColors._(
    background: Color(0xFF0F0F0F),
    surface: Color(0xFF181818),
    surfaceVariant: Color(0xFF272727),
    textPrimary: Color(0xFFF1F1F1),
    textSecondary: Color(0xFFAAAAAA),
    divider: Color(0xFF303030),
  );
  static const light = AppColors._(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF9F9F9),
    surfaceVariant: Color(0xFFF2F2F2),
    textPrimary: Color(0xFF0F0F0F),
    textSecondary: Color(0xFF606060),
    divider: Color(0xFFE5E5E5),
  );

  final Color background,
      surface,
      surfaceVariant,
      textPrimary,
      textSecondary,
      divider;
}
