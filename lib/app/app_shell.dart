import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/playback/playback_service.dart';
import '../core/playback/player_ui_state.dart';
import '../features/watch/watch_panel.dart';
import '../features/watch/mini_player_inset.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/floating_nav.dart';
import '../core/providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  static const _destinations = [
    (label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
    (
      label: 'Shorts',
      icon: Icons.play_arrow_outlined,
      activeIcon: Icons.play_arrow,
    ),
    (
      label: 'Subscriptions',
      icon: Icons.subscriptions_outlined,
      activeIcon: Icons.subscriptions,
    ),
    (
      label: 'Library',
      icon: Icons.video_library_outlined,
      activeIcon: Icons.video_library,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnreadSubs = ref.watch(hasUnreadUploadsProvider).value ?? false;
    final wide =
        MediaQuery.sizeOf(context).width >= AppSpacing.navigationBreakpoint;
    final shorts = navigationShell.currentIndex == 1;

    // Entering Shorts: stop playback and close the mini panel
    if (shorts && ref.read(watchPanelProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(watchPanelProvider.notifier).close();
        ref.read(playerUiProvider.notifier).setDismissed(true);
        ref.read(playbackProvider)?.stop();
      });
    }

    Future<void> select(int index) async {
      if (navigationShell.currentIndex == index) {
        ref.read(tabRefreshProvider.notifier).request(index);
        return;
      }
      if (index == 1 && navigationShell.currentIndex != 1) {
        // Navigating TO Shorts: stop mini player
        ref.read(watchPanelProvider.notifier).close();
        ref.read(playerUiProvider.notifier).setDismissed(true);
        ref.read(playbackProvider)?.stop();
      }
      if (navigationShell.currentIndex == 1 && index != 1) {
        // Leaving Shorts: pause the shared player if active
        ref.read(playbackProvider)?.setVisible(false);
      }
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    final panelMode = ref.watch(playerUiProvider.select((s) => s.panelMode));
    final panelExpanded =
        ref.watch(watchPanelProvider) != null &&
        panelMode == PlayerPanelMode.expanded;

    final hasMini =
        ref.watch(watchPanelProvider) != null &&
        panelMode != PlayerPanelMode.expanded &&
        !shorts;
    final miniHeight =
        (wide
            ? AppSpacing.videoMaxWidth
            : MediaQuery.sizeOf(context).width * .55) /
        AppSpacing.thumbnailRatio;
    final miniInset = hasMini ? miniHeight + AppSpacing.sm * 2 : 0.0;

    return Stack(
      children: [
        // ── Main scaffold ────────────────────────────────────────────────────
        Scaffold(
          backgroundColor: shorts
              ? AppColors.shortsBackground
              : Theme.of(context).colorScheme.surface,
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
                                icon: Icon(item.activeIcon),
                                label: Text(item.label),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: MiniPlayerInset(
                        bottom: 0.0,
                        child: navigationShell,
                      ),
                    ),
                  ],
                )
              : SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      const HomeTopBar(),
                      Expanded(
                        child: Row(
                          children: [
                            // Wide layout: rail slides away when panel expands
                            if (wide)
                              AnimatedContainer(
                                duration: AppMotion.slow,
                                curve: AppMotion.emphasized,
                                width: !panelExpanded ? 72 : 0,
                                child: !panelExpanded
                                    ? NavigationRail(
                                        selectedIndex:
                                            navigationShell.currentIndex,
                                        onDestinationSelected: select,
                                        labelType: NavigationRailLabelType.all,
                                        destinations: [
                                          for (final item in _destinations)
                                            NavigationRailDestination(
                                              icon:
                                                  item.label ==
                                                          'Subscriptions' &&
                                                      hasUnreadSubs
                                                  ? Badge(
                                                      smallSize: 8,
                                                      child: Icon(
                                                        item.activeIcon,
                                                      ),
                                                    )
                                                  : Icon(item.activeIcon),
                                              label: Text(item.label),
                                            ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            Expanded(
                              child: MiniPlayerInset(
                                bottom: miniInset,
                                child: navigationShell,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // ── Floating bottom nav pill (phone) ─────────────────────────────────
        if (!wide)
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
            child: ValueListenableBuilder<double>(
              valueListenable: ref.watch(watchPanelProgressProvider),
              builder: (context, progress, _) {
                final navVisible = progress < .5;
                return AnimatedSlide(
                  offset: navVisible ? Offset.zero : const Offset(0, 2),
                  duration: AppMotion.slow,
                  curve: AppMotion.emphasized,
                  child: AnimatedOpacity(
                    opacity: navVisible ? 1 : 0,
                    duration: AppMotion.base,
                    child: Center(
                      child: FloatingNav(
                        key: const ValueKey('bottomNavPill'),
                        items: [
                          for (final item in _destinations)
                            FloatingNavItem(
                              item.label,
                              item.icon,
                              activeIcon: item.activeIcon,
                              showBadge:
                                  item.label == 'Subscriptions' &&
                                  hasUnreadSubs,
                            ),
                        ],
                        currentIndex: navigationShell.currentIndex,
                        onSelected: (index) => select(index),
                        onDragSelected: (index) => select(index),
                        inverted: shorts,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // ── Watch panel overlay (above everything) ───────────────────────────
        const Positioned.fill(
          child: Material(type: MaterialType.transparency, child: WatchPanel()),
        ),
      ],
    );
  }
}
