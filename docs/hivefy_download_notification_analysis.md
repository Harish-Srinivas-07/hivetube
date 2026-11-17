# Hivefy download and notification analysis

Read-only source review, 17 November 2026. This describes the checked-out code, not a device test.

## File map

Hivefy paths relative to `E:\hivemusic`:

- `lib/services/offlinemanager.dart` — singleton download queue, progress/status, offline and cache indexes, sets and albums.
- `lib/services/chunk_downloader.dart` — validated, ranged YouTube audio transfers and URL refresh.
- `lib/services/youtube.dart` — resolves YouTube audio rendition and refreshed URLs.
- `lib/models/database.dart` — persists song metadata used by offline library.
- `lib/services/localnotification.dart` — notification initialization, channels, progress, cancellation and simple notices.
- `lib/components/notification_permission_gate.dart` — notification permission explanation and request.
- `lib/shared/player.dart`, `lib/components/showmenu.dart` — entry points and download UI; album/playlist views also request sets.
- `lib/screens/dashboard.dart` — initializes the offline manager.
- `lib/main.dart` — initializes local notifications.
- `lib/services/audiohandler.dart` — separate media playback service and notification.
- `android/app/src/main/AndroidManifest.xml` — permissions, audio service, media and notification receivers.
- `android/app/src/main/kotlin/` — MainActivity subclass; manifest launches AudioServiceActivity directly.
- `ios/Runner/Info.plist`, `ios/Podfile` — audio background mode and notification permission macro.
- `pubspec.yaml`, `pubspec.lock` — declared and resolved packages.

HiveTube paths relative to `E:\hivetube`:

- `lib/core/db/tables.dart`, `lib/core/db/app_db.dart` — existing Drift Downloads table and registration.
- `lib/features/library/library_screen.dart` — watches download rows; Downloads tap currently reports unavailable.
- `lib/main.dart`, `lib/core/playback/audio_handler.dart` — playback AudioService and media notification.
- `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/` — playback service, permissions and Android 13 notification request.
- `lib/widgets/update_dialog.dart` — separate cancellable Dio APK update download; not a media download queue.
- `pubspec.yaml`, `pubspec.lock` — existing dependencies and resolved versions.

## Hivefy flow

```text
Player/menu/album/playlist → downloadSong(id, metadata)
 → same-ID requests share a Future; other explicit downloads queue serially
 → wait for same-song cache → copy valid cache OR resolve URL → download .part
 → byte callback → ValueNotifier/UI + throttled notification ID 0
 → validate nonempty → rename → save offline index + metadata → completed → cancel ID 0
 → on exception: remove .part, failed status + log → cancel ID 0
```

- `OfflineStorageManager` keeps a Future chain with **one explicit download at a time**. Queued items are marked downloading before starting. Cache transfers can run separately. Set and album methods await songs sequentially.
- Files go under application-support `OfflineSongs/<songId>.<extension>`, first as `.part`; YouTube uses the resolved format extension, other sources use mp3. Raw IDs become file names. Explicit offline files and the automatic `SongCache` are separate; valid cache may be copied to offline storage.
- YouTube uses 1 MiB range requests, checks Content-Range, length and offsets, and refreshes an expired 401/403 URL for the same itag up to three times; receive timeout is 45 seconds. Other audio uses Dio with 15-second connect and 45-second receive timeouts. No general retry, pause, cancellation, or partial resume API.
- SharedPreferences stores completed `offlineSongs` ID-to-path mappings, `cachedSongs` and `offlineAlbums`; song metadata is stored separately by AppDatabase. Initialization restores valid completed files and removes invalid index entries. In-flight queue, partial byte offsets and failed jobs are not persisted; process death does not resume them.
- The same callback updates per-song `ValueNotifier` progress and optional UI callback, then posts notification updates. Status and library revision use other ValueNotifiers / ValueListenableBuilder, not a download Riverpod provider. No isolate, SendPort or ReceivePort in this progress path. AppDatabase uses compute elsewhere, independently.

## Notification behavior

- `flutter_local_notifications` initializes Android and Darwin; no notification tap callback is registered. Android channel `downloads_channel` / `Song Downloads` is created with **high** importance. Individual details request max importance and high priority, but Android's created channel settings govern channel behavior.
- Progress is determinate integer 0–100, silent, no sound/vibration, `onlyAlertOnce`, with percentage subtext. No explicit ongoing flag, group/summary, action buttons, or indeterminate mode. Fixed ID **0** is shared; payload `download_progress` has no navigation handler.
- A first network progress callback posts, then at least each 10 percentage-point increase or 100%. Unknown-length Dio transfers produce no progress callback. Cached copies show no progress notification. Asynchronous calls are not awaited.
- Both successful and failed individual downloads cancel ID 0; neither posts a completion/failure notice. Successful full albums/playlists post a separate high-importance `general_channel` notification; partial failures do not. Timestamp-in-seconds IDs can collide.
- Essential implementation:
```dart
// Channel: downloads_channel / Song Downloads, Importance.high
showProgress: true, maxProgress: 100,
progress: progress.toInt(), onlyAlertOnce: true,
```
```dart
if (progress - lastNotification >= 10 || progress >= 100) {
  lastNotification = progress.toInt();
  showDownloadNotification(details.title, progress);
}
```

## Packages, platform and execution

Locked Hivefy versions: `flutter_local_notifications 19.5.0`, `permission_handler 12.0.1`, `audio_service 0.18.18`. No `flutter_downloader`, `background_downloader`, `workmanager`, or `flutter_foreground_task` is used. Consult each package's platform requirements when selecting versions; Hivefy does not implement a background download worker.

