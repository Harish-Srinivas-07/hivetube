import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_db.dart';
import '../yt/models.dart';

class QueueEntry {
  const QueueEntry({required this.video, required this.media});

  final VideoItem video;
  final MediaCompanion media;
}

final sessionQueueProvider =
    NotifierProvider<SessionQueueController, List<QueueEntry>>(
      SessionQueueController.new,
    );

class SessionQueueController extends Notifier<List<QueueEntry>> {
  @override
  List<QueueEntry> build() => const [];

  void add(VideoItem video, {MediaCompanion? media}) {
    state = [
      ...state.where((entry) => entry.video.id != video.id),
      _entry(video, media),
    ];
  }

  void playNext(VideoItem video, {MediaCompanion? media}) {
    state = [
      _entry(video, media),
      ...state.where((entry) => entry.video.id != video.id),
    ];
  }

  void remove(String videoId) {
    state = state.where((entry) => entry.video.id != videoId).toList();
  }

  QueueEntry? takeNext() {
    if (state.isEmpty) return null;
    final next = state.first;
    state = state.skip(1).toList();
    return next;
  }

  void clear() => state = const [];

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.length) return;
    if (newIndex < 0 || newIndex >= state.length) return;
    final next = [...state];
    final entry = next.removeAt(oldIndex);
    next.insert(newIndex, entry);
    state = next;
  }

  QueueEntry _entry(VideoItem video, MediaCompanion? media) => QueueEntry(
    video: video,
    media:
        media ??
        MediaCompanion.insert(
          videoId: video.id,
          title: video.title,
          channelId: video.channelId,
          channelName: video.channelName,
          thumbUrl: video.thumbUrl,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
  );
}
