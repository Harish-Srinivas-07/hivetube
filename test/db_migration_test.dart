import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';

void main() {
  test('Drift DB migration v1 to v2 migrates subscriptions and history', () async {
    // Open in-memory DB
    final db = AppDb(NativeDatabase.memory());

    // Insert legacy v1 prefs JSON
    await db.setValue(
      'subscriptions_v1',
      jsonEncode(['UC_x5XG1OV2P6uZZ5FSM9Ttw', 'UC1234567890abcdefghij']),
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

    // Call migration
    await db.customStatement('PRAGMA user_version = 1');
    // Run upgrade
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    final migrator = db.createMigrator();
    await db.migration.onUpgrade(migrator, 1, 2);

    // Verify subscriptions migrated
    final subs = await db.subscriptionsDao.getSubscriptions();
    expect(subs.length, 2);
    expect(subs.map((s) => s.channelId), contains('UC_x5XG1OV2P6uZZ5FSM9Ttw'));

    // Verify history and media migrated
    final history = await db.historyDao.getHistory();
    expect(history.length, 1);
    expect(history.first.history.videoId, 'aqz-KE-bpKQ');
    expect(history.first.history.positionMs, 45000);
    expect(history.first.media?.channelName, 'Test Channel');

    // Verify Watch Later playlist created
    final playlists = await db.playlistsDao.getPlaylists();
    expect(playlists.any((p) => p.name == 'Watch Later'), isTrue);

    await db.close();
  });

  test('Drift DAOs: Subscriptions, History, Playlists, Reactions CRUD and streams', () async {
    final db = AppDb(NativeDatabase.memory());

    // 1. Subscriptions
    await db.subscriptionsDao.subscribe('UC_test_1', name: 'Tester', avatarUrl: 'https://avatar');
    expect(await db.subscriptionsDao.isSubscribed('UC_test_1'), isTrue);
    final subs = await db.subscriptionsDao.getSubscriptions();
    expect(subs.first.name, 'Tester');
    await db.subscriptionsDao.unsubscribe('UC_test_1');
    expect(await db.subscriptionsDao.isSubscribed('UC_test_1'), isFalse);

    // 2. History & Position
    await db.historyDao.recordWatch(
      videoId: 'vid1',
      title: 'Video 1',
      channelId: 'UC_test_1',
      channelName: 'Tester',
      durationSec: 100,
      positionMs: 5000,
      durationMs: 100000,
    );
    expect(await db.historyDao.getLastPosition('vid1'), 5000);
    await db.historyDao.updatePosition('vid1', 12000, 100000);
    expect(await db.historyDao.getLastPosition('vid1'), 12000);

    // 3. Playlists & Reorder
    final plId = await db.playlistsDao.createPlaylist('Favorites');
    await db.playlistsDao.addPlaylistItem(plId, 'vidA');
    await db.playlistsDao.addPlaylistItem(plId, 'vidB');
    await db.playlistsDao.addPlaylistItem(plId, 'vidC');

    var items = await db.playlistsDao.getPlaylistItems(plId);
    expect(items.map((i) => i.item.videoId).toList(), ['vidA', 'vidB', 'vidC']);

    // Reorder vidA to index 2
    await db.playlistsDao.reorderPlaylistItems(plId, 0, 2);
    items = await db.playlistsDao.getPlaylistItems(plId);
    expect(items.map((i) => i.item.videoId).toList(), ['vidB', 'vidC', 'vidA']);

    // 4. Reactions
    await db.reactionsDao.setReaction('vid1', 1);
    expect(await db.reactionsDao.getReaction('vid1'), 1);
    await db.reactionsDao.setReaction('vid1', null);
    expect(await db.reactionsDao.getReaction('vid1'), isNull);

    await db.close();
  });
}
