import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../core/playback/playback_service.dart';
import '../core/playback/player_ui_state.dart';
import '../features/watch/watch_panel.dart';
import '../features/watch/mini_player_inset.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/floating_nav.dart';
import '../core/providers.dart';

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
    final hasUnreadSubs = ref.watch(hasUnreadUploadsProvider).value ?? false;
    final wide =
        MediaQuery.sizeOf(context).width >= AppSpacing.navigationBreakpoint;
    final home = navigationShell.currentIndex == 0;
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

    // Panel progress: 0 = mini, 1 = fully expanded
    final panelProgress = ref.watch(
      playerUiProvider.select((s) => s.panelProgress),
    );
    // Nav pill: visible when no panel, or panel is mini (< 0.5)
    final navVisible = panelProgress < 0.5;

    final hasMini = ref.watch(watchPanelProvider) != null && navVisible && !shorts;
    final miniHeight =
        (wide
            ? AppSpacing.videoMaxWidth
            : MediaQuery.sizeOf(context).width * .55) /
        AppSpacing.thumbnailRatio;
    final miniInset = hasMini ? miniHeight + AppSpacing.sm * 2 : 0.0;

    return Stack(
      children: [
        // ── Home background glow ─────────────────────────────────────────────
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

        // ── Main scaffold ────────────────────────────────────────────────────
        Scaffold(
          backgroundColor: shorts
              ? AppColors.shortsBackground
              : home
              ? AppColors.transparent
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
                      if (home) const HomeTopBar() else const AppTopBar(),
                      Expanded(
                        child: Row(
                          children: [
                            // Wide layout: rail slides away when panel expands
                            if (wide)
                              AnimatedContainer(
                                duration: AppMotion.slow,
                                curve: AppMotion.emphasized,
                                width: panelProgress < 0.5 ? 72 : 0,
                                child: panelProgress < 0.5
                                    ? NavigationRail(
                                        selectedIndex:
                                            navigationShell.currentIndex,
                                        onDestinationSelected: select,
                                        labelType: NavigationRailLabelType.all,
                                        destinations: [
                                          for (final item in _destinations)
                                            NavigationRailDestination(
                                              icon: item.label == 'Subscriptions' && hasUnreadSubs
                                                  ? const Badge(smallSize: 8, child: Icon(LucideIcons.clapperboard))
                                                  : Icon(item.icon),
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
            child: AnimatedSlide(
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
                          showBadge: item.label == 'Subscriptions' && hasUnreadSubs,
                        ),
                    ],
                    currentIndex: navigationShell.currentIndex,
                    onSelected: (index) => select(index),
                    onDragSelected: (index) => select(index),
                    inverted: shorts,
                  ),
                ),
              ),
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
