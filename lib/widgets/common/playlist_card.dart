import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'thumbnail_with_duration.dart';

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    super.key,
    required this.title,
    required this.thumbnail,
    required this.count,
    required this.onTap,
  });

  final String title;
  final String thumbnail;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: AppSizes.libraryHistoryCardWidth,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ThumbnailWithDuration(
                url: thumbnail,
                borderRadius: AppRadius.mdBorder,
              ),
              Positioned(
                right: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.badgeBg,
                    borderRadius: AppRadius.xsBorder,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.listVideo,
                          size: AppSizes.iconXs,
                          color: AppColors.badgeFg,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '$count',
                          style: AppTextStyles.badge.copyWith(
                            color: AppColors.badgeFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.videoTitle,
          ),
        ],
      ),
    ),
  );
}
