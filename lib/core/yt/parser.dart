import '../innertube/json_find.dart';
import '../innertube/continuation.dart';
import 'models.dart';

String _text(dynamic value) {
  if (value is String) return value;
  if (value is Map) {
    if (value['simpleText'] is String) return value['simpleText'] as String;
    if (value['content'] is String) return value['content'] as String;
    if (value['runs'] is List) {
      return (value['runs'] as List)
          .map((v) => v is Map ? v['text'] ?? '' : '')
          .join();
    }
  }
  return '';
}

String _thumbnail(dynamic v, String id) {
  final urls = findAll(
    v,
    'url',
  ).whereType<String>().where((u) => u.contains('ytimg.com')).toList();
  return urls.isNotEmpty
      ? urls.last
      : 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
}

VideoPage parseVideos(dynamic json) {
  final items = <VideoItem>[];
  final seen = <String>{};
  for (final key in [
    'videoRenderer',
    'compactVideoRenderer',
    'gridVideoRenderer',
    'lockupViewModel',
  ]) {
    for (final value in findAll(json, key)) {
      if (value is! Map) continue;
      final id = value['videoId'] ?? value['contentId'];
      if (id is! String || id.isEmpty || !seen.add(id)) continue;
      final title = _text(value['title']).isNotEmpty
          ? _text(value['title'])
          : _text(
              safeNav(value, ['metadata', 'lockupMetadataViewModel', 'title']),
            );
      if (title.isEmpty) continue;
      final channel = _text(value['ownerText']).isNotEmpty
          ? _text(value['ownerText'])
          : _text(value['shortBylineText']);
      final channelIds = findAll(
        value,
        'browseId',
      ).whereType<String>().where((id) => id.startsWith('UC'));
      items.add(
        VideoItem(
          id: id,
          title: title,
          channelId: channelIds.firstOrNull ?? '',
          channelName: channel,
          thumbUrl: _thumbnail(value, id),
          durationText: _text(value['lengthText']),
          viewsText: _text(value['viewCountText']),
          publishedText: _text(value['publishedTimeText']),
        ),
      );
    }
  }
  return VideoPage(items, continuationToken(json));
}

List<ShortItem> parseShorts(dynamic json) {
  final results = <ShortItem>[];
  final seen = <String>{};
  for (final key in [
    'shortsLockupViewModel',
    'reelItemRenderer',
    'reelWatchEndpoint',
  ]) {
    for (final v in findAll(json, key)) {
      if (v is! Map) continue;
      final id =
          v['videoId'] ?? findAll(v, 'videoId').whereType<String>().firstOrNull;
      if (id is String && seen.add(id)) {
        results.add(
          ShortItem(
            id: id,
            thumbUrl: _thumbnail(v, id),
            title: _text(v['headline']).isNotEmpty
                ? _text(v['headline'])
                : null,
          ),
        );
      }
    }
  }
  return results;
}
