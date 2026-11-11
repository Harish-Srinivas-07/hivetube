import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/yt/models.dart';
import 'home_cache.dart';
import 'home_mixer.dart';
import 'home_guards.dart';

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
  @override
  FutureOr<HomeData> build() {
    if (_token.isCancelled) _token = CancelToken();
    final buildToken = _token;
    ref.onDispose(() {
      _debounce?.cancel();
      buildToken.cancel();
    });
    final settings = ref.watch(
      appSettingsProvider.select(
        (s) => (
          cacheKey: s.cacheKey,
          localContent: s.localContent,
          revision: s.revision,
        ),
      ),
    );
    final initial = ref.read(initialAppSettingsProvider);
    final cache =
        settings.cacheKey == initial.cacheKey &&
            settings.localContent == initial.localContent &&
            settings.revision == 0
        ? ref.read(initialHomeCacheProvider)
        : null;
    if (cache != null) {
      Future<void>(() => _backgroundRefresh());
      return HomeData(videos: cache.videos, shorts: cache.shorts);
    }
    return _fetch('All', _token);
  }

  void interact() {
    _refreshGuard.interact();
  }

  Future<void> _backgroundRefresh() async {
    final generation = _generation;
    try {
      final fresh = await _fetch('All', _token);
      if (_refreshGuard.canApply && generation == _generation) {
        state = AsyncData(fresh);
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
        if (cached == null ||
            now.difference(cached.fetched) >= const Duration(minutes: 30)) {
          try {
            cached = (
              fetched: now,
              items: await api.rss.uploads(id, cancelToken: token),
            );
            _rssCache[id] = cached;
          } catch (_) {
            if (!token.isCancelled) {
              errors.add('Subscriptions');
              cached = (fetched: now, items: cached?.items ?? <VideoItem>[]);
              _rssCache[id] = cached;
            }
          }
        }
        if (cached != null) items.addAll(cached.items);
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
    if (token.isCancelled) {
      throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.cancel,
      );
    }
    final errors = <String>[];
    Future<T?> isolate<T>(String name, Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        if (token.isCancelled) rethrow;
        errors.add(name);
        return null;
      }
    }

    final settings = ref.read(appSettingsProvider);
    if (api.search.http.hl != settings.hl ||
        api.search.http.gl != settings.gl) {
      throw StateError('Regional session changed');
    }
    final history = await ref.read(historyRepoProvider).recent();
    final disliked = await ref.read(historyRepoProvider).dislikedChannels();
    final channels = await ref.read(subscriptionRepoProvider).channelIds();
    final watchedIds = history.map((e) => e.videoId).toSet();
    final uploadsFuture = _subscriptions(
      api,
      channels,
      token,
      errors,
    ).then((items) => items.where((v) => !watchedIds.contains(v.id)).toList());
    if (chip == 'Recently uploaded') {
      return HomeData(chip: chip, videos: await uploadsFuture, errors: errors);
    }
    const topics = <String, String>{
      'Music': 'music',
      'Gaming': 'gaming',
      'Live': 'live',
      'News': 'news today',
      'Podcasts': 'podcast',
      'Sports': 'sports highlights',
      'Comedy': 'comedy',
      'Cooking': 'cooking recipes',
      'Science': 'science',
    };
    final selectedTopics = chip == 'All'
        ? topics.entries.toList()
        : topics.entries.where((e) => e.key == chip).toList();
    final queries = <({String query, bool live, bool regional})>[];
    for (final topic in selectedTopics) {
      final variants = regionalQueries(topic.value, settings);
      for (var i = 0; i < variants.length; i++) {
        queries.add((
          query: variants[i],
          live: topic.key == 'Live',
          regional: variants.length > 1 && i == 0,
        ));
      }
    }
    final feedFuture = chip == 'All'
        ? isolate('Home', () => api.browse.home(cancelToken: token))
        : Future<VideoPage?>.value(null);
    final chartsFuture = chip == 'All'
        ? isolate(
            'Trending',
            () => api.charts.trending(settings.gl, cancelToken: token),
          )
        : Future<List<VideoItem>?>.value(null);
    final kioskFuture = chip == 'All'
        ? Future.wait([
            isolate('Live', () => api.browse.live(cancelToken: token)),
            isolate('Gaming', () => api.browse.gaming(cancelToken: token)),
            isolate('Podcasts', () => api.browse.podcasts(cancelToken: token)),
          ])
        : Future<List<VideoPage?>>.value([]);
    final pagesFuture = Future.wait(
      queries.map(
        (q) => isolate(
          q.query,
          () => api.search.videos(
            q.query,
            params: q.live ? 'EgJAAQ%3D%3D' : null,
            cancelToken: token,
          ),
        ),
      ),
    );
    final shortsFuture = Future.wait(
      queries.map(
        (q) => isolate(
          'Shorts',
          () => api.search.shorts(q.query, cancelToken: token),
        ),
      ),
    );
    final relatedFuture = chip == 'All'
        ? Future.wait(
            history
                .take(6)
                .map(
                  (h) => isolate(
                    'Related',
                    () => api.next.related(h.videoId, cancelToken: token),
                  ),
                ),
          )
        : Future<List<VideoPage?>>.value([]);
    final feed = await feedFuture;
    final trending = await chartsFuture ?? <VideoItem>[];
    final pages = await pagesFuture;
    final shortPages = await shortsFuture;
    final relatedPages = await relatedFuture;
    final kioskPages = await kioskFuture;
    final uploads = await uploadsFuture;
    final personal = channels.isNotEmpty || history.isNotEmpty;
    final sources = <List<VideoItem>>[
      for (final page in relatedPages) page?.items ?? [],
      if (chip == 'All') uploads,
      for (final page in kioskPages) page?.items ?? [],
      for (final page in pages) page?.items ?? [],
    ];
    final weights = <int>[
      for (final _ in relatedPages) 2,
      if (chip == 'All') 2,
      for (final _ in kioskPages) 1,
      for (final _ in queries) personal ? 1 : 2,
    ];
    // Plain English remains a weight-one secondary source when a regional query exists.
    for (var i = 0; i < queries.length; i++) {
      if (!queries[i].regional && i > 0 && queries[i - 1].regional) {
        weights[relatedPages.length +
                (chip == 'All' ? 1 : 0) +
                kioskPages.length +
                i] =
            1;
      }
    }
    final mixed = mixHome(
      sources,
      weights,
      history: history,
      disliked: disliked,
    );
    final videos = mixHome(
      [feed?.items ?? [], mixed],
      [feed?.items.length ?? 0, mixed.length],
      history: history,
      disliked: disliked,
    );
    final shortSeen = <String>{};
    final shorts = <ShortItem>[
      for (final page in shortPages)
        for (final item in page ?? <ShortItem>[])
          if (!watchedIds.contains(item.id) && shortSeen.add(item.id)) item,
    ];
    final cursors = <String, String>{};
    for (var i = 0; i < queries.length; i++) {
      if (pages[i]?.continuation != null) {
        cursors['${queries[i].live ? 'liveSearch' : 'search'}:${queries[i].query}'] =
            pages[i]!.continuation!;
      }
    }
    for (var i = 0; i < relatedPages.length; i++) {
      if (relatedPages[i]?.continuation != null) {
        cursors['related:${history[i].videoId}'] =
            relatedPages[i]!.continuation!;
      }
    }
    for (var i = 0; i < kioskPages.length; i++) {
      if (kioskPages[i]?.continuation != null) {
        cursors[['Live', 'Gaming', 'Podcasts'][i]] =
            kioskPages[i]!.continuation!;
      }
    }
    if (token.isCancelled) throw StateError('Home request cancelled');
    if (feed?.continuation != null) cursors['home'] = feed!.continuation!;
    if (videos.isEmpty &&
        shorts.isEmpty &&
        trending.isEmpty &&
        errors.isNotEmpty) {
      throw StateError('Could not load Home');
    }
    if (chip == 'All') {
      await ref
          .read(dbProvider)
          .setValue(
            homeCacheKey(settings),
            HomeCache(videos, shorts, DateTime.now()).encode(),
          );
    }
    return HomeData(
      videos: videos,
      shorts: shorts,
      chip: chip,
      trending: trending,
      continuations: cursors,
      errors: errors.toSet().toList(),
    );
  }

  Future<VideoPage> _page(
    YtApi api,
    String source,
    CancelToken token, [
    String? cursor,
  ]) => switch (source) {
    'home' => api.browse.home(continuation: cursor, cancelToken: token),
    _ when source.startsWith('liveSearch:') => api.search.videos(
      source.substring(11),
      params: 'EgJAAQ%3D%3D',
      continuation: cursor,
      cancelToken: token,
    ),
    _ when source.startsWith('search:') => api.search.videos(
      source.substring(7),
      continuation: cursor,
      cancelToken: token,
    ),
    'Live' => api.browse.live(continuation: cursor, cancelToken: token),
    'Gaming' => api.browse.gaming(continuation: cursor, cancelToken: token),
    'Podcasts' => api.browse.podcasts(continuation: cursor, cancelToken: token),
    _ when source.startsWith('topic:') => api.search.videos(
      source.substring(6),
      continuation: cursor,
      cancelToken: token,
    ),
    _ when source.startsWith('related:') => api.next.related(
      source.substring(8),
      continuation: cursor,
      cancelToken: token,
    ),
    _ => api.search.videos(source, continuation: cursor, cancelToken: token),
  };
  void _cancel() {
    _token.cancel();
    _token = CancelToken();
    _generation++;
    _debounce?.cancel();
  }

  Future<void> refresh() async {
    final chip = state.value?.chip ?? 'All';
    _cancel();
    final generation = _generation;
    final token = _token;
    final result = await AsyncValue.guard(() => _fetch(chip, token));
    if (generation == _generation) state = result;
  }

  void select(String chip) {
    interact();
    _cancel();
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
      final api = await ref.read(ytApiProvider.future);
      final results = await Future.wait(
        current.continuations.entries.map(
          (e) async => (e.key, await _page(api, e.key, token, e.value)),
        ),
      );
      if (generation != _generation) return;
      final history = await ref.read(historyRepoProvider).recent();
      final disliked = await ref.read(historyRepoProvider).dislikedChannels();
      final fresh = mixHome(
        results.map((e) => e.$2.items).toList(),
        results.map((_) => 1).toList(),
        history: history,
        disliked: disliked,
      );
      final seen = current.videos.map((v) => v.id).toSet();
      state = AsyncData(
        current.copy(
          videos: [...current.videos, ...fresh.where((v) => seen.add(v.id))],
          continuations: {
            for (final result in results)
              if (result.$2.continuation != null &&
                  result.$2.continuation != current.continuations[result.$1])
                result.$1: result.$2.continuation!,
          },
          loadingMore: false,
        ),
      );
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
