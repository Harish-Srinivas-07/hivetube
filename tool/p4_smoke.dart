import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/player_interactions.dart';
import 'package:hivetube/core/yt/backup_service.dart';
import 'package:hivetube/core/yt/takeout_parser.dart';

void main() async {
  stdout.writeln('\n=== P4 Local Account Smoke Test ===');
  var passed = 0;
  var total = 0;

  void check(String name, bool condition, [String details = '']) {
    total++;
    if (condition) {
      passed++;
      stdout.writeln('  [PASS] $name $details');
    } else {
      stdout.writeln('  [FAIL] $name $details');
    }
    assert(condition, name);
  }

    final db = AppDb(NativeDatabase.memory());

    // 1. Migration from v1 prefs
    await db.setValue(
      'subscriptions_v1',
      jsonEncode(['UC_x5XG1OV2P6uZZ5FSM9Ttw', 'UCBCyU7B3gT8bU3Hq34bWw2w']),
    );
    await db.setValue(
      'watch_history_v1',
      jsonEncode([
        {
          'id': 'aqz-KE-bpKQ',
          'position': 45000,
          'duration': 120000,
          'channelName': 'Test Channel',
          'isShort': false,
        }
      ]),
    );

    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 1, 2);

    final subs = await db.subscriptionsDao.getSubscriptions();
    check('DB Migration - Subscriptions', subs.length == 2, '(${subs.length} channels)');

    final hist = await db.historyDao.getHistory();
    check(
      'DB Migration - Watch History',
      hist.length == 1 && hist.first.history.videoId == 'aqz-KE-bpKQ',
      '(id: ${hist.firstOrNull?.history.videoId}, pos: ${hist.firstOrNull?.history.positionMs}ms)',
    );

    // 2. Subscriptions DAO
    await db.subscriptionsDao.subscribe('UC_smoke_chan', name: 'Smoke Channel');
    check('Subscriptions DAO - subscribe', await db.subscriptionsDao.isSubscribed('UC_smoke_chan'));
    await db.subscriptionsDao.unsubscribe('UC_smoke_chan');
    check('Subscriptions DAO - unsubscribe', !(await db.subscriptionsDao.isSubscribed('UC_smoke_chan')));

    // 3. History DAO & Resume rule
    await db.historyDao.recordWatch(
      videoId: 'vid_resume_test',
      title: 'Resume Test Video',
      channelId: 'UC_test',
      channelName: 'Tester',
      durationSec: 100,
      positionMs: 40000,
      durationMs: 100000,
    );
    check('History DAO - recordWatch', (await db.historyDao.getLastPosition('vid_resume_test')) == 40000);

    // Resume rule: 40% watched -> resumes at 40s
    final entry40 = HistoryEntry('vid_resume_test', const Duration(seconds: 40), const Duration(seconds: 100));
    final pos40 = resumePosition(entry40);
    check('Resume rule (<90%)', pos40 == const Duration(seconds: 40), '(pos: ${pos40.inSeconds}s)');

    // Resume rule: 92% watched -> resets to 0
    final entry92 = HistoryEntry('vid_resume_test', const Duration(seconds: 92), const Duration(seconds: 100));
    final pos92 = resumePosition(entry92);
    check('Resume rule (>=90%)', pos92 == Duration.zero, '(pos: ${pos92.inSeconds}s)');

    // 4. Playlists DAO & Reorder
    final plId = await db.playlistsDao.createPlaylist('Smoke Playlist');
    await db.playlistsDao.addPlaylistItem(plId, 'item_1');
    await db.playlistsDao.addPlaylistItem(plId, 'item_2');
    await db.playlistsDao.addPlaylistItem(plId, 'item_3');

    var items = await db.playlistsDao.getPlaylistItems(plId);
    check('Playlists DAO - add items', items.length == 3, '(${items.length} items)');

    await db.playlistsDao.reorderPlaylistItems(plId, 0, 2);
    items = await db.playlistsDao.getPlaylistItems(plId);
    check(
      'Playlists DAO - reorder',
      items[0].item.videoId == 'item_2' && items[1].item.videoId == 'item_3' && items[2].item.videoId == 'item_1',
      '(order: ${items.map((i) => i.item.videoId).join(', ')})',
    );

    // 5. Reactions DAO
    await db.reactionsDao.setReaction('item_1', 1);
    check('Reactions DAO - like', (await db.reactionsDao.getReaction('item_1')) == 1);
    final liked = await db.reactionsDao.getLikedVideos();
    check('Reactions DAO - liked videos', liked.any((m) => m.videoId == 'item_1'), '(${liked.length} liked)');

    // 6. Backup JSON round-trip
    final backupService = BackupService(db);
    final jsonStr = await backupService.exportJson();
    final preview = backupService.inspectJson(jsonStr);

    final beforeSubs = (await db.select(db.subscriptions).get()).length;
    final beforePl = (await db.select(db.playlists).get()).length;
    final beforePlItems = (await db.select(db.playlistItems).get()).length;
    final beforeHist = (await db.select(db.history).get()).length;
    final beforeReact = (await db.select(db.reactions).get()).length;
    stdout.writeln('  [Backup Before] subs=$beforeSubs, playlists=$beforePl, items=$beforePlItems, history=$beforeHist, reactions=$beforeReact');

    check(
      'BackupService - export & inspect',
      preview.subscriptionCount >= 2 && preview.playlistCount >= 2,
      '(subs: ${preview.subscriptionCount}, pl: ${preview.playlistCount}, hist: ${preview.historyCount})',
    );

    final db2 = AppDb(NativeDatabase.memory());
    final backupService2 = BackupService(db2);
    await backupService2.importJson(jsonStr);

    final afterSubs = (await db2.select(db2.subscriptions).get()).length;
    final afterPl = (await db2.select(db2.playlists).get()).length;
    final afterPlItems = (await db2.select(db2.playlistItems).get()).length;
    final afterHist = (await db2.select(db2.history).get()).length;
    final afterReact = (await db2.select(db2.reactions).get()).length;
    stdout.writeln('  [Backup After]  subs=$afterSubs, playlists=$afterPl, items=$afterPlItems, history=$afterHist, reactions=$afterReact');

    check('BackupService - import match subs', beforeSubs == afterSubs);
    check('BackupService - import match playlists', afterPl == 2, '(deduped Watch Later + custom: $afterPl)');
    check('BackupService - import match items', beforePlItems == afterPlItems);
    check('BackupService - import match history', beforeHist == afterHist);
    check('BackupService - import match reactions', beforeReact == afterReact);
    check('BackupService - import', await db2.subscriptionsDao.isSubscribed('UC_x5XG1OV2P6uZZ5FSM9Ttw'));

    // 7. Google Takeout CSV parsing
    const csv = '''Channel Id,Channel Url,Channel Title
UC_x5XG1OV2P6uZZ5FSM9Ttw,http://www.youtube.com/channel/UC_x5XG1OV2P6uZZ5FSM9Ttw,Google for Developers
UCBCyU7B3gT8bU3Hq34bWw2w,http://www.youtube.com/channel/UCBCyU7B3gT8bU3Hq34bWw2w,Tech With Tim
''';
    final parsed = parseTakeoutCsv(csv);
    check('Takeout CSV parser', parsed.length == 2 && parsed[0].channelId == 'UC_x5XG1OV2P6uZZ5FSM9Ttw');

    await db.close();
    await db2.close();

    stdout.writeln('-----------------------------------');
    stdout.writeln('Smoke result: $passed/$total tests passed.');
    exit(passed == total ? 0 : 1);
}
