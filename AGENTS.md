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

## HiveTube agent rules

### Hard rules
1. ONE agent at a time on the tree. Parallel agents only if they touch disjoint NEW files. Two overlapping runs already broke the build twice.
2. No emulator, no screenshots, no golden tests. Never start a golden or screenshot audit. Override any repo rule that asks for them. Run the non-golden test files only.
3. Edit first, test last. Don't run `flutter test` before editing.
4. Never: push, tag, amend, rebase, force. Commit only when the task says so.
5. Never delete or skip a test. STALE assertion (asserts a value design.md replaced on purpose) = update it. Anything else = fix the code.
6. Don't touch: Drift schema (`tables.dart`, migrations), playback service logic, audio handler. UI wiring only. Schema change needs my approval.
7. Tokens only (`lib/theme/app_*.dart`). No inline `fontSize`, `Color(0x..)`, `Colors.*`, raw `EdgeInsets` or radius numbers. Missing token = add it, then use it.
8. One VideoCard, one AppChip, one AppButton, one showAppSheet. Never create a duplicate widget. Reuse design.md section 4 components.
9. Restyle tasks never change behavior.
10. Blocked = report exact file, line, error. Never write "not completed" without the reason.
11. Don't invent features, settings, endpoints or DB columns. Use only what exists today.
12. Never commit: `.env`, `*.jks`, `*.keystore`, `key.properties`, `local.properties`, `build/`, `.dart_tool/`, `*.log`.

### Commands
```powershell
dart analyze                         # 0 errors, 0 warnings
dart run tool/design_lint.dart       # exit 0
$t = "$env:LOCALAPPDATA\Pub\agent-test-tmp"; New-Item -ItemType Directory -Force $t | Out-Null
$env:TEMP = $t; $env:TMP = $t
$files = rg --files test | Where-Object { $_ -match '_test\.dart$' -and $_ -notmatch '(?i)golden|screenshot' } | Sort-Object
flutter test --no-pub --concurrency=1 $files
python -c "import json,glob;[json.load(open(f,encoding='utf-8')) for f in glob.glob('assets/languages/*.json')]"
```

### Known pitfalls
- Language JSON trailing comma empties the language registry, so Home shows "No videos found". Validate JSON after any edit under `assets/languages`; `test/language_assets_test.dart` guards it.
- Flutter ships `AssetManifest.bin`, not `.json`. Use `AssetManifest.loadFromAssetBundle`.
- `watch_panel.dart` `_start()` must not `resume()` on rebuild. A pause got undone by it. Don't reintroduce.
- Signed-out FEwhat_to_watch returns 0 videos. Home builds from local sources (search, related, RSS, browse). The 8s first-result wait is intentional.
- Caption probe uses the VISIONOS InnerTube client, not ANDROID.
- History does not persist `isShort`. All entries render as compact rows. No Shorts badge or chip.
- A mock-only test is not proof of a live fetch. Use `tool/probe*.dart` for live endpoint checks.
- Run test files with the TEMP fix above on Windows.
- Floating draggable mini player is intentional (not docked).
- Search suggestions go through `lib/services/search_suggestions.dart` (250ms debounce, stale dropped).

UI spec: docs/design.md (source of truth).
Task templates: docs/master_prompt.md. Open only when the task names a template.
Multi-step job: docs/orchestrator.md. New feature: docs/features.md.
The task is the line after 'Task:'. If there is none, ask one question.
Final reply is ONE line in the template's format.
