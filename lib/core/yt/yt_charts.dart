import 'package:dio/dio.dart';
import '../innertube/innertube_http.dart';
import '../innertube/json_find.dart';
import 'models.dart';

class YtCharts {
  YtCharts(this.http);
  final InnertubeHttp http;
  Future<List<VideoItem>> trending(
    String country, {
    CancelToken? cancelToken,
  }) async {
    final json = await http.post(
      'browse',
      {
        'browseId': 'FEmusic_analytics_charts_home',
        'query':
            'perspective=CHART_DETAILS&chart_params_country_code=$country&chart_params_chart_type=TRENDING_VIDEOS',
      },
      clientName: 'WEB_MUSIC_ANALYTICS',
      cancelToken: cancelToken,
    );
    final values =
        findAll(json, 'videoViews').whereType<List>().firstOrNull ?? [];
    return values
        .whereType<Map>()
        .map((v) {
          final id =
              v['id'] ??
              v['videoId'] ??
              findAll(v, 'videoId').whereType<String>().firstOrNull;
          final title =
              v['title'] ?? findAll(v, 'title').whereType<String>().firstOrNull;
          if (id is! String || title is! String) return null;
          return VideoItem(
            id: id,
            title: title,
            channelId: v['externalChannelId'] as String? ?? '',
            channelName: v['channelName'] as String? ?? '',
            thumbUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
          );
        })
        .whereType<VideoItem>()
        .toList();
  }
}
