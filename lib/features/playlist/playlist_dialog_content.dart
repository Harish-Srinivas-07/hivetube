import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ui/app_controls.dart';

class PlaylistDialogContent extends StatelessWidget {
  const PlaylistDialogContent({
    super.key,
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.onCancel,
    this.message,
    this.details,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onCancel;
  final String? message;
  final Widget? details;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: AppRadius.xlBorder,
              ),
              child: Icon(icon, size: AppSizes.iconLg, color: colors.onSurface),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.pageTitle,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          if (details != null) ...[
            const SizedBox(height: AppSpacing.lg),
            details!,
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton.filled(
            label: actionLabel,
            size: AppButtonSize.large,
            onPressed: onAction,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton.text(label: 'Cancel', onPressed: onCancel),
        ],
      ),
    );
  }
}
