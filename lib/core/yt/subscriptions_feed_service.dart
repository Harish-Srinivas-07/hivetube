import 'dart:async';
import 'package:drift/drift.dart';
import '../db/app_db.dart';
import 'channel_avatars.dart';
import 'channel_metadata.dart';
import 'models.dart';
import 'yt_browse.dart';
import 'yt_rss.dart';

class SubscriptionsFeedService {
  SubscriptionsFeedService({
    required this.db,
    required this.rss,
    required this.browse,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final AppDb db;
  final YtRss rss;
  final YtBrowse browse;
  final DateTime Function() clock;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  static const _lastOpenedKey = 'subs_tab_last_opened_at';

  Future<void> markTabOpened() async {
    final now = clock().millisecondsSinceEpoch;
    await db.setValue(_lastOpenedKey, now.toString());
  }

  Future<bool> hasUnreadUploads() async {
    final val = await db.getValue(_lastOpenedKey);
    final lastOpened = int.tryParse(val ?? '') ?? 0;
    if (lastOpened == 0) return false;

    final latest = await (db.select(db.feedItems)
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
          ..limit(1))
        .getSingleOrNull();

    if (latest != null && latest.publishedAt > lastOpened) {
      return true;
    }
    return false;
  }

  Future<void> backfillSubscriptionDetails() async {
    final subs = await db.subscriptionsDao.getSubscriptions();
    final missing = subs
        .where(
          (sub) =>
              isMissingChannelName(sub.name, sub.channelId) ||
              sub.avatarUrl.isEmpty ||
              sub.handle.isEmpty,
        )
        .toList();
    const concurrency = 3;
    for (var start = 0; start < missing.length; start += concurrency) {
      final end = start + concurrency < missing.length
          ? start + concurrency
          : missing.length;
      await Future.wait(
        missing.sublist(start, end).map((sub) async {
          try {
            final channel = await browse.channelPage(sub.channelId);
            final avatar = normalizeChannelAvatarUrl(channel.avatarUrl);
            await db.subscriptionsDao.updateDetails(
              channelId: sub.channelId,
              name: channel.name,
              avatarUrl: avatar,
              handle: channel.handle,
            );
            if (avatar.isNotEmpty) {
              await ChannelAvatarCache.instance.put(sub.channelId, avatar);
            }
          } catch (_) {}
        }),
      );
    }
  }

  Future<void> refreshFeed({bool force = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final subs = await db.subscriptionsDao.getSubscriptions();
      if (subs.isEmpty) return;

      final now = clock().millisecondsSinceEpoch;
      const cooldownMs = 30 * 60 * 1000; // 30 minutes

      final channelsToRefresh = subs.where((s) {
        if (force) return true;
        return (now - s.lastFeedAt) >= cooldownMs;
      }).toList();

      if (channelsToRefresh.isEmpty) return;

      // Parallel fetch with concurrency cap of 6
      const maxConcurrent = 6;
      for (var i = 0; i < channelsToRefresh.length; i += maxConcurrent) {
        final end = (i + maxConcurrent < channelsToRefresh.length)
            ? i + maxConcurrent
            : channelsToRefresh.length;
        final chunk = channelsToRefresh.sublist(i, end);

        await Future.wait(
          chunk.map((sub) => _fetchChannelFeed(sub, now)),
        );
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _fetchChannelFeed(SubscriptionRow sub, int fetchTimestamp) async {
    List<VideoItem> items = const [];

    try {
      // 1. Try RSS with UULF playlist (exclude shorts)
      items = await rss.uploads(sub.channelId, excludeShorts: true);
    } catch (_) {}

    // 2. If empty, try channel_id RSS
    if (items.isEmpty) {
      try {
        items = await rss.uploads(sub.channelId, excludeShorts: false);
      } catch (_) {}
    }

    // 3. Fallback to Y7 Videos tab
    if (items.isEmpty) {
      try {
        final page = await browse.channelVideos(sub.channelId);
        items = page.items;
      } catch (_) {}
    }

    if (items.isNotEmpty) {
      final companions = items.map((item) {
        final publishedMs = item.publishedAt?.millisecondsSinceEpoch ?? fetchTimestamp;
        final durSec = _parseDuration(item.durationText);
        return FeedItemsCompanion.insert(
          videoId: item.id,
          channelId: sub.channelId,
          title: item.title,
          publishedAt: publishedMs,
          thumbUrl: item.thumbUrl,
          durationSec: Value(durSec),
          fetchedAt: fetchTimestamp,
        );
      }).toList();

      await db.feedItemsDao.insertFeedItems(companions);

      // Cache avatars & media records
      for (final item in items) {
        if (item.channelAvatarUrl.isNotEmpty) {
          ChannelAvatarCache.instance.put(
            sub.channelId,
            normalizeChannelAvatarUrl(item.channelAvatarUrl),
          );
        }
        final durSec = _parseDuration(item.durationText);
        await db.into(db.media).insertOnConflictUpdate(
          MediaCompanion.insert(
            videoId: item.id,
            title: item.title,
            channelId: sub.channelId,
            channelName: sub.name,
            durationSec: Value(durSec),
            thumbUrl: item.thumbUrl,
            updatedAt: fetchTimestamp,
          ),
        );
      }
    }

    await db.subscriptionsDao.updateLastFeedAt(sub.channelId, fetchTimestamp);
  }

  static int? _parseDuration(String text) {
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return h * 3600 + m * 60 + s;
    }
    return null;
  }
}
