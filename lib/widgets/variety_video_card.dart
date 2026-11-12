import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/db/app_db.dart';
import '../core/yt/models.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'common.dart';
import 'video_options_menu.dart';

class VarietyVideoCard extends ConsumerWidget {
  const VarietyVideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.trailing,
    this.progress,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final Widget? trailing;
  final double? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbnail with duration overlay
          AspectRatio(
            aspectRatio: AppSpacing.thumbnailRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: const Icon(LucideIcons.imageOff),
                    ),
                  ),
                  if (video.durationText.isNotEmpty)
                    Positioned(
                      right: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          video.durationText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
                        value: progress,
                        minHeight: AppSpacing.progressHeight,
                        color: theme.colorScheme.primary,
                        backgroundColor: Colors.black45,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (video.channelId.isNotEmpty || video.channelName.isNotEmpty) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    onTap: video.channelId.isNotEmpty
                        ? () => context.push('/channel/${video.channelId}')
                        : null,
                    child: Avatar(
                      name: video.channelName,
                      url: video.channelAvatarUrl,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      InkWell(
                        onTap: video.channelId.isNotEmpty
                            ? () => context.push('/channel/${video.channelId}')
                            : null,
                        child: Text(
                          [video.channelName, video.viewsText, video.publishedText]
                              .where((s) => s.isNotEmpty)
                              .join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    IconButton(
                      icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
