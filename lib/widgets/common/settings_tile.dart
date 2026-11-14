import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.value,
    this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      minTileHeight: AppSizes.settingsRowHeight,
      horizontalTitleGap: AppSpacing.xl,
      leading: Icon(icon, size: AppSizes.icon, color: colors.onSurfaceVariant),
      title: Text(
        title,
        style: AppTextStyles.settingsTitle.copyWith(color: colors.onSurface),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.settingsSub.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
      trailing: value == null
          ? Icon(
              LucideIcons.chevronRight,
              size: AppSizes.iconSm,
              color: colors.onSurfaceVariant,
            )
          : Switch(value: value!, onChanged: onChanged),
      onTap: value == null ? onTap : () => onChanged?.call(!value!),
    );
  }
}
