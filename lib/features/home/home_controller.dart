import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
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

final _avatarCoordinatorProvider = Provider<AvatarBackfillCoordinator>(
  (ref) => AvatarBackfillCoordinator(),
);
final channelAvatarProvider =
    FutureProvider.family<
      ({String url, String channelId}),
      ({String channelId, String videoId})
    >((ref, key) async {
      var channelId = key.channelId;
      final cache = ref.read(channelAvatarCacheProvider);
      if (channelId.isNotEmpty) {
        final cached = cache.get(channelId);
        if (cached != null) return (url: cached, channelId: channelId);
      }
      final url =
          await ref.read(_avatarCoordinatorProvider).resolve(
            channelId.isNotEmpty ? channelId : 'video:${key.videoId}',
            () async {
              final api = await ref.read(ytApiProvider.future);
              if (channelId.isNotEmpty) {
                return api.browse.channelAvatar(channelId);
              }
              final owner = await api.next.ownerMetadata(key.videoId);
              channelId = owner?.channelId ?? '';
              return owner?.channelAvatarUrl ?? '';
            },
          ) ??
          '';
      if (channelId.isNotEmpty && url.isNotEmpty) {
        await cache.put(channelId, url);
      }
      return (url: url, channelId: channelId);
    });

class HomeController extends AsyncNotifier<HomeData> {
  final _refreshGuard = HomeRefreshGuard();
  final _paginationGuard = PaginationGuard();
  CancelToken _token = CancelToken();
  Timer? _debounce;
  int _generation = 0;
  final Map<String, ({DateTime fetched, List<VideoItem> items})> _rssCache = {};
  final Map<String, HomeData> _sessionDataByChip = {};
  final Map<String, HomeMixer> _mixersByChip = {};
  final Map<String, CancelToken> _tokensByChip = {};
  HomeMixer? _mixer;
  List<VideoItem> _pendingFresh = [];
  String? _sessionKey;
  int _seed = DateTime.now().microsecondsSinceEpoch;
  Set<String> _refreshExcluded = {};

