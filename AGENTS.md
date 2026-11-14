# HiveTube agent notes

## App

- Flutter client for YouTube videos and Shorts. Main code lives in `lib/`.
- `lib/main.dart` loads language profiles and persisted settings before starting Riverpod.
- Routing is in `lib/app/router.dart`; providers and shared services are in `lib/core/providers.dart`.

## Current content behavior

- Home language filtering is implemented in `lib/core/content/`.
- Language data is bundled from `assets/languages/*.json`; keep profile JSON in sync with `LanguageProfile`.
- `ContentFilter` classifies by script, channel votes, romanized lexicon, then caption probe. Hidden languages are always removed. Strict Home keeps shown languages; library surfaces allow languages unless hidden.
- `ChannelLanguageCache` stores votes in app preferences. `CaptionProbeService` checks caption tracks with a short timeout.
- Home feed sources, filtering, ranking, seen-video state, and replenishment live in `lib/features/home/home_controller.dart` and `home_variety.dart`.
- Settings are in `lib/core/settings/app_settings.dart` and `lib/features/settings/settings_screen.dart`. Persisted keys include region, shown/hidden languages, local ratio, strict Home, and autoplay. Settings changes clear related home cache and seen state.
- Content diagnostics use `HomeTraceStore` and `lib/features/settings/content_debug_screen.dart`.
- Keep filtering policy consistent across Home, Shorts, Watch recommendations, and library screens. Check callers when changing `ContentFilter`.

## Storage and playback

- `AppDb` is Drift-backed. Flutter uses `app_db_executor_flutter.dart`; VM/tests use `app_db_executor_vm.dart`.
- Update schema migrations and generated Drift code together when changing tables.
- Playback and stream handling live in `lib/core/playback/` and `lib/core/streams/`. Preserve current playback position and state when changing stream selection or controls.
- Backup import/export is in `lib/core/yt/backup_service.dart`; keep its format compatible with existing backups.

## UI system

- Shared design tokens are in `lib/theme/`: colors, text, spacing, radius, sizes, layout, and motion.
- Shared widgets are in `lib/widgets/ui/`; import `ui.dart` where suitable.
- Use tokens and shared widgets for new screens and controls. Keep responsive behavior in mind: rail at 600 px, two-column watch layout at 1024 px.
- App theme setup is in `lib/theme/app_theme.dart`.

## Change guidance

- Preserve existing offline/local data and old settings during migrations.
- Do not commit credentials or signing files.
- Tests are in `test/`; manual smoke and inspection tools are in `tool/`.
- Run only checks requested for the task. Do not treat smoke scripts as unit tests.

## Windows Flutter tests

- If `flutter test` fails before tests start with `Flutter failed to copy file` under the sandbox-managed Windows `Temp\flutter_tools` directory, the temp directory may be inaccessible. Set `TEMP` and `TMP` for the test process to a writable directory under the Pub cache, for example:
  `$testTempPath = Join-Path $env:LOCALAPPDATA 'Pub\codex-test-tmp'; New-Item -ItemType Directory -Force -Path $testTempPath | Out-Null; $env:TEMP = $testTempPath; $env:TMP = $testTempPath`
