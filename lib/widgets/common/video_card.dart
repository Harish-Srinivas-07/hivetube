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
import '../../theme/app_text_styles.dart';
import '../../features/home/home_controller.dart';
import '../video_options_menu.dart';
import 'channel_avatar.dart';
import 'thumbnail_with_duration.dart';

String _feedThumbnail(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      (uri.host != 'i.ytimg.com' && uri.host != 'img.youtube.com')) {
    return url;
  }
  return url.replaceFirst(
    RegExp(r'/(?:hqdefault|default)\.jpg(?=\?|$)'),
    '/mqdefault.jpg',
  );
}

/// Display presentation mode for [VideoCard].
enum VideoCardMode {
  /// Full-bleed mobile feed card (thumbnail top, avatar + metadata bottom).
  feed,

  /// Compact horizontal list row (thumbnail left, text right).
  compact,

  /// Grid card with rounded thumbnail corners.
  grid,

  /// Stacked YouTube mobile search result card.
  searchResult,

  /// Rounded card for a horizontal shelf.
  shelf,
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
    this.thumbnailBadge,
    this.enabled = true,
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
  }) : mode = VideoCardMode.feed,
       enabled = true,
       thumbnailBadge = null,
       compact = null,
       roundedThumbnail = null;

  /// Factory for a compact horizontal row card.
  const VideoCard.compact({
    super.key,
    required this.video,
    required this.onTap,
    this.progress,
    this.trailing,
    this.thumbnailBadge,
    this.enabled = true,
  }) : mode = VideoCardMode.compact,
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
  }) : mode = VideoCardMode.grid,
       enabled = true,
       thumbnailBadge = null,
       compact = null,
       roundedThumbnail = null;

  /// Stacked card used by search results.
  const VideoCard.searchResult({
    super.key,
    required this.video,
    required this.onTap,
  }) : mode = VideoCardMode.searchResult,
       compact = null,
       roundedThumbnail = null,
       progress = null,
       trailing = null,
       thumbnailBadge = null,
       enabled = true,
       showAvatar = true;

  const VideoCard.shelf({
    super.key,
    required this.video,
    required this.onTap,
    this.progress,
  }) : mode = VideoCardMode.shelf,
       showAvatar = false,
       trailing = null,
       thumbnailBadge = null,
       enabled = true,
       compact = null,
       roundedThumbnail = null;

  final VideoItem video;
  final VoidCallback onTap;
  final VideoCardMode mode;
  final double? progress;
  final Widget? trailing;
  final String? thumbnailBadge;
  final bool enabled;
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
      case VideoCardMode.shelf:
        return RepaintBoundary(
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThumbnailWithDuration(
                  url: video.thumbUrl,
                  duration: video.durationText,
                  progress: progress,
                  borderRadius: AppRadius.mdBorder,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.videoTitle,
                ),
                Text(
                  video.channelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.meta.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      case VideoCardMode.compact:
        return _CompactCard(
          video: video,
          onTap: onTap,
          progress: progress,
          trailing: trailing,
          thumbnailBadge: thumbnailBadge,
          enabled: enabled,
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
      case VideoCardMode.searchResult:
        return _SearchResultCard(video: video, onTap: onTap, ref: ref);
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
            url: roundedThumbnail
                ? video.thumbUrl
                : _feedThumbnail(video.thumbUrl),
            duration: video.durationText,
            progress: progress,
            borderRadius: roundedThumbnail ? AppRadius.mdBorder : null,
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.xl,
              left: AppSpacing.md,
              right: AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAvatar &&
                    (video.channelId.isNotEmpty ||
                        video.channelName.isNotEmpty)) ...[
                  _FeedAvatar(video: video),
                  const SizedBox(width: AppSpacing.md),
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
                      dimension: AppSizes.buttonIcon,
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
                          video: video,
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

class _FeedAvatar extends ConsumerWidget {
  const _FeedAvatar({required this.video});
  final VideoItem video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = video.channelAvatarUrl.isEmpty
        ? ref
              .watch(
                channelAvatarProvider((
                  channelId: video.channelId,
                  videoId: video.channelId.isEmpty ? video.id : '',
                )),
              )
              .value
        : null;
    final channelId = resolved?.channelId ?? video.channelId;
    return ChannelAvatar(
      name: video.channelName,
      url: resolved?.url ?? video.channelAvatarUrl,
      size: AppSizes.searchResultAvatar,
      onTap: channelId.isNotEmpty
          ? () => context.push('/channel/$channelId')
          : null,
    );
  }
}

class _CompactCard extends StatelessWidget {
  const _CompactCard({
    required this.video,
    required this.onTap,
    this.progress,
    this.trailing,
    this.thumbnailBadge,
    required this.enabled,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final double? progress;
  final Widget? trailing;
  final String? thumbnailBadge;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      horizontalTitleGap: AppSpacing.md,
      minLeadingWidth: 0,
      minTileHeight: AppSizes.compactRowMinHeight,
      leading: SizedBox(
        width: AppSizes.compactThumbW,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (enabled)
              ThumbnailWithDuration(
                thumbnailKey: ValueKey('compactThumbnail:${video.id}'),
                progressKey: ValueKey('watchedProgress:${video.id}'),
                url: video.thumbUrl,
                duration: video.durationText,
                progress: progress,
                borderRadius: AppRadius.smBorder,
              )
            else
              ClipRRect(
                borderRadius: AppRadius.smBorder,
                child: ColoredBox(color: cs.surfaceContainerHighest),
              ),
            if (thumbnailBadge != null)
              Positioned(
                top: AppSpacing.xs,
                left: AppSpacing.xs,
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
                    thumbnailBadge!,
                    style: AppTextStyles.badge.copyWith(
                      color: AppColors.thumbnailBadgeText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Text(
        video.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: enabled
            ? AppTextStyles.videoTitle
            : AppTextStyles.videoTitle.copyWith(color: cs.onSurfaceVariant),
      ),
      subtitle: Text(
        [
          video.channelName,
          video.viewsText,
          video.publishedText,
        ].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.meta.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: trailing,
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.video,
    required this.onTap,
    required this.ref,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = [
      video.channelName,
      video.viewsText,
      video.publishedText,
    ].where((value) => value.isNotEmpty).join(' · ');

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ThumbnailWithDuration(
              thumbnailKey: ValueKey('searchThumbnail:${video.id}'),
              progressKey: ValueKey('watchedProgress:${video.id}'),
              url: video.thumbUrl,
              duration: video.durationText,
              borderRadius: AppRadius.mdBorder,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChannelAvatar(
                  name: video.channelName,
                  url: video.channelAvatarUrl,
                  size: AppSizes.searchResultAvatar,
                  onTap: video.channelId.isEmpty
                      ? null
                      : () => context.push('/channel/${video.channelId}'),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          metadata,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox.square(
                  dimension: AppSizes.touchMin,
                  child: IconButton(
                    tooltip: 'More options',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      LucideIcons.ellipsisVertical,
                      size: AppSizes.iconSm,
                    ),
                    onPressed: () => showVideoOptionsMenu(
                      context,
                      videoId: video.id,
                      ref: ref,
                      video: video,
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
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
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
          style: AppTextStyles.feedTitle.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: AppSpacing.xxs),
        GestureDetector(
          onTap: onChannelTap,
          child: Text(
            [
              video.channelName,
              video.viewsText,
              video.publishedText,
            ].where((s) => s.isNotEmpty).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.feedMeta.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
