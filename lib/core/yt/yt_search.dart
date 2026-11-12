import 'package:dio/dio.dart';
import '../innertube/continuation.dart';
import '../innertube/innertube_http.dart';
import 'models.dart';
import 'parser.dart';

class YtSearch {
  YtSearch(this.http);
  final InnertubeHttp http;
  Future<List<String>> suggestions(String query) async {
    final response = await http.dio.get<dynamic>(
      'https://suggestqueries.google.com/complete/search',
      queryParameters: {
        'client': 'firefox',
        'ds': 'yt',
        'q': query,
        'hl': http.hl,
        'gl': http.gl,
      },
    );
    final data = response.data;
    return data is List && data.length > 1 && data[1] is List
        ? (data[1] as List).whereType<String>().toList()
        : [];
  }

  Future<List<ShortItem>> shorts(
    String query, {
    String? continuation,
    CancelToken? cancelToken,
  }) async => (await shortsPage(
    query,
    continuation: continuation,
    cancelToken: cancelToken,
  )).items;

  Future<ShortPage> shortsPage(
    String query, {
    String? continuation,
    CancelToken? cancelToken,
  }) async {
    final json = await http.post(
      'search',
      continuation == null
          ? {'query': query, 'params': 'EgIQCQ%3D%3D'}
          : {'continuation': continuation},
      cancelToken: cancelToken,
    );
    return ShortPage(parseShorts(json), continuationToken(json));
  }

  Future<VideoPage> videos(
    String query, {
    String? continuation,
    String? params,
    CancelToken? cancelToken,
  }) async => parseVideos(
    await http.post(
      'search',
      continuation == null
          ? {'query': query, 'params': params ?? 'EgIQAfABAQ%3D%3D'}
          : {'continuation': continuation},
      cancelToken: cancelToken,
    ),
  );
}
