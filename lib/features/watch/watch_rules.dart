import '../../core/yt/models.dart';

enum WatchBackAction { locked, fullscreen, panel, page }

WatchBackAction watchBackAction({
  required bool locked,
  required bool fullscreen,
  required bool panelOpen,
}) {
  if (locked) return WatchBackAction.locked;
  if (fullscreen) return WatchBackAction.fullscreen;
  if (panelOpen) return WatchBackAction.panel;
  return WatchBackAction.page;
}

VideoItem? selectUpNext({
  required List<VideoItem> queue,
  required Iterable<VideoItem> related,
  required Set<String> finished,
  required String currentId,
}) {
  if (queue.isNotEmpty) return queue.first;
  return related
      .where(
        (v) =>
            v.id != currentId &&
            !v.isShort &&
            !v.isLive &&
            !finished.contains(v.id),
      )
      .firstOrNull;
}
