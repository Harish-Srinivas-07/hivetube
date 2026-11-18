import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/lifecycle_policy.dart';

void main() {
  test('background playback selects audio, pauses, and restores on resume', () {
    for (final lifecycle in [
      AppLifecycleState.paused,
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
    ]) {
      expect(
        lifecyclePlaybackAction(lifecycle, backgroundPlay: true),
        LifecyclePlaybackAction.audioOnly,
      );
      expect(
        lifecyclePlaybackAction(lifecycle, backgroundPlay: false),
        LifecyclePlaybackAction.pause,
      );
    }
    expect(
      lifecyclePlaybackAction(AppLifecycleState.resumed, backgroundPlay: true),
      LifecyclePlaybackAction.restoreVideo,
    );
    expect(
      lifecyclePlaybackAction(AppLifecycleState.resumed, backgroundPlay: false),
      LifecyclePlaybackAction.none,
    );
  });
}
