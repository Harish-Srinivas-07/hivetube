import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/streams/stream_selector.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  test(
    'retained video track switch preserves the latest playback position',
    () async {
      final snapshot = PlaybackSnapshot()
        ..position = const Duration(seconds: 40);
      const video = PlayRequest(videoId: 'video', mode: PlaybackMode.video);
      final tracks = <String>[];
      final gate = Completer<void>();
      Future<void> select(VideoTrack track) async {
        tracks.add(track.id);
        if (track.id == 'no') await gate.future;
      }

      final switching = switchRetainedVideoTrack(
        snapshot: snapshot,
        current: video,
        audioOnly: true,
        setTrack: select,
        isCurrent: () => true,
        isPaused: () => false,
      );
      snapshot.position = const Duration(seconds: 42);
      gate.complete();
      final audio = (await switching)!;
      expect(audio.mode, PlaybackMode.audio);
      expect(audio.startAt, const Duration(seconds: 42));
      expect(snapshot.position, const Duration(seconds: 42));
      snapshot.position = const Duration(seconds: 56);
      final restored = await switchRetainedVideoTrack(
        snapshot: snapshot,
        current: audio,
        audioOnly: false,
        setTrack: select,
        isCurrent: () => true,
        isPaused: () => false,
      );
      expect(restored!.mode, PlaybackMode.video);
      expect(restored.startAt, const Duration(seconds: 56));
      expect(snapshot.position, const Duration(seconds: 56));
      expect(tracks, ['no', 'auto']);
    },
  );
  test(
    'audio-only selects a completed local video without needing a stream',
    () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final dir = await Directory.systemTemp.createTemp(
        'hivetube_local_audio_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final video = File('${dir.path}/saved.mp4');
      await video.writeAsBytes([1, 2, 3]);
      await db
          .into(db.downloads)
          .insert(
            DownloadsCompanion.insert(
              videoId: 'saved',
              kind: 'video',
              status: const Value('completed'),
              path: Value(video.path),
              createdAt: 1,
            ),
          );
      expect(
        await findLocalPlaybackPath(db, 'saved', PlaybackMode.audio),
        video.path,
      );
      expect(
        (await findLocalPlaybackSource(
          db,
          'saved',
          PlaybackMode.audio,
        ))?.hasVideo,
        isTrue,
      );
      expect(
        await findLocalPlaybackPath(db, 'saved', PlaybackMode.video),
        video.path,
      );
      expect(
        await findLocalPlaybackPath(db, 'saved', PlaybackMode.short),
        isNull,
      );
    },
  );
  test('Shorts progress never creates history or media rows', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final history = DriftHistoryRepo(db);
    await savePlaybackHistory(
      history,
      const PlayRequest.short('short-id'),
      const Duration(seconds: 4),
      const Duration(seconds: 20),
    );
    expect(await db.historyDao.getHistory(), isEmpty);
    expect(await db.select(db.media).get(), isEmpty);
  });

  test('watch progress retains title and channel metadata', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final history = DriftHistoryRepo(db);
    await db.historyDao.updateMediaMetadata(
      videoId: 'video-id',
      title: 'Video title',
      channelId: 'UCchannel',
      channelName: 'Channel name',
      thumbUrl: '',
    );
    await savePlaybackHistory(
      history,
      const PlayRequest(videoId: 'video-id', mode: PlaybackMode.video),
      const Duration(seconds: 4),
      const Duration(minutes: 2),
    );
    final rows = await db.historyDao.getHistory();
    expect(rows, hasLength(1));
    expect(rows.single.media?.title, 'Video title');
    expect(rows.single.media?.channelId, 'UCchannel');
    expect(rows.single.media?.channelName, 'Channel name');
  });
}
