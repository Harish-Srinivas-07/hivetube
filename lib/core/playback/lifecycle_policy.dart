import 'package:flutter/widgets.dart';

enum LifecyclePlaybackAction { pause, audioOnly, restoreVideo, none }

LifecyclePlaybackAction lifecyclePlaybackAction(
  AppLifecycleState lifecycle, {
  required bool backgroundPlay,
  bool audioOnly = false,
}) {
  if (lifecycle == AppLifecycleState.resumed) {
    return backgroundPlay && !audioOnly
        ? LifecyclePlaybackAction.restoreVideo
        : LifecyclePlaybackAction.none;
  }
  if (lifecycle == AppLifecycleState.paused ||
      lifecycle == AppLifecycleState.inactive ||
      lifecycle == AppLifecycleState.hidden) {
    if (audioOnly) {
      return LifecyclePlaybackAction.none;
    }
    return backgroundPlay
        ? LifecyclePlaybackAction.audioOnly
        : LifecyclePlaybackAction.pause;
  }
  return LifecyclePlaybackAction.none;
}
