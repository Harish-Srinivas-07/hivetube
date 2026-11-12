import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../core/playback/playback_service.dart';
import '../core/playback/player_ui_state.dart';
import '../features/watch/watch_panel.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/floating_nav.dart';

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
    if (shorts && ref.read(watchPanelProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(watchPanelProvider.notifier).close();
        ref.read(playerUiProvider.notifier).setDismissed(true);
      });
    }
    Future<void> select(int index) async {
      if (index == 1 && navigationShell.currentIndex != 1) {
        ref.read(watchPanelProvider.notifier).close();
        ref.read(playerUiProvider.notifier).setDismissed(true);
      }
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
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
            child: Center(
              child: FloatingNav(
                key: const ValueKey('bottomNavPill'),
                items: [
                  for (final item in _destinations)
                    FloatingNavItem(item.label, item.icon),
                ],
                currentIndex: navigationShell.currentIndex,
                onSelected: (index) => select(index),
                onDragSelected: (index) => select(index),
                inverted: shorts,
              ),
            ),
          ),
        const Positioned.fill(
          child: Material(type: MaterialType.transparency, child: WatchPanel()),
        ),
      ],
    );
  }
}
