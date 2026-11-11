import 'dart:async';

/// Confirms that playback has stopped advancing before treating a player log as
/// a playback failure. media_kit's error stream also contains nonfatal logs.
class PlaybackFailureMonitor {
  PlaybackFailureMonitor({this.gracePeriod = const Duration(seconds: 3)});
  final Duration gracePeriod;
  Timer? _timer;
  Duration? _positionAtError;

  void report(Duration position, void Function() onStall) {
    if (_timer != null) return;
    _positionAtError = position;
    _timer = Timer(gracePeriod, () {
      _timer = null;
      _positionAtError = null;
      onStall();
    });
  }

  void positionChanged(Duration position) {
    if (_timer != null && position != _positionAtError) cancel();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _positionAtError = null;
  }
}
