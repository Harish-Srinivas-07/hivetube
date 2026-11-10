import '../innertube/innertube_http.dart';
import '../innertube/json_find.dart';
import 'models.dart';
import 'parser.dart';

class YtReel {
  YtReel(this.http);
  final InnertubeHttp http;
  Future<List<ShortItem>> shorts() async {
    final first = await http.post('reel/reel_watch_sequence', {
      'sequenceParams': 'CA8%3D',
    });
    final result = parseShorts(first);
    final token = findAll(
      first,
      'continuation',
    ).whereType<String>().firstOrNull;
    if (token != null) {
      final next = await http.post('reel/reel_watch_sequence', {
        'continuation': token,
      });
      final seen = result.map((e) => e.id).toSet();
      result.addAll(parseShorts(next).where((e) => seen.add(e.id)));
    }
    return result;
  }
}
