import 'dart:convert';
import 'package:drift/drift.dart';
import 'app_db_executor_vm.dart'
    if (dart.library.ui) 'app_db_executor_flutter.dart';

import 'history_entry.dart';
import 'tables.dart';
import '../yt/channel_metadata.dart';

export 'history_entry.dart';
export 'tables.dart' hide Media;

part 'daos.dart';
part 'app_db.g.dart';

@DriftDatabase(
  tables: [
    Prefs,
    Profile,
    Subscriptions,
    FeedItems,
    Media,
    Reactions,
    History,
    Playlists,
    PlaylistItems,
    SavedRemote,
    SearchHistory,
    RydCache,
    Downloads,
    AudioCache,
    LyricsCache,
    SbCache,
    LearnedChannels,
    LearnedTerms,
    DiscoveryQueries,
    SuggestionCache,
    ChannelEvidence,
  ],
  daos: [
    SubscriptionsDao,
    FeedItemsDao,
    HistoryDao,
    ReactionsDao,
    PlaylistsDao,
    SavedRemoteDao,
    SearchHistoryDao,
    RydDao,
    ProfileDao,
  ],
)
class AppDb extends _$AppDb {
  AppDb([QueryExecutor? executor]) : super(executor ?? defaultAppDbExecutor());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE UNIQUE INDEX history_video_scope_unique ON history(video_id, scope)',
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await into(playlists).insert(
        PlaylistsCompanion.insert(
          name: 'Watch Later',
          scope: const Value('yt'),
          remoteId: const Value('watch_later'),
          createdAt: now,
          updatedAt: now,
        ),
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(profile);
        await m.createTable(subscriptions);
        await m.createTable(feedItems);
        await m.createTable(media);
        await m.createTable(reactions);
        await m.createTable(history);
        await m.createTable(playlists);
        await m.createTable(playlistItems);
        await m.createTable(savedRemote);
        await m.createTable(searchHistory);
        await m.createTable(rydCache);
        await m.createTable(downloads);
        await m.createTable(audioCache);
        await m.createTable(lyricsCache);
        await m.createTable(sbCache);

        await _migrateFromV1();
      }
      if (from < 3) {
        await m.createTable(learnedChannels);
        await m.createTable(learnedTerms);
        await m.createTable(discoveryQueries);
        await m.createTable(suggestionCache);
        await m.createTable(channelEvidence);
      }
      if (from >= 2 && from < 4) {
        await m.addColumn(subscriptions, subscriptions.handle);
      }
      await customStatement('''
        DELETE FROM history
        WHERE id NOT IN (
          SELECT latest.id FROM history AS latest
          WHERE latest.id = (
            SELECT candidate.id FROM history AS candidate
            WHERE candidate.video_id = latest.video_id
              AND candidate.scope = latest.scope
            ORDER BY candidate.at DESC, candidate.id DESC
            LIMIT 1
          )
        )
      ''');
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS history_video_scope_unique ON history(video_id, scope)',
      );
    },
  );

  Future<void> _migrateFromV1() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Subscriptions migration
    try {
      final subValue = await getValue('subscriptions_v1');
      if (subValue != null && subValue.isNotEmpty) {
        final list = jsonDecode(subValue);
        if (list is List) {
          for (final item in list) {
            final id = item is String
                ? item
                : (item is Map ? item['channelId'] as String? : null);
            if (id != null && id.isNotEmpty) {
              await into(subscriptions).insertOnConflictUpdate(
                SubscriptionsCompanion.insert(
                  channelId: id,
                  name: id,
                  avatarUrl: '',
                  subscribedAt: now,
                  lastFeedAt: const Value(0),
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    // 2. Watch History migration
    try {
      final histValue = await getValue('watch_history_v1');
      if (histValue != null && histValue.isNotEmpty) {
        final list = jsonDecode(histValue);
        if (list is List) {
          for (final item in list) {
            if (item is Map) {
              final id = item['id'] as String?;
              if (id != null && id.isNotEmpty) {
                final pos = item['position'] as int? ?? 0;
                final dur = item['duration'] as int? ?? 0;
                final chName = item['channelName'] as String? ?? '';
                await into(media).insertOnConflictUpdate(
                  MediaCompanion.insert(
                    videoId: id,
                    title: id,
                    channelId: '',
                    channelName: chName,
                    durationSec: Value(dur ~/ 1000),
                    thumbUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                    updatedAt: now,
                  ),
                );
                await into(history).insert(
                  HistoryCompanion.insert(
                    videoId: id,
                    positionMs: pos,
                    durationMs: dur,
                    at: now,
                    scope: const Value('yt'),
                  ),
                );
              }
            }
          }
        }
      }
    } catch (_) {}

    // 3. Create default Watch Later playlist
    try {
      await into(playlists).insert(
        PlaylistsCompanion.insert(
          name: 'Watch Later',
          scope: const Value('yt'),
          remoteId: const Value('watch_later'),
          createdAt: now,
          updatedAt: now,
        ),
      );
    } catch (_) {}
  }

  Future<String?> getValue(String key) async => (await (select(
    prefs,
  )..where((p) => p.key.equals(key))).getSingleOrNull())?.value;

  Future<int> deleteValue(String key) =>
      (delete(prefs)..where((p) => p.key.equals(key))).go();

  Future<int> deleteValuesStartingWith(String prefix) =>
      (delete(prefs)..where((p) => p.key.like('$prefix%'))).go();

  Future<int> clearAppData() async {
    await delete(subscriptions).go();
    await delete(feedItems).go();
    await delete(history).go();
    await delete(reactions).go();
    await delete(playlistItems).go();
    await delete(playlists).go();
    await delete(savedRemote).go();
    await delete(searchHistory).go();
    await delete(rydCache).go();
    await delete(media).go();
    await delete(profile).go();
    return delete(prefs).go();
  }

  Future<void> setValue(String key, String value) => into(
    prefs,
  ).insertOnConflictUpdate(PrefsCompanion.insert(key: key, value: value));
}

abstract interface class HistoryRepo {
  Future<List<HistoryEntry>> recent();
  Future<Set<String>> dislikedChannels();
  Future<void> save(HistoryEntry entry);
}

abstract interface class SubscriptionRepo {
  Future<List<String>> channelIds();
  Future<void> setSubscribed(
    String channelId,
    bool subscribed, {
    String name,
    String avatarUrl,
    String handle,
  });
}

class EmptyHistoryRepo implements HistoryRepo {
  final Map<String, HistoryEntry> _entries = {};
  @override
  Future<List<HistoryEntry>> recent() async =>
      _entries.values.toList().reversed.toList();
  @override
  Future<Set<String>> dislikedChannels() async => {};
  @override
  Future<void> save(HistoryEntry entry) async {
    _entries.remove(entry.videoId);
    _entries[entry.videoId] = entry;
  }
}

class DriftHistoryRepo implements HistoryRepo {
  DriftHistoryRepo(this.db);
  final AppDb db;

  @override
  Future<List<HistoryEntry>> recent() async {
    final rows = await db.historyDao.getHistory();
    return rows.map((r) {
      return HistoryEntry(
        r.history.videoId,
        Duration(milliseconds: r.history.positionMs),
        Duration(milliseconds: r.history.durationMs),
        channelName: r.media?.channelName ?? '',
        title: r.media?.title ?? 'Untitled video',
        channelId: r.media?.channelId ?? '',
        thumbUrl: r.media?.thumbUrl ?? '',
      );
    }).toList();
  }

  @override
  Future<Set<String>> dislikedChannels() async {
    try {
      final value = jsonDecode(
        await db.getValue('disliked_channels_v1') ?? '[]',
      );
      if (value is List) {
        return value.whereType<String>().toSet();
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> save(HistoryEntry entry) async {
    final saveHistory = await db.getValue('history_enabled') ?? 'true';
    final historyPaused = await db.getValue('history_paused') ?? 'false';
    if (saveHistory == 'false' || historyPaused == 'true') {
      return;
    }
    await db.historyDao.recordWatch(
      videoId: entry.videoId,
      title: entry.title,
      channelId: entry.channelId,
      channelName: entry.channelName,
      durationSec: entry.duration.inSeconds,
      thumbUrl: entry.thumbUrl,
      positionMs: entry.position.inMilliseconds,
      durationMs: entry.duration.inMilliseconds,
    );
  }
}

// Retain StoredHistoryRepo as an alias/wrapper if needed
typedef StoredHistoryRepo = DriftHistoryRepo;

class DriftSubscriptionRepo implements SubscriptionRepo {
  DriftSubscriptionRepo(this.db);
  final AppDb db;

  @override
  Future<List<String>> channelIds() async {
    final subs = await db.subscriptionsDao.getSubscriptions();
    return subs.map((s) => s.channelId).toList();
  }

  @override
  Future<void> setSubscribed(
    String channelId,
    bool subscribed, {
    String name = '',
    String avatarUrl = '',
    String handle = '',
  }) async {
    if (subscribed) {
      await db.subscriptionsDao.subscribe(
        channelId,
        name: name,
        avatarUrl: avatarUrl,
        handle: handle,
      );
    } else {
      await db.subscriptionsDao.unsubscribe(channelId);
    }
  }
}

// Retain StoredSubscriptionRepo as an alias/wrapper
typedef StoredSubscriptionRepo = DriftSubscriptionRepo;

class EmptySubscriptionRepo implements SubscriptionRepo {
  @override
  Future<void> setSubscribed(
    String channelId,
    bool subscribed, {
    String name = '',
    String avatarUrl = '',
    String handle = '',
  }) async {}
  @override
  Future<List<String>> channelIds() async => [];
}
