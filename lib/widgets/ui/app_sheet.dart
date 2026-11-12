import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../glass_surface.dart';

/// Standard bottom sheet wrapper with drag handle, xl top radius, safe area.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.child,
    this.title,
    this.showHandle = true,
  });

  final Widget child;
  final String? title;
  final bool showHandle;

  /// Open this sheet using the standard show method.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: AppColors.transparent,
      builder: (_) => AppSheet(title: title, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mq = MediaQuery.of(context);

    return GlassSurface(
      borderRadius: AppRadius.sheetTopBorder,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppLayout.sheetPadding,
          AppSpacing.md,
          AppLayout.sheetPadding,
          AppLayout.sheetPadding + mq.padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHandle)
              Center(
                child: Container(
                  width: AppSpacing.contentSheetHandleWidth,
                  height: AppSpacing.contentSheetHandleHeight,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
            if (title != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(title!, style: theme.textTheme.titleLarge),
            ],
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// Standard dialog wrapper with rounded corners and consistent padding.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    required this.content,
    this.actions,
  });

  final String? title;
  final Widget content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppLayout.sheetPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
            ],
            content,
            if (actions != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final a in actions!)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: a,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

