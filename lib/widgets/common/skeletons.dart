import 'package:flutter/material.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Animated shimmer placeholder box for loading states.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppMotion.shimmer)
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest;
    final highlight = cs.surfaceContainerHigh;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(base, highlight, _anim.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// A skeleton matching the full video card layout (thumbnail, avatar, title lines).
class VideoSkeleton extends StatelessWidget {
  const VideoSkeleton({
    super.key,
    this.compact = false,
    this.searchResult = false,
  });

  final bool compact;
  final bool searchResult;

  @override
  Widget build(BuildContext context) {
    if (searchResult) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: AspectRatio(
                aspectRatio: AppSpacing.thumbnailRatio,
                child: SkeletonBox(
                  height: double.infinity,
                  borderRadius: AppRadius.md,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(
                    width: AppSizes.searchResultAvatar,
                    height: AppSizes.searchResultAvatar,
                    borderRadius: AppSizes.searchResultAvatar / 2,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(
                          height: AppTextStyles.body.fontSize!,
                          borderRadius: AppRadius.xs,
                        ),
                        SizedBox(height: AppSpacing.xs),
                        SkeletonBox(
                          height: AppTextStyles.body.fontSize!,
                          borderRadius: AppRadius.xs,
                        ),
                        SizedBox(height: AppSpacing.xxs),
                        SkeletonBox(
                          height: AppTextStyles.label.fontSize!,
                          borderRadius: AppRadius.xs,
                        ),
                        SizedBox(height: AppSpacing.xxs),
                        SkeletonBox(
                          height: AppTextStyles.label.fontSize!,
                          borderRadius: AppRadius.xs,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox.square(
                    dimension: AppSizes.touchMin,
                    child: Center(
                      child: SkeletonBox(
                        width: AppSizes.iconSm,
                        height: AppSizes.iconSm,
                        borderRadius: AppRadius.pill,
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

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: AppSizes.compactThumbW,
              child: const AspectRatio(
                aspectRatio: AppSpacing.thumbnailRatio,
                child: SkeletonBox(
                  height: double.infinity,
                  borderRadius: AppRadius.sm,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    height: AppTextStyles.body.fontSize!,
                    borderRadius: AppRadius.xs,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  SkeletonBox(
                    width: AppSizes.compactThumbW,
                    height: AppTextStyles.label.fontSize!,
                    borderRadius: AppRadius.xs,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AspectRatio(
          aspectRatio: AppSpacing.thumbnailRatio,
          child: SkeletonBox(
            height: double.infinity,
            borderRadius: AppRadius.md,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(
              width: AppSizes.avatar,
              height: AppSizes.avatar,
              borderRadius: AppSizes.avatar / 2,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    height: AppTextStyles.body.fontSize!,
                    borderRadius: AppRadius.xs,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  SkeletonBox(
                    width: AppSizes.libraryHistoryCardWidth,
                    height: AppTextStyles.label.fontSize!,
                    borderRadius: AppRadius.xs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Backward compatibility alias for [VideoSkeleton].
typedef SkeletonVideoCard = VideoSkeleton;

/// Loading placeholders for the subscriptions channel strip.
class ChannelStripSkeleton extends StatelessWidget {
  const ChannelStripSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height:
        AppSizes.subscriptionsAvatar +
        AppSpacing.xs +
        AppSizes.iconXs +
        AppSpacing.sm * 2,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xxs),
      itemBuilder: (_, _) => SizedBox(
        width: AppSizes.subscriptionsChannelWidth,
        child: Column(
          children: [
            SkeletonBox(
              width: AppSizes.subscriptionsAvatar,
              height: AppSizes.subscriptionsAvatar,
              borderRadius: AppSizes.subscriptionsAvatar / 2,
            ),
            const SizedBox(height: AppSpacing.xs),
            const SkeletonBox(width: AppSizes.avatar, height: AppSizes.iconXs),
          ],
        ),
      ),
    ),
  );
}

/// A full-page scrolling skeleton feed.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xl),
      itemBuilder: (_, _) => const _FeedSkeletonCard(),
    );
  }
}

/// Sliver form for screens that compose FeedSkeleton into a CustomScrollView.
class FeedSkeletonSliver extends StatelessWidget {
  const FeedSkeletonSliver({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) => SliverList.builder(
    itemCount: count * 2 - 1,
    itemBuilder: (_, index) => index.isOdd
        ? const SizedBox(height: AppSpacing.xl)
        : const _FeedSkeletonCard(),
  );
}

class _FeedSkeletonCard extends StatelessWidget {
  const _FeedSkeletonCard();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const AspectRatio(
        aspectRatio: AppSpacing.thumbnailRatio,
        child: SkeletonBox(
          height: double.infinity,
          borderRadius: AppRadius.none,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(
              width: AppSizes.searchResultAvatar,
              height: AppSizes.searchResultAvatar,
              borderRadius: AppSizes.searchResultAvatar / 2,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    height: AppTextStyles.body.fontSize!,
                    borderRadius: AppRadius.xs,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SkeletonBox(
                    width: AppSizes.libraryHistoryCardWidth,
                    height: AppTextStyles.label.fontSize!,
                    borderRadius: AppRadius.xs,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.buttonIcon),
          ],
        ),
      ),
    ],
  );
}

class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton({super.key, this.rowCount = 6, this.bottomPadding = 0});

  final int rowCount;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.only(bottom: bottomPadding),
    children: [
      for (var index = 0; index < rowCount; index++) ...[
        if (index == 0 || index == rowCount ~/ 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SkeletonBox(
              width: AppSizes.compactThumbW / 2,
              height: AppTextStyles.sectionTitle.fontSize!,
              borderRadius: AppRadius.xs,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              const SizedBox(
                width: AppSizes.compactThumbW,
                child: AspectRatio(
                  aspectRatio: AppSpacing.thumbnailRatio,
                  child: SkeletonBox(
                    height: double.infinity,
                    borderRadius: AppRadius.sm,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(
                      height: AppTextStyles.videoTitle.fontSize!,
                      borderRadius: AppRadius.xs,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SkeletonBox(
                      width: AppSizes.compactThumbW,
                      height: AppTextStyles.meta.fontSize!,
                      borderRadius: AppRadius.xs,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.buttonIcon),
            ],
          ),
        ),
      ],
    ],
  );
}

class PlaylistScreenSkeleton extends StatelessWidget {
  const PlaylistScreenSkeleton({super.key, this.bottomPadding = 0});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: EdgeInsets.only(bottom: bottomPadding),
    children: [
      Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AspectRatio(
          aspectRatio: AppSpacing.thumbnailRatio,
          child: SkeletonBox(
            height: double.infinity,
            borderRadius: AppRadius.md,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(
              width: AppSizes.compactThumbW,
              height: AppTextStyles.pageTitle.fontSize!,
            ),
            const SizedBox(height: AppSpacing.xs),
            SkeletonBox(
              width: AppSizes.libraryHistoryCardWidth,
              height: AppTextStyles.meta.fontSize!,
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            const Expanded(child: SkeletonBox(height: AppSizes.buttonStandard)),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: SkeletonBox(height: AppSizes.buttonStandard)),
            const SizedBox(width: AppSpacing.sm),
            SkeletonBox(
              width: AppSizes.buttonIconTouch,
              height: AppSizes.buttonIconTouch,
              borderRadius: AppRadius.pill,
            ),
          ],
        ),
      ),
      for (var index = 0; index < 5; index++)
        const VideoSkeleton(compact: true),
    ],
  );
}

class PlaylistSheetSkeleton extends StatelessWidget {
  const PlaylistSheetSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < count; index++)
        SizedBox(
          height: AppSizes.settingsRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                SkeletonBox(
                  width: AppSizes.icon,
                  height: AppSizes.icon,
                  borderRadius: AppRadius.xs,
                ),
                const SizedBox(width: AppSpacing.xxl),
                Expanded(
                  child: SkeletonBox(
                    width: AppSizes.compactThumbW,
                    height: AppTextStyles.settingsTitle.fontSize!,
                  ),
                ),
                const SizedBox(width: AppSizes.icon),
                SkeletonBox(
                  width: AppSizes.icon,
                  height: AppSizes.icon,
                  borderRadius: AppRadius.xs,
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
