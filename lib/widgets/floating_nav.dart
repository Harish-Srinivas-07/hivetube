import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_sizes.dart';

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

class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
    this.onDragSelected,
    this.inverted = false,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int>? onDragSelected;
  final bool inverted;
  final List<FloatingNavItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppSizes.bottomNav,
      width: double.infinity,
      child: Material(
        key: const ValueKey('floatingNavSurface'),
        color: theme.scaffoldBackgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: onDragSelected == null
                ? null
                : (details) {
                    if (constraints.maxWidth <= 0 || items.isEmpty) return;
                    final index =
                        (details.localPosition.dx /
                                constraints.maxWidth *
                                items.length)
                            .floor()
                            .clamp(0, items.length - 1);
                    if (index != currentIndex) onDragSelected!(index);
                  },
            child: Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: _NavDestination(
                      item: items[index],
                      selected: index == currentIndex,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = selected ? colors.onSurface : colors.onSurfaceVariant;
    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  key: ValueKey(selected),
                  size: AppSizes.navIconSize,
                  color: color,
                ),
              ),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
