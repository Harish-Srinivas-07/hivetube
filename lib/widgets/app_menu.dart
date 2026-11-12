import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'ui/ui.dart';

/// Shared bottom-sheet chrome for player and content menus.
Future<T?> showAppMenu<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  VoidCallback? onBack,
  bool onVideo = false,
}) {
  final theme = onVideo ? AppTheme.dark : Theme.of(context);
  return showAppSheet<T>(
    context,
    fit: true,
    title: title,
    onBack: onBack,
    backgroundColor: theme.colorScheme.surface,
    builder: (sheetContext, _) => Theme(
      data: theme,
      child: builder(sheetContext),
    ),
  );
}

class AppMenuRow extends StatelessWidget {
  const AppMenuRow({
    super.key,
    required this.label,
    this.icon,
    this.value,
    this.subtitle,
    this.onTap,
    this.showChevron = false,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final String? value, subtitle;
  final VoidCallback? onTap;
  final bool showChevron, selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      minLeadingWidth: AppSpacing.xl,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      leading: icon == null
          ? null
          : Icon(icon, color: theme.colorScheme.onSurface),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: selected
          ? Icon(LucideIcons.check, color: theme.colorScheme.onSurface)
          : (value != null || showChevron)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null && value!.isNotEmpty)
                  Flexible(
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (showChevron) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    LucideIcons.chevronRight,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            )
          : null,
      onTap: onTap,
    );
  }
}
