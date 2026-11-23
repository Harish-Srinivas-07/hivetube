part of 'app_db.dart';

class HistoryItemWithMedia {
  const HistoryItemWithMedia({required this.history, this.media});
  final HistoryRow history;
  final MediaRow? media;
}

class PlaylistItemWithMedia {
  const PlaylistItemWithMedia({required this.item, this.media});
  final PlaylistItemRow item;
  final MediaRow? media;
}

@DriftAccessor(tables: [Subscriptions])
class SubscriptionsDao extends DatabaseAccessor<AppDb>
    with _$SubscriptionsDaoMixin {
  SubscriptionsDao(super.db);

  Stream<List<SubscriptionRow>> watchSubscriptions() => (select(
    subscriptions,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Future<List<SubscriptionRow>> getSubscriptions() => (select(
    subscriptions,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).get();

  Future<SubscriptionRow?> getSubscription(String channelId) => (select(
    subscriptions,
  )..where((t) => t.channelId.equals(channelId))).getSingleOrNull();

  Future<bool> isSubscribed(String channelId) async =>
      (await getSubscription(channelId)) != null;

  Future<void> subscribe(
    String channelId, {
    String name = '',
    String avatarUrl = '',
    String handle = '',
  }) async {
    final existing = await getSubscription(channelId);
    final normalizedAvatar = normalizeChannelAvatarUrl(avatarUrl);
    await into(subscriptions).insertOnConflictUpdate(
      SubscriptionsCompanion.insert(
        channelId: channelId,
        name: isMissingChannelName(name, channelId)
            ? (existing?.name ?? channelId)
            : name.trim(),
        avatarUrl: normalizedAvatar.isNotEmpty
            ? normalizedAvatar
            : (existing?.avatarUrl ?? ''),
        handle: Value(handle.isNotEmpty ? handle : (existing?.handle ?? '')),
        subscribedAt:
            existing?.subscribedAt ?? DateTime.now().millisecondsSinceEpoch,
        lastFeedAt: Value(existing?.lastFeedAt ?? 0),
      ),
    );
  }

  Future<void> updateDetails({
    required String channelId,
    required String name,
    required String avatarUrl,
    required String handle,
  }) async {
    final existing = await getSubscription(channelId);
    if (existing == null) return;
    await (update(
      subscriptions,
    )..where((t) => t.channelId.equals(channelId))).write(
      SubscriptionsCompanion(
        name: isMissingChannelName(name, channelId)
            ? Value(existing.name)
            : Value(name.trim()),
        avatarUrl: Value(
          normalizeChannelAvatarUrl(avatarUrl).isNotEmpty
              ? normalizeChannelAvatarUrl(avatarUrl)
              : existing.avatarUrl,
        ),
        handle: Value(handle.isNotEmpty ? handle : existing.handle),
      ),
    );
  }

  Future<void> unsubscribe(String channelId) =>
      (delete(subscriptions)..where((t) => t.channelId.equals(channelId))).go();

  Future<void> updateLastFeedAt(String channelId, int timestamp) =>
      (update(subscriptions)..where((t) => t.channelId.equals(channelId)))
          .write(SubscriptionsCompanion(lastFeedAt: Value(timestamp)));
}

@DriftAccessor(tables: [FeedItems])
class FeedItemsDao extends DatabaseAccessor<AppDb> with _$FeedItemsDaoMixin {
  FeedItemsDao(super.db);

  Stream<List<FeedItemRow>> watchFeedItems({int limit = 100}) =>
      (select(feedItems)
            ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
            ..limit(limit))
          .watch();

  Future<List<FeedItemRow>> getFeedItems({int limit = 100}) =>
      (select(feedItems)
            ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
            ..limit(limit))
          .get();

  Future<void> insertFeedItems(List<FeedItemsCompanion> items) =>
      batch((b) => b.insertAllOnConflictUpdate(feedItems, items));

  Future<void> deleteOldFeedItems({int keep = 1000}) async {
    final rows =
        await (select(feedItems)
              ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
              ..limit(keep))
            .get();
    if (rows.isNotEmpty) {
      final oldest = rows.last.publishedAt;
      await (delete(
        feedItems,
      )..where((t) => t.publishedAt.isSmallerThanValue(oldest))).go();
    }
  }
}

@DriftAccessor(tables: [History, Media])
class HistoryDao extends DatabaseAccessor<AppDb> with _$HistoryDaoMixin {
  HistoryDao(super.db);

  Stream<List<HistoryItemWithMedia>> watchHistory({
    String scope = 'yt',
    int limit = 200,
  }) {
    final query =
        select(history).join([
            leftOuterJoin(media, media.videoId.equalsExp(history.videoId)),
          ])
          ..where(history.scope.equals(scope))
          ..orderBy([OrderingTerm.desc(history.at)])
          ..limit(limit);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => HistoryItemWithMedia(
              history: r.readTable(history),
              media: r.readTableOrNull(media),
            ),
          )
          .toList(),
    );
  }

  Future<List<HistoryItemWithMedia>> getHistory({
    String scope = 'yt',
    int limit = 200,
    int offset = 0,
  }) async {
    final query =
        select(history).join([
            leftOuterJoin(media, media.videoId.equalsExp(history.videoId)),
          ])
          ..where(history.scope.equals(scope))
          ..orderBy([OrderingTerm.desc(history.at)])
          ..limit(limit, offset: offset);

    final rows = await query.get();
    return rows
        .map(
          (r) => HistoryItemWithMedia(
            history: r.readTable(history),
            media: r.readTableOrNull(media),
          ),
        )
        .toList();
  }

  Future<void> recordWatch({
    required String videoId,
    required String title,
    required String channelId,
    required String channelName,
    int? durationSec,
    String? thumbUrl,
    bool isMusic = false,
    required int positionMs,
    required int durationMs,
    String scope = 'yt',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      final oldMedia = await (select(
        media,
      )..where((t) => t.videoId.equals(videoId))).getSingleOrNull();
      final safeTitle = !isMissingVideoTitle(title, videoId)
          ? title.trim()
          : oldMedia != null && !isMissingVideoTitle(oldMedia.title, videoId)
          ? oldMedia.title
          : 'Untitled video';
      final safeChannelId = channelId.isNotEmpty
          ? channelId
          : oldMedia?.channelId ?? '';
      final safeChannelName = channelName.isNotEmpty
          ? channelName
          : oldMedia?.channelName ?? '';
      final safeThumb = thumbUrl?.isNotEmpty == true
          ? thumbUrl!
          : (oldMedia?.thumbUrl.isNotEmpty == true
                ? oldMedia!.thumbUrl
                : 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg');
      final safeDurationSec = durationSec != null && durationSec > 0
          ? durationSec
          : oldMedia?.durationSec;

      await into(media).insertOnConflictUpdate(
        MediaCompanion.insert(
          videoId: videoId,
          title: safeTitle,
          channelId: safeChannelId,
          channelName: safeChannelName,
          durationSec: Value(safeDurationSec),
          thumbUrl: safeThumb,
          isMusic: Value(isMusic || (oldMedia?.isMusic ?? false)),
          updatedAt: now,
        ),
      );

      final rows =
          await (select(history)
                ..where(
                  (t) => t.videoId.equals(videoId) & t.scope.equals(scope),
                )
                ..orderBy([
                  (t) => OrderingTerm.desc(t.at),
                  (t) => OrderingTerm.desc(t.id),
                ]))
              .get();
      if (rows.isEmpty) {
        await into(history).insert(
          HistoryCompanion.insert(
            videoId: videoId,
            positionMs: positionMs,
            durationMs: durationMs,
            at: now,
            scope: Value(scope),
          ),
        );
      } else {
        final latest = rows.first;
        if (rows.length > 1) {
          await (delete(history)..where(
                (t) =>
                    t.videoId.equals(videoId) &
                    t.scope.equals(scope) &
                    t.id.isNotIn(rows.map((row) => row.id)),
              ))
              .go();
        }
        await (update(history)..where((t) => t.id.equals(latest.id))).write(
          HistoryCompanion(
            positionMs: Value(positionMs),
            durationMs: Value(durationMs),
            at: Value(now),
          ),
        );
      }
    });
  }

  Future<void> updateMediaMetadata({
    required String videoId,
    required String title,
    required String channelId,
    required String channelName,
    required String thumbUrl,
    int? durationSec,
  }) async {
    final existing = await (select(
      media,
    )..where((t) => t.videoId.equals(videoId))).getSingleOrNull();
    final safeTitle = !isMissingVideoTitle(title, videoId)
        ? title
        : existing != null && !isMissingVideoTitle(existing.title, videoId)
        ? existing.title
        : 'Untitled video';
    await into(media).insertOnConflictUpdate(
      MediaCompanion.insert(
        videoId: videoId,
        title: safeTitle,
        channelId: channelId.isNotEmpty ? channelId : existing?.channelId ?? '',
        channelName: channelName.isNotEmpty
            ? channelName
            : existing?.channelName ?? '',
        durationSec: Value(
          durationSec != null && durationSec > 0
              ? durationSec
              : existing?.durationSec,
        ),
        thumbUrl: thumbUrl.isNotEmpty
            ? thumbUrl
            : existing?.thumbUrl ??
                  'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
        isMusic: Value(existing?.isMusic ?? false),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> updatePosition(
    String videoId,
    int positionMs,
    int durationMs, {
    String scope = 'yt',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing =
        await (select(history)
              ..where((t) => t.videoId.equals(videoId) & t.scope.equals(scope))
              ..orderBy([(t) => OrderingTerm.desc(t.at)])
              ..limit(1))
            .getSingleOrNull();

    if (existing != null) {
      await (update(history)..where((t) => t.id.equals(existing.id))).write(
        HistoryCompanion(
          positionMs: Value(positionMs),
          durationMs: Value(durationMs),
          at: Value(now),
        ),
      );
    } else {
      await into(history).insert(
        HistoryCompanion.insert(
          videoId: videoId,
          positionMs: positionMs,
          durationMs: durationMs,
          at: now,
          scope: Value(scope),
        ),
      );
    }
  }

  Future<int?> getLastPosition(String videoId, {String scope = 'yt'}) async {
    final entry =
        await (select(history)
              ..where((t) => t.videoId.equals(videoId) & t.scope.equals(scope))
              ..orderBy([(t) => OrderingTerm.desc(t.at)])
              ..limit(1))
            .getSingleOrNull();
    return entry?.positionMs;
  }

  Future<void> deleteHistoryItem(int id) =>
      (delete(history)..where((t) => t.id.equals(id))).go();

  Future<void> restoreHistoryItem(HistoryRow item) => into(history).insert(
    HistoryCompanion.insert(
      videoId: item.videoId,
      positionMs: item.positionMs,
      durationMs: item.durationMs,
      at: item.at,
      scope: Value(item.scope),
    ),
  );

  Future<void> deleteVideoHistory(String videoId, {String scope = 'yt'}) =>
      (delete(
        history,
      )..where((t) => t.videoId.equals(videoId) & t.scope.equals(scope))).go();

  Future<void> clearHistory({String scope = 'yt'}) =>
      (delete(history)..where((t) => t.scope.equals(scope))).go();
}

@DriftAccessor(tables: [Reactions, Media])
class ReactionsDao extends DatabaseAccessor<AppDb> with _$ReactionsDaoMixin {
  ReactionsDao(super.db);

  Stream<int?> watchReaction(String videoId, {String scope = 'yt'}) =>
      (select(reactions)
            ..where((t) => t.videoId.equals(videoId) & t.scope.equals(scope)))
          .watchSingleOrNull()
          .map((r) => r?.value);

  Future<int?> getReaction(String videoId, {String scope = 'yt'}) async =>
      (await (select(reactions)..where(
                (t) => t.videoId.equals(videoId) & t.scope.equals(scope),
              ))
              .getSingleOrNull())
          ?.value;

  Future<void> setReaction(
    String videoId,
    int? value, {
    String scope = 'yt',
  }) async {
    if (value == null || value == 0) {
      await (delete(
        reactions,
      )..where((t) => t.videoId.equals(videoId) & t.scope.equals(scope))).go();
    } else {
      await into(reactions).insertOnConflictUpdate(
        ReactionsCompanion.insert(
          videoId: videoId,
          value: value,
          at: DateTime.now().millisecondsSinceEpoch,
          scope: Value(scope),
        ),
      );
    }
  }

  Stream<List<MediaRow>> watchLikedVideos({String scope = 'yt'}) {
    final query =
        select(reactions).join([
            leftOuterJoin(media, media.videoId.equalsExp(reactions.videoId)),
          ])
          ..where(reactions.value.equals(1) & reactions.scope.equals(scope))
          ..orderBy([OrderingTerm.desc(reactions.at)]);

    return query.watch().map(
      (rows) => rows.map((r) {
        final m = r.readTableOrNull(media);
        if (m != null) return m;
        final rx = r.readTable(reactions);
        return MediaRow(
          videoId: rx.videoId,
          title: rx.videoId,
          channelId: '',
          channelName: '',
          thumbUrl: 'https://i.ytimg.com/vi/${rx.videoId}/hqdefault.jpg',
          isMusic: false,
          updatedAt: rx.at,
        );
      }).toList(),
    );
  }

  Future<List<MediaRow>> getLikedVideos({String scope = 'yt'}) async {
    final query =
        select(reactions).join([
            leftOuterJoin(media, media.videoId.equalsExp(reactions.videoId)),
          ])
          ..where(reactions.value.equals(1) & reactions.scope.equals(scope))
          ..orderBy([OrderingTerm.desc(reactions.at)]);

    final rows = await query.get();
    return rows.map((r) {
      final m = r.readTableOrNull(media);
      if (m != null) return m;
      final rx = r.readTable(reactions);
      return MediaRow(
        videoId: rx.videoId,
        title: rx.videoId,
        channelId: '',
        channelName: '',
        thumbUrl: 'https://i.ytimg.com/vi/${rx.videoId}/hqdefault.jpg',
        isMusic: false,
        updatedAt: rx.at,
      );
    }).toList();
  }

  Future<int?> getLatestLikedAt({String scope = 'yt'}) async =>
      (await (select(reactions)
                ..where((t) => t.value.equals(1) & t.scope.equals(scope))
                ..orderBy([(t) => OrderingTerm.desc(t.at)])
                ..limit(1))
              .getSingleOrNull())
          ?.at;
}

@DriftAccessor(tables: [Playlists, PlaylistItems, Media])
class PlaylistsDao extends DatabaseAccessor<AppDb> with _$PlaylistsDaoMixin {
  PlaylistsDao(super.db);

  Stream<List<PlaylistRow>> watchPlaylists({String scope = 'yt'}) =>
      (select(playlists)
            ..where((t) => t.scope.equals(scope))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<List<PlaylistRow>> getPlaylists({String scope = 'yt'}) =>
      (select(playlists)
            ..where((t) => t.scope.equals(scope))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

  Future<PlaylistRow?> getPlaylist(int id) =>
      (select(playlists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<PlaylistRow> getOrCreateWatchLater({String scope = 'yt'}) async {
    final existing =
        await (select(playlists)..where(
              (t) => t.remoteId.equals('watch_later') & t.scope.equals(scope),
            ))
            .getSingleOrNull();
    if (existing != null) return existing;

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await into(playlists).insert(
      PlaylistsCompanion.insert(
        name: 'Watch Later',
        scope: Value(scope),
        remoteId: const Value('watch_later'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await getPlaylist(id))!;
  }

  Future<int> createPlaylist(
    String name, {
    String scope = 'yt',
    String? remoteId,
    String? thumbUrl,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return into(playlists).insert(
      PlaylistsCompanion.insert(
        name: name,
        scope: Value(scope),
        remoteId: Value(remoteId),
        thumbUrl: Value(thumbUrl),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> renamePlaylist(int id, String name) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (update(playlists)..where((t) => t.id.equals(id))).write(
      PlaylistsCompanion(name: Value(name), updatedAt: Value(now)),
    );
  }

  Future<void> deletePlaylist(int id) async {
    await (delete(playlistItems)..where((t) => t.playlistId.equals(id))).go();
    await (delete(playlists)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<PlaylistItemWithMedia>> watchPlaylistItems(int playlistId) {
    final query =
        select(playlistItems).join([
            leftOuterJoin(
              media,
              media.videoId.equalsExp(playlistItems.videoId),
            ),
          ])
          ..where(playlistItems.playlistId.equals(playlistId))
          ..orderBy([OrderingTerm.asc(playlistItems.position)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (r) => PlaylistItemWithMedia(
              item: r.readTable(playlistItems),
              media: r.readTableOrNull(media),
            ),
          )
          .toList(),
    );
  }

  Future<List<PlaylistItemWithMedia>> getPlaylistItems(int playlistId) async {
    final query =
        select(playlistItems).join([
            leftOuterJoin(
              media,
              media.videoId.equalsExp(playlistItems.videoId),
            ),
          ])
          ..where(playlistItems.playlistId.equals(playlistId))
          ..orderBy([OrderingTerm.asc(playlistItems.position)]);

    final rows = await query.get();
    return rows
        .map(
          (r) => PlaylistItemWithMedia(
            item: r.readTable(playlistItems),
            media: r.readTableOrNull(media),
          ),
        )
        .toList();
  }

  Future<void> addPlaylistItem(
    int playlistId,
    String videoId, {
    MediaCompanion? mediaItem,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (mediaItem != null) {
      await into(media).insertOnConflictUpdate(mediaItem);
    }
    final existing =
        await (select(playlistItems)..where(
              (t) =>
                  t.playlistId.equals(playlistId) & t.videoId.equals(videoId),
            ))
            .getSingleOrNull();
    if (existing != null) return;

    final allItems = await (select(
      playlistItems,
    )..where((t) => t.playlistId.equals(playlistId))).get();
    await into(playlistItems).insertOnConflictUpdate(
      PlaylistItemsCompanion.insert(
        playlistId: playlistId,
        videoId: videoId,
        position: allItems.length,
        addedAt: now,
      ),
    );
    await (update(playlists)..where((t) => t.id.equals(playlistId))).write(
      PlaylistsCompanion(updatedAt: Value(now)),
    );
  }

  Future<void> removePlaylistItem(int playlistId, String videoId) async {
    await (delete(playlistItems)..where(
          (t) => t.playlistId.equals(playlistId) & t.videoId.equals(videoId),
        ))
        .go();
    final remaining =
        await (select(playlistItems)
              ..where((t) => t.playlistId.equals(playlistId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    for (var i = 0; i < remaining.length; i++) {
      if (remaining[i].position != i) {
        await (update(playlistItems)..where(
              (t) =>
                  t.playlistId.equals(playlistId) &
                  t.videoId.equals(remaining[i].videoId),
            ))
            .write(PlaylistItemsCompanion(position: Value(i)));
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(playlists)..where((t) => t.id.equals(playlistId))).write(
      PlaylistsCompanion(updatedAt: Value(now)),
    );
  }

  Future<void> reorderPlaylistItems(
    int playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final items =
        await (select(playlistItems)
              ..where((t) => t.playlistId.equals(playlistId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    if (oldIndex < 0 || oldIndex >= items.length) return;
    if (newIndex < 0 || newIndex >= items.length) return;

    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    for (var i = 0; i < items.length; i++) {
      await (update(playlistItems)..where(
            (t) =>
                t.playlistId.equals(playlistId) &
                t.videoId.equals(items[i].videoId),
          ))
          .write(PlaylistItemsCompanion(position: Value(i)));
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(playlists)..where((t) => t.id.equals(playlistId))).write(
      PlaylistsCompanion(updatedAt: Value(now)),
    );
  }

  Future<bool> isInPlaylist(int playlistId, String videoId) async =>
      (await (select(playlistItems)..where(
            (t) => t.playlistId.equals(playlistId) & t.videoId.equals(videoId),
          ))
          .getSingleOrNull()) !=
      null;
}

@DriftAccessor(tables: [SavedRemote])
class SavedRemoteDao extends DatabaseAccessor<AppDb>
    with _$SavedRemoteDaoMixin {
  SavedRemoteDao(super.db);

  Stream<List<SavedRemoteRow>> watchSavedRemote() => (select(
    savedRemote,
  )..orderBy([(t) => OrderingTerm.desc(t.savedAt)])).watch();

  Future<List<SavedRemoteRow>> getSavedRemote() => (select(
    savedRemote,
  )..orderBy([(t) => OrderingTerm.desc(t.savedAt)])).get();

  Future<void> saveRemote(
    String id,
    String kind,
    String title, {
    String? thumbUrl,
  }) => into(savedRemote).insertOnConflictUpdate(
    SavedRemoteCompanion.insert(
      id: id,
      kind: kind,
      title: title,
      thumbUrl: Value(thumbUrl),
      savedAt: DateTime.now().millisecondsSinceEpoch,
    ),
  );

  Future<void> removeRemote(String id) =>
      (delete(savedRemote)..where((t) => t.id.equals(id))).go();

  Future<bool> isRemoteSaved(String id) async =>
      (await (select(
        savedRemote,
      )..where((t) => t.id.equals(id))).getSingleOrNull()) !=
      null;
}

@DriftAccessor(tables: [SearchHistory])
class SearchHistoryDao extends DatabaseAccessor<AppDb>
    with _$SearchHistoryDaoMixin {
  SearchHistoryDao(super.db);

  Stream<List<String>> watchRecentSearches({
    String scope = 'yt',
    int limit = 20,
  }) =>
      (select(searchHistory)
            ..where((t) => t.scope.equals(scope))
            ..orderBy([(t) => OrderingTerm.desc(t.at)])
            ..limit(limit))
          .watch()
          .map((rows) => rows.map((r) => r.query).toList());

  Future<List<String>> getRecentSearches({
    String scope = 'yt',
    int limit = 20,
  }) async =>
      (await (select(searchHistory)
                ..where((t) => t.scope.equals(scope))
                ..orderBy([(t) => OrderingTerm.desc(t.at)])
                ..limit(limit))
              .get())
          .map((r) => r.query)
          .toList();

  Future<void> saveSearchTerm(String query, {String scope = 'yt'}) =>
      into(searchHistory).insertOnConflictUpdate(
        SearchHistoryCompanion.insert(
          query: query,
          scope: Value(scope),
          at: DateTime.now().millisecondsSinceEpoch,
        ),
      );

  Future<void> addSearch(String query, {String scope = 'yt'}) =>
      saveSearchTerm(query, scope: scope);

  Future<void> removeSearch(String query, {String scope = 'yt'}) => (delete(
    searchHistory,
  )..where((t) => t.query.equals(query) & t.scope.equals(scope))).go();

  Future<void> clearSearches({String scope = 'yt'}) =>
      (delete(searchHistory)..where((t) => t.scope.equals(scope))).go();
}

@DriftAccessor(tables: [RydCache])
class RydDao extends DatabaseAccessor<AppDb> with _$RydDaoMixin {
  RydDao(super.db);

  Future<RydCacheRow?> getRyd(String videoId) => (select(
    rydCache,
  )..where((t) => t.videoId.equals(videoId))).getSingleOrNull();

  Future<void> putRyd(
    String videoId,
    int likes,
    int dislikes, {
    int? fetchedAt,
  }) => into(rydCache).insertOnConflictUpdate(
    RydCacheCompanion.insert(
      videoId: videoId,
      likes: likes,
      dislikes: dislikes,
      fetchedAt: fetchedAt ?? DateTime.now().millisecondsSinceEpoch,
    ),
  );
}

@DriftAccessor(tables: [Profile])
class ProfileDao extends DatabaseAccessor<AppDb> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  Stream<ProfileRow?> watchProfile() =>
      (select(profile)..where((t) => t.id.equals(1))).watchSingleOrNull();

  Future<ProfileRow?> getProfile() =>
      (select(profile)..where((t) => t.id.equals(1))).getSingleOrNull();

  Future<void> setProfile({required String name, String? avatarPath}) =>
      into(profile).insertOnConflictUpdate(
        ProfileCompanion.insert(
          id: const Value(1),
          name: name,
          avatarPath: Value(avatarPath),
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
}
