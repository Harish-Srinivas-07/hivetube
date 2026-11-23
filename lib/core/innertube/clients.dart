import 'dart:convert';
import 'package:dio/dio.dart';
import 'json_find.dart';

class InnertubeClients {
  InnertubeClients(this.values);
  final Map<String, dynamic> values;
  Map<String, dynamic> operator [](String key) =>
      Map<String, dynamic>.from(values[key] as Map);

  static Future<InnertubeClients> load(Dio dio, String asset) async {
    final values = jsonDecode(asset) as Map<String, dynamic>;
    try {
      final response = await dio.get<String>(
        'https://www.youtube.com/sw.js_data',
        options: Options(responseType: ResponseType.plain),
      );
      var body = response.data ?? '';
      if (body.startsWith(")]}'")) body = body.substring(4);
      final version = safeNav(jsonDecode(body), [0, 2, 0, 0, 16]);
      if (version is String && version.startsWith('2.')) {
        values['WEB']['clientVersion'] = version;
      }
    } catch (_) {
      /* JSON fallback */
    }
    return InnertubeClients(values);
  }
}
