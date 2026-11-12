import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import 'models.dart';
import 'channel_avatars.dart';

List<VideoItem> parseRss(String xml) {
  final doc = XmlDocument.parse(xml);
  return doc
      .findAllElements('entry', namespaceUri: 'http://www.w3.org/2005/Atom')
      .map((entry) {
        String text(String name, String ns) =>
            entry
                .findAllElements(name, namespaceUri: ns)
                .firstOrNull
                ?.innerText ??
            '';
        final id = text('videoId', 'http://www.youtube.com/xml/schemas/2015');
        final thumb = entry
            .findAllElements(
              'thumbnail',
              namespaceUri: 'http://search.yahoo.com/mrss/',
            )
            .firstOrNull
            ?.getAttribute('url');
        final channelId = text(
          'channelId',
          'http://www.youtube.com/xml/schemas/2015',
        );
        return VideoItem(
          id: id,
          title: text('title', 'http://www.w3.org/2005/Atom'),
          channelId: channelId,
          channelName: text('name', 'http://www.w3.org/2005/Atom'),
          channelAvatarUrl: ChannelAvatarCache.instance.get(channelId) ?? '',
          thumbUrl: thumb ?? 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
          publishedAt: DateTime.tryParse(
            text('published', 'http://www.w3.org/2005/Atom'),
          ),
        );
      })
      .where((item) => item.id.isNotEmpty)
      .toList();
}

class YtRss {
  YtRss(this.dio);
  final Dio dio;
  Future<List<VideoItem>> uploads(
    String channelId, {
    CancelToken? cancelToken,
  }) async {
    final response = await dio.get<String>(
      'https://www.youtube.com/feeds/videos.xml',
      queryParameters: {'channel_id': channelId},
      options: Options(responseType: ResponseType.plain),
      cancelToken: cancelToken,
    );
    return parseRss(response.data ?? '');
  }
}
