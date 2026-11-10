import 'package:dio/dio.dart';
import '../innertube/innertube_http.dart';
import 'models.dart';
import 'parser.dart';

class YtNext {
  YtNext(this.http);
  final InnertubeHttp http;
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
