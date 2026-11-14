import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'glass_surface.dart';

class FloatingNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final double? iconSize;
  final bool showBadge;

  const FloatingNavItem(
    this.label,
    this.icon, {
    IconData? activeIcon,
    this.iconSize,
    this.showBadge = false,
  }) : activeIcon = activeIcon ?? icon;
}

class FloatingNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int>? onDragSelected;
  final bool inverted;
  final List<FloatingNavItem> items;

  const FloatingNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    this.onDragSelected,
    this.inverted = false,
    required this.items,
  });

  @override
  State<FloatingNav> createState() => _FloatingNavState();
}

class _FloatingNavState extends State<FloatingNav> {
  double _indicatorLeft = 0;
  double _indicatorWidth = 0;
  bool _isDragging = false;
  double _dragX = 0;
  double _dragOffset = 0;
  int _hoverIndex = 0;

  bool _showText = true;

  @override
  void initState() {
    super.initState();
    _hoverIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(FloatingNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && !_isDragging) {
      _hoverIndex = widget.currentIndex;
    }
  }

  bool _isTabExpanded(int i, double maxWidth) {
    if (_isDragging) return false;
    if (i != widget.currentIndex || !_showText) return false;
    final collapsedTotal =
        widget.items.length * _getTabWidth(0, false, maxWidth) +
        (widget.items.length - 1) * 8.0;
    final expandedExtra =
        _getTabWidth(i, true, maxWidth) - _getTabWidth(i, false, maxWidth);
    return (collapsedTotal + expandedExtra) <= maxWidth;
  }

