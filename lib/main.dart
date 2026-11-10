import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'theme/app_theme.dart';

void main() => runApp(const ProviderScope(child: HiveTubeApp()));

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
