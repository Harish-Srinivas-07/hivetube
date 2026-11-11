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

String _imageUrl(dynamic value) {
  final url = findAll(value, 'url').whereType<String>().firstOrNull ?? '';
  if (url.startsWith('//')) return 'https:$url';
  return url.startsWith('https://') ? url : '';
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
      final metadata = safeNav(value, [
        'metadata', 'lockupMetadataViewModel', 'metadata', 'contentMetadataViewModel',
      ]);
      final rows = metadata is Map ? metadata['metadataRows'] : null;
      final firstRow = rows is List && rows.isNotEmpty ? rows.first : null;
      final parts = firstRow is Map ? firstRow['metadataParts'] : null;
      final firstPart = parts is List && parts.isNotEmpty ? parts.first : null;
      final lockupChannel = _text(firstPart is Map ? firstPart['text'] : null);
      final channel = [
        _text(value['ownerText']),
        _text(value['shortBylineText']),
        _text(value['longBylineText']),
        lockupChannel,
      ].firstWhere((name) => name.isNotEmpty, orElse: () => '');
      final channelIds = findAll(
        value,
        'browseId',
      ).whereType<String>().where((id) => id.startsWith('UC'));
      final avatarRenderer =
          findAll(value, 'channelThumbnailWithLinkRenderer').firstOrNull ??
          findAll(value, 'channelThumbnailSupportedRenderers').firstOrNull;
      final avatar = _imageUrl(
        avatarRenderer ?? safeNav(value, [
          'metadata', 'lockupMetadataViewModel', 'image',
        ]),
      );
      items.add(
        VideoItem(
          id: id,
          title: title,
          channelId: channelIds.firstOrNull ?? '',
          channelName: channel,
          channelAvatarUrl: avatar,
          thumbUrl: _thumbnail(value['thumbnail'] ?? value['contentImage'], id),
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
      if (id is String && id.isNotEmpty && seen.add(id)) {
        results.add(
          ShortItem(
            id: id,
            thumbUrl: _thumbnail(v, id),
            title: _text(v['headline']).isNotEmpty
                ? _text(v['headline'])
                : (_text(v['title']).isNotEmpty ? _text(v['title']) : null),
          ),
        );
      }
    }
  }
  return results;
}

List<ShortItem> parseReelEntries(dynamic json) {
  final items = <ShortItem>[];
  final seen = <String>{};
  for (final entries in findAll(json, 'entries')) {
    if (entries is! List) continue;
    for (final entry in entries) {
      final endpoint = safeNav(entry, ['command', 'reelWatchEndpoint']);
      final id = endpoint is Map ? endpoint['videoId'] : null;
      if (id is String && id.isNotEmpty && seen.add(id)) {
        items.add(
          ShortItem(
            id: id,
            thumbUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
          ),
        );
      }
    }
  }
  return items;
}

ShortItem? parseShortMetadata(dynamic json, String id) {
  final primary = findAll(json, 'videoPrimaryInfoRenderer').firstOrNull;
  final secondary = findAll(json, 'videoSecondaryInfoRenderer').firstOrNull;
  final title = _text(primary is Map ? primary['title'] : null);
  final owner = findAll(secondary, 'videoOwnerRenderer').firstOrNull;
  final channel = _text(owner is Map ? owner['title'] : null);
  final channelId = findAll(
    owner,
    'browseId',
  ).whereType<String>().where((v) => v.startsWith('UC')).firstOrNull;
  final avatar = findAll(
    owner is Map ? owner['thumbnail'] : null,
    'url',
  ).whereType<String>().where((url) => url.startsWith('https://')).firstOrNull;
  if (title.isEmpty && channel.isEmpty && channelId == null) return null;
  return ShortItem(
    id: id,
    thumbUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
    title: title.isEmpty ? null : title,
    channelName: channel.isEmpty ? null : channel,
    channelId: channelId,
    channelAvatarUrl: avatar,
  );
}
