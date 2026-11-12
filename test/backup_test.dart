import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/yt/backup_service.dart';
import 'package:hivetube/core/yt/takeout_parser.dart';

void main() {
  test('Takeout CSV parser extracts channel IDs and titles', () {
    const csv = '''Channel Id,Channel Url,Channel Title
UC_x5XG1OV2P6uZZ5FSM9Ttw,http://www.youtube.com/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw,Google for Developers
UCBCyU7B3gT8bU3Hq34bWw2w,http://www.youtube.com/channel/UCBCyU7B3gT8bU3Hq34bWw2w,"Tech With Tim"
''';
    final parsed = parseTakeoutCsv(csv);
    expect(parsed.length, 2);
    expect(parsed[0].channelId, 'UC_x5XG1OV2P6uZZ5FSM9Ttw');
    expect(parsed[0].title, 'Google for Developers');
    expect(parsed[1].channelId, 'UCBCyU7B3gT8bU3Hq34bWw2w');
    expect(parsed[1].title, 'Tech With Tim');
  });

  test('BackupService exports and imports data cleanly', () async {
    final db1 = AppDb(NativeDatabase.memory());
    await db1.subscriptionsDao.subscribe('UC_test_chan', name: 'Channel Alpha');
    final plId = await db1.playlistsDao.createPlaylist('Custom List');
    await db1.playlistsDao.addPlaylistItem(plId, 'vid_123');
    await db1.historyDao.recordWatch(
      videoId: 'vid_123',
      title: 'Awesome Video',
      channelId: 'UC_test_chan',
      channelName: 'Channel Alpha',
      durationSec: 300,
      positionMs: 60000,
      durationMs: 300000,
    );
    await db1.reactionsDao.setReaction('vid_123', 1);

    final service1 = BackupService(db1);
    final jsonString = await service1.exportJson();
    expect(jsonString, isNotEmpty);

    final preview = service1.inspectJson(jsonString);
    expect(preview.subscriptionCount, 1);
    expect(preview.playlistCount, 2); // Watch Later + Custom List
    expect(preview.historyCount, 1);
    expect(preview.reactionCount, 1);

    // Import into fresh db
    final db2 = AppDb(NativeDatabase.memory());
    final service2 = BackupService(db2);
    await service2.importJson(jsonString, replace: false);

    expect(await db2.subscriptionsDao.isSubscribed('UC_test_chan'), isTrue);
    final pl2 = await db2.playlistsDao.getPlaylists();
    expect(pl2.any((p) => p.name == 'Custom List'), isTrue);
    final hist2 = await db2.historyDao.getHistory();
    expect(hist2.length, 1);
    expect(hist2.first.history.videoId, 'vid_123');
    expect(await db2.reactionsDao.getReaction('vid_123'), 1);

    await db1.close();
    await db2.close();
  });

  test('BackupService does not export hl and ignores hl on import', () async {
    final db1 = AppDb(NativeDatabase.memory());
    await db1.setValue('content_gl_v1', 'IN');
    await db1.setValue('settings_hl', 'ta');
    await db1.setValue('content_hl_v1', 'ta');

    final service1 = BackupService(db1);
    final jsonString = await service1.exportJson();
    expect(jsonString.contains('"content_hl_v1"'), isFalse);
    expect(jsonString.contains('"settings_hl"'), isFalse);

    // Import into db2 with legacy json having hl
    final db2 = AppDb(NativeDatabase.memory());
    final service2 = BackupService(db2);
    const legacyBackup = '{"format":"hivetube_backup_v1","prefs":{"content_hl_v1":"hi","settings_hl":"hi","content_gl_v1":"US"}}';
    await service2.importJson(legacyBackup);
    expect(await db2.getValue('content_hl_v1'), isNull);
    expect(await db2.getValue('settings_hl'), isNull);
    expect(await db2.getValue('content_gl_v1'), 'US');

    await db1.close();
    await db2.close();
  });
}

