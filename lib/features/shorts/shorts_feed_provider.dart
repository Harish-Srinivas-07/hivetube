import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/playback/playback_service.dart';
import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/streams/stream_selector.dart';
import '../../core/db/history_entry.dart';
import '../../core/yt/models.dart';
import '../../widgets/logger.dart';
import '../home/home_variety.dart';
import '../home/home_shorts.dart';

class ShortsFeedState {
  const ShortsFeedState({
    this.items = const [],
    this.cursor,
    this.isLoading = false,
    this.hasLoaded = false,
  });

  final List<ShortItem> items;
  final String? cursor;
  final bool isLoading;
  final bool hasLoaded;
}

final shortsFeedProvider =
    NotifierProvider<ShortsFeedController, ShortsFeedState>(
      ShortsFeedController.new,
    );

class ShortsFeedController extends Notifier<ShortsFeedState> {
  Future<void>? _inFlight;
  int _generation = 0;
  PlaybackService? _warmedService;
  String _warmedIds = '';
  bool _retryAfterFlight = false;
  int _warmStartIndex = 0;
  Future<void> _warmTask = Future<void>.value();

  @override
  ShortsFeedState build() {
    ref.listen(contentPrefsProvider, (previous, next) {
      if (previous != null && previous.prefsVersion != next.prefsVersion) {
        clear();
      }
    });
    ref.listen(playbackProvider, (_, service) {
      if (service != null) _warmFirstWindow(service);
    });
    ref.onDispose(() {
      _warmedService?.cancelShortPreloads(disposePlayer: true);
    });
    return const ShortsFeedState();
  }

  void seed(List<ShortItem> items) {
    if (items.isEmpty || state.items.isNotEmpty) return;
    _warmStartIndex = 0;
    state = ShortsFeedState(
      items: List.unmodifiable(items),
      isLoading: state.isLoading,
      hasLoaded: state.hasLoaded,
    );
    _warmFirstWindow(ref.read(playbackProvider));
  }

  void adoptSelection(List<ShortItem> items, {int startIndex = 0}) {
    if (items.isEmpty) return;
    _warmStartIndex = startIndex;
    if (_sameItems(state.items, items)) {
      _warmFirstWindow(ref.read(playbackProvider));
      return;
    }
    state = ShortsFeedState(
      items: List.unmodifiable(items),
      isLoading: state.isLoading,
      hasLoaded: false,
    );
    _warmedIds = '';
    _warmFirstWindow(ref.read(playbackProvider));
  }

  Future<void> prefetch({List<ShortItem> seedItems = const []}) async {
    seed(seedItems);
    final started = Stopwatch()..start();
    Logger.log(
      'ShortsPrefetch',
      'start items=${state.items.length} ms=${started.elapsedMilliseconds}',
    );
    await _startFetch(cursor: null, merge: true);
    try {
      await _warmTask;
    } catch (_) {}
    Logger.log(
      'ShortsPrefetch',
      'done items=${state.items.length} ms=${started.elapsedMilliseconds}',
    );
  }

  Future<void> loadInitial({bool refresh = false}) {
    if (!refresh && state.items.isNotEmpty) return Future<void>.value();
    return _startFetch(cursor: null, merge: true);
  }

  Future<void> loadMore() {
    if (_inFlight != null) return _inFlight!;
    if (state.cursor == null && state.hasLoaded) {
      return Future<void>.value();
    }
    return _startFetch(cursor: state.cursor, merge: true);
  }

  Future<void> refresh() => _startFetch(cursor: null, merge: true);

  void clear() {
    _generation++;
    _retryAfterFlight = _inFlight != null;
    state = const ShortsFeedState();
    _warmedIds = '';
    _warmStartIndex = 0;
    _warmedService?.cancelShortPreloads(disposePlayer: true);
    _warmedService = null;
  }

  void releaseWarmWindow() {
    _warmedIds = '';
    _warmedService?.cancelShortPreloads(disposePlayer: true);
    _warmedService = null;
  }

  void prepareCachedWindow({int startIndex = 0}) {
    _warmStartIndex = startIndex;
    _warmFirstWindow(ref.read(playbackProvider));
  }

  Future<void> _startFetch({required String? cursor, required bool merge}) {
    final pending = _inFlight;
    if (pending != null) {
      if (!_retryAfterFlight) return pending;
      _retryAfterFlight = false;
      return pending.then((_) => _startFetch(cursor: cursor, merge: merge));
    }

    final requestGeneration = ++_generation;
    state = ShortsFeedState(
      items: state.items,
      cursor: state.cursor,
      isLoading: true,
      hasLoaded: state.hasLoaded,
    );

    late final Future<void> task;
    task = _fetch(cursor: cursor, merge: merge, generation: requestGeneration)
        .whenComplete(() {
          if (identical(_inFlight, task)) _inFlight = null;
        });
    _inFlight = task;
    return task;
  }

