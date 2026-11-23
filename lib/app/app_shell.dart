import 'dart:async';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/playback/playback_service.dart';
import '../core/playback/lifecycle_policy.dart';
import '../core/playback/picture_in_picture.dart';
import '../core/settings/app_settings.dart';
import '../core/streams/stream_selector.dart';
import '../core/playback/player_ui_state.dart';
import '../features/watch/watch_panel.dart';
import '../features/watch/mini_player_inset.dart';
import '../features/shorts/shorts_feed_provider.dart';
import '../features/shorts/shorts_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/floating_nav.dart';
import '../widgets/logger.dart';
import '../core/providers.dart';
import '../core/orientation/orientation_policy.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with RouteAware, WidgetsBindingObserver {
  ModalRoute<dynamic>? _route;

  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        Platform.isAndroid &&
        ref.read(pictureInPictureProvider.notifier).eligible) {
      return;
    }
    if (ref.read(pictureInPictureProvider) ||
        ref.read(pictureInPictureProvider.notifier).entering) {
      return;
    }
    _applyLifecycleState(state);
  }

  void _applyLifecycleState(AppLifecycleState state) {
    final settings = ref.read(appSettingsProvider);
    final service = ref.read(playbackProvider);
    final isAudioOnly = settings.audioOnly ||
        service?.state.mode == PlaybackMode.audio ||
        (service?.audioOnlyPreference?.call() ?? false);
    final enabled = settings.backgroundPlay || isAudioOnly;
    final action = lifecyclePlaybackAction(
      state,
      backgroundPlay: enabled,
      audioOnly: isAudioOnly,
    );
    final mode = switch (action) {
      LifecyclePlaybackAction.audioOnly => 'audio',
      LifecyclePlaybackAction.restoreVideo => 'video',
      _ => (isAudioOnly || service?.state.mode == PlaybackMode.audio)
          ? 'audio'
          : 'video',
    };
    Logger.log(
      'AppShell',
      'BackgroundPlay enabled=$enabled state=${state.name} mode=$mode action=$action',
    );
    switch (action) {
      case LifecyclePlaybackAction.pause:
        unawaited(service?.pause());
        break;
      case LifecyclePlaybackAction.audioOnly:
        unawaited(service?.enterBackgroundAudioMode());
        break;
      case LifecyclePlaybackAction.restoreVideo:
        unawaited(service?.restoreBackgroundVideo());
        break;
      case LifecyclePlaybackAction.none:
        break;
    }
  }

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, _route)) return;
    if (_route != null) appRouteObserver.unsubscribe(this);
    _route = route;
    appRouteObserver.subscribe(this, route);
  }

  void _setHomeOrientationForCurrentBranch() {
    unawaited(
      setHomeScreenOrientationEnabled(
        navigationShell.currentIndex == 0 &&
            ref.read(watchPanelProvider) == null,
      ),
    );
  }

  @override
  void didPush() {
    shellRouteVisible.value = true;
    _setHomeOrientationForCurrentBranch();
  }

  @override
  void didPopNext() {
    shellRouteVisible.value = true;
    _setHomeOrientationForCurrentBranch();
  }

  @override
  void didPushNext() {
    shellRouteVisible.value = false;
    unawaited(setHomeScreenOrientationEnabled(false));
  }

  @override
  void didPop() {
    shellRouteVisible.value = false;
    unawaited(setHomeScreenOrientationEnabled(false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    unawaited(setHomeScreenOrientationEnabled(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    ref.listen(watchPanelProvider, (_, _) {
      _setHomeOrientationForCurrentBranch();
    });
    final hasUnreadSubs = ref.watch(hasUnreadUploadsProvider).value ?? false;
    final screenSize = MediaQuery.sizeOf(context);
    final wide = screenSize.shortestSide >= AppSpacing.navigationBreakpoint;
    final shorts = navigationShell.currentIndex == 1;
    final shortsVideo =
        shorts &&
        (ref.watch(
              shortsFeedProvider.select((feed) => feed.items.isNotEmpty),
            ) ||
            ref.watch(
              shortsSelectionProvider.select(
                (selection) => selection.items.isNotEmpty,
              ),
            ));
    final homeLandscape =
        navigationShell.currentIndex == 0 &&
        MediaQuery.orientationOf(context) == Orientation.landscape;

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
      unawaited(
        setHomeScreenOrientationEnabled(
          index == 0 && ref.read(watchPanelProvider) == null,
        ),
      );
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

    final darkTheme = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: AppColors.transparent,
        systemNavigationBarColor: AppColors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
        statusBarIconBrightness: darkTheme ? Brightness.light : Brightness.dark,
        statusBarBrightness: darkTheme ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness: darkTheme
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Stack(
        children: [
          PopScope(
            canPop: !shorts,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && shorts) unawaited(select(0));
            },
            child: const SizedBox.shrink(),
          ),
          // ── Main scaffold ────────────────────────────────────────────────────
          Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            extendBody: true,
            body: shorts
                ? Row(
                    children: [
                      if (wide)
                        SafeArea(
                          child: NavigationRail(
                            selectedIndex: navigationShell.currentIndex,
                            minWidth: homeLandscape ? AppSizes.railWidth : null,
                            onDestinationSelected: select,
                            labelType: NavigationRailLabelType.all,
                            destinations: [
                              for (final item in _destinations)
                                NavigationRailDestination(
                                  icon: Icon(item.activeIcon),
                                  label: homeLandscape
                                      ? Text(
                                          item.label == 'Subscriptions'
                                              ? 'Subs'
                                              : item.label,
                                          style: AppTextStyles.caption,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                        )
                                      : Text(item.label),
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
                    top: false,
                    bottom: false,
                    child: Column(
                      children: [
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
                                          minWidth: homeLandscape
                                              ? AppSizes.railWidth
                                              : null,
                                          onDestinationSelected: select,
                                          labelType:
                                              NavigationRailLabelType.all,
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
                                                label: homeLandscape
                                                    ? Text(
                                                        item.label ==
                                                                'Subscriptions'
                                                            ? 'Subs'
                                                            : item.label,
                                                        style: AppTextStyles
                                                            .caption,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        softWrap: false,
                                                      )
                                                    : Text(item.label),
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
              left:
                  (MediaQuery.sizeOf(context).width - AppSizes.navBarWidth) / 2,
              width: AppSizes.navBarWidth,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
              child: ValueListenableBuilder<double>(
                valueListenable: ref.watch(watchPanelProgressProvider),
                builder: (context, progress, _) {
                  final navVisible = shorts || progress < .5;
                  final floatingNav = FloatingNav(
                    key: const ValueKey('bottomNavPill'),
                    items: [
                      FloatingNavItem('Home', LucideIcons.house),
                      FloatingNavItem('Shorts', LucideIcons.clapperboard),
                      FloatingNavItem(
                        'Subs',
                        LucideIcons.layoutGrid,
                        showBadge: hasUnreadSubs,
                      ),
                      FloatingNavItem('Library', LucideIcons.libraryBig),
                    ],
                    currentIndex: navigationShell.currentIndex,
                    onSelected: (index) => select(index),
                    onDragSelected: (index) => select(index),
                    inverted: shortsVideo,
                  );
                  return AnimatedSlide(
                    offset: navVisible ? Offset.zero : const Offset(0, 2),
                    duration: AppMotion.slow,
                    curve: AppMotion.emphasized,
                    child: IgnorePointer(
                      ignoring: !navVisible,
                      child: AnimatedOpacity(
                        opacity: navVisible ? 1 : 0,
                        duration: AppMotion.base,
                        child: floatingNav,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
