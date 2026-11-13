import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playback_service.dart';
import '../settings/app_settings.dart';

enum PlayerPanelMode { mini, moving, expanded }

class PlayerUiState {
  const PlayerUiState({
    this.overlayVisible = true,
    this.locked = false,
    this.isFullscreen = false,
    this.speed = 1,
    this.scrubbing = false,
    this.scrubPosition = Duration.zero,
    this.panelMode = PlayerPanelMode.expanded,
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
  final double speed;
  final PlayerPanelMode panelMode;
  final Duration scrubPosition, position, buffered, duration;
  final bool buffering, playing, completed, autoplay, recovering;

  Duration get displayPosition => scrubbing ? scrubPosition : position;

  PlayerUiState copyWith({
    bool? overlayVisible,
    bool? locked,
    bool? isFullscreen,
    double? speed,
    bool? scrubbing,
    Duration? scrubPosition,
    PlayerPanelMode? panelMode,
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
    panelMode: panelMode ?? this.panelMode,
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
    final autoplay = ref.read(contentPrefsProvider).autoplay;
    ref.listen(contentPrefsProvider.select((s) => s.autoplay), (_, value) {
      state = state.copyWith(autoplay: value);
    });
    final service = ref.watch(playbackProvider.select((value) => value));
    if (service == null) return PlayerUiState(autoplay: autoplay);
    final playback = service.state;
    void changed() {
      final current = service.state;
      state = state.copyWith(
        position: current.position,
        buffered: current.buffered,
        duration: current.duration,
        buffering:
            current.status == PlayerStatus.loading ||
            current.status == PlayerStatus.buffering,
        playing: current.playing,
        completed: current.status == PlayerStatus.ended,
        speed: current.rate,
        recovering: current.recovering,
      );
    }

    service.addListener(changed);
    ref.onDispose(() => service.removeListener(changed));
    return PlayerUiState(
      position: playback.position,
      buffered: playback.buffered,
      duration: playback.duration,
      buffering:
          playback.status == PlayerStatus.loading ||
          playback.status == PlayerStatus.buffering,
      playing: playback.playing,
      speed: playback.rate,
      completed: playback.status == PlayerStatus.ended,
      recovering: playback.recovering,
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
  void setPanelMode(PlayerPanelMode value) {
    if (state.panelMode == value) return;
    state = state.copyWith(panelMode: value);
  }

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
