import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_motion.dart';
import 'preview_card_visibility.dart';
import '../../core/providers.dart';
import 'formatters.dart';

String _posterForAnimatedThumbnail(String url, String videoId) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final path = uri.path.toLowerCase();
  final animated =
      path.contains('/an_webp/') ||
      path.endsWith('.webp') ||
      path.endsWith('.gif');
  if (!animated) return url;

  if (uri.host == 'i.ytimg.com' || uri.host == 'img.youtube.com') {
    return 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';
  }
  return uri
      .replace(
        path: uri.path.replaceFirst(RegExp(r'\.(webp|gif)$'), '.jpg'),
        query: null,
      )
      .toString();
}

/// Unified YouTube-style video thumbnail with duration badge and watched progress bar.
class ThumbnailWithDuration extends ConsumerWidget {
  const ThumbnailWithDuration({
    super.key,
    required this.url,
    this.duration = '',
    this.videoId,
    this.progress,
    this.borderRadius,
    this.thumbnailKey,
    this.progressKey,
    this.aspectRatio = AppSpacing.thumbnailRatio,
  });

  final String url;
  final String duration;
  final String? videoId;
  final double? progress;
  final BorderRadius? borderRadius;
  final Key? thumbnailKey;
  final Key? progressKey;
  final double aspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? BorderRadius.zero;
    final preview = PreviewCardScope.maybeOf(context);
    final seconds = duration.isEmpty && videoId != null
        ? ref.watch(videoDurationProvider(videoId!)).value
        : null;
    final displayedDuration = duration.isNotEmpty
        ? duration
        : (seconds != null && seconds > 0
              ? AppFormatters.formatDurationSeconds(seconds)
              : '');
    final imageUrl = preview == null || preview.isActive
        ? url
        : _posterForAnimatedThumbnail(url, preview.videoId);

    return AspectRatio(
      key: thumbnailKey,
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.startsWith('file:'))
              Image.file(
                File.fromUri(Uri.parse(imageUrl)),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: theme.colorScheme.surfaceContainerHigh),
              )
            else if (imageUrl.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) => CachedNetworkImage(
                  imageUrl: imageUrl,
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
            if (displayedDuration.isNotEmpty)
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
                    displayedDuration,
                    style: AppTextStyles.badge.copyWith(
                      color: AppColors.thumbnailBadgeText,
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
