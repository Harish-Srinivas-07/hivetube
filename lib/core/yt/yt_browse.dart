import 'package:dio/dio.dart';
import '../innertube/innertube_http.dart';
import 'models.dart';
import 'parser.dart';

class YtBrowse {
  YtBrowse(this.http);
  final InnertubeHttp http;

  static const tabParamsVideos = 'EgZ2aWRlb3PyBgQKAjoA';
  static const tabParamsShorts = 'EgZzaG9ydHPyBgUKA5oBAA%3D%3D';
  static const tabParamsLive = 'EgdzdHJlYW1z8gYECgJ6AA%3D%3D';
  static const tabParamsReleases = 'EghyZWxlYXNlc_IGBQoDsgEA';
  static const tabParamsPlaylists = 'EglwbGF5bGlzdHPyBgQKAkIA';
  static const tabParamsPodcasts = 'Eghwb2RjYXN0c_IGBQoDugEA';

  static const tabParamsMap = {
    'Videos': tabParamsVideos,
    'Shorts': tabParamsShorts,
    'Live': tabParamsLive,
    'Releases': tabParamsReleases,
    'Playlists': tabParamsPlaylists,
    'Podcasts': tabParamsPodcasts,
  };
  Future<String> resolveUrl(String url, {CancelToken? cancelToken}) async {
    final json = await http.post('navigation/resolve_url', {
      'url': url,
    }, cancelToken: cancelToken);
    return parseBrowseIdFromResolve(json);
  }

  Future<ChannelPageData> channelPage(
    String channelId, {
    String? params,
    String? continuation,
    CancelToken? cancelToken,
  }) async {
    final json = await http.post(
      'browse',
      continuation == null
          ? {'browseId': channelId, 'params': ?params}
          : {'continuation': continuation},
      cancelToken: cancelToken,
    );
    return parseChannelPage(json, channelId);
  }

  Future<PlaylistPageData> playlistPage(
    String playlistId, {
    String? continuation,
    CancelToken? cancelToken,
  }) async {
    final browseId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
    final json = await http.post(
      'browse',
      continuation == null
          ? {'browseId': browseId}
          : {'continuation': continuation},
      cancelToken: cancelToken,
    );
    return parsePlaylistPage(json, playlistId);
  }

  Future<String> channelAvatar(
    String channelId, {
    CancelToken? cancelToken,
  }) async {
    final json = await http.post('browse', {
      'browseId': channelId,
    }, cancelToken: cancelToken);
    return parseChannelHeaderAvatar(json);
  }

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
  Future<VideoPage> channelVideos(
    String id, {
    String? continuation,
    CancelToken? cancelToken,
  }) => _browse(id, 'EgZ2aWRlb3PyBgQKAjoA', continuation, cancelToken);
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
