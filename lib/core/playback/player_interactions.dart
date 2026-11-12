import 'package:meta/meta.dart';
import '../db/app_db.dart';

@immutable
class SeekStep {
  const SeekStep(this.target, this.totalSeconds);
  final Duration target;
  final int totalSeconds;
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
  final progress = entry.position.inMilliseconds / entry.duration.inMilliseconds;
  if (progress >= 0.90 || entry.position >= entry.duration - const Duration(seconds: 5)) {
    return Duration.zero;
  }
  return entry.position;
}