  Future<void> _fetch({
    required String? cursor,
    required bool merge,
    required int generation,
  }) async {
    try {
      final api = await ref.read(ytApiProvider.future);
      final prefs = ref.read(contentPrefsProvider);
      final historyFuture = cursor == null
          ? ref.read(historyRepoProvider).recent()
          : Future.value(const <HistoryEntry>[]);
      final pageFuture = api.reel.fetch(continuation: cursor, count: 24);
      final history = await historyFuture;
      final page = await pageFuture;
      final regional = <ShortItem>[];
      if (cursor == null) {
        final queries = shortsQueries(
          chip: 'All',
          channels: const [],
          random: Random(DateTime.now().microsecondsSinceEpoch ^ generation),
          localRatio: prefs.localRatio,
          shownLanguages: prefs.contentLanguages,
          hasHistory: history.isNotEmpty,
        );
        final pages = await Future.wait(
          queries.map((query) async {
            try {
              return await api.search.shortsPage(query);
            } catch (_) {
              return const ShortPage([], null);
            }
          }),
        );
        regional.addAll(pages.expand((result) => result.items).take(36));
      }

      final candidates = <String, ShortItem>{};
      for (final item in [...regional, ...page.items]) {
        candidates.putIfAbsent(item.id, () => item);
      }
      final enriched = await Future.wait(
        candidates.values.take(60).map((item) async {
          try {
            final metadata = await api.reel.metadata(item.id);
            if (metadata == null) return item;
            return ShortItem(
              id: item.id,
              thumbUrl: item.thumbUrl,
              title: item.title ?? metadata.title,
              channelName: metadata.channelName,
              channelId: metadata.channelId,
              channelAvatarUrl: metadata.channelAvatarUrl,
              viewsText: item.viewsText ?? metadata.viewsText,
            );
          } catch (_) {
            return item;
          }
        }),
      );
      final seen = SeenVideos.decode(
        await ref.read(dbProvider).getValue('home_seen_videos_v1'),
        DateTime.now(),
      );
      final rankedIds = rankHomeItems(
        [
          for (final item in enriched)
            VideoItem(
              id: item.id,
              title: item.title ?? '',
              channelId: item.channelId ?? '',
              channelName: item.channelName ?? '',
              channelAvatarUrl: item.channelAvatarUrl ?? '',
              thumbUrl: item.thumbUrl,
              isShort: true,
            ),
        ],
        preferred: prefs.contentLanguages,
        hidden: prefs.hiddenLanguages,
        seen: seen.ids,
        random: Random(prefs.prefsVersion ^ generation),
      ).map((item) => item.id).toList();
      final byId = {for (final item in enriched) item.id: item};
      final filteredItems = rankedIds.map((id) => byId[id]!).toList();
      if (generation != _generation) return;

      final existing = merge ? state.items : const <ShortItem>[];
      final existingIds = existing.map((item) => item.id).toSet();
      final nextItems = [
        ...existing,
        ...filteredItems.where((item) => existingIds.add(item.id)),
      ];
      state = ShortsFeedState(
        items: List.unmodifiable(nextItems),
        cursor: page.continuation,
        isLoading: false,
        hasLoaded: true,
      );
      _warmFirstWindow(ref.read(playbackProvider));
    } catch (_) {
      if (generation != _generation) return;
      state = ShortsFeedState(
        items: state.items,
        cursor: state.cursor,
        isLoading: false,
        hasLoaded: true,
      );
    }
  }

  void _warmFirstWindow(PlaybackService? service) {
    _warmWindow(service, state.items, _warmStartIndex);
  }

  void _warmWindow(
    PlaybackService? service,
    List<ShortItem> items,
    int startIndex,
  ) {
    if (service == null || items.isEmpty || startIndex >= items.length) return;
    final firstItems = items.skip(startIndex).take(3).toList(growable: false);
    final ids = firstItems.map((item) => item.id).join('|');
    if (identical(service, _warmedService) && ids == _warmedIds) return;
    _warmedService = service;
    _warmedIds = ids;
    final cycle = service.beginShortPreloadCycle();
    _warmTask = Future.wait([
      for (final item in firstItems)
        service.preResolve(item.id, PlaybackMode.short, generation: cycle),
      service.preloadShort(firstItems.first.id, generation: cycle),
    ]).then<void>((_) {});
  }

  bool _sameItems(List<ShortItem> left, List<ShortItem> right) =>
      left.length == right.length &&
      List.generate(
        left.length,
        (index) => left[index].id == right[index].id,
      ).every((same) => same);
}
