import 'package:dio/dio.dart';
import 'clients.dart';

class InnertubeHttp {
  InnertubeHttp(this.dio, this.clients, {this.hl = 'en', this.gl = 'IN'});
  final String hl, gl;
  final Dio dio;
  final InnertubeClients clients;
  String? visitorData;
  Future<void> Function()? refreshVisitor;

  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data, {
    String clientName = 'WEB',
    bool refreshOnForbidden = true,
    CancelToken? cancelToken,
  }) async {
    final c = clients[clientName];
    final origin = c['origin'] as String;
    final context = buildClientContext(
      c,
      hl: hl,
      gl: gl,
      visitorData: visitorData,
    );
    final headers = {
      'Content-Type': 'application/json',
      'User-Agent': c['ua'] ?? clients['WEB']['ua'],
      'X-YouTube-Client-Name': c['id'],
      'X-YouTube-Client-Version': c['clientVersion'],
      'Origin': origin,
      'Referer': '$origin/',
      'Cookie': 'SOCS=CAE=',
      if (visitorData != null) 'X-Goog-Visitor-Id': visitorData,
    };
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await dio.post(
          '$origin/youtubei/v1/$endpoint?prettyPrint=false${clientName == 'WEB_MUSIC_ANALYTICS' ? '&alt=json' : ''}',
          data: {'context': context, ...data},
          options: Options(headers: headers),
          cancelToken: cancelToken,
        );
        return response.data;
      } on DioException catch (e) {
        if (e.response?.statusCode == 403 &&
            refreshOnForbidden &&
            refreshVisitor != null) {
          await refreshVisitor!();
          return post(
            endpoint,
            data,
            clientName: clientName,
            refreshOnForbidden: false,
            cancelToken: cancelToken,
          );
        }
        final retry =
            (e.response?.statusCode ?? 0) >= 500 ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout;
        if (attempt != 0 || !retry) rethrow;
      }
    }
  }
}

Map<String, dynamic> buildClientContext(
  Map<String, dynamic> client, {
  String hl = 'en',
  required String gl,
  String? visitorData,
}) => {
  'client': {
    'clientName': client['clientName'],
    'clientVersion': client['clientVersion'],
    if (client['platform'] != null) 'platform': client['platform'],
    'hl': 'en',
    'gl': gl,
    'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
    'visitorData': ?visitorData,
  },
  'user': {'lockedSafetyMode': false},
  'request': {'useSsl': true, 'internalExperimentFlags': []},
};