Hivefy Android declares INTERNET, POST_NOTIFICATIONS, WAKE_LOCK, FOREGROUND_SERVICE and FOREGROUND_SERVICE_MEDIA_PLAYBACK. Its exported AudioService has `mediaPlayback` type and a MediaButtonReceiver; local-notification scheduled and boot receivers are also declared. There is **no download foreground service or dataSync permission**. Scheduled-notification receivers do not make downloads persistent. The normal Dart transfer is not guaranteed to continue after process death or under background restrictions.

On Android 13+, the app's permission gate explains and requests notification permission through permission_handler when appropriate; Settings can request it too. Denial does not stop the download. There is no special Android 14 download-service implementation. Darwin initialization disables automatic alert/badge/sound requests; the shown progress notification supplies Android details only. iOS declares audio background mode, not background transfer; no equivalent reliable iOS background download flow is established.

HiveTube already locks `dio 5.11.1`, `drift 2.35.4`, `flutter_riverpod 3.5.0`, `path_provider 2.1.6`, and `audio_service 0.18.19`; `audio_session 0.2.4` is transitive. It has no local-notifications, download-worker, or permission_handler packages in its lockfile. Its AudioService uses channel `com.hiveminds.hivetube.playback` / `Playback`; its manifest already has INTERNET, WAKE_LOCK, POST_NOTIFICATIONS, FOREGROUND_SERVICE and FOREGROUND_SERVICE_MEDIA_PLAYBACK, plus AudioService and MediaButtonReceiver. Its native activity requests POST_NOTIFICATIONS on Android 13+; avoid a duplicate prompt. Preserve the existing audio service and activity.

Contrary to the task premise, this checkout has **no `ffmpeg_kit_flutter_new_min` dependency or FFmpeg merge implementation** in lib or the pubspec/lockfile. Select and verify an available compatible mux implementation before promising merge support.

### Additions to evaluate for HiveTube

- Add a compatible notification plugin such as `flutter_local_notifications` only if the selected download engine does not already provide the needed notifications. Use a distinct download channel and stable per-job IDs; do not reuse playback channel or notification ID.
- For durable background transfers select a platform-capable background download mechanism. Its chosen package determines dependencies, manifest services/receivers and iOS configuration. If using an Android data-sync foreground service, declare its service with the appropriate `dataSync` type and `FOREGROUND_SERVICE_DATA_SYNC` alongside the existing base permission, and comply with current foreground-start and execution limits. A local notification alone provides no execution guarantee. Do not declare unused services or copy scheduled receivers blindly.
- Existing notification permission and media-playback permissions need no duplicate declarations. Check the selected plugin's merged manifest, SDK and dependency requirements; verify Android and iOS behavior on devices. Download and playback services must remain independently managed.

## Port plan

1. Define job lifecycle and offline product behavior: queued, resolving, downloading video, downloading audio, merging, completed, failed, cancelled. Choose a suitable mux engine and platform background execution; test container/codec compatibility and OS limits.
2. Create `lib/core/downloads/` services for job orchestration, resumable transfer, safe temp files, progress and muxing; use existing stream resolution where suitable. For large files stream to disk, avoid holding whole files in memory, check storage, and validate HTTP ranges, rendition identity and expired URL refresh.
3. Adapt the existing Drift Downloads table/repository and migrations only after schema approval. Current columns include video ID, kind, video/audio itags, height, container, path, total, done, status, error and creation time; robust restart/resume and phase/validator data may require additional fields. Reconcile DB state and temporary files after restart; never claim interrupted jobs resumed without verification.
4. Create a notification adapter with a separate channel, unique stable job IDs, time/percentage throttling, serialized updates, explicit ongoing/clear behavior, actions only when wired, tap navigation, and explicit success/failure states. Show per-phase progress; use indeterminate progress when size or merge progress is unknown. Keep merge distinct from completed download.
5. Wire a Riverpod 3 controller/provider to the persistent job state and notification adapter; update Library and download entry points to observe the same job. Keep media-playback and download notifications independent. Add only selected plugin/platform configuration and runtime permission handling.
6. Add focused tests for range validation, cancellation/retry and restart recovery, state transitions, merge failure/cleanup, notification ordering and existing library behavior. Verify Android permission denial, background execution, playback coexistence and process death on device; validate iOS separately.

## Risks and bugs not to copy

- Fixed progress ID and unawaited show/cancel can overwrite another job or resurrect a cleared notification; notification visibility does not imply background execution.
- No job persistence, pause/cancel, general retry, progress for unknown totals, or individual success/failure notification. Partial files can remain after process death.
- Queue state labels waiting jobs as downloading; failures are caught/logged rather than propagated to callers. Separate queued and failed states and expose actionable errors.
- First two SharedPreferences writes in `_save` are not awaited; incomplete persistence can follow interruption. Keep data and file-state updates recoverable.
- Raw song IDs form paths; sanitize or derive safe stable names. Validate existing cached content and final media, not merely nonzero length.
- Set deletion/count bookkeeping and delete-all cache/album bookkeeping can become inconsistent. Keep explicit downloads and automatic cache independent.
- Metadata saving can be skipped when a song has neither source URL nor YouTube ID, leaving an offline file absent from detailed library results.
- Android channel importance cannot be reliably changed by changing later notification details; user settings also apply. iOS behavior cannot be inferred from Android-only notification details.
