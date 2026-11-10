import 'package:dio/dio.dart';
import '../innertube/innertube_http.dart';
import 'models.dart';
import 'parser.dart';

class YtSearch {
  YtSearch(this.http);
  final InnertubeHttp http;
  Future<VideoPage> videos(
    String query, {
    String? continuation,
    CancelToken? cancelToken,
  }) async => parseVideos(
    await http.post(
      'search',
      continuation == null
          ? {'query': query, 'params': 'EgIQAfABAQ%3D%3D'}
          : {'continuation': continuation},
      cancelToken: cancelToken,
    ),
  );
}
