import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'dart:io';

import 'package:flutter/services.dart';

import 'dart:developer' as dev;

import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'app/router.dart';
import 'core/playback/player_ui_state.dart';
import 'core/providers.dart';
import 'core/downloads/download_manager.dart';
import 'core/content/language_profile.dart';
import 'core/settings/app_settings.dart';
import 'core/streams/adaptive_quality_policy.dart';
import 'core/db/app_db.dart';
import 'core/playback/audio_handler.dart';
import 'features/home/home_cache.dart';
import 'features/home/home_controller.dart';
import 'features/home/home_variety.dart';
import 'theme/app_theme.dart';
import 'theme/app_motion.dart';
import 'theme/app_spacing.dart';
import 'core/playback/preview_coordinator.dart';
import 'features/watch/mini_player_inset.dart';
import 'features/watch/player_back_scope.dart';
import 'features/watch/watch_panel.dart';
import 'widgets/player/player_controls.dart';
import 'core/update/update_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    try {
      await cleanStaleUpdateFiles();
    } catch (error, stackTrace) {
      dev.log(
        'Unable to clean stale update files',
        name: 'HiveTube',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  VisibilityDetectorController.instance.updateInterval =
      AppMotion.previewVisibilityUpdate;
  MediaKit.ensureInitialized();
  await LanguageProfileRegistry.instance.ensureLoaded();
  final audioHandler = await AudioService.init(
    builder: HiveAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.hiveminds.hivetube.playback',
      androidNotificationChannelName: 'Playback',
      androidStopForegroundOnPause: false,
    ),
  );
  final db = AppDb();
  final defaults = AppSettings.defaults(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
  final savedGl = await db.getValue('settings_gl');
  final savedLocal = await db.getValue('settings_local_content');
  final savedAutoplay = await db.getValue('settings_autoplay');
  final savedBackgroundPlay = await db.getValue('settings_background_play');
  final savedPreviewsEnabled = await db.getValue('settings_previews_enabled');
  final savedPreviewsWifiOnly = await db.getValue(
    'settings_previews_wifi_only',
  );
  final savedVideoQuality = await db.getValue('settings_video_quality');
  final savedContentLanguages = await db.getValue('settings_content_languages');
  final savedHiddenLanguages = await db.getValue('settings_hidden_languages');
  final savedLocalRatio =
      await db.getValue('settings_local_ratio') ??
      await db.getValue('settings_tamil_ratio');
  final savedStrictHome = await db.getValue('settings_strict_home');
  final savedPrefsVersion = await db.getValue('settings_prefs_version');
  Set<String> parseLanguages(String? value, Set<String> fallback) {
    final parsed = value
        ?.split(',')
        .where(contentLanguageOptions.containsKey)
        .toSet();
    return parsed == null || parsed.isEmpty ? fallback : parsed;
  }

  // One-time migration to English-only: clear old stored hl, visitorData, and home caches
  final hlMigrated = await db.getValue('settings_hl_en_migrated');
  if (hlMigrated != 'true') {
    await db.deleteValue('settings_hl');
    await db.deleteValue('content_hl_v1');
    await db.deleteValuesStartingWith('visitor_data_');
    await db.deleteValuesStartingWith('home_cache_');
    await db.setValue('settings_hl_en_migrated', 'true');
    final nextVersion = ((int.tryParse(savedPrefsVersion ?? '') ?? 0) + 1)
        .toString();
    await db.setValue('settings_prefs_version', nextVersion);
  }

  final settings = defaults.copyWith(
    gl: regions.containsKey(savedGl) ? savedGl : defaults.gl,
    localContent: savedLocal != 'false',
    autoplay: savedAutoplay == 'true',
    backgroundPlay: savedBackgroundPlay != 'false',
    previewsEnabled: savedPreviewsEnabled != 'false',
    previewsWifiOnly: savedPreviewsWifiOnly != 'false',
    videoQualityPreference: VideoQualityPreference.values.firstWhere(
      (preference) => preference.name == savedVideoQuality,
      orElse: () => VideoQualityPreference.auto,
    ),
    contentLanguages: parseLanguages(
      savedContentLanguages,
      defaults.contentLanguages,
    ),
    hiddenLanguages: parseLanguages(
      savedHiddenLanguages,
      defaults.hiddenLanguages,
    ),
    localRatio:
        double.tryParse(savedLocalRatio ?? '')?.clamp(0.0, 1.0).toDouble() ??
        defaults.localRatio,
    strictHome: savedStrictHome != 'false',
    revision: int.tryParse(savedPrefsVersion ?? '') ?? 0,
  );
  HomeCache? cache;
  try {
    cache = HomeCache.decode(
      await db.getValue(homeCacheKey(settings)),
      DateTime.now(),
    );
  } catch (error, stackTrace) {
    dev.log(
      'Failed to load initial Home cache; starting without cached items',
      name: 'HiveTube',
      error: error,
      stackTrace: stackTrace,
    );
  }
  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        audioHandlerProvider.overrideWith(
          () => AudioHandlerController(audioHandler),
        ),
        initialAppSettingsProvider.overrideWithValue(settings),
        initialHomeCacheProvider.overrideWithValue(cache),
      ],
      child: const HiveTubeApp(),
    ),
  );
}

