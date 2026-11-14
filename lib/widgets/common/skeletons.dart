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
              width: AppSizes.searchCompactThumbnailWidth,
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
                    width: AppSizes.searchCompactThumbnailWidth,
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
                children: const [
                  SkeletonBox(height: 14, borderRadius: AppRadius.xs),
                  SizedBox(height: AppSpacing.xs),
                  SkeletonBox(
                    width: 160,
                    height: 12,
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
      itemBuilder: (_, _) => Column(
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
      ),
    );
  }
}
