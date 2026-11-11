import 'package:dio/dio.dart';
import '../innertube/innertube_http.dart';
import 'models.dart';
import 'parser.dart';

class YtBrowse {
  YtBrowse(this.http);
  final InnertubeHttp http;
  Future<List<ShortItem>> channelShorts(
    String channelId, {
    String? continuation,
    CancelToken? cancelToken,
  }) async => parseShorts(
    await http.post(
      'browse',
      continuation == null
          ? {'browseId': channelId, 'params': 'EgZzaG9ydHPyBgUKA5oBAA%3D%3D'}
          : {'continuation': continuation},
      cancelToken: cancelToken,
    ),
  );
  Future<VideoPage> home({String? continuation, CancelToken? cancelToken}) =>
      _browse('FEwhat_to_watch', null, continuation, cancelToken);
  Future<VideoPage> live({String? continuation, CancelToken? cancelToken}) =>
      _browse(
        'UC4R8DWoMoI7CAwX8_LjQHig',
        'EgdsaXZldGFikgEDCKEK',
        continuation,
        cancelToken,
      );
  Future<VideoPage> gaming({String? continuation, CancelToken? cancelToken}) =>
      _browse(
        'UCOpNcN46UbXVtpKMrmU4Abg',
        'Egh0cmVuZGluZw%3D%3D',
        continuation,
        cancelToken,
      );
  Future<VideoPage> podcasts({
    String? continuation,
    CancelToken? cancelToken,
  }) => _browse(
    'FEpodcasts_destination',
    'qgcCCAM%3D',
    continuation,
    cancelToken,
  );
  Future<VideoPage> _browse(
    String id,
    String? params,
    String? continuation,
    CancelToken? cancelToken,
  ) async => parseVideos(
    await http.post(
      'browse',
      continuation == null
          ? {'browseId': id, 'params': ?params}
          : {'continuation': continuation},
      cancelToken: cancelToken,
    ),
  );
}
