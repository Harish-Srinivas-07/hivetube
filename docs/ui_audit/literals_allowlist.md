# Literals Allowlist & Audit Rationale

This document defines the strict allowlist for numeric/literal values in HiveTube outside of `lib/theme/`.

## Target
Zero magic numbers for visual layout, styling, colors, borders, paddings, sizing, and typography across the entire codebase.

### Audit Summary
- **EdgeInsets / Padding literals**: 0 (all use `AppSpacing` / `AppLayout`)
- **SizedBox numeric literals**: 0 (all use `AppSpacing` / `AppSizes`)
- **BorderRadius numeric literals**: 0 (all use `AppRadius`)
- **Color / Colors literals**: 0 (all use `AppColors` or `theme.colorScheme`)
- **TextStyle numeric literals**: 0 (all use `theme.textTheme` or `AppTextStyles`)
- **Icon size numeric literals**: 0 (all use `AppSizes`)

---

## Allowlisted Non-UI Literals (Backend, Protocol, Timeouts & Cache)

The remaining 46 `Duration` literals represent protocol-level invariants, network socket timeouts, cache invalidation TTLs, and asynchronous event debouncing. They are NOT design or UI tokens:

1. **Network & HTTP Client Timeouts**:
   - `lib/core/providers.dart` (connectTimeout: 15s, receiveTimeout: 20s)
   - `lib/core/streams/net_family.dart` (connectionTimeout: 10s)
   - `lib/core/streams/player_client.dart` (http request timeout: 15s)
   - `lib/core/streams/relay_server.dart` (relay response timeout: 6s)
   - `lib/core/playback/playback_service.dart` (stream probe timeout: 2s, mpv network timeout: 15s)
   - `lib/core/content/caption_probe.dart` (caption request timeout: 1500ms)

2. **Cache Expiry / TTL Policies**:
   - `lib/core/streams/stream_cache.dart` (stream format freshness: 10m/20m, expiry safety margin: 5m, playback resolve timeout: 6s)
   - `lib/core/yt/channel_avatars.dart` (avatar failure backoff: 10m)
   - `lib/features/home/home_cache.dart` (home feed cache validity: 30m)
   - `lib/features/home/home_controller.dart` (background refresh cooldown: 30m)

3. **Playback & Seek Engine State Machine**:
   - `lib/core/playback/seek_controller.dart` (scrub debounce: 120ms, seek timeout: 8s, poll interval: 50ms, settle timeout: 4000ms, clamping margin: 500ms)
   - `lib/core/playback/load_guard.dart` (max stall before re-resolve: 60s)
   - `lib/core/playback/playback_failure_monitor.dart` (failure grace period: 3s)
   - `lib/core/playback/player_interactions.dart` (watch history resume end threshold: 5s)
   - `lib/core/playback/player_ui_state.dart` (position throttle threshold: 200ms)
   - `lib/core/playback/playback_service.dart` (stall gap detector: 2s/5s, quality change debounce: 300ms)

4. **UI Event Debounce & Overlay Timers**:
   - `lib/widgets/player/player_controls.dart` (overlay auto-hide: 3s, double-tap seek commit: 400ms, seek accumulation timer: 600ms, HUD banner dismiss: 1s)
   - `lib/features/watch/watch_panel.dart` (mini controls auto-hide: 3s, sleep timer tick: 1s, tooltip hover delay: 500ms)
   - `lib/features/watch/watch_screen.dart` (sleep timer countdown tick: 1s, 10s seek button steps)
   - `lib/features/search/search_screen.dart` (query input debounce: 250ms)
   - `lib/features/home/home_controller.dart` (feed refresh debounce: 250ms)

