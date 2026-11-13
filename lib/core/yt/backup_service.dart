import 'dart:convert';
import 'package:drift/drift.dart';
import '../db/app_db.dart';

class BackupPreview {
  const BackupPreview({
    required this.subscriptionCount,
    required this.playlistCount,
    required this.historyCount,
    required this.reactionCount,
    required this.savedRemoteCount,
  });

  final int subscriptionCount;
  final int playlistCount;
  final int historyCount;
  final int reactionCount;
  final int savedRemoteCount;
}

class BackupService {
  BackupService(this.db);
  final AppDb db;

  Future<String> exportJson() async {
    final now = DateTime.now();

    final subs = await db.subscriptionsDao.getSubscriptions();
    final playlists = await db.playlistsDao.getPlaylists();
    final playlistData = <Map<String, dynamic>>[];
    for (final pl in playlists) {
      final items = await db.playlistsDao.getPlaylistItems(pl.id);
      playlistData.add({
        'id': pl.id,
        'name': pl.name,
        'scope': pl.scope,
        'remoteId': pl.remoteId,
        'thumbUrl': pl.thumbUrl,
        'createdAt': pl.createdAt,
        'updatedAt': pl.updatedAt,
        'items': items
            .map(
              (i) => {
                'videoId': i.item.videoId,
                'position': i.item.position,
                'addedAt': i.item.addedAt,
                'title': i.media?.title,
                'channelName': i.media?.channelName,
                'thumbUrl': i.media?.thumbUrl,
                'durationSec': i.media?.durationSec,
              },
            )
            .toList(),
      });
    }

    final historyRows = await db.historyDao.getHistory();
    final historyData = historyRows
        .map(
          (h) => {
            'videoId': h.history.videoId,
            'positionMs': h.history.positionMs,
            'durationMs': h.history.durationMs,
            'at': h.history.at,
            'scope': h.history.scope,
            'title': h.media?.title,
            'channelId': h.media?.channelId,
            'channelName': h.media?.channelName,
            'thumbUrl': h.media?.thumbUrl,
            'durationSec': h.media?.durationSec,
          },
        )
        .toList();

    final reactions = await (db.select(db.reactions)).get();
    final savedRemotes = await db.savedRemoteDao.getSavedRemote();
    final profile = await db.profileDao.getProfile();

    final safePrefsKeys = [
      'content_shown_languages_v1',
      'content_hidden_languages_v1',
      'content_language_mode_v1',
      'content_gl_v1',
      'theme_mode',
      'history_paused',
      'history_enabled',
    ];

    final prefsMap = <String, String>{};
    for (final k in safePrefsKeys) {
      final val = await db.getValue(k);
      if (val != null) prefsMap[k] = val;
    }

    final data = {
      'format': 'hivetube_backup_v1',
      'exportedAt': now.toIso8601String(),
      'subscriptions': subs
          .map(
            (s) => {
              'channelId': s.channelId,
              'name': s.name,
              'avatarUrl': s.avatarUrl,
              'handle': s.handle,
              'subscribedAt': s.subscribedAt,
              'lastFeedAt': s.lastFeedAt,
            },
          )
          .toList(),
      'playlists': playlistData,
      'history': historyData,
      'reactions': reactions
          .map(
            (r) => {
              'videoId': r.videoId,
              'value': r.value,
              'at': r.at,
              'scope': r.scope,
            },
          )
          .toList(),
      'saved_remote': savedRemotes
          .map(
            (s) => {
              'id': s.id,
              'kind': s.kind,
              'title': s.title,
              'thumbUrl': s.thumbUrl,
              'savedAt': s.savedAt,
            },
          )
          .toList(),
      if (profile != null)
        'profile': {
          'name': profile.name,
          'avatarPath': profile.avatarPath,
          'createdAt': profile.createdAt,
        },
      'prefs': prefsMap,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  BackupPreview inspectJson(String jsonString) {
    final dynamic data = jsonDecode(jsonString);
    if (data is! Map) {
      throw const FormatException('Invalid backup JSON format');
    }

    final subs = (data['subscriptions'] as List?)?.length ?? 0;
    final playlists = (data['playlists'] as List?)?.length ?? 0;
    final history = (data['history'] as List?)?.length ?? 0;
    final reactions = (data['reactions'] as List?)?.length ?? 0;
    final savedRemotes = (data['saved_remote'] as List?)?.length ?? 0;

    return BackupPreview(
      subscriptionCount: subs,
      playlistCount: playlists,
      historyCount: history,
      reactionCount: reactions,
      savedRemoteCount: savedRemotes,
    );
  }

  Future<void> importJson(String jsonString, {bool replace = false}) async {
    final dynamic data = jsonDecode(jsonString);
    if (data is! Map) {
      throw const FormatException('Invalid backup JSON format');
    }

    await db.transaction(() async {
      if (replace) {
        await db.clearAppData();
      }

      final subs = data['subscriptions'] as List? ?? const [];
      for (final s in subs) {
        if (s is Map && s['channelId'] is String) {
          await db
              .into(db.subscriptions)
              .insertOnConflictUpdate(
                SubscriptionsCompanion.insert(
                  channelId: s['channelId'] as String,
                  name: (s['name'] as String?) ?? '',
                  avatarUrl: (s['avatarUrl'] as String?) ?? '',
                  handle: Value((s['handle'] as String?) ?? ''),
                  subscribedAt:
                      (s['subscribedAt'] as int?) ??
                      DateTime.now().millisecondsSinceEpoch,
                  lastFeedAt: Value((s['lastFeedAt'] as int?) ?? 0),
                ),
              );
        }
      }

      final playlists = data['playlists'] as List? ?? const [];
      for (final pl in playlists) {
        if (pl is Map && pl['name'] is String) {
          final plName = pl['name'] as String;
          final remoteId = pl['remoteId'] as String?;
          final scope = (pl['scope'] as String?) ?? 'yt';
          final now = DateTime.now().millisecondsSinceEpoch;

          int plId;
          final existing =
              await (db.select(db.playlists)..where(
                    (t) => t.name.equals(plName) & t.scope.equals(scope),
                  ))
                  .getSingleOrNull();

          if (existing != null) {
            plId = existing.id;
          } else {
            plId = await db
                .into(db.playlists)
                .insert(
                  PlaylistsCompanion.insert(
                    name: plName,
                    scope: Value(scope),
                    remoteId: Value(remoteId),
                    thumbUrl: Value(pl['thumbUrl'] as String?),
                    createdAt: (pl['createdAt'] as int?) ?? now,
                    updatedAt: (pl['updatedAt'] as int?) ?? now,
                  ),
                );
          }

          final items = pl['items'] as List? ?? const [];
          for (final item in items) {
            if (item is Map && item['videoId'] is String) {
              final vId = item['videoId'] as String;
              if (item['title'] != null) {
                await db
                    .into(db.media)
                    .insertOnConflictUpdate(
                      MediaCompanion.insert(
                        videoId: vId,
                        title: item['title'] as String,
                        channelId: '',
                        channelName: (item['channelName'] as String?) ?? '',
                        durationSec: Value(item['durationSec'] as int?),
                        thumbUrl:
                            (item['thumbUrl'] as String?) ??
                            'https://i.ytimg.com/vi/$vId/hqdefault.jpg',
                        updatedAt: now,
                      ),
                    );
              }
              await db
                  .into(db.playlistItems)
                  .insertOnConflictUpdate(
                    PlaylistItemsCompanion.insert(
                      playlistId: plId,
                      videoId: vId,
                      position: (item['position'] as int?) ?? 0,
                      addedAt: (item['addedAt'] as int?) ?? now,
                    ),
                  );
            }
          }
        }
      }

      final historyList = data['history'] as List? ?? const [];
      for (final h in historyList) {
        if (h is Map && h['videoId'] is String) {
          final vId = h['videoId'] as String;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (h['title'] != null) {
            await db
                .into(db.media)
                .insertOnConflictUpdate(
                  MediaCompanion.insert(
                    videoId: vId,
                    title: h['title'] as String,
                    channelId: (h['channelId'] as String?) ?? '',
                    channelName: (h['channelName'] as String?) ?? '',
                    durationSec: Value(h['durationSec'] as int?),
                    thumbUrl:
                        (h['thumbUrl'] as String?) ??
                        'https://i.ytimg.com/vi/$vId/hqdefault.jpg',
                    updatedAt: now,
                  ),
                );
          }
          final scope = (h['scope'] as String?) ?? 'yt';
          final at = (h['at'] as int?) ?? now;
          final existing = await (db.select(db.history)
                ..where(
                  (row) => row.videoId.equals(vId) & row.scope.equals(scope),
                ))
              .getSingleOrNull();
          if (existing == null) {
            await db.into(db.history).insert(
              HistoryCompanion.insert(
                videoId: vId,
                positionMs: (h['positionMs'] as int?) ?? 0,
                durationMs: (h['durationMs'] as int?) ?? 0,
                at: at,
                scope: Value(scope),
              ),
            );
          } else if (at > existing.at) {
            await (db.update(db.history)
                  ..where((row) => row.id.equals(existing.id)))
                .write(
                  HistoryCompanion(
                    positionMs: Value((h['positionMs'] as int?) ?? 0),
                    durationMs: Value((h['durationMs'] as int?) ?? 0),
                    at: Value(at),
                  ),
                );
          }
        }
      }

      final reactions = data['reactions'] as List? ?? const [];
      for (final r in reactions) {
        if (r is Map && r['videoId'] is String && r['value'] is int) {
          await db
              .into(db.reactions)
              .insertOnConflictUpdate(
                ReactionsCompanion.insert(
                  videoId: r['videoId'] as String,
                  value: r['value'] as int,
                  at:
                      (r['at'] as int?) ??
                      DateTime.now().millisecondsSinceEpoch,
                  scope: Value((r['scope'] as String?) ?? 'yt'),
                ),
              );
        }
      }

      final savedRemotes = data['saved_remote'] as List? ?? const [];
      for (final sr in savedRemotes) {
        if (sr is Map && sr['id'] is String) {
          await db
              .into(db.savedRemote)
              .insertOnConflictUpdate(
                SavedRemoteCompanion.insert(
                  id: sr['id'] as String,
                  kind: (sr['kind'] as String?) ?? 'playlist',
                  title: (sr['title'] as String?) ?? '',
                  thumbUrl: Value(sr['thumbUrl'] as String?),
                  savedAt:
                      (sr['savedAt'] as int?) ??
                      DateTime.now().millisecondsSinceEpoch,
                ),
              );
        }
      }

      final profile = data['profile'];
      if (profile is Map && profile['name'] is String) {
        await db.profileDao.setProfile(
          name: profile['name'] as String,
          avatarPath: profile['avatarPath'] as String?,
        );
      }

      await db.deleteValue('settings_hl');
      await db.deleteValue('content_hl_v1');
      final prefs = data['prefs'];
      if (prefs is Map) {
        for (final entry in prefs.entries) {
          if (entry.key is String && entry.value is String) {
            final key = entry.key as String;
            if (key == 'content_hl_v1' || key == 'settings_hl') continue;
            await db.setValue(key, entry.value as String);
          }
        }
      }
    });
  }
}
