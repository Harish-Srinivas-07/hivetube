import 'dart:developer' as dev;
import 'dart:async';
import '../../core/yt/models.dart';

List<VideoItem> mixHome(List<List<VideoItem>> sources, List<int> weights) {
  final indexes = List<int>.filled(sources.length, 0);
  final seen = <String>{};
  final result = <VideoItem>[];
  var progressed = true;
  while (progressed) {
    progressed = false;
    for (var i = 0; i < sources.length; i++) {
      for (var n = 0; n < weights[i] && indexes[i] < sources[i].length; n++) {
        final item = sources[i][indexes[i]++];
        progressed = true;
        if (!item.isShort && seen.add(item.id)) {
          result.add(item);
        }
      }
    }
  }
  return result;
}

/// A paged source owns its cursor, buffer and failure state.
class HomeSource {
  HomeSource({required this.weight, required this.fetch, this.transform});
  final int weight;
  final Future<VideoPage> Function(String? cursor) fetch;
  final List<VideoItem> Function(List<VideoItem>)? transform;
  final List<VideoItem> _buffer = [];
  int fetchedCount = 0;
  int filteredCount = 0;
  bool done = false;
  bool _started = false;
  String? _cursor;
  Object? error;
  Future<void>? _pending;

  Future<void> ensure() {
    if (_buffer.isNotEmpty || done) return Future.value();
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<void> _load() async {
    try {
      var pages = 0;
      do {
        final page = await fetch(_cursor);
        final oldCursor = _cursor;
        _cursor = page.continuation;
        fetchedCount += page.items.length;
        final transformed = transform?.call(page.items) ?? page.items;
        filteredCount += transformed.length;
        _buffer.addAll(transformed);
        dev.log(
          '[HomeSource] page=$pages items=${page.items.length} kept=${transformed.length} buffer=${_buffer.length}',
        );
        if (_cursor == null || (_started && _cursor == oldCursor)) done = true;
        _started = true;
        pages++;
      } while (_buffer.length < 20 && !done && pages <= 3);
    } catch (error, stackTrace) {
      dev.log(
        '[HomeSource] fetch failed',
        name: 'HomeMixer',
        error: error,
        stackTrace: stackTrace,
      );
      this.error = error;
      done = true;
    }
  }
}

class HomeMixer {
  HomeMixer(this.sources);
  final List<HomeSource> sources;
  final Set<String> _seen = {};
  bool get hasMore => sources.any((s) => s._buffer.isNotEmpty || !s.done);
  void exclude(Iterable<String> ids) => _seen.addAll(ids);
  Future<void> start() async {
    // Start every source together, but don't make the first screen wait for
    // the slowest source (RSS subscriptions can be numerous or unavailable).
    for (final source in sources) {
      unawaited(source.ensure());
    }
  }

  Future<List<VideoItem>> next(
    int count, {
    Duration waitTimeout = const Duration(seconds: 8),
  }) async {
    final result = <VideoItem>[];
    final stopwatch = Stopwatch()..start();
    while (result.length < count && hasMore) {
      final ready = sources.any((source) => source._buffer.isNotEmpty);
      if (!ready) {
        final pending = sources
            .where((source) => !source.done)
            .map((source) => source.ensure())
            .toList();
        if (pending.isEmpty) break;
        final remaining = waitTimeout - stopwatch.elapsed;
        if (remaining <= Duration.zero) break;
        await Future.any<void>([
          Future.any<void>(pending),
          Future<void>.delayed(remaining),
        ]);
        if (!sources.any((source) => source._buffer.isNotEmpty) &&
            stopwatch.elapsed >= waitTimeout) {
          break;
        }
      }
      for (final source in sources) {
        for (var n = 0; n < source.weight && result.length < count; n++) {
          if (source._buffer.isEmpty) break;
          final item = source._buffer.removeAt(0);
          if (!item.isShort && _seen.add(item.id)) {
            result.add(item);
          }
        }
      }
    }
    return result;
  }
}
