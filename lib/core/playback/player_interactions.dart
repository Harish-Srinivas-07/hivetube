import 'dart:async';

import 'package:meta/meta.dart';
import '../db/app_db.dart';

@immutable
class SeekStep {
  const SeekStep(this.target, this.totalSeconds);
  final Duration target;
  final int totalSeconds;
}

SeekStep multiTapSeek({
  required int taps,
  required bool forward,
  required Duration position,
  required Duration duration,
}) {
  final seconds =
      switch (taps) {
        < 2 => 0,
        2 => 10,
        3 => 20,
        4 => 30,
        _ => 50,
      } *
      (forward ? 1 : -1);
  final target = position + Duration(seconds: seconds);
  return SeekStep(
    target < Duration.zero
        ? Duration.zero
        : target > duration
        ? duration
        : target,
    seconds,
  );
}

class MultiTapSeekSession {
  MultiTapSeekSession({
    required this.gap,
    required this.onSingleTap,
    required this.onFeedback,
    required this.onSeek,
  });

  final Duration gap;
  final void Function() onSingleTap;
  final void Function(SeekStep?) onFeedback;
  final void Function(Duration) onSeek;
  Timer? _timer;
  Duration _origin = Duration.zero, _duration = Duration.zero;
  bool _forward = false;
  int _taps = 0;

  void tap({
    required bool forward,
    required Duration position,
    required Duration duration,
  }) {
    if (_taps > 0 && _forward != forward) _finish();
    if (_taps == 0) {
      _origin = position;
      _duration = duration;
      _forward = forward;
    }
    _taps++;
    if (_taps >= 2) {
      onFeedback(
        multiTapSeek(
          taps: _taps,
          forward: _forward,
          position: _origin,
          duration: _duration,
        ),
      );
    }
    _timer?.cancel();
    _timer = Timer(gap, _finish);
  }

  void _finish() {
    _timer?.cancel();
    final taps = _taps;
    if (taps == 0) return;
    final result = multiTapSeek(
      taps: taps,
      forward: _forward,
      position: _origin,
      duration: _duration,
    );
    _taps = 0;
    if (taps == 1) {
      onSingleTap();
    } else {
      onSeek(result.target);
      onFeedback(null);
    }
  }

  void cancel({bool notify = true}) {
    _timer?.cancel();
    final hadFeedback = _taps >= 2;
    _taps = 0;
    if (notify && hadFeedback) onFeedback(null);
  }
}

SeekStep accumulateSeek({
  required Duration position,
  required Duration duration,
  required int seconds,
  required int previousSeconds,
  Duration? previousTarget,
}) {
  final sameDirection =
      previousSeconds != 0 && previousSeconds.sign == seconds.sign;
  final target =
      (sameDirection ? previousTarget ?? position : position) +
      Duration(seconds: seconds);
  final clamped = target < Duration.zero
      ? Duration.zero
      : duration > Duration.zero && target > duration
      ? duration
      : target;
  return SeekStep(clamped, sameDirection ? previousSeconds + seconds : seconds);
}

double panelReleaseTarget(double progress, double velocity) =>
    velocity.abs() > 700 ? (velocity > 0 ? 1 : 0) : (progress > .5 ? 1 : 0);

Duration resumePosition(HistoryEntry? entry) {
  if (entry == null || entry.duration.inMilliseconds <= 0) return Duration.zero;
  final progress =
      entry.position.inMilliseconds / entry.duration.inMilliseconds;
  if (progress >= 0.90 ||
      entry.position >= entry.duration - const Duration(seconds: 5)) {
    return Duration.zero;
  }
  return entry.position;
}
