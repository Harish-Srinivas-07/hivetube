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
  HomeSource({
    required this.weight,
    required this.fetch,
    this.transform,
    this.name = '',
    this.isRelated = false,
  });

  final int weight;
  final Future<VideoPage> Function(String? cursor) fetch;
  final FutureOr<List<VideoItem>> Function(List<VideoItem>)? transform;
  final String name;
  final bool isRelated;
  final List<VideoItem> _buffer = [];
  final Set<String> _seenIds = {};
  final Set<String> _seenCursors = {};
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
        if (_cursor != null && !_seenCursors.add(_cursor!)) {
          done = true;
          break;
        }
        final page = await fetch(_cursor);
        final oldCursor = _cursor;
        _cursor = page.continuation;
        fetchedCount += page.items.length;
        if (page.items.isEmpty) {
          done = true;
          break;
        }
        final freshItems =
            page.items.where((item) => _seenIds.add(item.id)).toList();
        final transformed = await (transform?.call(freshItems) ?? freshItems);
        filteredCount += transformed.length;
        _buffer.addAll(transformed);
        dev.log(
          '[HomeSource $name] page=$pages items=${page.items.length} fresh=${freshItems.length} kept=${transformed.length} buffer=${_buffer.length}',
        );
        if (_cursor == null || (_started && _cursor == oldCursor)) done = true;
        _started = true;
        pages++;
      } while (_buffer.length < 20 && !done && pages <= 3);
    } catch (error, stackTrace) {
      dev.log(
        '[HomeSource $name] fetch failed',
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
    final channelCounts = <String, int>{};
    var relatedCount = 0;
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

      var progressed = false;
      for (final source in sources) {
        final deferred = <VideoItem>[];
        var yieldedForSource = 0;

        while (source._buffer.isNotEmpty &&
            yieldedForSource < source.weight &&
            result.length < count) {
          final item = source._buffer.removeAt(0);
          if (item.isShort || _seen.contains(item.id)) {
            continue;
          }

          // Cap watch_related to <= 25% of total page results
          if (source.isRelated &&
              result.length >= 4 &&
              (relatedCount + 1) / (result.length + 1) > 0.25) {
            deferred.add(item);
            continue;
          }

          // Cap max 2 items per channel per page
          final channelKey = item.channelId.isNotEmpty
              ? item.channelId
              : item.channelName.toLowerCase().trim();
          if (channelKey.isNotEmpty && (channelCounts[channelKey] ?? 0) >= 2) {
            deferred.add(item);
            continue;
          }

          _seen.add(item.id);
          result.add(item);
          yieldedForSource++;
          progressed = true;
          if (source.isRelated) relatedCount++;
          if (channelKey.isNotEmpty) {
            channelCounts[channelKey] = (channelCounts[channelKey] ?? 0) + 1;
          }
        }

        if (deferred.isNotEmpty) {
          source._buffer.insertAll(0, deferred);
        }
      }

      if (!progressed) {
        var unblocked = false;
        for (final source in sources) {
          if (source._buffer.isNotEmpty && result.length < count) {
            final item = source._buffer.removeAt(0);
            if (!item.isShort && _seen.add(item.id)) {
              result.add(item);
              if (source.isRelated) relatedCount++;
              unblocked = true;
              break;
            }
          }
        }
        if (!unblocked) {
          final hasPending = sources.any((s) => !s.done);
          if (!hasPending) break;
          for (final source in sources.where((s) => !s.done)) {
            unawaited(source.ensure());
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    }
    return result;
  }
}