final _playerNavigatorKey = GlobalKey<NavigatorState>();
final _miniPlayerKey = GlobalKey();

class HiveTubeApp extends ConsumerWidget {
  const HiveTubeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(downloadManagerProvider);
    playerBackButtonDispatcher.onPlayerBack = () async {
      if (ref.read(watchPanelProvider) == null) return false;
      final playerNavigator = _playerNavigatorKey.currentState;
      if (playerNavigator != null && playerNavigator.canPop()) {
        await playerNavigator.maybePop();
        return true;
      }
      final ui = ref.read(playerUiProvider);
      if (ui.locked) {
        ref.read(playerUiProvider.notifier).setOverlayVisible(true);
        return true;
      }
      if (ui.isFullscreen) {
        ref.read(playerUiProvider.notifier).setFullscreen(false);
        await setPlayerFullscreenOrientation(false);
        return true;
      }
      if (ui.panelMode != PlayerPanelMode.mini) {
        ref.read(watchPanelExpandProvider.notifier).minimize();
        return true;
      }
      return false;
    };
    return MaterialApp.router(
      title: 'HiveTube',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en')],
      routeInformationProvider: appRouter.routeInformationProvider,
      routeInformationParser: appRouter.routeInformationParser,
      routerDelegate: appRouter.routerDelegate,
      backButtonDispatcher: playerBackButtonDispatcher,
      builder: (context, child) => _RootPlayerOverlay(child: child),
    );
  }
}

class _RootPlayerOverlay extends ConsumerWidget {
  const _RootPlayerOverlay({this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(playerUiProvider);
    final panelOpen = ref.watch(watchPanelProvider) != null;
    final wide =
        MediaQuery.sizeOf(context).shortestSide >=
        AppSpacing.navigationBreakpoint;
    final miniHeight =
        (wide
            ? AppSpacing.videoMaxWidth
            : MediaQuery.sizeOf(context).width * .55) /
        AppSpacing.thumbnailRatio;
    final miniInset = panelOpen && ui.panelMode != PlayerPanelMode.expanded
        ? miniHeight + AppSpacing.sm * 2
        : 0.0;
    return MiniPlayerInset(
      bottom: miniInset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PreviewScrollListener(child: child ?? const SizedBox.shrink()),
          Positioned.fill(
            child: _PlayerHitTestGate(
              acceptsHit: (globalPosition) {
                if (!panelOpen) return false;
                if (ui.panelMode != PlayerPanelMode.mini ||
                    (_playerNavigatorKey.currentState?.canPop() ?? false)) {
                  return true;
                }
                final box = _miniPlayerKey.currentContext?.findRenderObject();
                if (box is! RenderBox || !box.hasSize) return false;
                return (Offset.zero & box.size).contains(
                  box.globalToLocal(globalPosition),
                );
              },
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => PlayerNavigatorScope(
                      child: Navigator(
                        key: _playerNavigatorKey,
                        onGenerateRoute: (_) => PageRouteBuilder<void>(
                          opaque: false,
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                          pageBuilder: (context, _, _) => Material(
                            type: MaterialType.transparency,
                            child: WatchPanel(
                              miniPlayerKey: _miniPlayerKey,
                              navigatorContext: () =>
                                  rootNavigatorKey.currentContext,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerHitTestGate extends SingleChildRenderObjectWidget {
  const _PlayerHitTestGate({required this.acceptsHit, required super.child});

  final bool Function(Offset globalPosition) acceptsHit;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPlayerHitTestGate(acceptsHit);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPlayerHitTestGate renderObject,
  ) => renderObject.acceptsHit = acceptsHit;
}

class _RenderPlayerHitTestGate extends RenderProxyBox {
  _RenderPlayerHitTestGate(this.acceptsHit);

  bool Function(Offset globalPosition) acceptsHit;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      acceptsHit(localToGlobal(position)) &&
      super.hitTest(result, position: position);
}
