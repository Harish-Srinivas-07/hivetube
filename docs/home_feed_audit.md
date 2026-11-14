# Home feed audit

Date: 2026-11-14

Scope: signed-out Home feed startup and the report that Home displayed “No videos found”.

## Result

The simulator reproduced the failure before the fix. The root cause was language-profile loading on Flutter platforms: the app searched for `AssetManifest.json`, while the installed Flutter app bundle ships `AssetManifest.bin`. The loader converted that mismatch into an empty asset list and silently fell back to reading `assets/languages/` from the device filesystem. That source directory is not present in an installed app bundle. The `LanguageProfileRegistry` therefore stayed empty, `buildQueries()` returned no profile searches, and a fresh signed-out install with no subscriptions or history had no remaining Home source that could produce videos.

The direct VM probe did not reveal this fault because the VM/test implementation reads language JSON files from the repository filesystem. Its 20-video result was a source/filter simulation, not proof that the Flutter Home screen rendered. The previous response overstated that evidence; the live probe did not validate the app’s asset initialization or `HomeController` execution.

## Evidence

- Before the fix, `flutter run` launched HiveTube on the booted **iPhone 17 iOS 27.0 simulator**. A screen capture showed the Home page and its “No videos found” empty state.
- The installed app bundle contained `Frameworks/App.framework/flutter_assets/AssetManifest.bin` and the `assets/languages/*.json` files. It did not contain `AssetManifest.json`.
- The pre-fix simulator database recorded an empty `home_cache_classifier2_AUTO_en-ta_hi_60_strict_local_All` cache, and no fresh query rows appeared in `discovery_queries`.
- The VM live probe had already shown the sources themselves can return usable items: signed-out Y9 `FEwhat_to_watch` returned 0; five of six tested RSS calls returned HTTP 404; Y7 channel-video fallback worked for the failed feeds; the profile-generated Tamil search returned 16 strict-filtered results in the final run. That did not establish device behavior.
- After the fix, the same simulator showed Home video cards. The app database had a populated Home cache with **24 videos**, and fresh discovery-query rows appeared for `Deepavali Tamil songs`, `Deepavali English songs`, and generated profile queries.

## Changes made

- Replaced the removed `AssetManifest.json` lookup in `lib/core/content/asset_loader_flutter.dart` with Flutter’s `AssetManifest.loadFromAssetBundle(rootBundle)` API. The loader enumerates the bundled language JSON assets and throws if none are found.
- Updated `LanguageProfileRegistry.ensureLoaded()` to log asset-load and profile-parse failures. It now fails clearly if both asset and filesystem loading leave the registry empty, instead of allowing Home to proceed with zero generated queries.
- Earlier Home source fixes in this task remain in the working tree: progressive mixer consumption, an 8-second first-result wait, a Y7 channel-videos fallback for empty/failed RSS, VISIONOS caption probing, and strict filter behavior that does not fill a quota with unknown-language items. They improve source availability and filter consistency, but the asset-manifest mismatch was the root cause of this device’s empty feed.
- Added Home source count logging and logging for chart/source failures. The earlier Home cache preference path still has best-effort handling for malformed local cache data; that is separate from network source errors.

## Validation

- Live VM endpoint probe: signed-out; FEwhat_to_watch, RSS, Y7 fallback, VISIONOS caption probing, generated search, and strict content filtering. It returned 20 unique videos in the final run, but was not considered device-render proof.
- Device validation: rebuilt and launched with `flutter run -d A2DC29BC-5D25-4A91-BD9A-0D07A6933DB1 --debug --no-resident`; captured the running Home screen, which displayed video cards; verified 24 cached feed items and new generated-query records in the simulator’s Drift database.
- Focused Flutter tests: `test/home_feed_fetch_test.dart`, `test/home_mixer_test.dart`, and `test/content_filter_test.dart` passed together (22 tests) after the asset-loader correction.

## Remaining limits

- The connected device discovered by Flutter was an iOS simulator, not an Android emulator. No Android device was visible to `flutter devices` (`Unable to locate an Android SDK`).
- The simulator screen and local database were checked after rebuilding. Playback, image-loading reliability under a cold network, and Android behavior were not audited.
- The screenshot was written to `/tmp/hivetube_home_fixed.png` during this session; it is not a tracked repository artifact.
