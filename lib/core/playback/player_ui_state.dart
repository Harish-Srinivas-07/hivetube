import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playback_service.dart';
import '../settings/app_settings.dart';

class PlayerUiState {
  const PlayerUiState({
    this.overlayVisible = true,
    this.locked = false,
    this.isFullscreen = false,
    this.speed = 1,
    this.scrubbing = false,
    this.scrubPosition = Duration.zero,
    this.panelProgress = 0,
    this.dismissed = true,
    this.position = Duration.zero,
    this.buffered = Duration.zero,
    this.duration = Duration.zero,
    this.buffering = false,
    this.playing = false,
    this.completed = false,
    this.autoplay = false,
    this.recovering = false,
  });

  final bool overlayVisible, locked, isFullscreen, scrubbing, dismissed;
  final double speed, panelProgress;
  final Duration scrubPosition, position, buffered, duration;
  final bool buffering, playing, completed, autoplay, recovering;

  PlayerUiState copyWith({
    bool? overlayVisible,
    bool? locked,
    bool? isFullscreen,
    double? speed,
    bool? scrubbing,
    Duration? scrubPosition,
    double? panelProgress,
    bool? dismissed,
    Duration? position,
    Duration? buffered,
    Duration? duration,
    bool? buffering,
    bool? playing,
    bool? completed,
    bool? autoplay,
    bool? recovering,
  }) => PlayerUiState(
    overlayVisible: overlayVisible ?? this.overlayVisible,
    locked: locked ?? this.locked,
    isFullscreen: isFullscreen ?? this.isFullscreen,
    speed: speed ?? this.speed,
    scrubbing: scrubbing ?? this.scrubbing,
    scrubPosition: scrubPosition ?? this.scrubPosition,
    panelProgress: panelProgress ?? this.panelProgress,
    dismissed: dismissed ?? this.dismissed,
    position: position ?? this.position,
    buffered: buffered ?? this.buffered,
    duration: duration ?? this.duration,
    buffering: buffering ?? this.buffering,
    playing: playing ?? this.playing,
    completed: completed ?? this.completed,
    autoplay: autoplay ?? this.autoplay,
    recovering: recovering ?? this.recovering,
  );
}

final playerUiProvider = NotifierProvider<PlayerUiController, PlayerUiState>(
  PlayerUiController.new,
);

class PlayerUiController extends Notifier<PlayerUiState> {
  @override
  PlayerUiState build() {
    final autoplay = ref.read(appSettingsProvider).autoplay;
    ref.listen(appSettingsProvider.select((s) => s.autoplay), (_, value) {
      state = state.copyWith(autoplay: value);
    });
    final service = ref.watch(playbackProvider.select((value) => value));
    if (service == null) return PlayerUiState(autoplay: autoplay);
    final player = service.player;
    final subscriptions = <StreamSubscription<dynamic>>[
      player.stream.position.listen(
        (value) => state = state.copyWith(position: value),
      ),
      player.stream.buffer.listen(
        (value) => state = state.copyWith(buffered: value),
      ),
      player.stream.duration.listen(
        (value) => state = state.copyWith(duration: value),
      ),
      player.stream.buffering.listen(
        (value) => state = state.copyWith(buffering: value),
      ),
      player.stream.playing.listen(
        (value) => state = state.copyWith(playing: value),
      ),
      player.stream.rate.listen(
        (value) => state = state.copyWith(speed: value),
      ),
      player.stream.completed.listen(
        (value) => state = state.copyWith(completed: value),
      ),
    ];
    void changed() =>
        state = state.copyWith(recovering: service.state.recovering);
    service.addListener(changed);
    ref.onDispose(() {
      service.removeListener(changed);
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    });
    return PlayerUiState(
      position: player.state.position,
      buffered: player.state.buffer,
      duration: player.state.duration,
      buffering: player.state.buffering,
      playing: player.state.playing,
      speed: player.state.rate,
      completed: player.state.completed,
      recovering: service.state.recovering,
      autoplay: autoplay,
      dismissed: service.request == null,
    );
  }

  void setOverlayVisible(bool value) =>
      state = state.copyWith(overlayVisible: value);
  void setLocked(bool value) => state = state.copyWith(locked: value);
  void setFullscreen(bool value) => state = state.copyWith(isFullscreen: value);
  void setScrubbing(bool value) => state = state.copyWith(scrubbing: value);
  void setScrubPosition(Duration value) =>
      state = state.copyWith(scrubPosition: value);
  void setPanelProgress(double value) =>
      state = state.copyWith(panelProgress: value.clamp(0.0, 1.0));
  void setDismissed(bool value) => state = state.copyWith(dismissed: value);
}

final playbackPositionProvider =
    NotifierProvider<PlaybackPositionController, Duration>(
      PlaybackPositionController.new,
    );

class PlaybackPositionController extends Notifier<Duration> {
  @override
  Duration build() => ref.watch(playerUiProvider.select((s) => s.position));
}

final playbackBufferedProvider =
    NotifierProvider<PlaybackBufferedController, Duration>(
      PlaybackBufferedController.new,
    );

class PlaybackBufferedController extends Notifier<Duration> {
  @override
  Duration build() => ref.watch(playerUiProvider.select((s) => s.buffered));
}

final playbackDurationProvider =
    NotifierProvider<PlaybackDurationController, Duration>(
      PlaybackDurationController.new,
    );

class PlaybackDurationController extends Notifier<Duration> {
  @override
  Duration build() => ref.watch(playerUiProvider.select((s) => s.duration));
}

final playbackPlayingProvider =
    NotifierProvider<PlaybackPlayingController, bool>(
      PlaybackPlayingController.new,
    );

class PlaybackPlayingController extends Notifier<bool> {
  @override
  bool build() => ref.watch(playerUiProvider.select((s) => s.playing));
}

final playbackBufferingProvider =
    NotifierProvider<PlaybackBufferingController, bool>(
      PlaybackBufferingController.new,
    );

class PlaybackBufferingController extends Notifier<bool> {
  @override
  bool build() => ref.watch(playerUiProvider.select((s) => s.buffering));
}

final playbackCompletedProvider =
    NotifierProvider<PlaybackCompletedController, bool>(
      PlaybackCompletedController.new,
    );

class PlaybackCompletedController extends Notifier<bool> {
  @override
  bool build() => ref.watch(playerUiProvider.select((s) => s.completed));
}
