import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/yt/models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'thumbnail_with_duration.dart';
import '../video_options_menu.dart';

class ShortsShelf extends StatelessWidget {
  const ShortsShelf({
    super.key,
    required this.items,
    required this.onTap,
    this.cardWidth = AppSpacing.homeShortWidth,
  });
  final List<ShortItem> items;
  final ValueChanged<int> onTap;
  final double cardWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, _) {
      final itemWidth = cardWidth;
      final itemHeight =
          itemWidth / AppSpacing.homeShortRatio +
          MediaQuery.textScalerOf(context).scale(AppSizes.listRowHeight);

      Widget shortCard(int index) {
        final item = items[index];
        final suppliedUrl = item.thumbUrl;
        final preferredUrl = preferredYoutubeThumbnailUrl(suppliedUrl, item.id);

        Widget image(
          String url, {
          bool allowFallback = true,
        }) => CachedNetworkImage(
          key: ValueKey(
            'shortsShelfThumbnail:${item.id}:${allowFallback ? 'preferred' : 'fallback'}',
          ),
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: (itemWidth * MediaQuery.devicePixelRatioOf(context))
              .round(),
          maxWidthDiskCache:
              (itemWidth * MediaQuery.devicePixelRatioOf(context)).round(),
          fadeInDuration: AppMotion.imageFade,
          placeholder: (_, _) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          errorWidget: (_, _, _) => allowFallback && preferredUrl != suppliedUrl
              ? image(suppliedUrl, allowFallback: false)
              : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
        );

        return InkWell(
          onTap: () => onTap(index),
          child: SizedBox(
            width: itemWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.mdBorder,
                  child: AspectRatio(
                    aspectRatio: AppSpacing.homeShortRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        image(preferredUrl),
                        Positioned(
                          right: AppSpacing.xs,
                          top: AppSpacing.xs,
                          child: IconButton(
                            tooltip: 'More options',
                            onPressed: () =>
                                showVideoOptionsMenu(context, videoId: item.id),
                            icon: const Icon(
                              LucideIcons.ellipsisVertical,
                              color: AppColors.shortsForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.title ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.homeShortTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if ((item.viewsText ?? '').isNotEmpty)
                  Text(
                    item.viewsText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const Icon(LucideIcons.clapperboard, size: AppSizes.icon),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Shorts',
                  style: AppTextStyles.homeShelfTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: itemHeight * 2 + AppSpacing.sm,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: itemWidth,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
              ),
              itemCount: items.length,
              itemBuilder: (_, index) => shortCard(index),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      );
    },
  );
}
