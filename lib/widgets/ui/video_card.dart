import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/db/app_db.dart';
import '../../core/yt/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../video_options_menu.dart';
import 'app_controls.dart';

/// The canonical video card used throughout the app.
/// [compact] = list row (thumbnail left, text right).
/// default = full-bleed phone feed card (thumbnail top).
class VideoCard extends ConsumerWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.progress,
    this.trailing,
    this.compact = false,
    this.showAvatar = true,
    this.roundedThumbnail = false,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final double? progress;
  final Widget? trailing;
  final bool compact;
  final bool showAvatar;

  /// true = rounded thumbnail corners (grids), false = full-bleed (feed)
  final bool roundedThumbnail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) return _CompactCard(video: video, onTap: onTap, trailing: trailing);
    return _FeedCard(
      video: video,
      onTap: onTap,
      progress: progress,
      trailing: trailing,
      showAvatar: showAvatar,
      roundedThumbnail: roundedThumbnail,
      ref: ref,
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.url,
    required this.duration,
    this.progress,
    this.borderRadius,
  });

  final String url;
  final String duration;
  final double? progress;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: AppSpacing.thumbnailRatio,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                color: theme.colorScheme.surfaceContainerHigh,
                child: const Icon(LucideIcons.imageOff, color: AppColors.shortsProgressTrack),
              ),
            ),
            if (duration.isNotEmpty)
              Positioned(
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: _DurationBadge(duration),
              ),
            if (progress != null && progress! > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: AppSizes.progressBarHeight,
                  color: AppColors.progressFill,
                  backgroundColor: AppColors.thumbnailBadge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.thumbnailBadge,
        borderRadius: AppRadius.xsBorder,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.thumbnailBadgeText,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.video,
    required this.onTap,
    this.progress,
    this.trailing,
    this.showAvatar = true,
    this.roundedThumbnail = false,
    required this.ref,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final double? progress;
  final Widget? trailing;
  final bool showAvatar;
  final bool roundedThumbnail;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: roundedThumbnail ? AppRadius.mdBorder : BorderRadius.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Thumbnail(
            url: video.thumbUrl,
            duration: video.durationText,
            progress: progress,
            borderRadius: roundedThumbnail ? AppRadius.mdBorder : null,
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAvatar && (video.channelId.isNotEmpty || video.channelName.isNotEmpty)) ...[
                  GestureDetector(
                    onTap: video.channelId.isNotEmpty
                        ? () => context.push('/channel/${video.channelId}')
                        : null,
                    child: AppAvatar(
                      name: video.channelName,
                      url: video.channelAvatarUrl,
                      size: AppSizes.avatar,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: _TextBlock(
                    video: video,
                    onChannelTap: video.channelId.isNotEmpty
                        ? () => context.push('/channel/${video.channelId}')
                        : null,
                    theme: theme,
                    cs: cs,
                  ),
                ),
                trailing ??
                    SizedBox.square(
                      dimension: AppSizes.touchMin,
                      child: IconButton(
                        icon: const Icon(LucideIcons.ellipsisVertical,
                            size: AppSizes.iconSm),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => showVideoOptionsMenu(
                          context,
                          videoId: video.id,
                          ref: ref,
                          media: MediaCompanion.insert(
                            videoId: video.id,
                            title: video.title,
                            channelId: video.channelId,
                            channelName: video.channelName,
                            thumbUrl: video.thumbUrl,
                            updatedAt: DateTime.now().millisecondsSinceEpoch,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCard extends StatelessWidget {
  const _CompactCard({
    required this.video,
    required this.onTap,
    this.trailing,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: SizedBox(
        width: 120,
        child: _Thumbnail(
          url: video.thumbUrl,
          duration: video.durationText,
          borderRadius: AppRadius.smBorder,
        ),
      ),
      title: Text(
        video.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        [video.channelName, video.viewsText, video.publishedText]
            .where((s) => s.isNotEmpty)
            .join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: trailing,
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.video,
    this.onChannelTap,
    required this.theme,
    required this.cs,
  });

  final VideoItem video;
  final VoidCallback? onChannelTap;
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          video.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xxs),
        GestureDetector(
          onTap: onChannelTap,
          child: Text(
            [video.channelName, video.viewsText, video.publishedText]
                .where((s) => s.isNotEmpty)
                .join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

