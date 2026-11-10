import 'dart:async';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
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
    ref.onDispose(() {
      _debounce?.cancel();
      _token.cancel();
    });
    final cache = ref.read(initialHomeCacheProvider);
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

    if (chip != 'All') {
      final page = await isolate(chip, () => _page(api, chip, token));
      return HomeData(
        chip: chip,
        videos: page?.items ?? [],
        continuations: {
          if (page?.continuation != null) chip: page!.continuation!,
        },
        errors: errors,
      );
    }
    final history = await ref.read(historyRepoProvider).recent();
    final disliked = await ref.read(historyRepoProvider).dislikedChannels();
    final channels = await ref.read(subscriptionRepoProvider).channelIds();
    final country = ui.PlatformDispatcher.instance.locale.countryCode ?? 'US';
    final topics = ['Music', 'Gaming', 'Live', 'News'];
    final watchedIds = history.map((e) => e.videoId).toSet();
    final results = await Future.wait<dynamic>([
      isolate('Home', () => api.browse.home(cancelToken: token)),
      isolate(
        'Trending',
        () => api.charts.trending(country, cancelToken: token),
      ),
      isolate('Shorts', () => api.reel.shorts(cancelToken: token)),
      isolate(
        'Subscriptions',
        () => _subscriptions(api, channels, token, errors),
      ),
      ...topics.map(
        (q) => isolate(q, () => api.search.videos(q, cancelToken: token)),
      ),
      ...history
          .take(6)
          .map(
            (h) => isolate(
              'Related',
              () => api.next.related(h.videoId, cancelToken: token),
            ),
          ),
    ]);
    final feed = results[0] as VideoPage?;
    final trending = results[1] as List<VideoItem>? ?? [];
    final shorts = results[2] as List<ShortItem>? ?? [];
    final uploads = (results[3] as List<VideoItem>? ?? [])
        .where((v) => !watchedIds.contains(v.id))
        .toList();
    final topicPages = results.skip(4).take(4).toList();
    final relatedPages = results.skip(8).toList();
    final related = relatedPages
        .whereType<VideoPage>()
        .map((e) => e.items)
        .toList();
    final topicItems = topicPages
        .whereType<VideoPage>()
        .map((e) => e.items)
        .toList();
    final personal = channels.isNotEmpty || history.isNotEmpty;
    final mixed = mixHome(
      [...related, uploads, ...topicItems],
      [...related.map((_) => 2), 2, ...topicItems.map((_) => personal ? 1 : 2)],
      history: history,
      disliked: disliked,
    );
    final videos = mixHome(
      [feed?.items ?? [], mixed],
      [feed?.items.length ?? 0, mixed.length],
      history: history,
      disliked: disliked,
    );
    final cursors = <String, String>{};
    for (var i = 0; i < topics.length; i++) {
      final page = topicPages[i];
      if (page is VideoPage && page.continuation != null) {
        cursors['topic:${topics[i]}'] = page.continuation!;
      }
    }
    for (var i = 0; i < relatedPages.length; i++) {
      final page = relatedPages[i];
      if (page is VideoPage && page.continuation != null) {
        cursors['related:${history[i].videoId}'] = page.continuation!;
      }
    }
    if (feed?.continuation != null) cursors['home'] = feed!.continuation!;
    if (videos.isEmpty &&
        shorts.isEmpty &&
        trending.isEmpty &&
        errors.isNotEmpty) {
      throw StateError('Could not load Home');
    }
    await ref
        .read(dbProvider)
        .setValue(
          'home_cache',
          HomeCache(videos, shorts, DateTime.now()).encode(),
        );
    return HomeData(
      videos: videos,
      shorts: shorts,
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
