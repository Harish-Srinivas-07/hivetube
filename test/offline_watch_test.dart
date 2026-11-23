import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/features/watch/offline_watch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline watch list uses only completed local video files', () async {
    final directory = await Directory.systemTemp.createTemp('offline_watch_');
    final videoFile = File('${directory.path}/video.mp4')
      ..writeAsStringSync('local video');
    final db = AppDb(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [dbProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
      await directory.delete(recursive: true);
    });

    await db
        .into(db.downloads)
        .insert(
          DownloadsCompanion.insert(
            videoId: 'local-video',
            kind: 'video',
            path: Value(videoFile.path),
            status: const Value('completed'),
            createdAt: 1,
          ),
        );
    await db
        .into(db.downloads)
        .insert(
          DownloadsCompanion.insert(
            videoId: 'audio-only',
            kind: 'audio',
            path: Value(videoFile.path),
            status: const Value('completed'),
            createdAt: 2,
          ),
        );

    final videos = await container.read(offlineWatchVideosProvider.future);
    expect(videos.map((video) => video.id), ['local-video']);
  });
}
