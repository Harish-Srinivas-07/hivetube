import 'dart:convert';
import '../db/app_db.dart';
import 'innertube_http.dart';
import 'json_find.dart';

class VisitorService {
  VisitorService(this.http, this.db);
  final InnertubeHttp http;
  final AppDb db;
  Future<String> get({bool force = false}) async {
    if (!force) {
      try {
        final cached =
            jsonDecode((await db.getValue('visitor_data')) ?? '') as Map;
        if (DateTime.now().millisecondsSinceEpoch <
                (cached['expires'] as int) &&
            cached['value'] is String) {
          return cached['value'] as String;
        }
      } catch (_) {
        /* cache miss */
      }
    }
    final result = await http.post('visitor_id', {}, refreshOnForbidden: false);
    final visitor = safeNav(result, ['responseContext', 'visitorData']);
    if (visitor is! String || visitor.isEmpty) {
      throw StateError('Visitor data missing');
    }
    await db.setValue(
      'visitor_data',
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
