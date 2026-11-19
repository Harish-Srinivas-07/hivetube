import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/yt/models.dart';

final offlineWatchVideosProvider = FutureProvider<List<VideoItem>>((ref) async {
  final db = ref.watch(dbProvider);
  final downloads =
      await (db.select(db.downloads)
            ..where((row) => row.status.equals('completed'))
            ..where((row) => row.kind.equals('video'))
            ..orderBy([(row) => OrderingTerm.asc(row.id)]))
          .get();
  final seen = <String>{};
  final videos = <VideoItem>[];
  for (final download in downloads) {
    final path = download.path;
    if (path == null || !seen.add(download.videoId)) continue;
    try {
      if (!await File(path).exists()) continue;
    } on FileSystemException {
      continue;
    }
    final media = await (db.select(
      db.media,
    )..where((row) => row.videoId.equals(download.videoId))).getSingleOrNull();
    videos.add(
      VideoItem(
        id: download.videoId,
        title: media?.title ?? download.videoId,
        channelId: media?.channelId ?? '',
        channelName: media?.channelName ?? '',
        thumbUrl: media?.thumbUrl ?? '',
        durationText: '',
      ),
    );
  }
  return videos;
});
