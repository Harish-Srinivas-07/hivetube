import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/streams/stream_selector.dart';

void main() {
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
