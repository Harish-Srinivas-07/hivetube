import 'package:flutter/material.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../features/watch/mini_player_inset.dart';

/// Single snackbar helper. Call anywhere via AppSnackbar.show(context, ...).
abstract final class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    bool isError = false,
    Duration duration = AppMotion.snackbar,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final snackbarBg = isDark
        ? AppColors.snackbarDark
        : AppColors.snackbarLight;
    final snackbarFg = isDark ? AppColors.black : AppColors.white;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.body.copyWith(color: snackbarFg),
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + MiniPlayerInset.of(context),
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
        backgroundColor: snackbarBg,
        elevation: 0,
        width: AppSizes.snackbarMaxWidth,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel,
                textColor: snackbarFg,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  static void showError(BuildContext context, String message) =>
      show(context, message, isError: true);
}
