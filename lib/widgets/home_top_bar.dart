import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'glass_surface.dart';
import 'hive_logo.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, this.notificationCount = 0});
  final int notificationCount;
  @override
  Widget build(BuildContext context) {
    final desktop =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Expanded(child: HiveLogo()),
          if (!desktop) ...[
            _GlassButton(icon: LucideIcons.cast, tooltip: 'Cast', onTap: () {}),
            const SizedBox(width: AppSpacing.sm),
          ],
          Stack(
            clipBehavior: Clip.none,
            children: [
              _GlassButton(
                icon: LucideIcons.bell,
                tooltip: 'Notifications',
                onTap: () {},
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    key: const ValueKey('notificationBadge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.badge,
                      borderRadius: AppRadius.pillBorder,
                    ),
                    child: Text(
                      '$notificationCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.onBadge,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          _GlassButton(
            icon: LucideIcons.search,
            tooltip: 'Search',
            onTap: () => context.push('/search'),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GlassSurface(
    borderRadius: AppRadius.pillBorder,
    child: SizedBox(
      width: AppSpacing.topButton,
      height: AppSpacing.topButton,
      child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon)),
    ),
  );
}
