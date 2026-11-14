import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_motion.dart';

/// Unified YouTube-style video thumbnail with duration badge and watched progress bar.
class ThumbnailWithDuration extends StatelessWidget {
  const ThumbnailWithDuration({
    super.key,
    required this.url,
    this.duration = '',
    this.progress,
    this.borderRadius,
    this.thumbnailKey,
    this.progressKey,
    this.aspectRatio = AppSpacing.thumbnailRatio,
  });

  final String url;
  final String duration;
  final double? progress;
  final BorderRadius? borderRadius;
  final Key? thumbnailKey;
  final Key? progressKey;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? BorderRadius.zero;

    return AspectRatio(
      key: thumbnailKey,
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) => CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      (constraints.maxWidth *
                              MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                  maxWidthDiskCache:
                      (constraints.maxWidth *
                              MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                  fadeInDuration: AppMotion.imageFade,
                  errorWidget: (_, _, _) => Container(
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: const Center(
                      child: Icon(
                        LucideIcons.imageOff,
                        color: AppColors.shortsProgressTrack,
                        size: AppSizes.icon,
                      ),
                    ),
                  ),
                  placeholder: (_, _) =>
                      Container(color: theme.colorScheme.surfaceContainerHigh),
                ),
              )
            else
              Container(
                color: theme.colorScheme.surfaceContainerHigh,
                child: const Center(
                  child: Icon(
                    LucideIcons.video,
                    color: AppColors.shortsProgressTrack,
                    size: AppSizes.icon,
                  ),
                ),
              ),
            if (duration.isNotEmpty)
              Positioned(
                right: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.thumbnailBadge,
                    borderRadius: AppRadius.xsBorder,
                  ),
                  child: Text(
                    duration,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.thumbnailBadgeText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (progress != null && progress! > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  key: progressKey,
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: AppSizes.progressBarHeight,
                  color: theme.colorScheme.primary,
                  backgroundColor: AppColors.thumbnailBadge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