  double _getTabWidth(int index, bool expanded, double maxWidth) {
    final item = widget.items[index];
    double width = 24.0; // padding horizontal (12 * 2)
    width += item.iconSize ?? 22.0; // must match the rendered Icon's size

    if (expanded) {
      width += 8.0; // spacing (AppSpacing.sm)

      // textScaler is not optional: main.dart clamps to 2.0x, and measuring the
      // label at 1.0x makes _isTabExpanded expand a tab that cannot fit.
      final textPainter = TextPainter(
        text: TextSpan(
          text: item.label,
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
            // allowed: floating nav
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();

      width +=
          textPainter.width +
          2.0; // buffer — TextPainter underestimates real RenderParagraph by ~1px depending on font hinting
    }

    return width;
  }

  List<double> _calculateItemLefts(double maxWidth) {
    final lefts = <double>[];
    double currentLeft =
        4.0; // Start offset due to Padding(horizontal: 4) on items
    for (int i = 0; i < widget.items.length; i++) {
      lefts.add(currentLeft);
      final itemWidth = _getTabWidth(i, _isTabExpanded(i, maxWidth), maxWidth);
      currentLeft += itemWidth + 8.0; // item width + gap of 8.0
    }
    return lefts;
  }

  int _getNearestIndex(double x, double maxWidth) {
    final lefts = _calculateItemLefts(maxWidth);
    int nearest = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < widget.items.length; i++) {
      final itemWidth = _getTabWidth(i, _isTabExpanded(i, maxWidth), maxWidth);
      final itemCenter = lefts[i] + (itemWidth / 2);
      final dist = (x - itemCenter).abs();
      if (dist < minDistance) {
        minDistance = dist;
        nearest = i;
      }
    }
    return nearest;
  }

  void _handleDragStart(DragStartDetails details, double maxWidth) {
    setState(() {
      _showText = false;
      _isDragging = true;
      _hoverIndex = widget.currentIndex;
    });

    final lefts = _calculateItemLefts(maxWidth);
    final currentWidth = _getTabWidth(widget.currentIndex, false, maxWidth);
    final currentCenter = lefts[widget.currentIndex] + (currentWidth / 2);

    setState(() {
      _dragX = details.localPosition.dx;
      _dragOffset = details.localPosition.dx - currentCenter;
      _indicatorLeft = lefts[widget.currentIndex];
      _indicatorWidth = currentWidth;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxWidth) {
    setState(() {
      _dragX = details.localPosition.dx;
      final adjustedX = _dragX - _dragOffset;

      final lefts = _calculateItemLefts(maxWidth);
      final targetWidth = _getTabWidth(
        0,
        false,
        maxWidth,
      ); // Collapsed width is uniform (46.0)

      final minCenter = lefts.first + (_getTabWidth(0, false, maxWidth) / 2);
      final maxCenter =
          lefts.last +
          (_getTabWidth(widget.items.length - 1, false, maxWidth) / 2);
      final clampedX = adjustedX.clamp(minCenter, maxCenter);

      _hoverIndex = _getNearestIndex(clampedX, maxWidth);
      _indicatorLeft = clampedX - (targetWidth / 2);
      _indicatorWidth = targetWidth;
    });
  }

  void _handleDragEnd(DragEndDetails details, double maxWidth) {
    final lefts = _calculateItemLefts(maxWidth);
    if (lefts.isEmpty) {
      setState(() {
        _isDragging = false;
        _showText = true;
      });
      return;
    }
    final adjustedX = _dragX - _dragOffset;
    final minCenter = lefts.first + (_getTabWidth(0, false, maxWidth) / 2);
    final maxCenter =
        lefts.last +
        (_getTabWidth(widget.items.length - 1, false, maxWidth) / 2);
    final clampedX = adjustedX.clamp(minCenter, maxCenter);

    final nearestIndex = _getNearestIndex(clampedX, maxWidth);
    (widget.onDragSelected ?? widget.onSelected)(nearestIndex);

    setState(() {
      _isDragging = false;
      _hoverIndex = nearestIndex;
      _showText = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    const indicatorColor = AppColors.primary;
    const indicatorText = AppColors.onPrimary;
    final idleColor = widget.inverted
        ? AppColors.shortsProgressBuffer
        : colors.textSecondary;
    return AnimatedSize(
      duration: AppMotion.slow,
      curve: AppMotion.enter,
      child: Container(
        key: const ValueKey('floatingNavSurface'),
        decoration: BoxDecoration(
          color: widget.inverted
              ? AppColors.shortsNavGlassFill
              : colors.surface.withValues(alpha: 0.72),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: widget.inverted
                ? AppColors.shortsNavGlassBorder
                : colors.glassBorder,
            width: 1.0,
          ),
          // allowed: floating nav
          boxShadow: const [
            // allowed: floating nav
            BoxShadow(
              color: AppColors.playerControlBorder,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        // allowed: floating nav
        child: GlassSurface(
          borderRadius: AppRadius.pillBorder,
          fill: AppColors.transparent,
          borderColor: AppColors.transparent,
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final activeIdx = _isDragging
                    ? _hoverIndex
                    : widget.currentIndex;
                final lefts = _calculateItemLefts(maxWidth);

                final double targetLeft = lefts[activeIdx];
                final double targetWidth = _getTabWidth(
                  activeIdx,
                  _isTabExpanded(activeIdx, maxWidth),
                  maxWidth,
                );

                final double left = _isDragging ? _indicatorLeft : targetLeft;
                final double width = _isDragging
                    ? _indicatorWidth
                    : targetWidth;

                final lastItemWidth = _getTabWidth(
                  widget.items.length - 1,
                  _isTabExpanded(widget.items.length - 1, maxWidth),
                  maxWidth,
                );
                final totalRowWidth = math.min(
                  lefts.last + lastItemWidth + 4.0,
                  maxWidth,
                );

                return GestureDetector(
                  onHorizontalDragStart: (details) =>
                      _handleDragStart(details, maxWidth),
                  onHorizontalDragUpdate: (details) =>
                      _handleDragUpdate(details, maxWidth),
                  onHorizontalDragEnd: (details) =>
                      _handleDragEnd(details, maxWidth),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: Center(
                      widthFactor: 1.0,
                      child: SizedBox(
                        width: totalRowWidth,
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: _isDragging
                                  ? Duration.zero
                                  : AppMotion.slow,
                              curve: AppMotion.enter,
                              left: left,
                              width: width,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                key: const ValueKey('floatingNavIndicator'),
                                decoration: const BoxDecoration(
                                  color: indicatorColor,
                                  borderRadius: AppRadius.pillBorder,
                                ),
                              ),
                            ),
                            // Nav Items Row wrapped in FittedBox to prevent overflow
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(widget.items.length, (
                                  i,
                                ) {
                                  final item = widget.items[i];
                                  final isUnderIndicator = activeIdx == i;
                                  final isSelected = widget.currentIndex == i;
                                  final showLabel = _isTabExpanded(i, maxWidth);

                                  final Color contentColor = isUnderIndicator
                                      ? indicatorText
                                      : idleColor;

                                  final iconData = isUnderIndicator
                                      ? item.activeIcon
                                      : (isSelected
                                            ? item.activeIcon
                                            : item.icon);

                                  return Tooltip(
                                    message: item.label,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: GestureDetector(
                                        onTap: () => widget.onSelected(i),
                                        behavior: HitTestBehavior.opaque,
                                        child: ClipRect(
                                          child: AnimatedContainer(
                                            duration: AppMotion.base,
                                            curve: Curves.easeInOut,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.md,
                                              vertical: AppSpacing.sm,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: AppColors.transparent,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    Icon(
                                                      iconData,
                                                      size: item.iconSize ?? 22,
                                                      color: contentColor,
                                                    ),
                                                    if (item.showBadge)
                                                      Positioned(
                                                        right: -2,
                                                        top: -2,
                                                        child: Container(
                                                          width: 8,
                                                          height: 8,
                                                          decoration: BoxDecoration(
                                                            color:
                                                                AppColors.badge,
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color: AppColors
                                                                  .onBadge,
                                                              width: 1.5,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                AnimatedCrossFade(
                                                  duration: AppMotion.fast,
                                                  reverseDuration:
                                                      AppMotion.fast,
                                                  firstCurve: Curves.easeIn,
                                                  secondCurve: Curves.easeOut,
                                                  sizeCurve: Curves.easeInOut,
                                                  crossFadeState: showLabel
                                                      ? CrossFadeState
                                                            .showSecond
                                                      : CrossFadeState
                                                            .showFirst,
                                                  firstChild:
                                                      const SizedBox.shrink(),
                                                  secondChild: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: AppSpacing.sm,
                                                        ),
                                                    child: Text(
                                                      item.label,
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      overflow:
                                                          TextOverflow.clip,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelLarge!
                                                          .copyWith(
                                                            // allowed: floating nav
                                                            fontSize: 13,
                                                            color: contentColor,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
