import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'playback_service.dart';

class SeekController {
  SeekController({
    this.player,
    Future<void> Function(Duration target)? onSeekToPlayer,
    Duration Function()? getPlayerPosition,
    bool Function()? isPlayerBuffering,
    required this.getDuration,
    required this.getPosition,
    required this.getStatus,
    required this.isUserPaused,
    required this.onSeekStateChanged,
    required this.onRecovery,
    required this.onAudioSyncCheck,
    required this.onPlaybackResume,
    this.debounceDuration = const Duration(milliseconds: 120),
    this.timeoutDuration = const Duration(seconds: 8),
    this.pollInterval = const Duration(milliseconds: 50),
    this.settleTimeout = const Duration(milliseconds: 4000),
  })  : _onSeekToPlayer = onSeekToPlayer ?? ((d) => player!.seek(d)),
        _getPlayerPosition =
            getPlayerPosition ?? (() => player!.state.position),
        _isPlayerBuffering =
            isPlayerBuffering ?? (() => player!.state.buffering);

  final Player? player;
  final Future<void> Function(Duration target) _onSeekToPlayer;
  final Duration Function() _getPlayerPosition;
  final bool Function() _isPlayerBuffering;
  final Duration Function() getDuration;
  final Duration Function() getPosition;
  final PlayerStatus Function() getStatus;
  final bool Function() isUserPaused;
  final void Function(SeekState state, Duration? target) onSeekStateChanged;
  final Future<void> Function() onRecovery;
  final Future<void> Function() onAudioSyncCheck;
  final Future<void> Function() onPlaybackResume;
  final Duration debounceDuration;
  final Duration timeoutDuration;
  final Duration pollInterval;
  final Duration settleTimeout;

  int _generation = 0;
  int get generation => _generation;
  Timer? _debounceTimer;
  Timer? _timeoutTimer;
  bool _mpvSeeking = false;
  bool _mpvPausedForCache = false;
  bool _wasPlayingBeforeSeek = false;
  SeekState _state = SeekState.idle;
  SeekState get state => _state;
  Duration? _target;
  Duration? get target => _target;
  bool _disposed = false;

  void updateMpvProperties({bool? seeking, bool? pausedForCache}) {
    if (seeking != null) _mpvSeeking = seeking;
    if (pausedForCache != null) _mpvPausedForCache = pausedForCache;
  }

  Future<void> seekTo(Duration v) async {
    final maxDuration = getDuration() > Duration.zero ? getDuration() : v;
    final clamped = v < Duration.zero
        ? Duration.zero
        : (v > maxDuration ? maxDuration : v);

    final gen = ++_generation;

    // Record wasPlaying if starting from idle
    if (_state == SeekState.idle) {
      _wasPlayingBeforeSeek = !isUserPaused();
    }

    _state = SeekState.seeking;
    _target = clamped;
    onSeekStateChanged(_state, _target);

    _debounceTimer?.cancel();
    _timeoutTimer?.cancel();

    _debounceTimer = Timer(debounceDuration, () async {
      if (_generation != gen || _disposed) return;

      _timeoutTimer = Timer(timeoutDuration, () {
        if (_generation == gen && !_disposed) {
          unawaited(onRecovery());
        }
      });

      try {
        await _onSeekToPlayer(clamped);
      } catch (e) {
        if (kDebugMode) {
          stdout.writeln('[SeekController] player.seek error: $e');
        }
      }

      final waitSw = Stopwatch()..start();
      while (waitSw.elapsedMilliseconds < settleTimeout.inMilliseconds) {
        if (_generation != gen || _disposed) return;
        final posDiff = (_getPlayerPosition() - clamped).inMilliseconds.abs();
        final isBuffering = _isPlayerBuffering();

        if (!_mpvSeeking &&
            !_mpvPausedForCache &&
            !isBuffering &&
            (posDiff <= 1500 ||
                _getPlayerPosition() >=
                    clamped - const Duration(milliseconds: 500))) {
          break;
        }
        await Future<void>.delayed(pollInterval);
      }

      if (_generation != gen || _disposed) return;
      _timeoutTimer?.cancel();

      // Audio sync check
      await onAudioSyncCheck();

      _state = SeekState.ready;
      onSeekStateChanged(_state, clamped);

      // Restore playback state: restore wasPlaying if it was playing before seek
      if (_wasPlayingBeforeSeek) {
        await onPlaybackResume();
      }

      _state = SeekState.idle;
      _target = null;
      onSeekStateChanged(_state, null);
    });
  }

  void cancel() {
    _debounceTimer?.cancel();
    _timeoutTimer?.cancel();
    _state = SeekState.idle;
    _target = null;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
