import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
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
  int? _dragIndex;

  int _indexAt(double x, double width) {
    if (widget.items.isEmpty) return 0;
    final cellWidth = width / widget.items.length;
    return (x / cellWidth).floor().clamp(0, widget.items.length - 1);
  }

  void _select(int index) {
    HapticFeedback.selectionClick();
    widget.onSelected(index);
  }

  void _startDrag(DragStartDetails details, double width) {
    setState(() => _dragIndex = _indexAt(details.localPosition.dx, width));
  }

  void _updateDrag(DragUpdateDetails details, double width) {
    final index = _indexAt(details.localPosition.dx, width);
    if (index != _dragIndex) HapticFeedback.selectionClick();
    setState(() => _dragIndex = index);
  }

  void _endDrag() {
    final index = _dragIndex;
    setState(() => _dragIndex = null);
    if (index != null) (widget.onDragSelected ?? widget.onSelected)(index);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = dark ? AppColors.dark : AppColors.light;
    final activeColor = widget.inverted || !dark
        ? AppColors.primary
        : AppColors.white;
    final inactiveBase = widget.inverted ? AppColors.white : colors.textPrimary;
    final glassFill = widget.inverted
        ? AppColors.navGlassFillDark
        : dark
        ? AppColors.navGlassFillDark
        : AppColors.navGlassFillLight;
    final borderColor = AppColors.navGlassBorder;
    final selectedFill = widget.inverted || dark
        ? AppColors.navSelectionFillDark
        : AppColors.navSelectionFillLight;

    return Container(
      width: AppSizes.navBarWidth,
      key: const ValueKey('floatingNavSurface'),
      decoration: const BoxDecoration(
        borderRadius: AppRadius.pillBorder,
        boxShadow: [
          // allowed: floating nav
          BoxShadow(
            color: AppColors.navGlassShadow,
            blurRadius: AppSpacing.xl,
            offset: Offset(AppSpacing.none, AppSpacing.xs),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: AppSizes.navHeight,
              // allowed: floating nav
              child: GlassSurface(
                borderRadius: AppRadius.pillBorder,
                fill: glassFill,
                borderColor: borderColor,
                blurSigma: AppSpacing.navGlassBlur,
                borderWidth: AppSpacing.glassBorderWidth,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final selectedIndex = _dragIndex ?? widget.currentIndex;
                    final cellWidth = width / widget.items.length;
                    final selectedWidth = cellWidth;
                    final selectedLeft = selectedIndex * cellWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: (details) =>
                          _startDrag(details, width),
                      onHorizontalDragUpdate: (details) =>
                          _updateDrag(details, width),
                      onHorizontalDragEnd: (_) => _endDrag(),
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            key: const ValueKey('floatingNavIndicator'),
                            duration: AppMotion.navSelection,
                            curve: AppMotion.enter,
                            left: selectedLeft + AppSpacing.xs,
                            top: AppSpacing.xs,
                            bottom: AppSpacing.xs,
                            width: selectedWidth - AppSpacing.sm,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: selectedFill,
                                borderRadius: AppRadius.pillBorder,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Row(
                              children: [
                                for (var i = 0; i < widget.items.length; i++)
                                  Expanded(
                                    child: _TabButton(
                                      item: widget.items[i],
                                      selected: selectedIndex == i,
                                      activeColor: activeColor,
                                      inactiveColor: inactiveBase.withValues(
                                        alpha: AppColors.navInactiveOpacity,
                                      ),
                                      onTap: () => _select(i),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        message: item.label,
        triggerMode: TooltipTriggerMode.manual,
        child: SizedBox.expand(
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              borderRadius: AppRadius.pillBorder,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          size: item.iconSize ?? AppSizes.navIconSize,
                          weight: selected
                              ? AppSizes.navIconWeightActive
                              : AppSizes.navIconWeightInactive,
                          color: color,
                        ),
                        if (item.showBadge)
                          Positioned(
                            right: -AppSpacing.xxs,
                            top: -AppSpacing.xxs,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.badge,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.onBadge,
                                  width: AppSpacing.glassBorderWidth,
                                ),
                              ),
                              child: SizedBox.square(
                                dimension: AppSpacing.badgeDotSize,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xxs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        softWrap: false,
                        style: AppTextStyles.navLabel.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
