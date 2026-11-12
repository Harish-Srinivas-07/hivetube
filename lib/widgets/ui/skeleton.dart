import 'package:flutter/material.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';

/// Animated shimmer skeleton for loading states.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppSpacing.sm,
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

/// A skeleton that matches the full video card layout.
class SkeletonVideoCard extends StatelessWidget {
  const SkeletonVideoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 16:9 thumbnail
        AspectRatio(
          aspectRatio: AppSpacing.thumbnailRatio,
          child: SkeletonBox(
            height: double.infinity,
            borderRadius: AppSpacing.md,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            const SkeletonBox(width: 40, height: 40, borderRadius: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(height: 14, borderRadius: AppSpacing.xs),
                  const SizedBox(height: AppSpacing.xs),
                  SkeletonBox(
                    width: 160,
                    height: 12,
                    borderRadius: AppSpacing.xs,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // More button placeholder
            const SkeletonBox(
              width: 24,
              height: 24,
              borderRadius: AppSpacing.xs,
            ),
          ],
        ),
      ],
    );
  }
}

/// Fade-in transition that wraps a child after data loads.
class AppFadeIn extends StatefulWidget {
  const AppFadeIn({super.key, required this.child});
  final Widget child;

  @override
  State<AppFadeIn> createState() => _AppFadeInState();
}

class _AppFadeInState extends State<AppFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppMotion.base)
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _ctrl, child: widget.child);
  }
}
