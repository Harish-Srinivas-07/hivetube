/// Tracks network recovery that must wait until playback can resolve streams.
class PlaybackNetworkState {
  bool online = true;
  bool _recoverWhenOnline = false;

  /// Returns true once when a deferred recovery becomes possible.
  bool updateOnline(bool value) {
    final wasOnline = online;
    online = value;
    if (value && !wasOnline && _recoverWhenOnline) {
      _recoverWhenOnline = false;
      return true;
    }
    return false;
  }

  void deferRecovery() {
    _recoverWhenOnline = true;
  }
}
