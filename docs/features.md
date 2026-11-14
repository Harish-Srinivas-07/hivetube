Rules: AGENTS.md. UI: docs/design.md.

# MASTER PROMPT 3: FUTURE FEATURES

Use for any new feature. Applies on top of AGENTS.md and docs/design.md. Multi-step features: wrap in the orchestrator (docs/orchestrator.md O4).
RULE ZERO: many items below may already exist (SponsorBlock toggle, RYD, captions, backup, Takeout import, chapters, autoplay). Check the code first. If it exists, extend or fix it. Never build a second copy.

## F1. INTAKE (do before writing code, read-only, print nothing)
1. Does it already exist? grep names, providers, settings keys, routes. Check docs/yt_source.md for the planned design.
2. Data source: which InnerTube endpoint or local data? (lib/core/yt/*, lib/core/innertube/*). Probe it live with a tool/probe_*.dart script before building UI. No endpoint = stop and report.
3. Storage: does it need a new Drift table or column? YES = STOP, ask me (schema change needs approval). Prefer app settings (lib/core/settings) or the existing key-value store (db.getValue/setValue) for small state.
4. New dependency? New Android permission or native code? YES = STOP, ask me. Report the package, size and why.
5. UI: which docs/design.md components and screen section? Missing component = add it under lib/widgets/common and add it to docs/design.md section 4 in the same change.
6. States: loading, empty, error, offline, partial (docs/design.md section 6).
7. Tests: one logic test + one widget test minimum.

## F2. FEATURE SPECS (agent-ready; verify against the code first)

DOWNLOADS / OFFLINE
- Source: the existing stream selector (lib/core/streams/stream_selector.dart), 1080p max, H.264+AAC merged with ffmpeg_kit_flutter_new_min (stream copy). Audio-only option for music.
- Storage: files in app documents dir; metadata via MediaCompanion/playlists if a place exists. New table = ask first.
- UI: Library row "Downloads" (count), per-video menu "Download", progress as a 2px primary line on the compact row, a cancel/retry sheet. Offline playback prefers the local file.
- States: queued, downloading %, paused, failed (Retry), done. Survives app restart. Respects the "Wi-Fi only" setting if added.
- Gotchas: foreground service notification on Android, storage-full error, URL expiry (re-resolve the stream on retry).

QUEUE / PLAY NEXT
- Menu rows "Play next" and "Add to queue" already have hooks in video_options_menu.dart. Wire them to a session queue (in memory, persisted lightly via key-value if cheap).
- UI: a queue sheet from the player (showAppSheet): reorderable compact rows, current item marked, "Clear". Autoplay follows the queue first, then related.
- Gotchas: don't change playback_service internals without approval. Use its public play/seek API only.

YT MUSIC (lyrics, audio mode)
- Lyrics: YTM lyrics endpoint via the InnerTube client, parsed into timed or plain lines. Show in a sheet or watch tab with the current line highlighted (onSurface, others onSurfaceVariant, 16/24). No lyrics = "No lyrics available" empty state.
- Audio mode: the audio-only toggle in the player settings sheet (stream selector audio track), background play continues, media notification shows title/artist/art.
- Copyright note: don't hardcode lyrics, don't cache them beyond the session.

SPONSORBLOCK
- Fetch segments per video (privacy-friendly hash prefix API), auto-skip with a snackbar "Skipped sponsor" + Undo, category toggles in Settings.
- Seekbar: draw segments as thin colored ticks on the track (docs/design.md 4.21 stays flat).
- Gotchas: segment fetch must never block playback start. Timeout 3s, fail silently with a log.

COMMENTS
- Teaser + sheet exist per docs/design.md 4.22 / 5.3. Extend: sort (Top / Newest), replies expansion, pagination via continuation, pinned and hearted badges.
- Gotchas: comments disabled = "Comments are turned off" state. Heavy lists use keyed slivers, per-item data via family providers.

NEW-VIDEO NOTIFICATIONS (Android)
- Background check of subscription RSS via WorkManager (about every 30-60 min), local notification per channel set to "All". Respect the per-channel bell sheet.
- Needs: workmanager + local notifications dependencies, POST_NOTIFICATIONS permission (Android 13+). ASK FIRST.
- Gotchas: battery limits, dedupe against seen ids, tap opens the watch panel.

BACKUP / RESTORE
- backup_service.dart exists: export/import local data (subscriptions, playlists, history, settings) as a file. Extend, don't rewrite. Takeout CSV import exists. Add versioning to the backup file and a validation step before import (never half-import).

SEARCH EXTRAS
- Filters sheet (duration, upload date, type, sort) using the existing search params. Voice search: skip until requested.

PICTURE-IN-PICTURE (Android)
- Native activity change. ASK FIRST. Auto-enter PiP on leaving the app while a video plays, with play/pause action only.

DESKTOP (Windows / macOS / Linux) — NOT IN SCOPE NOW
- docs/design.md is mobile-only. Before any desktop work: write a "wide layout" section in docs/design.md (side rail nav, 2-3 column grid, mini player docking, hover states, keyboard shortcuts), get my approval, then orchestrate screen by screen. Don't add breakpoints ad hoc.

## F3. DECISION GATES (stop and ask in one line, don't pick silently)
- Drift schema change or migration
- New package (pubspec), new Android permission, native/Kotlin/Swift code
- Anything touching playback_service.dart internals or audio_handler.dart
- Removing a feature or setting
- A feature that needs a login or a backend (project rule: none)
- Anything that could violate YouTube/third-party terms in a new way: stop and ask

## F4. FEATURE PROMPT TEMPLATE (copy, fill the <>)
```
Task: <feature>. Read AGENTS.md, docs/features.md (F1-F3), and docs/design.md. If it has 3+ steps, run as ORCHESTRATOR (docs/orchestrator.md O4).
1. INTAKE per F1. If it already exists, say so in one line and extend it.
2. Probe the data source live (tool/probe_<name>.dart), report status and a sample.
3. Build: data layer, then UI from docs/design.md components, then wiring. States per docs/design.md section 6.
4. Tests: one logic + one widget test.
5. Gate: dart analyze, design_lint, non-golden tests. Checkpoint commit "feat(<scope>): <title>". No push.
If a decision gate (F3) is hit: stop, ask, don't continue that part.
Final reply = ONE line:
FEATURE | <name> | existed=<yes/no> | probe=<status/n items> | files=<list> | deps/permissions added=<none/list> | analyze=<ok/errors> | lint=<0/n> | tests=<pass/fail> | blocker=<none/exact>
```

## F5. ACCEPTANCE (every feature)
- Works signed-out, no backend, from the user's device.
- All states present, light + dark, tokens only, design_lint exit 0.
- No playback regression: pause/resume, background play, mini player, fullscreen still work (watch_panel_test passes).
- Failure of an optional source (lyrics, SponsorBlock, RYD) never blocks the main flow.
- Settings keys are stable and documented in one line in docs/design.md section 5.7 if user-facing.

## F6. SUGGESTED ORDER
1. Queue / play next (hooks already exist, no schema)
2. SponsorBlock UX polish (seekbar ticks, undo)
3. Downloads (largest; needs the F3 check on storage)
4. YT Music lyrics + audio mode
5. Comments sort/replies
6. New-video notifications (needs approval)
7. Search filters
8. PiP (needs approval)
9. Desktop (needs a docs/design.md wide spec first)
