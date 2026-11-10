import 'package:dio/dio.dart';
import 'clients.dart';

class InnertubeHttp {
  InnertubeHttp(this.dio, this.clients);
  final Dio dio;
  final InnertubeClients clients;
  String? visitorData;
  Future<void> Function()? refreshVisitor;

  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data, {
    String clientName = 'WEB',
    bool refreshOnForbidden = true,
  }) async {
    final c = clients[clientName];
    final origin = c['origin'] as String;
    final context = {
      'client': {
        'clientName': c['clientName'],
        'clientVersion': c['clientVersion'],
        if (c['platform'] != null) 'platform': c['platform'],
        'hl': 'en',
        'gl': 'US',
        'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        if (visitorData != null) 'visitorData': visitorData,
      },
      'user': {'lockedSafetyMode': false},
      'request': {'useSsl': true, 'internalExperimentFlags': []},
    };
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
