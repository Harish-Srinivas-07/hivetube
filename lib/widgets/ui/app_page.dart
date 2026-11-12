import 'package:flutter/material.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_spacing.dart';

/// Wraps a screen with correct safe area, gutters, and optional max content width.
/// All screens should be wrapped in AppPage instead of raw Scaffold/SafeArea.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = AppLayout.maxContentWidth,
    this.applyTopSafeArea = true,
    this.applyBottomSafeArea = true,
    this.bottomInset = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;
  final bool applyTopSafeArea;
  final bool applyBottomSafeArea;

  /// Extra bottom inset beyond safe area (e.g. nav pill + mini player height).
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final gutter = AppLayout.pageGutter(context);
    final effectivePadding = padding ??
        EdgeInsets.fromLTRB(
          gutter,
          applyTopSafeArea ? 0 : 0,
          gutter,
          bottomInset,
        );

    Widget content = Padding(padding: effectivePadding, child: child);

    if (maxWidth < double.infinity) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content,
        ),
      );
    }

    return SafeArea(
      top: applyTopSafeArea,
      bottom: applyBottomSafeArea,
      child: content,
    );
  }
}

/// A labelled section with optional "See all" action and consistent vertical gaps.
class AppSection extends StatelessWidget {
  const AppSection({
    super.key,
    this.title,
    this.onSeeAll,
    this.seeAllLabel = 'See all',
    required this.child,
    this.topGap = true,
  });

  final String? title;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;
  final Widget child;
  final bool topGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (topGap) const SizedBox(height: AppLayout.sectionGap),
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    child: Text(seeAllLabel),
                  ),
              ],
            ),
          ),
        child,
      ],
    );
  }
}

