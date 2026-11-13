import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/db/app_db.dart';
import '../../core/yt/models.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../video_options_menu.dart';
import 'channel_avatar.dart';
import 'thumbnail_with_duration.dart';

/// Display presentation mode for [VideoCard].
enum VideoCardMode {
  /// Full-bleed mobile feed card (thumbnail top, avatar + metadata bottom).
  feed,

  /// Compact horizontal list row (thumbnail left, text right).
  compact,

  /// Grid card with rounded thumbnail corners.
  grid,
}

/// Canonical, unified VideoCard component used across all surfaces.
class VideoCard extends ConsumerWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.mode = VideoCardMode.feed,
    this.progress,
    this.trailing,
    this.showAvatar = true,
    this.compact,
    this.roundedThumbnail,
  });

  /// Factory for a standard feed card.
  const VideoCard.feed({
    super.key,
    required this.video,
    required this.onTap,
    this.progress,
    this.trailing,
    this.showAvatar = true,
  })  : mode = VideoCardMode.feed,
        compact = null,
        roundedThumbnail = null;

  /// Factory for a compact horizontal row card.
  const VideoCard.compact({
    super.key,
    required this.video,
    required this.onTap,
    this.progress,
    this.trailing,
  })  : mode = VideoCardMode.compact,
        showAvatar = false,
        compact = null,
        roundedThumbnail = null;

  /// Factory for a grid card with rounded thumbnail corners.
  const VideoCard.grid({
    super.key,
    required this.video,
    required this.onTap,
    this.progress,
    this.trailing,
    this.showAvatar = true,
  })  : mode = VideoCardMode.grid,
        compact = null,
        roundedThumbnail = null;

  final VideoItem video;
  final VoidCallback onTap;
  final VideoCardMode mode;
  final double? progress;
  final Widget? trailing;
  final bool showAvatar;

  /// Backward-compatibility parameters:
  final bool? compact;
  final bool? roundedThumbnail;

  VideoCardMode get _effectiveMode {
    if (compact == true) return VideoCardMode.compact;
    if (roundedThumbnail == true) return VideoCardMode.grid;
    return mode;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (_effectiveMode) {
      case VideoCardMode.compact:
        return _CompactCard(
          video: video,
          onTap: onTap,
          progress: progress,
          trailing: trailing,
        );
      case VideoCardMode.grid:
        return _FeedCard(
          video: video,
          onTap: onTap,
          progress: progress,
          trailing: trailing,
          showAvatar: showAvatar,
          roundedThumbnail: true,
          ref: ref,
        );
      case VideoCardMode.feed:
        return _FeedCard(
          video: video,
          onTap: onTap,
          progress: progress,
          trailing: trailing,
          showAvatar: showAvatar,
          roundedThumbnail: false,
          ref: ref,
        );
    }
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
          ThumbnailWithDuration(
            thumbnailKey: ValueKey('homeThumbnail:${video.id}'),
            progressKey: ValueKey('watchedProgress:${video.id}'),
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
                if (showAvatar &&
                    (video.channelId.isNotEmpty || video.channelName.isNotEmpty)) ...[
                  ChannelAvatar(
                    name: video.channelName,
                    url: video.channelAvatarUrl,
                    size: AppSizes.avatar,
                    onTap: video.channelId.isNotEmpty
                        ? () => context.push('/channel/${video.channelId}')
                        : null,
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
                        icon: const Icon(
                          LucideIcons.ellipsisVertical,
                          size: AppSizes.icon,
                        ),
                        tooltip: 'More options',
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
    this.progress,
    this.trailing,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final double? progress;
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
        child: ThumbnailWithDuration(
          thumbnailKey: ValueKey('compactThumbnail:${video.id}'),
          progressKey: ValueKey('watchedProgress:${video.id}'),
          url: video.thumbUrl,
          duration: video.durationText,
          progress: progress,
          borderRadius: AppRadius.smBorder,
        ),
      ),
      title: Text(
        video.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        [video.channelName, video.viewsText, video.publishedText]
            .where((s) => s.isNotEmpty)
            .join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: cs.onSurfaceVariant,
        ),
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
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        GestureDetector(
          onTap: onChannelTap,
          child: Text(
            [video.channelName, video.viewsText, video.publishedText]
                .where((s) => s.isNotEmpty)
                .join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
