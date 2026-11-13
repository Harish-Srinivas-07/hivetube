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
        _buffer.addAll(transform?.call(page.items) ?? page.items);
        if (_cursor == null || (_started && _cursor == oldCursor)) done = true;
        _started = true;
        pages++;
      } while (_buffer.length < 20 && !done && pages <= 3);
    } catch (e) {
      error = e;
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
  Future<void> start() => Future.wait(sources.map((s) => s.ensure()));

  Future<List<VideoItem>> next(int count) async {
    final result = <VideoItem>[];
    var stalled = 0;
    while (result.length < count && hasMore && stalled < 3) {
      final before = result.length;
      await Future.wait(sources.map((s) => s.ensure()));
      for (final source in sources) {
        for (var n = 0; n < source.weight && result.length < count; n++) {
          if (source._buffer.isEmpty) break;
          final item = source._buffer.removeAt(0);
          if (!item.isShort && _seen.add(item.id)) {
            result.add(item);
          }
        }
      }
      stalled = result.length == before ? stalled + 1 : 0;
    }
    return result;
  }
}
