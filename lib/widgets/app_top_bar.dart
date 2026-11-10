import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.searchMaxWidth,
                ),
                child: Material(
                  color: colors.surfaceContainerHighest,
                  borderRadius: AppRadius.pillBorder,
                  child: InkWell(
                    borderRadius: AppRadius.pillBorder,
                    onTap: () => context.push('/search'),
                    child: SizedBox(
                      height: AppSpacing.searchHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.search,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Search HiveTube',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          CircleAvatar(
            radius: AppRadius.lg,
            backgroundColor: colors.surfaceContainerHighest,
            child: IconButton(
              onPressed: () {},
              icon: const Icon(LucideIcons.user),
              padding: EdgeInsets.zero,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
