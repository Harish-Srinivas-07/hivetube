import 'package:flutter/material.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../ui/app_controls.dart';

/// Standard error display with message and retry button.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    this.message = 'Something went wrong',
    this.onRetry,
    this.retryLabel = 'Retry',
    this.icon = Icons.error_outline_rounded,
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppLayout.sheetPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSizes.iconLg * 2, color: cs.error),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: retryLabel,
                variant: AppButtonVariant.tonal,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

