import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import 'models.dart';

class YtRss {
  YtRss(this.dio);
  final Dio dio;
  Future<List<VideoItem>> uploads(String channelId) async {
    final response = await dio.get<String>(
      'https://www.youtube.com/feeds/videos.xml',
      queryParameters: {'channel_id': channelId},
      options: Options(responseType: ResponseType.plain),
    );
    final doc = XmlDocument.parse(response.data ?? '');
    return doc
        .findAllElements('entry')
        .map((entry) {
          String value(String name) =>
              entry.findAllElements(name).firstOrNull?.innerText ?? '';
          final id = value('yt:videoId');
          return VideoItem(
            id: id,
            title: value('title'),
            channelId: value('yt:channelId'),
            channelName: value('name'),
            thumbUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
            publishedAt: DateTime.tryParse(value('published')),
          );
        })
        .where((e) => e.id.isNotEmpty)
        .toList();
  }
}
