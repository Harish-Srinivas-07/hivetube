import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class _Block extends StatelessWidget {
  const _Block({
    required this.animation,
    required this.width,
    required this.height,
    this.radius = AppRadius.xsBorder,
  });
  final Animation<double> animation;
  final double width;
  final double height;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Color.lerp(
            colors.shimmerBase,
            colors.shimmerHighlight,
            MediaQuery.disableAnimationsOf(context) ? 0 : animation.value,
          ),
          borderRadius: radius,
        ),
      ),
    );
  }
}

class LibraryHeaderSkeleton extends StatelessWidget {
  const LibraryHeaderSkeleton({super.key, required this.animation});
  final Animation<double> animation;

  double _buttonWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: AppTextStyles.buttonLabel),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width + AppSpacing.lg * 2;
    painter.dispose();
    return width < AppSizes.buttonCompact ? AppSizes.buttonCompact : width;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _Block(
            animation: animation,
            width: AppSizes.avatarLg,
            height: AppSizes.avatarLg,
            radius: AppRadius.pillBorder,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Block(
                  animation: animation,
                  width: AppSizes.libraryHistoryCardWidth,
                  height: AppTextStyles.pageTitle.fontSize!,
                ),
                const SizedBox(height: AppSpacing.xxs),
                _Block(
                  animation: animation,
                  width: AppSizes.libraryHistoryCardWidth,
                  height: AppTextStyles.meta.fontSize!,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        children: [
          _Block(
            animation: animation,
            width: _buttonWidth(context, 'Edit profile'),
            height: AppSizes.buttonCompact,
            radius: AppRadius.pillBorder,
          ),
          _Block(
            animation: animation,
            width: _buttonWidth(context, 'Backup'),
            height: AppSizes.buttonCompact,
            radius: AppRadius.pillBorder,
          ),
        ],
      ),
    ],
  );
}

class LibraryShelfSkeleton extends StatelessWidget {
  const LibraryShelfSkeleton({super.key, required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: _Block(
          animation: animation,
          width: AppSizes.libraryHistoryCardWidth,
          height: AppTextStyles.sectionTitle.fontSize!,
        ),
      ),
      SizedBox(
        height: AppSizes.libraryHistoryCardWidth + AppSpacing.md,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: 3,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: SizedBox(
              width: AppSizes.libraryHistoryCardWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Block(
                    animation: animation,
                    width: AppSizes.libraryHistoryCardWidth,
                    height:
                        AppSizes.libraryHistoryCardWidth / AppSizes.thumbRatio,
                    radius: AppRadius.mdBorder,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Block(
                    animation: animation,
                    width: AppSizes.libraryHistoryCardWidth,
                    height: AppTextStyles.videoTitle.fontSize!,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _Block(
                    animation: animation,
                    width: AppSizes.libraryHistoryCardWidth / 2,
                    height: AppTextStyles.meta.fontSize!,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class LibraryRowSkeleton extends StatelessWidget {
  const LibraryRowSkeleton({super.key, required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppSizes.settingsRowHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _Block(
            animation: animation,
            width: AppSizes.icon,
            height: AppSizes.icon,
          ),
          const SizedBox(width: AppSpacing.lg),
          _Block(
            animation: animation,
            width: AppSizes.libraryHistoryCardWidth,
            height: AppTextStyles.settingsTitle.fontSize!,
          ),
        ],
      ),
    ),
  );
}
