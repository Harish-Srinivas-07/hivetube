import 'package:flutter/material.dart';

class AppColors {
  const AppColors._({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.glassFill,
    required this.glassBorder,
    required this.glowTop,
    required this.progressTrack,
  });

  static const transparent = Colors.transparent;
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const maskOpaque = Color(0xFF000000);
  static const scrim50 = Color(0x80000000);
  static const primary = Color(0xFFFF0033);
  static const onPrimary = Color(0xFFFFFFFF);
  static const success = Color(0xFF2BA640);
  static const warning = Color(0xFFF5A623);
  static const badge = primary;
  static const onBadge = onPrimary;
  static const progressFill = primary;
  static const thumbnailBadge = Color(0xCC000000);
  static const shelfTitleScrim = Color(0xD9000000);
  static const thumbnailBadgeText = Colors.white;
  static const shortsBackground = Color(0xFF000000);
  static const shortsForeground = Color(0xFFFFFFFF);
  static const shortsScrim = Color(0xD9000000);
  static const playerControlGlass = Color(0x73000000);
  static const playerControlBorder = Color(0x33FFFFFF);
  static const shortsNavGlassFill = Color(0x33FFFFFF);
  static const shortsNavGlassBorder = Color(0x66FFFFFF);
  static const shortsProgressTrack = Color(0x33FFFFFF);
  static const shortsProgressBuffer = Color(0x4DFFFFFF);
  static const shortsProgressPlayed = Color(0xFFFF0000);
  static const shortsSelected = Color(0xFFFF0033);
  static const error = Color(0xFFFF4E45);

  static const dark = AppColors._(
    background: Color(0xFF0F0F0F),
    surface: Color(0xFF181818),
    surfaceVariant: Color(0xFF272727),
    textPrimary: Color(0xFFF1F1F1),
    textSecondary: Color(0xFFAAAAAA),
    divider: Color(0xFF303030),
    glassFill: Color(0x1AFFFFFF),
    glassBorder: Color(0x24FFFFFF),
    glowTop: Color(0x50A90022),
    progressTrack: Color(0x80FFFFFF),
  );
  static const light = AppColors._(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF9F9F9),
    surfaceVariant: Color(0xFFF2F2F2),
    textPrimary: Color(0xFF0F0F0F),
    textSecondary: Color(0xFF606060),
    divider: Color(0xFFE5E5E5),
    glassFill: Color(0x0F000000),
    glassBorder: Color(0x1A000000),
    glowTop: Color(0x0FFF0033),
    progressTrack: Color(0x80000000),
  );

  final Color background,
      surface,
      surfaceVariant,
      textPrimary,
      textSecondary,
      divider,
      glassFill,
      glassBorder,
      glowTop,
      progressTrack;
}
