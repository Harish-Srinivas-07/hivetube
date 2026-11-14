import 'package:flutter/material.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';

/// Standard empty state display with icon, title, description, and action button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(
          compact ? AppSpacing.md : AppLayout.sheetPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? AppSizes.icon : AppSizes.iconLg * 2,
              color: cs.onSurfaceVariant,
            ),
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.lg),
            Text(
              title,
              style: compact
                  ? theme.textTheme.bodyMedium
                  : theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
              maxLines: compact ? 1 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
            ),
            if (!compact && message != null && message!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onAction != null && actionLabel != null) ...[
              SizedBox(height: compact ? AppSpacing.xs : AppSpacing.xl),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
