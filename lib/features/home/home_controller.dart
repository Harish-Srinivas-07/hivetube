import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/app_db.dart';
import '../../core/providers.dart';
import '../../core/yt/models.dart';
import 'home_cache.dart';
import 'home_mixer.dart';

class HomeData {
  const HomeData({
    this.videos = const [],
    this.shorts = const [],
    this.trending = const [],
    this.errors = const [],
    this.continuation,
    this.chip = 'All',
  });
  final List<VideoItem> videos, trending;
  final List<ShortItem> shorts;
  final List<String> errors;
  final String? continuation;
  final String chip;
}

final homeProvider = AsyncNotifierProvider<HomeController, HomeData>(
  HomeController.new,
);

class HomeController extends AsyncNotifier<HomeData> {
  bool touched = false;
  @override
  Future<HomeData> build() async {
    final db = ref.read(dbProvider);
    final cache = HomeCache.decode(
      await db.getValue('home_cache'),
      DateTime.now(),
    );
    if (cache != null) {
      Future(() => _refreshIfUntouched());
      return HomeData(videos: cache.videos, shorts: cache.shorts);
    }
    return _fetch();
  }

  Future<void> _refreshIfUntouched() async {
    try {
      final fresh = await _fetch();
      if (!touched) state = AsyncData(fresh);
    } catch (_) {
      /* keep cache */
    }
  }

  Future<HomeData> _fetch({String chip = 'All'}) async {
    final api = await ref.read(ytApiProvider.future);
    final errors = <String>[];
    Future<T?> isolate<T>(String name, Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        errors.add(name);
        return null;
      }
    }

    if (chip != 'All') {
      final result = await isolate(
        chip,
        () => switch (chip) {
          'Live' => api.browse.live(),
          'Gaming' => api.browse.gaming(),
          'Podcasts' => api.browse.podcasts(),
          _ => api.search.videos(chip),
        },
      );
      return HomeData(
        chip: chip,
        videos: result?.items ?? [],
        continuation: result?.continuation,
        errors: errors,
      );
    }
    final history = await EmptyHistoryRepo().recent();
    final disliked = await EmptyHistoryRepo().dislikedChannels();
    final country = ui.PlatformDispatcher.instance.locale.countryCode ?? 'US';
    final requests = await Future.wait<dynamic>([
      isolate('Home', () => api.browse.home()),
      isolate('Trending', () => api.charts.trending(country)),
      isolate('Shorts', () => api.reel.shorts()),
      ...[
        'Music',
        'Gaming',
        'Live',
        'News',
      ].map((topic) => isolate(topic, () => api.search.videos(topic))),
      ...history
          .take(6)
          .map(
            (entry) =>
                isolate('Related', () => api.next.related(entry.videoId)),
          ),
    ]);
    final feed = requests[0] as VideoPage?;
    final trending = requests[1] as List<VideoItem>? ?? [];
    final shorts = requests[2] as List<ShortItem>? ?? [];
    final topics = requests
        .skip(3)
        .take(4)
        .whereType<VideoPage>()
        .map((e) => e.items)
        .toList();
    final related = requests
        .skip(7)
        .whereType<VideoPage>()
        .map((e) => e.items)
        .toList();
    final videos = mixHome(
      [if (feed != null) feed.items, ...related, ...topics],
      [
        if (feed != null) 2,
        ...related.map((_) => 2),
        ...topics.map((_) => history.isEmpty ? 2 : 1),
      ],
      history: history,
      disliked: disliked,
    );
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
      errors: errors,
    );
  }

  Future<void> refresh() async {
    final chip = state.value?.chip ?? 'All';
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(chip: chip));
  }

  Future<void> select(String chip) async {
    touched = true;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(chip: chip));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.continuation == null) return;
    final api = await ref.read(ytApiProvider.future);
    final page = await switch (current.chip) {
      'Live' => api.browse.live(continuation: current.continuation),
      'Gaming' => api.browse.gaming(continuation: current.continuation),
      'Podcasts' => api.browse.podcasts(continuation: current.continuation),
      _ => api.search.videos(current.chip, continuation: current.continuation),
    };
    state = AsyncData(
      HomeData(
        chip: current.chip,
        videos: mixHome([current.videos, page.items], [1, 1]),
        continuation: page.continuation,
        errors: current.errors,
      ),
    );
  }
}
