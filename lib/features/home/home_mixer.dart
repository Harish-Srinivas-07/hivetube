import '../../core/db/app_db.dart';
import '../../core/yt/models.dart';

List<VideoItem> mixHome(
  List<List<VideoItem>> sources,
  List<int> weights, {
  List<HistoryEntry> history = const [],
  Set<String> disliked = const {},
}) {
  final watched = history
      .where(
        (e) =>
            e.duration.inMilliseconds > 0 &&
            e.position.inMilliseconds / e.duration.inMilliseconds >= .9,
      )
      .map((e) => e.videoId)
      .toSet();
  final indexes = List<int>.filled(sources.length, 0);
  final seen = <String>{};
  final result = <VideoItem>[];
  var progressed = true;
  while (progressed) {
    progressed = false;
    for (var i = 0; i < sources.length; i++) {
      for (var n = 0; n < weights[i] && indexes[i] < sources[i].length; n++) {
        final item = sources[i][indexes[i]++];
        progressed = true;
        if (!watched.contains(item.id) &&
            !disliked.contains(item.channelId) &&
            seen.add(item.id)) {
          result.add(item);
        }
      }
    }
  }
  return result;
}
