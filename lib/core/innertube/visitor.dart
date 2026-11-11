import 'dart:convert';
import '../db/app_db.dart';
import 'innertube_http.dart';
import 'json_find.dart';

String visitorCacheKey(String hl, String gl) => 'visitor_data_${hl}_$gl';

class VisitorService {
  VisitorService(this.http, this.db);
  final InnertubeHttp http;
  final AppDb db;
  Future<String> get({bool force = false}) async {
    if (!force) {
      try {
        final cached =
            jsonDecode(
                  (await db.getValue(visitorCacheKey(http.hl, http.gl))) ?? '',
                )
                as Map;
        if (DateTime.now().millisecondsSinceEpoch <
                (cached['expires'] as int) &&
            cached['value'] is String) {
          return cached['value'] as String;
        }
      } catch (_) {
        /* cache miss */
      }
    }
    http.visitorData = null;
    final result = await http.post('visitor_id', {}, refreshOnForbidden: false);
    final visitor = safeNav(result, ['responseContext', 'visitorData']);
    if (visitor is! String || visitor.isEmpty) {
      throw StateError('Visitor data missing');
    }
    await db.setValue(
      visitorCacheKey(http.hl, http.gl),
      jsonEncode({
        'value': visitor,
        'expires': DateTime.now()
            .add(const Duration(days: 30))
            .millisecondsSinceEpoch,
      }),
    );
    return visitor;
  }
}