  @override
  FutureOr<HomeData> build() {
    if (_token.isCancelled) _token = CancelToken();
    ref.onDispose(() {
      _debounce?.cancel();
      _token.cancel();
      for (final token in _tokensByChip.values) {
        token.cancel();
      }
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
      for (final token in _tokensByChip.values) {
        token.cancel();
      }
      _token = CancelToken();
      _generation++;
      _sessionKey = sessionKey;
      _pendingFresh = [];
      _rssCache.clear();
      _mixer = null;
      _sessionDataByChip.clear();
      _mixersByChip.clear();
      _tokensByChip.clear();
      _seed = DateTime.now().microsecondsSinceEpoch;
    }
    final initial = ref.read(initialAppSettingsProvider);
    final cache =
        homeCacheKey(ref.read(contentPrefsProvider)) == homeCacheKey(initial)
        ? ref.read(initialHomeCacheProvider)
        : null;
    if (cache != null && (cache.videos.isNotEmpty || cache.shorts.isNotEmpty)) {
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
    } catch (error, stackTrace) {
      dev.log(
        'Background Home refresh failed',
        name: 'HomeController',
        error: error,
        stackTrace: stackTrace,
      );
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
            final raw = await ref
                .read(dbProvider)
                .getValue('home_rss_cache_$id');
            if (raw != null) {
              final json = jsonDecode(raw) as Map<String, dynamic>;
              final fetched = DateTime.tryParse(
                json['fetched'] as String? ?? '',
              );
              final entries = (json['items'] as List? ?? const [])
                  .whereType<Map>()
                  .map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
              if (fetched != null) cached = (fetched: fetched, items: entries);
            }
          } catch (error, stackTrace) {
            dev.log(
              'Failed to read RSS cache for channel $id',
              name: 'HomeController',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
        if (cached == null ||
            now.difference(cached.fetched) >= const Duration(minutes: 30)) {
          try {
            cached = (
              fetched: now,
              items: await api.rss.uploads(id, cancelToken: token),
            );
            _rssCache[id] = cached;
            await ref
                .read(dbProvider)
                .setValue(
                  'home_rss_cache_$id',
                  jsonEncode({
                    'fetched': now.toIso8601String(),
                    'items': cached.items.map((e) => e.toJson()).toList(),
                  }),
                );
          } catch (error, stackTrace) {
            dev.log(
              'RSS refresh failed for channel $id',
              name: 'HomeController',
              error: error,
              stackTrace: stackTrace,
            );
            if (!token.isCancelled) {
              errors.add('Subscriptions');
              cached = (fetched: now, items: cached?.items ?? <VideoItem>[]);
              _rssCache[id] = cached;
            }
          }
        }
        if (cached != null && cached.items.isEmpty && !token.isCancelled) {
          try {
            dev.log(
              'RSS had no entries for $id; falling back to the Y7 channel videos tab',
              name: 'HomeController',
            );
            final fallback = await api.browse.channelVideos(
              id,
              cancelToken: token,
            );
            cached = (fetched: now, items: fallback.items);
            _rssCache[id] = cached;
            await ref
                .read(dbProvider)
                .setValue(
                  'home_rss_cache_$id',
                  jsonEncode({
                    'fetched': now.toIso8601String(),
                    'items': cached.items.map((e) => e.toJson()).toList(),
                  }),
                );
          } catch (error, stackTrace) {
            dev.log(
              'Y7 channel videos fallback failed for $id',
              name: 'HomeController',
              error: error,
              stackTrace: stackTrace,
            );
            if (!token.isCancelled) errors.add('Subscriptions');
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

  Future<void> _finishShortsLoad({
    required String chip,
    required CancelToken token,
    required Future<List<List<ShortItem>>> pagesFuture,
    required Set<String> watched,
    required Set<String> preferred,
    required Set<String> hidden,
    required SeenVideos seen,
    required AppSettings settings,
    required HomeData initial,
  }) async {
    try {
      // Let the initial HomeData return before even immediately available
      // Shorts results attempt to update the notifier.
      await Future<void>.delayed(Duration.zero);
      final pages = await pagesFuture;
      final unique = <String, ShortItem>{};
      for (final item in pages.expand((page) => page)) {
        unique.putIfAbsent(item.id, () => item);
      }
      final candidates = unique.values.take(48).toList();
      final api = await ref.read(ytApiProvider.future);
      final metadata = List<ShortItem>.filled(
        candidates.length,
        const ShortItem(id: '', thumbUrl: ''),
        growable: false,
      );
      var cursor = 0;
      Future<void> worker() async {
        while (cursor < candidates.length && !token.isCancelled) {
          final index = cursor++;
          final item = candidates[index];
          try {
            final meta = await api.next.ownerMetadata(
              item.id,
              cancelToken: token,
            );
            metadata[index] = ShortItem(
              id: item.id,
              thumbUrl: item.thumbUrl,
              title: item.title ?? meta?.title,
              channelId: meta?.channelId,
              channelName: meta?.channelName,
              channelAvatarUrl: meta?.channelAvatarUrl,
            );
          } catch (error, stackTrace) {
            dev.log(
              'Shorts metadata failed for ${item.id}',
              name: 'HomeController',
              error: error,
              stackTrace: stackTrace,
            );
            metadata[index] = item;
          }
        }
      }

      // Metadata is only used to refine the optional Shorts shelf. Keep it
      // bounded and off the critical path that displays regular Home videos.
      await Future.wait(List.generate(3, (_) => worker()));
      if (token.isCancelled) return;
      final shorts = buildShortsShelf(
        [metadata],
        watched,
        random: Random(_seed),
        preferred: preferred,
        hidden: hidden,
        seen: seen.ids,
      );
      seen.mark(shorts.map((item) => item.id), DateTime.now());
      await ref
          .read(dbProvider)
          .setValue(homeSeenKey(settings, chip: chip), seen.encode());
      final current = _sessionDataByChip[chip] ?? initial;
      final result = current.copy(
        shorts: shorts,
        errors: pages.every((page) => page.isEmpty)
            ? [...current.errors, 'Shorts']
            : current.errors,
      );
      _sessionDataByChip[chip] = result;
      await ref
          .read(dbProvider)
          .setValue(
            homeCacheKey(settings, chip: chip),
            HomeCache(result.videos, result.shorts, DateTime.now()).encode(),
          );
      if (identical(token, _token) &&
          (state.value == null || state.value?.chip == chip)) {
        state = AsyncData(result);
      }
    } catch (error, stackTrace) {
      dev.log(
        'Background Shorts load failed for $chip',
        name: 'HomeController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<HomeData> _fetch(String chip, CancelToken token) async {
    if (!token.isCancelled) _tokensByChip[chip] = token;
    final api = await ref.read(ytApiProvider.future);
    final settings = ref.read(contentPrefsProvider);
    if (token.isCancelled ||
        api.search.http.gl != (settings.gl == 'AUTO' ? '' : settings.gl)) {
      throw StateError('Regional session changed');
    }
    final historyFuture = ref.read(historyRepoProvider).recent();
    final channelsFuture = ref.read(subscriptionRepoProvider).channelIds();
    final db = ref.read(dbProvider);
    final historyMediaFuture = db.historyDao.getHistory();
    final likedMediaFuture = db.reactionsDao.getLikedVideos();
    final history = await historyFuture;
    final channels = await channelsFuture;
    final historyMedia = await historyMediaFuture;
    final likedMedia = (await likedMediaFuture).take(100).toList();
    final errors = <String>[];
    final watched = history.map((h) => h.videoId).toSet();
    final now = DateTime.now();
    final seen = SeenVideos.decode(
      await db.getValue(homeSeenKey(settings, chip: chip)),
      now,
    );
    final preferred = settings.contentLanguages;
    final hidden = settings.hiddenLanguages;
    final strictHome = settings.strictHome;
    final filter = ref.read(contentFilterProvider);
    final probe = await ref.read(captionProbeProvider.future);
    final random = Random(_seed);
    final refreshExcluded = Set<String>.of(_refreshExcluded);
    List<VideoItem> Function(List<VideoItem>) rankFor(String source) =>
        (items) {
          final ranked = filter
              .filterVideos(
                items,
                shownLanguages: preferred,
                hiddenLanguages: hidden,
                strictHome: strictHome,
                seen: seen.ids,
                random: random,
                source: source,
              )
              .items
              .where((item) => !refreshExcluded.contains(item.id))
              .toList();
          if (!strictHome) return ranked;

          // Keep ambiguous Latin-script candidates in the internal mixer long
          // enough for the ASR caption probe to classify them. The final strict
          // filter still decides whether they reach the visible feed.
          final included = ranked.map((item) => item.id).toSet();
          ranked.addAll(
            items.where(
              (item) =>
                  !refreshExcluded.contains(item.id) &&
                  !included.contains(item.id) &&
                  filter.isAmbiguous(
                    title: item.title,
                    channelId: item.channelId,
                    channelName: item.channelName,
                  ),
            ),
          );
          return ranked;
        };
    final uploadFuture = _subscriptions(api, channels.toList(), token, errors);
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
      if (filter
              .evaluate(
                id: item.id,
                title: item.title,
                channelId: item.channelId,
                channelName: item.channelName,
                shownLanguages: preferred,
                hiddenLanguages: hidden,
                strictHome: strictHome,
              )
              .kept &&
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
      if (filter
              .evaluate(
                id: item.id,
                title: item.title,
                channelId: item.channelId,
                channelName: item.channelName,
                shownLanguages: preferred,
                hiddenLanguages: hidden,
                strictHome: strictHome,
              )
              .kept &&
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
              final matched = page.items
                  .where(
                    (item) => filter
                        .evaluate(
                          id: item.id,
                          title: item.title,
                          channelId: item.channelId,
                          channelName: item.channelName,
                          shownLanguages: preferred,
                          hiddenLanguages: hidden,
                          strictHome: strictHome,
                        )
                        .kept,
                  )
                  .length;
              await ref
                  .read(discoveryStoreProvider)
                  .recordQuery(
                    query,
                    newItems: page.items
                        .where((item) => !seen.ids.contains(item.id))
                        .length,
                    precision: page.items.isEmpty
                        ? 0
                        : matched / page.items.length,
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
      if (channels.isNotEmpty) {
        sources.add(
          HomeSource(
            weight: 2,
            transform: rankFor('subscriptions'),
            fetch: (_) async => VideoPage(await uploadFuture, null),
          ),
        );
      }
      final personalSourceCount = sources.length;
      final homeQueries = chooseHomeQueries(
        chip: 'All',
        hasHistory: history.isNotEmpty,
        localRatio: settings.localRatio,
        shownLanguages: settings.contentLanguages,
        random: random,
      );
      for (final query in homeQueries) {
        searchSource(query, weight: personal ? 1 : 2);
      }
      sources.add(
        HomeSource(
          weight: 1,
          transform: rankFor('browse:home'),
          fetch: (cursor) =>
              api.browse.home(continuation: cursor, cancelToken: token),
        ),
      );
      final rotatingSources = sources.sublist(personalSourceCount)
        ..shuffle(random);
      sources.replaceRange(
        personalSourceCount,
        sources.length,
        rotatingSources,
      );
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
            if (settings.gl == 'AUTO') return const VideoPage([], null);
            final page = await api.charts.trending(
              settings.gl,
              cancelToken: token,
            );
            var candidates = filter
                .filterVideos(
                  page,
                  shownLanguages: preferred,
                  hiddenLanguages: hidden,
                  strictHome: strictHome,
                  seen: const {},
                  random: random,
                  source: 'charts:trending',
                )
                .items;
            var items = trendingWithSeenFallback(candidates, seen);
            if (items.length < 3) {
              final topUpQueries = chooseHomeQueries(
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
                  final topped = filter
                      .filterVideos(
                        res.items,
                        shownLanguages: preferred,
                        hiddenLanguages: hidden,
                        strictHome: strictHome,
                        seen: const {},
                        random: random,
                        source: 'topup:$q',
                      )
                      .items;
                  candidates = [...candidates, ...topped];
                  items = trendingWithSeenFallback(candidates, seen);
                } catch (error, stackTrace) {
                  dev.log(
                    'Trending top-up query failed: $q',
                    name: 'HomeController',
                    error: error,
                    stackTrace: stackTrace,
                  );
                }
              }
            }
            return VideoPage(items.take(5).toList(), null);
          },
        ),
      );
    } else if (homeCategoryChips.contains(chip)) {
      final categoryQueries = chooseHomeQueries(
        chip: chip,
        hasHistory: history.isNotEmpty,
        localRatio: settings.localRatio,
        shownLanguages: preferred,
        random: random,
      );
      for (final query in categoryQueries) {
        searchSource(query, weight: 1, live: chip == 'Live');
      }
    }
    final mixer = HomeMixer(sources);
    final startFuture = mixer.start();
    final chartsFuture = chip == 'All' && settings.gl != 'AUTO'
        ? api.charts.trending(settings.gl, cancelToken: token).catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            dev.log(
              'Home trending charts fetch failed',
              name: 'HomeController',
              error: error,
              stackTrace: stackTrace,
            );
            errors.add('Trending');
            return <VideoItem>[];
          })
        : Future.value(<VideoItem>[]);
    final queries = chip == 'All'
        ? shortsQueries(
            chip: chip,
            channels: history.take(30).map((h) => h.channelName).toList(),
            localRatio: settings.localRatio,
            shownLanguages: settings.contentLanguages,
            hasHistory: history.isNotEmpty,
            // Subscriptions personalize the mixer, but query breadth narrows only
            // after actual watch history exists.
            random: random,
          )
        : <String>[];
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
          return result;
        } catch (error, stackTrace) {
          dev.log(
            'Home Shorts query failed: $query',
            name: 'HomeController',
            error: error,
            stackTrace: stackTrace,
          );
          return <ShortItem>[];
        }
      }),
    );
    await startFuture;
    var videos = await mixer.next(24);
    // ASR caption probe before render on ambiguous Latin items
    final ambiguous =
        <({String videoId, String? channelId, String? channelName})>[];
    for (final v in videos) {
      if (filter.isAmbiguous(
        title: v.title,
        channelId: v.channelId,
        channelName: v.channelName,
      )) {
        ambiguous.add((
          videoId: v.id,
          channelId: v.channelId,
          channelName: v.channelName,
        ));
      }
    }
    var asrResults = <String, String?>{};
    if (ambiguous.isNotEmpty) {
      asrResults = await probe.probeBatch(
        ambiguous.take(20).toList(),
        asrOnly: true,
      );
      videos = filter
          .filterVideos(
            videos,
            shownLanguages: preferred,
            hiddenLanguages: hidden,
            strictHome: strictHome,
            seen: seen.ids,
            probeResults: asrResults,
            random: random,
            source: 'probe_refine',
          )
          .items;
    }
    var refillTries = 0;
    while (videos.length < 24 && mixer.hasMore && refillTries < 3) {
      refillTries++;
      final more = await mixer.next(
        24 - videos.length,
        waitTimeout: const Duration(seconds: 2),
      );
      if (more.isEmpty) break;
      videos.addAll(more);
    }
    videos = mixByPublishedAge(videos, random: random);
    final rankedTrending = filter
        .filterVideos(
          await chartsFuture,
          shownLanguages: preferred,
          hiddenLanguages: hidden,
          strictHome: strictHome,
          seen: const {},
          random: random,
          source: 'charts:trending',
        )
        .items
        .where((item) => !refreshExcluded.contains(item.id));
    final trending = trendingWithSeenFallback(rankedTrending, seen);
    dev.log(
      'Home stages: fetched=${sources.fold<int>(0, (n, s) => n + s.fetchedCount)} '
      'after_filter=${sources.fold<int>(0, (n, s) => n + s.filteredCount)} '
      'shown=${videos.length} trending=${trending.length} chip=$chip',
      name: 'HomeController',
    );
    if (token.isCancelled) throw StateError('Home request cancelled');
    for (final source in sources) {
      if (source.error != null) errors.add('Feed');
    }
    if (videos.isEmpty && trending.isEmpty && errors.isNotEmpty) {
      throw StateError('Could not load Home');
    }
    if (!token.isCancelled) {
      _mixersByChip[chip] = mixer;
      if (identical(token, _token)) _mixer = mixer;
    }
    seen.mark([...videos.map((v) => v.id), ...trending.map((v) => v.id)], now);
    await db.setValue(homeSeenKey(settings, chip: chip), seen.encode());
    final result = HomeData(
      videos: videos,
      chip: chip,
      trending: chip == 'All' ? trending : const [],
      continuations: mixer.hasMore ? const {'mixer': 'more'} : const {},
      errors: errors.toSet().toList(),
    );
    if (!token.isCancelled) _sessionDataByChip[chip] = result;
    await db.setValue(
      homeCacheKey(settings, chip: chip),
      HomeCache(videos, const [], DateTime.now()).encode(),
    );
    if (queries.isNotEmpty) {
      unawaited(
        _finishShortsLoad(
          chip: chip,
          token: token,
          pagesFuture: shortFuture,
          watched: watched,
          preferred: preferred,
          hidden: hidden,
          seen: seen,
          settings: settings,
          initial: result,
        ),
      );
    }
    return result;
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
    _sessionDataByChip.remove(chip);
    _mixersByChip.remove(chip);
    _tokensByChip.remove(chip)?.cancel();
    _refreshExcluded =
        state.value?.videos.take(10).map((v) => v.id).toSet() ?? {};
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
    final cached = _sessionDataByChip[chip];
    if (cached != null) {
      _debounce?.cancel();
      _generation++;
      _token = _tokensByChip[chip] ?? CancelToken();
      _mixer = _mixersByChip[chip];
      state = AsyncData(cached);
      return;
    }
    _debounce?.cancel();
    _generation++;
    _pendingFresh = [];
    _token = CancelToken();
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
      _sessionDataByChip[current.chip] = state.value!;
      final db = ref.read(dbProvider);
      final seen = SeenVideos.decode(
        await db.getValue(
          homeSeenKey(ref.read(contentPrefsProvider), chip: current.chip),
        ),
        DateTime.now(),
      );
      seen.mark(fresh.map((item) => item.id), DateTime.now());
      await db.setValue(
        homeSeenKey(ref.read(contentPrefsProvider), chip: current.chip),
        seen.encode(),
      );
    } catch (error, stackTrace) {
      dev.log(
        'Home pagination failed',
        name: 'HomeController',
        error: error,
        stackTrace: stackTrace,
      );
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
