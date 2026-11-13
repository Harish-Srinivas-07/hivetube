import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/content/language_profile.dart';
import '../../core/db/history_entry.dart';
import '../../core/settings/app_settings.dart';
import '../../core/yt/models.dart';
import '../../core/yt/channel_avatars.dart';
import 'home_cache.dart';
import 'home_mixer.dart';
import 'home_guards.dart';
import 'home_shorts.dart';
import 'home_variety.dart';

final initialHomeCacheProvider = Provider<HomeCache?>((ref) => null);

class HomeData {
  const HomeData({
    this.videos = const [],
    this.shorts = const [],
    this.trending = const [],
    this.errors = const [],
    this.continuations = const {},
    this.chip = 'All',
    this.loadingMore = false,
  });
  final List<VideoItem> videos, trending;
  final List<ShortItem> shorts;
  final List<String> errors;
  final Map<String, String> continuations;
  final String chip;
  final bool loadingMore;
  HomeData copy({
    List<VideoItem>? videos,
    List<ShortItem>? shorts,
    List<VideoItem>? trending,
    List<String>? errors,
    Map<String, String>? continuations,
    String? chip,
    bool? loadingMore,
  }) => HomeData(
    videos: videos ?? this.videos,
    shorts: shorts ?? this.shorts,
    trending: trending ?? this.trending,
    errors: errors ?? this.errors,
    continuations: continuations ?? this.continuations,
    chip: chip ?? this.chip,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final homeProvider = AsyncNotifierProvider<HomeController, HomeData>(
  HomeController.new,
);

class HomeController extends AsyncNotifier<HomeData> {
  final _refreshGuard = HomeRefreshGuard();
  final _paginationGuard = PaginationGuard();
  CancelToken _token = CancelToken();
  Timer? _debounce;
  int _generation = 0;
  final Map<String, ({DateTime fetched, List<VideoItem> items})> _rssCache = {};
  final _avatarBackfill = AvatarBackfillCoordinator();
  HomeMixer? _mixer;
  List<VideoItem> _pendingFresh = [];
  String? _sessionKey;
  int _seed = DateTime.now().microsecondsSinceEpoch;
  Set<String> _refreshExcluded = {};

  Future<void> ensureAvatar(VideoItem item) async {
    if (item.channelAvatarUrl.isNotEmpty) return;
    final cache = ref.read(channelAvatarCacheProvider);
    if (item.channelId.isNotEmpty) {
      final cached = cache.get(item.channelId);
      if (cached != null) {
        _applyAvatar(item, item.channelId, cached);
        return;
      }
    }
    final key = item.channelId.isNotEmpty ? item.channelId : 'video:${item.id}';
    var resolvedChannelId = item.channelId;
    final avatar = await _avatarBackfill.resolve(key, () async {
      final api = await ref.read(ytApiProvider.future);
      if (resolvedChannelId.isNotEmpty) {
        return api.browse.channelAvatar(resolvedChannelId);
      } else {
        final owner = await api.next.ownerMetadata(item.id);
        if (owner != null) {
          resolvedChannelId = owner.channelId ?? '';
          return owner.channelAvatarUrl ?? '';
        }
        return '';
      }
    });
    if (avatar == null) return;
    if (resolvedChannelId.isNotEmpty) {
      await cache.put(resolvedChannelId, avatar);
    }
    _applyAvatar(item, resolvedChannelId, avatar);
  }

  void _applyAvatar(VideoItem item, String channelId, String avatar) {
    final current = state.value;
    if (current == null) return;
    VideoItem updated(VideoItem video) {
      if (video.id != item.id &&
          (channelId.isEmpty || video.channelId != channelId)) {
        return video;
      }
      return VideoItem(
        id: video.id,
        title: video.title,
        channelId: channelId.isEmpty ? video.channelId : channelId,
        channelName: video.channelName,
        channelAvatarUrl: avatar,
        thumbUrl: video.thumbUrl,
        durationText: video.durationText,
        viewsText: video.viewsText,
        publishedText: video.publishedText,
        publishedAt: video.publishedAt,
        isShort: video.isShort,
      );
    }

    state = AsyncData(
      current.copy(
        videos: current.videos.map(updated).toList(),
        trending: current.trending.map(updated).toList(),
      ),
    );
  }

  @override
  FutureOr<HomeData> build() {
    if (_token.isCancelled) _token = CancelToken();
    ref.onDispose(() {
      _debounce?.cancel();
      _token.cancel();
    });
    final settings = ref.watch(
      contentPrefsProvider.select(
        (s) => (
          cacheKey: s.cacheKey,
          localContent: s.localContent,
          revision: s.revision,
          contentLanguages: s.contentLanguages,
          hiddenLanguages: s.hiddenLanguages,
          localRatio: s.localRatio,
        ),
      ),
    );
    final sessionKey =
        '${settings.cacheKey}_${settings.localContent}_${settings.revision}';
    if (_sessionKey != sessionKey) {
      _token.cancel();
      _token = CancelToken();
      _generation++;
      _sessionKey = sessionKey;
      _pendingFresh = [];
      _rssCache.clear();
      _mixer = null;
      _seed = DateTime.now().microsecondsSinceEpoch;
    }
    final initial = ref.read(initialAppSettingsProvider);
    final cache =
        homeCacheKey(ref.read(contentPrefsProvider)) == homeCacheKey(initial)
        ? ref.read(initialHomeCacheProvider)
        : null;
    if (cache != null) {
      Future<void>(() => _backgroundRefresh());
      return HomeData(videos: cache.videos, shorts: cache.shorts);
    }
    return _fetch('All', _token);
  }

  Future<void> rememberChannel(
    String id,
    String name, {
    bool isShort = false,
  }) async {
    final repo = ref.read(historyRepoProvider);
    final existing = (await repo.recent())
        .where((h) => h.videoId == id)
        .firstOrNull;
    await repo.save(
      HistoryEntry(
        id,
        existing?.position ?? Duration.zero,
        existing?.duration ?? Duration.zero,
        isShort: isShort,
        channelName: name,
      ),
    );
  }

  void interact() {
    _refreshGuard.interact();
  }

  Future<void> _backgroundRefresh() async {
    final generation = _generation;
    try {
      final fresh = await _fetch('All', _token);
      if (generation != _generation) return;
      if (_refreshGuard.canApply) {
        state = AsyncData(fresh);
      } else {
        final current = state.value;
        if (current != null && current.chip == 'All') {
          final existing = current.videos.map((e) => e.id).toSet();
          _pendingFresh = [];
          _mixer?.exclude(existing);
          state = AsyncData(
            current.copy(
              videos: [
                ...current.videos,
                ...fresh.videos.where((v) => !existing.contains(v.id)),
              ],
              shorts: fresh.shorts,
              trending: fresh.trending,
              continuations: fresh.continuations.isNotEmpty
                  ? const {'mixer': 'more'}
                  : const {},
            ),
          );
        }
      }
    } catch (_) {
      /* Preserve cached content. */
    }
  }

  Future<List<VideoItem>> _subscriptions(
    YtApi api,
    List<String> channels,
    CancelToken token,
    List<String> errors,
  ) async {
    final now = DateTime.now();
    final items = <VideoItem>[];
    var next = 0;
    Future<void> worker() async {
      while (next < channels.length && !token.isCancelled) {
        final id = channels[next++];
        var cached = _rssCache[id];
        if (cached == null) {
          try {
            final raw = await ref.read(dbProvider).getValue('home_rss_cache_$id');
            if (raw != null) {
              final json = jsonDecode(raw) as Map<String, dynamic>;
              final fetched = DateTime.tryParse(json['fetched'] as String? ?? '');
              final entries = (json['items'] as List? ?? const [])
                  .whereType<Map>()
                  .map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
              if (fetched != null) cached = (fetched: fetched, items: entries);
            }
          } catch (_) {}
        }
        if (cached == null ||
            now.difference(cached.fetched) >= const Duration(minutes: 30)) {
          try {
            cached = (
              fetched: now,
              items: await api.rss.uploads(id, cancelToken: token),
            );
            _rssCache[id] = cached;
            await ref.read(dbProvider).setValue('home_rss_cache_$id', jsonEncode({
              'fetched': now.toIso8601String(),
              'items': cached.items.map((e) => e.toJson()).toList(),
            }));
          } catch (_) {
            if (!token.isCancelled) {
              errors.add('Subscriptions');
              cached = (fetched: now, items: cached?.items ?? <VideoItem>[]);
              _rssCache[id] = cached;
            }
          }
        }
        if (cached != null) {
          final avatarCache = ref.read(channelAvatarCacheProvider);
          for (final item in cached.items) {
            final avatar = item.channelAvatarUrl.isNotEmpty
                ? item.channelAvatarUrl
                : avatarCache.get(item.channelId) ?? '';
            if (avatar.isNotEmpty && item.channelAvatarUrl.isEmpty) {
              items.add(
                VideoItem(
                  id: item.id,
                  title: item.title,
                  channelId: item.channelId,
                  channelName: item.channelName,
                  channelAvatarUrl: avatar,
                  thumbUrl: item.thumbUrl,
                  durationText: item.durationText,
                  viewsText: item.viewsText,
                  publishedText: item.publishedText,
                  publishedAt: item.publishedAt,
                ),
              );
            } else {
              items.add(item);
            }
          }
        }
      }
    }

    await Future.wait(
      List.generate(channels.length < 6 ? channels.length : 6, (_) => worker()),
    );
    items.sort(
      (a, b) => (b.publishedAt ?? DateTime(0)).compareTo(
        a.publishedAt ?? DateTime(0),
      ),
    );
    return items
        .where(
          (e) =>
              e.publishedAt != null &&
              !e.publishedAt!.isBefore(
                now.subtract(const Duration(days: 14)),
              ) &&
              !e.publishedAt!.isAfter(now),
        )
        .toList();
  }

  Future<HomeData> _fetch(String chip, CancelToken token) async {
    final api = await ref.read(ytApiProvider.future);
    final settings = ref.read(contentPrefsProvider);
    if (token.isCancelled ||
        api.search.http.gl != settings.gl) {
      throw StateError('Regional session changed');
    }
    final historyFuture = ref.read(historyRepoProvider).recent();
    final dislikedFuture = ref.read(historyRepoProvider).dislikedChannels();
    final channelsFuture = ref.read(subscriptionRepoProvider).channelIds();
    final db = ref.read(dbProvider);
    final historyMediaFuture = db.historyDao.getHistory();
    final likedMediaFuture = db.reactionsDao.getLikedVideos();
    final history = await historyFuture;
    final disliked = await dislikedFuture;
    final channels = await channelsFuture;
    final historyMedia = await historyMediaFuture;
    final likedMedia = (await likedMediaFuture).take(100).toList();
    final errors = <String>[];
    final watched = history.map((h) => h.videoId).toSet();
    final now = DateTime.now();
    final seen = SeenVideos.decode(
      await db.getValue('home_seen_videos_v1'),
      now,
    );
    final preferred = settings.contentLanguages;
    final hidden = settings.hiddenLanguages;
    final strictHome = settings.strictHome;
    final filter = ref.read(contentFilterProvider);
    final probe = await ref.read(captionProbeProvider.future);
    final random = Random(_seed);
    final discoveryLanguage = preferred.where((language) => language != 'en').firstOrNull;
    final discoveryPlan = discoveryLanguage == null
        ? null
        : await (await ref.read(discoveryEngineProvider.future)).plan(
            language: discoveryLanguage,
            chip: chip,
            random: random,
          );
    final refreshExcluded = Set<String>.of(_refreshExcluded);
    List<VideoItem> Function(List<VideoItem>) rankFor(String source) =>
        (items) => filter.filterVideos(
              items,
              shownLanguages: preferred,
              hiddenLanguages: hidden,
              strictHome: strictHome,
              seen: seen.ids,
              random: random,
              source: source,
              filterHindiDevotional: true,
            ).items.where((item) => !refreshExcluded.contains(item.id)).toList();
    final uploadFuture = _subscriptions(
      api,
      {...channels, ...?discoveryPlan?.channelIds}.toList(),
      token,
      errors,
    ).then((items) => items.where((v) => !watched.contains(v.id)).toList());
    final historyMediaById = {
      for (final row in historyMedia) row.history.videoId: row.media,
    };
    final seedVideos = <VideoItem>[];
    final seedIds = <String>{};
    for (final entry in history.where((item) => !item.isShort)) {
      if (seedVideos.length >= 6) break;
      final media = historyMediaById[entry.videoId];
      final item = VideoItem(
        id: entry.videoId,
        title: media?.title ?? '',
        channelId: media?.channelId ?? '',
        channelName: entry.channelName.isNotEmpty
            ? entry.channelName
            : media?.channelName ?? '',
        channelAvatarUrl: '',
        thumbUrl: media?.thumbUrl ?? '',
      );
      if (filter.evaluate(
            id: item.id,
            title: item.title,
            channelId: item.channelId,
            channelName: item.channelName,
            shownLanguages: preferred,
            hiddenLanguages: hidden,
            strictHome: strictHome,
          ).kept &&
          seedIds.add(item.id)) {
        seedVideos.add(item);
      }
    }
    for (final media in likedMedia) {
      if (seedVideos.length >= 6) break;
      final item = VideoItem(
        id: media.videoId,
        title: media.title,
        channelId: media.channelId,
        channelName: media.channelName,
        channelAvatarUrl: '',
        thumbUrl: media.thumbUrl,
      );
      if (filter.evaluate(
            id: item.id,
            title: item.title,
            channelId: item.channelId,
            channelName: item.channelName,
            shownLanguages: preferred,
            hiddenLanguages: hidden,
            strictHome: strictHome,
          ).kept &&
          seedIds.add(item.id)) {
        seedVideos.add(item);
      }
    }
    final personal = seedVideos.isNotEmpty || channels.isNotEmpty;
    final sources = <HomeSource>[];
    void searchSource(String query, {required int weight, bool live = false}) {
      String? activeParams;
      sources.add(
        HomeSource(
          weight: weight,
          transform: rankFor('search:$query'),
          fetch: (cursor) async {
            final started = DateTime.now();
            if (cursor != null) {
              return api.search.videos(
                query,
                params: activeParams ?? (live ? 'EgJAAQ%3D%3D' : null),
                continuation: cursor,
                cancelToken: token,
              );
            }
            var page = await api.search.videos(
              query,
              params: live ? 'EgJAAQ%3D%3D' : null,
              cancelToken: token,
            );
            if (page.searchDateFilters.isNotEmpty) {
              activeParams = page.searchDateFilters.length > 1
                  ? page.searchDateFilters[1]
                  : page.searchDateFilters.first;
              page = await api.search.videos(
                query,
                params: activeParams,
                cancelToken: token,
              );
            }
            if (page.searchSortParams.isNotEmpty) {
              final sort = page.searchSortParams.first;
              activeParams = sort;
              page = await api.search.videos(
                query,
                params: sort,
                cancelToken: token,
              );
            }
            if (cursor == null) {
              final matched = page.items.where((item) => filter.evaluate(
                id: item.id,
                title: item.title,
                channelId: item.channelId,
                channelName: item.channelName,
                shownLanguages: preferred,
                hiddenLanguages: hidden,
                strictHome: strictHome,
              ).kept).length;
              await ref.read(discoveryStoreProvider).recordQuery(
                query,
                newItems: page.items.where((item) => !seen.ids.contains(item.id)).length,
                precision: page.items.isEmpty ? 0 : matched / page.items.length,
                dwellMs: DateTime.now().difference(started).inMilliseconds,
              );
            }
            if (page.continuation != null && random.nextBool()) {
              page = await api.search.videos(
                query,
                params: activeParams,
                continuation: page.continuation,
                cancelToken: token,
              );
            }
            return page;
          },
        ),
      );
    }

    if (chip == 'All') {
      for (final entry in seedVideos) {
        sources.add(
          HomeSource(
            weight: 2,
            transform: rankFor('related:${entry.id}'),
            fetch: (cursor) => api.next.related(
              entry.id,
              continuation: cursor,
              cancelToken: token,
            ),
          ),
        );
      }
      if (channels.isNotEmpty || (discoveryPlan?.channelIds.isNotEmpty ?? false)) {
        sources.add(
          HomeSource(
            weight: 2,
            transform: rankFor('subscriptions'),
            fetch: (_) async => VideoPage(await uploadFuture, null),
          ),
        );
      }
      final personalSourceCount = sources.length;
      final homeQueries = discoveryPlan?.queries.isNotEmpty == true
          ? discoveryPlan!.queries
          : chooseHomeQueries(
              chip: 'All',
              hasHistory: history.isNotEmpty,
              localRatio: settings.localRatio,
              shownLanguages: settings.contentLanguages,
              random: random,
            );
      final personalQueries = personalSearchQueries(
        history: [
          for (final row in historyMedia)
            (
              title: row.media?.title ?? '',
              channelName: row.media?.channelName ?? '',
            ),
        ],
        likes: [
          for (final row in likedMedia)
            (title: row.title, channelName: row.channelName),
        ],
      );
      final addedQueries = <String>{};
      for (final query in personalQueries.take(3)) {
        addedQueries.add(query);
        searchSource(query, weight: personal ? 1 : 2);
      }
      for (final query in homeQueries) {
        if (!addedQueries.add(query)) continue;
        searchSource(
          query,
          weight: personal ? 1 : 2,
        );
      }
      sources.add(
        HomeSource(
          weight: 1,
          transform: rankFor('browse:home'),
          fetch: (cursor) =>
              api.browse.home(continuation: cursor, cancelToken: token),
        ),
      );
      if (!personal) {
        sources.add(
          HomeSource(
            weight: 1,
            transform: rankFor('browse:live'),
            fetch: (c) => api.browse.live(continuation: c, cancelToken: token),
          ),
        );
        sources.add(
          HomeSource(
            weight: 1,
            transform: rankFor('browse:gaming'),
            fetch: (c) =>
                api.browse.gaming(continuation: c, cancelToken: token),
          ),
        );
        sources.add(
          HomeSource(
            weight: 1,
            transform: rankFor('browse:podcasts'),
            fetch: (c) =>
                api.browse.podcasts(continuation: c, cancelToken: token),
          ),
        );
      }
      final rotatingSources = sources.sublist(personalSourceCount)..shuffle(random);
      sources.replaceRange(personalSourceCount, sources.length, rotatingSources);
    } else if (chip == 'Recently uploaded') {
      sources.add(
        HomeSource(
          weight: 2,
          transform: rankFor('subscriptions'),
          fetch: (_) async => VideoPage(await uploadFuture, null),
        ),
      );
    } else if (chip == 'Trending') {
      sources.add(
        HomeSource(
          weight: 1,
          transform: (items) => items
              .where((item) => !refreshExcluded.contains(item.id))
              .toList(),
          fetch: (_) async {
            final page = await api.charts.trending(settings.gl, cancelToken: token);
            var candidates = filter.filterVideos(
              page,
              shownLanguages: preferred,
              hiddenLanguages: hidden,
              strictHome: strictHome,
              seen: const {},
              random: random,
              source: 'charts:trending',
              filterHindiDevotional: true,
            ).items;
            var items = trendingWithSeenFallback(candidates, seen);
            if (items.length < 3) {
              final topUpQueries = discoveryPlan?.queries.isNotEmpty == true ? discoveryPlan!.queries : chooseHomeQueries(
                chip: 'Trending',
                hasHistory: personal,
                localRatio: settings.localRatio,
                shownLanguages: preferred,
                random: random,
              );
              for (final q in topUpQueries.take(3)) {
                if (items.length >= 3) break;
                try {
                  final res = await api.search.videos(q, cancelToken: token);
                  final topped = filter.filterVideos(
                    res.items,
                    shownLanguages: preferred,
                    hiddenLanguages: hidden,
                    strictHome: strictHome,
                    seen: const {},
                    random: random,
                    source: 'topup:$q',
                    filterHindiDevotional: true,
                  ).items;
                  candidates = [...candidates, ...topped];
                  items = trendingWithSeenFallback(candidates, seen);
                } catch (_) {}
              }
            }
            return VideoPage(items.take(5).toList(), null);
          },
        ),
      );
    } else if (chip == 'Live kiosk' ||
        chip == 'Gaming kiosk' ||
        chip == 'Podcasts kiosk') {
      sources.add(
        HomeSource(
          weight: 1,
          transform: rankFor('kiosk:$chip'),
          fetch: (c) async {
            final page = await switch (chip) {
              'Live kiosk' => api.browse.live(
                continuation: c,
                cancelToken: token,
              ),
              'Gaming kiosk' => api.browse.gaming(
                continuation: c,
                cancelToken: token,
              ),
              _ => api.browse.podcasts(continuation: c, cancelToken: token),
            };
            var items = filter.filterVideos(
              page.items,
              shownLanguages: preferred,
              hiddenLanguages: hidden,
              strictHome: strictHome,
              seen: seen.ids,
              random: random,
              source: 'kiosk:$chip',
              filterHindiDevotional: true,
            ).items;
            if (items.length < 15) {
              final topic = chip.replaceAll(' kiosk', '');
              final topUpQueries = discoveryPlan?.queries.isNotEmpty == true ? discoveryPlan!.queries : chooseHomeQueries(
                chip: topic,
                hasHistory: personal,
                localRatio: settings.localRatio,
                shownLanguages: preferred,
                random: random,
              );
              for (final q in topUpQueries) {
                if (items.length >= 15) break;
                try {
                  final res = await api.search.videos(q, cancelToken: token);
                  final topped = filter.filterVideos(
                    res.items,
                    shownLanguages: preferred,
                    hiddenLanguages: hidden,
                    strictHome: strictHome,
                    seen: seen.ids,
                    random: random,
                    source: 'topup:$q',
                    filterHindiDevotional: true,
                  ).items;
                  items = [...items, ...topped];
                } catch (_) {}
              }
            }
            return VideoPage(items, page.continuation);
          },
        ),
      );
    } else if (homeTopics.containsKey(chip)) {
      final topicQueries = discoveryPlan?.queries.isNotEmpty == true
          ? discoveryPlan!.queries
          : chooseHomeQueries(
              chip: chip,
              hasHistory: personal,
              localRatio: settings.localRatio,
              shownLanguages: settings.contentLanguages,
              random: random,
            );
      for (final query in topicQueries) {
        searchSource(
          query,
          weight: personal ? 1 : 2,
          live: chip == 'Live',
        );
      }
    }
    final mixer = HomeMixer(sources, history: history, disliked: disliked);
    final startFuture = mixer.start();
    final chartsFuture = chip == 'All'
        ? api.charts.trending(settings.gl, cancelToken: token).catchError((
            Object _,
          ) {
            errors.add('Trending');
            return <VideoItem>[];
          })
        : Future.value(<VideoItem>[]);
    // Recent owner lookups supplement channel names found in the subscription feed.
    final ownerFuture = chip == 'All'
        ? Future.wait(
            history.take(2).map((h) async {
              try {
                return (await api.next.ownerMetadata(
                      h.videoId,
                      cancelToken: token,
                    ))?.channelName ??
                    '';
              } catch (_) {
                return '';
              }
            }),
          )
        : Future.value(<String>[]);
    final uploads = await uploadFuture;
    final owners = await ownerFuture;
    final queries = shortsQueries(
      chip: chip,
      channels: [
        ...history.take(30).map((h) => h.channelName),
        ...owners,
        ...uploads.map((v) => v.channelName),
      ],
      localRatio: settings.localRatio,
      shownLanguages: settings.contentLanguages,
      hasHistory: history.isNotEmpty,
      // Subscriptions personalize the mixer, but query breadth narrows only
      // after actual watch history exists.
      random: random,
    );
    var successes = 0;
    Future<List<ShortItem>> loadShorts(String query) async {
      final items = <ShortItem>[];
      String? cursor;
      for (var page = 0; page <= 3; page++) {
        final result = await api.search.shortsPage(
          query,
          continuation: cursor,
          cancelToken: token,
        );
        items.addAll(result.items);
        cursor = result.continuation;
        if (cursor == null || items.length >= 20) break;
      }
      return items;
    }

    final shortFuture = Future.wait(
      queries.map((query) async {
        try {
          final result = await loadShorts(query);
          successes++;
          return result;
        } catch (_) {
          return <ShortItem>[];
        }
      }),
    );
    await startFuture;
    var videos = await mixer.next(24);
    // ASR caption probe before render on ambiguous Latin items
    final ambiguous = <({String videoId, String? channelId, String? channelName})>[];
    for (final v in videos) {
      if (filter.isAmbiguous(title: v.title, channelId: v.channelId, channelName: v.channelName)) {
        ambiguous.add((videoId: v.id, channelId: v.channelId, channelName: v.channelName));
      }
    }
    var asrResults = <String, String?>{};
    if (ambiguous.isNotEmpty) {
      asrResults = await probe.probeBatch(ambiguous.take(20).toList(), asrOnly: true);
      videos = filter.filterVideos(
        videos,
        shownLanguages: preferred,
        hiddenLanguages: hidden,
        strictHome: strictHome,
        seen: seen.ids,
        probeResults: asrResults,
        random: random,
        source: 'probe_refine',
        filterHindiDevotional: true,
      ).items;
    }
    var refillTries = 0;
    while (videos.length < 24 && mixer.hasMore && refillTries < 3) {
      refillTries++;
      final more = await mixer.next(24 - videos.length);
      if (more.isEmpty) break;
      videos.addAll(more);
    }
    videos = mixByPublishedAge(videos, random: random);
    if (discoveryLanguage != null) {
      final registry = LanguageProfileRegistry.instance;
      final store = ref.read(discoveryStoreProvider);
      final nonLanguageTokens = <String>{};
      for (final item in videos) {
        final script = registry.detectScript('${item.title} ${item.channelName}');
        if (script != null && script != discoveryLanguage) {
          nonLanguageTokens.addAll(RegExp(r"[a-zA-Z][a-zA-Z']{2,}").allMatches('${item.title} ${item.channelName}').map((e) => e.group(0)!.toLowerCase()));
        }
      }
      for (final item in videos) {
        if (item.channelId.isEmpty) continue;
        final script = registry.detectScript('${item.title} ${item.channelName}');
        final asr = asrResults[item.id]?.toLowerCase().split('-').first;
        final confirmed = script == discoveryLanguage || asr == discoveryLanguage;
        final rejected = (script != null && script != discoveryLanguage) || (asr != null && asr != discoveryLanguage);
        if (confirmed || rejected) {
          await store.observeChannel(
            channelId: item.channelId,
            videoId: item.id,
            language: discoveryLanguage,
            groundTruthMatch: confirmed,
            topics: [chip],
          );
        }
        if (confirmed) {
          await store.mineTerms(language: discoveryLanguage, title: item.title, verifiedNonLanguageTerms: nonLanguageTokens);
        }
      }
    }
    final shortPages = await shortFuture;
    if (successes == 0 && queries.isNotEmpty) errors.add('Shorts');
    final dedupedShorts = <String, ShortItem>{};
    for (final item in shortPages.expand((page) => page)) {
      dedupedShorts.putIfAbsent(item.id, () => item);
    }
    final candidates = dedupedShorts.values.take(48).toList();
    final candidateMetadata = List<ShortItem>.filled(
      candidates.length,
      const ShortItem(id: '', thumbUrl: ''),
      growable: false,
    );
    var metaCursor = 0;
    Future<void> metadataWorker() async {
      while (metaCursor < candidates.length) {
        final index = metaCursor++;
        final item = candidates[index];
        try {
          final meta = await api.next.ownerMetadata(
            item.id,
            cancelToken: token,
          );
          candidateMetadata[index] = ShortItem(
            id: item.id,
            thumbUrl: item.thumbUrl,
            title: item.title ?? meta?.title,
            channelId: meta?.channelId,
            channelName: meta?.channelName,
            channelAvatarUrl: meta?.channelAvatarUrl,
          );
        } catch (_) {
          candidateMetadata[index] = item;
        }
      }
    }

    await Future.wait(List.generate(3, (_) => metadataWorker()));
    final freshShorts = buildShortsShelf(
      [candidateMetadata],
      watched,
      random: random,
      preferred: preferred,
      hidden: hidden,
      seen: seen.ids,
      filterHindiDevotional: true,
    );
    final rankedTrending = filter.filterVideos(
      await chartsFuture,
      shownLanguages: preferred,
      hiddenLanguages: hidden,
      strictHome: strictHome,
      seen: const {},
      random: random,
      source: 'charts:trending',
      filterHindiDevotional: true,
    ).items.where((item) => !refreshExcluded.contains(item.id));
    final trending = trendingWithSeenFallback(rankedTrending, seen);
    if (token.isCancelled) throw StateError('Home request cancelled');
    for (final source in sources) {
      if (source.error != null) errors.add('Feed');
    }
    if (videos.isEmpty &&
        freshShorts.isEmpty &&
        trending.isEmpty &&
        errors.isNotEmpty) {
      throw StateError('Could not load Home');
    }
    if (identical(token, _token)) _mixer = mixer;
    seen.mark([
      ...videos.map((v) => v.id),
      ...freshShorts.map((v) => v.id),
      ...trending.map((v) => v.id),
    ], now);
    await db.setValue('home_seen_videos_v1', seen.encode());
    if (chip == 'All') {
      await ref
          .read(dbProvider)
          .setValue(
            homeCacheKey(settings),
            HomeCache(videos, freshShorts, DateTime.now()).encode(),
          );
    }
    return HomeData(
      videos: videos,
      shorts: freshShorts,
      chip: chip,
      trending: trending,
      continuations: mixer.hasMore ? const {'mixer': 'more'} : const {},
      errors: errors.toSet().toList(),
    );
  }

  void _cancel() {
    _token.cancel();
    _token = CancelToken();
    _generation++;
    _debounce?.cancel();
    _pendingFresh = [];
  }

  Future<void> refresh() async {
    final chip = state.value?.chip ?? 'All';
    _refreshExcluded = state.value?.videos.take(10).map((v) => v.id).toSet() ?? {};
    _cancel();
    _seed = DateTime.now().microsecondsSinceEpoch;
    final generation = _generation;
    final token = _token;
    final result = await AsyncValue.guard(() => _fetch(chip, token));
    if (generation == _generation) state = result;
    _refreshExcluded = {};
  }

  void select(String chip) {
    interact();
    _cancel();
    _seed = DateTime.now().microsecondsSinceEpoch;
    final generation = _generation;
    final token = _token;
    state = const AsyncLoading();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final result = await AsyncValue.guard(() => _fetch(chip, token));
      if (generation == _generation) state = result;
    });
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.loadingMore ||
        current.continuations.isEmpty) {
      return;
    }
    if (!_paginationGuard.begin()) return;
    state = AsyncData(current.copy(loadingMore: true));
    final generation = _generation;
    final token = _token;
    try {
      final mixer = _mixer;
      if (mixer == null) return;
      mixer.exclude(current.videos.map((v) => v.id));
      final pending = _pendingFresh;
      _pendingFresh = [];
      final fresh = [
        ...pending,
        ...await mixer.next((24 - pending.length).clamp(0, 24)),
      ];
      if (generation != _generation || token.isCancelled) return;
      state = AsyncData(
        current.copy(
          videos: [...current.videos, ...fresh],
          continuations: mixer.hasMore ? const {'mixer': 'more'} : const {},
          loadingMore: false,
        ),
      );
      final db = ref.read(dbProvider);
      final seen = SeenVideos.decode(
        await db.getValue('home_seen_videos_v1'),
        DateTime.now(),
      );
      seen.mark(fresh.map((item) => item.id), DateTime.now());
      await db.setValue('home_seen_videos_v1', seen.encode());
    } catch (_) {
      if (generation == _generation) {
        state = AsyncData(
          current.copy(
            errors: [...current.errors, 'More videos'],
            loadingMore: false,
          ),
        );
      }
    } finally {
      _paginationGuard.end();
    }
  }
}
