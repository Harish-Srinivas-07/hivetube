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
import 'features/home/home_variety.dart';
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
  final savedContentLanguages = await db.getValue('settings_content_languages');
  final savedHiddenLanguages = await db.getValue('settings_hidden_languages');
  final savedLocalRatio =
      await db.getValue('settings_local_ratio') ??
      await db.getValue('settings_tamil_ratio');
  final savedPrefsVersion = await db.getValue('settings_prefs_version');
  Set<String> parseLanguages(String? value, Set<String> fallback) {
    final parsed = value
        ?.split(',')
        .where(contentLanguageOptions.containsKey)
        .toSet();
    return parsed == null || parsed.isEmpty ? fallback : parsed;
  }

  final settings = defaults.copyWith(
    hl: languages.containsKey(savedHl) ? savedHl : defaults.hl,
    gl: regions.containsKey(savedGl) ? savedGl : defaults.gl,
    localContent: savedLocal != 'false',
    autoplay: savedAutoplay == 'true',
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
    revision: int.tryParse(savedPrefsVersion ?? '') ?? 0,
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
