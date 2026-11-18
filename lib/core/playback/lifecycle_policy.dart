import 'package:flutter/widgets.dart';

enum LifecyclePlaybackAction { pause, audioOnly, restoreVideo, none }

LifecyclePlaybackAction lifecyclePlaybackAction(
  AppLifecycleState lifecycle, {
  required bool backgroundPlay,
}) {
  if (lifecycle == AppLifecycleState.resumed) {
    return backgroundPlay
        ? LifecyclePlaybackAction.restoreVideo
        : LifecyclePlaybackAction.none;
  }
  if (lifecycle == AppLifecycleState.paused ||
      lifecycle == AppLifecycleState.inactive ||
      lifecycle == AppLifecycleState.hidden) {
    return backgroundPlay
        ? LifecyclePlaybackAction.audioOnly
        : LifecyclePlaybackAction.pause;
  }
  return LifecyclePlaybackAction.none;
}
