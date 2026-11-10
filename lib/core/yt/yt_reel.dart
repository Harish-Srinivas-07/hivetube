import 'package:dio/dio.dart';
import '../innertube/innertube_http.dart';
import '../innertube/json_find.dart';
import 'models.dart';
import 'parser.dart';

class YtReel {
  YtReel(this.http);
  final InnertubeHttp http;
  Future<({List<ShortItem> items, int continuationCount})> fetch({
    CancelToken? cancelToken,
  }) async {
    final items = <ShortItem>[];
    final seen = <String>{};
    final tokens = <String>{};
    String? continuation;
    var count = 0;
    do {
      final response = await http.post(
        'reel/reel_watch_sequence',
        continuation == null
            ? {'sequenceParams': 'CA8%3D'}
            : {'continuation': continuation},
        cancelToken: cancelToken,
      );
      if (continuation != null) count++;
      items.addAll(parseShorts(response).where((item) => seen.add(item.id)));
      final next = safeNav(response, [
        'continuationEndpoint',
        'continuationCommand',
        'token',
      ]);
      continuation = next is String && next.isNotEmpty && tokens.add(next)
          ? next
          : null;
    } while (items.length < 12 && continuation != null);
    return (items: items, continuationCount: count);
  }

  Future<List<ShortItem>> shorts({CancelToken? cancelToken}) async =>
      (await fetch(cancelToken: cancelToken)).items;
}
