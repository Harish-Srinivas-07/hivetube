import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'core/settings/app_settings.dart';
import 'core/db/app_db.dart';
import 'core/providers.dart';
import 'core/playback/audio_handler.dart';
import 'features/home/home_cache.dart';
import 'features/home/home_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
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
  final savedHl = await db.getValue('settings_hl');
  final savedGl = await db.getValue('settings_gl');
  final savedLocal = await db.getValue('settings_local_content');
  final savedAutoplay = await db.getValue('settings_autoplay');
  final settings = defaults.copyWith(
    hl: languages.containsKey(savedHl) ? savedHl : defaults.hl,
    gl: regions.containsKey(savedGl) ? savedGl : defaults.gl,
    localContent: savedLocal != 'false',
    autoplay: savedAutoplay == 'true',
  );
  HomeCache? cache;
  try {
    cache = HomeCache.decode(
      await db.getValue(homeCacheKey(settings)),
      DateTime.now(),
    );
  } catch (_) {
    /* Start without a cache. */
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

class HiveTubeApp extends StatelessWidget {
  const HiveTubeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'HiveTube',
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    routerConfig: appRouter,
  );
}
