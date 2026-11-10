import '../innertube/innertube_http.dart';
import 'models.dart';
import 'parser.dart';

class YtBrowse {
  YtBrowse(this.http);
  final InnertubeHttp http;
  Future<VideoPage> home({String? continuation}) =>
      _browse('FEwhat_to_watch', null, continuation);
  Future<VideoPage> live({String? continuation}) =>
      _browse('UC4R8DWoMoI7CAwX8_LjQHig', 'EgdsaXZldGFikgEDCKEK', continuation);
  Future<VideoPage> gaming({String? continuation}) =>
      _browse('UCOpNcN46UbXVtpKMrmU4Abg', 'Egh0cmVuZGluZw%3D%3D', continuation);
  Future<VideoPage> podcasts({String? continuation}) =>
      _browse('FEpodcasts_destination', 'qgcCCAM%3D', continuation);
  Future<VideoPage> _browse(
    String id,
    String? params,
    String? continuation,
  ) async => parseVideos(
    await http.post(
      'browse',
      continuation == null
          ? {'browseId': id, 'params': ?params}
          : {'continuation': continuation},
    ),
  );
}
