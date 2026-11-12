import 'package:flutter/material.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Single snackbar helper. Call anywhere via AppSnackbar.show(context, ...).
abstract final class AppSnackbar {
  static void show(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    bool isError = false,
    Duration duration = AppMotion.slow,
  }) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.md),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
        backgroundColor: isError ? cs.error : null,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }

  static void showError(BuildContext context, String message) =>
      show(context, message, isError: true);
}

/// Standard section divider (hairline, no leading/trailing space).
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: AppSpacing.borderWidth,
      indent: indent,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

