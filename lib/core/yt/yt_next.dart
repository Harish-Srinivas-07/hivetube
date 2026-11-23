import 'package:dio/dio.dart';
import '../innertube/innertube_http.dart';
import 'models.dart';
import 'parser.dart';
import 'watch_info.dart';

class YtNext {
  YtNext(this.http);
  final InnertubeHttp http;
  final Map<String, Future<WatchInfo>> _watchCache = {};
  Future<WatchInfo> watch(String id) => _watchCache.putIfAbsent(id, () async {
    try {
      return parseWatchInfo(
        await http.post('next', {
          'videoId': id,
          'contentCheckOk': true,
          'racyCheckOk': true,
        }),
        id,
      );
    } catch (_) {
      _watchCache.remove(id);
      rethrow;
    }
  });
  Future<ShortItem?> ownerMetadata(
    String id, {
    CancelToken? cancelToken,
  }) async => parseShortMetadata(
    await http.post('next', {
      'videoId': id,
      'contentCheckOk': true,
      'racyCheckOk': true,
    }, cancelToken: cancelToken),
    id,
  );
  Future<VideoPage> related(
    String id, {
    String? continuation,
    CancelToken? cancelToken,
  }) async => parseVideos(
    await http.post(
      'next',
      continuation == null
          ? {'videoId': id, 'contentCheckOk': true, 'racyCheckOk': true}
          : {'continuation': continuation},
      cancelToken: cancelToken,
    ),
  );
}
