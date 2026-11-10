import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'core/db/app_db.dart';
import 'core/providers.dart';
import 'features/home/home_cache.dart';
import 'features/home/home_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDb();
  HomeCache? cache;
  try {
    cache = HomeCache.decode(await db.getValue('home_cache'), DateTime.now());
  } catch (_) {
    /* Start without a cache. */
  }
  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
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
