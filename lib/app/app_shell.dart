import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../core/playback/playback_service.dart';
import '../theme/app_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/glass_surface.dart';
import '../widgets/home_top_bar.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  static const _destinations = [
    (label: 'Home', icon: LucideIcons.home),
    (label: 'Shorts', icon: LucideIcons.playSquare),
    (label: 'Subscriptions', icon: LucideIcons.clapperboard),
    (label: 'You', icon: LucideIcons.user),
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide =
        MediaQuery.sizeOf(context).width >= AppSpacing.navigationBreakpoint;
    final home = navigationShell.currentIndex == 0;
    final shorts = navigationShell.currentIndex == 1;
    final scheme = Theme.of(context).colorScheme;
    final selectedColor = shorts
        ? AppColors.shortsForeground
        : scheme.onSurface;
    final idleColor = shorts
        ? AppColors.shortsProgressBuffer
        : scheme.onSurfaceVariant;
    void select(int index) {
      if (navigationShell.currentIndex == 1 && index != 1) {
        ref.read(playbackProvider)?.setVisible(false);
      }
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    return Stack(
      children: [
        if (home)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height:
                      MediaQuery.sizeOf(context).height *
                      AppSpacing.glowHeightFactor,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: Theme.of(context).extension<HiveGlass>()!.glow,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Scaffold(
          backgroundColor: shorts
              ? AppColors.shortsBackground
              : home
              ? Colors.transparent
              : null,
          extendBody: true,
          body: shorts
              ? Row(
                  children: [
                    if (wide)
                      SafeArea(
                        child: NavigationRail(
                          selectedIndex: navigationShell.currentIndex,
                          onDestinationSelected: select,
                          labelType: NavigationRailLabelType.all,
                          destinations: [
                            for (final item in _destinations)
                              NavigationRailDestination(
                                icon: Icon(item.icon),
                                label: Text(item.label),
                              ),
                          ],
                        ),
                      ),
                    Expanded(child: navigationShell),
                  ],
                )
              : SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      if (home) const HomeTopBar() else const AppTopBar(),
                      Expanded(
                        child: Row(
                          children: [
                            if (wide)
                              NavigationRail(
                                selectedIndex: navigationShell.currentIndex,
                                onDestinationSelected: select,
                                labelType: NavigationRailLabelType.all,
                                destinations: [
                                  for (final item in _destinations)
                                    NavigationRailDestination(
                                      icon: Icon(item.icon),
                                      label: Text(item.label),
                                    ),
                                ],
                              ),
                            Expanded(child: navigationShell),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (!wide)
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
            child: Material(
              color: Colors.transparent,
              child: GlassSurface(
                borderRadius: AppRadius.pillBorder,
                child: SizedBox(
                  key: const ValueKey('bottomNavPill'),
                  height: AppSpacing.navHeight,
                  child: Row(
                    children: [
                      for (var i = 0; i < _destinations.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            child: Material(
                              color: i == navigationShell.currentIndex
                                  ? Theme.of(
                                      context,
                                    ).extension<HiveGlass>()!.glassFill
                                  : Colors.transparent,
                              borderRadius: AppRadius.pillBorder,
                              child: InkWell(
                                borderRadius: AppRadius.pillBorder,
                                onTap: () => select(i),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (i == 3)
                                      Container(
                                        width: AppSpacing.navAvatar,
                                        height: AppSpacing.navAvatar,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                i ==
                                                    navigationShell.currentIndex
                                                ? selectedColor
                                                : idleColor,
                                            width: AppSpacing.borderWidth,
                                          ),
                                        ),
                                        child: Icon(
                                          LucideIcons.user,
                                          size: AppSpacing.navIcon,
                                          color:
                                              i == navigationShell.currentIndex
                                              ? selectedColor
                                              : idleColor,
                                        ),
                                      )
                                    else
                                      Icon(
                                        _destinations[i].icon,
                                        size: AppSpacing.navIcon,
                                        color: i == navigationShell.currentIndex
                                            ? selectedColor
                                            : idleColor,
                                      ),
                                    Text(
                                      _destinations[i].label,
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color:
                                                i ==
                                                    navigationShell.currentIndex
                                                ? selectedColor
                                                : idleColor,
                                          ),
                                    ),
                                  ],
                                ),
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
      ],
    );
  }
}
