import '../innertube/continuation.dart';
import '../innertube/json_find.dart';
import 'models.dart';
import 'parser.dart';

String watchText(dynamic value) {
  if (value is String) return value;
  if (value is Map) {
    if (value['simpleText'] is String) return value['simpleText'];
    if (value['content'] is String) return value['content'];
    if (value['runs'] is List) {
      return (value['runs'] as List)
          .map((v) => v is Map ? v['text'] ?? '' : '')
          .join();
    }
  }
  return '';
}

class WatchChapter {
  const WatchChapter(this.title, this.start);
  final String title;
  final Duration start;
}

class WatchInfo {
  const WatchInfo({
    required this.id,
    required this.title,
    required this.channelName,
    required this.channelId,
    required this.avatar,
    required this.subscribers,
    required this.description,
    required this.likes,
    required this.views,
    required this.date,
    required this.handle,
    required this.commentsToken,
    required this.related,
    required this.chapters,
    required this.chips,
  });
  final String id,
      title,
      channelName,
      channelId,
      avatar,
      subscribers,
      description,
      likes,
      views,
      date,
      handle;
  final String? commentsToken;
  final VideoPage related;
  final List<WatchChapter> chapters;
  final Map<String, String> chips;
}

WatchInfo parseWatchInfo(dynamic json, String id) {
  final primary = findAll(json, 'videoPrimaryInfoRenderer').firstOrNull;
  final secondary = findAll(json, 'videoSecondaryInfoRenderer').firstOrNull;
  final owner = findAll(secondary, 'videoOwnerRenderer').firstOrNull;
  final like = findAll(
    primary,
    'segmentedLikeDislikeButtonViewModel',
  ).firstOrNull;
  final likeButton = findAll(
    like,
    'buttonViewModel',
  ).whereType<Map>().where((v) => v['iconName'] == 'LIKE').firstOrNull;
  final commentSection = findAll(json, 'itemSectionRenderer')
      .whereType<Map>()
      .where((v) => v['sectionIdentifier'] == 'comment-item-section')
      .firstOrNull;
  final secondaryResults = findAll(
    json,
    'secondaryResults',
  ).whereType<Map>().where((v) => v.containsKey('results')).firstOrNull;
  final related = parseVideos(secondaryResults ?? const {});
  final chapters = <WatchChapter>[];
  for (final chapter in findAll(
    findAll(json, 'markersMap').firstOrNull,
    'chapterRenderer',
  ).whereType<Map>()) {
    final ms = chapter['timeRangeStartMillis'];
    if (ms is num) {
      chapters.add(
        WatchChapter(
          watchText(chapter['title']),
          Duration(milliseconds: ms.toInt()),
        ),
      );
    }
  }
  final chips = <String, String>{};
  for (final chip in findAll(
    secondaryResults,
    'chipCloudChipRenderer',
  ).whereType<Map>()) {
    final label = watchText(chip['text']);
    final token = findAll(chip, 'token').whereType<String>().firstOrNull;
    if (label.isNotEmpty && token != null) chips[label] = token;
  }
  return WatchInfo(
    id: id,
    title: watchText(primary is Map ? primary['title'] : null),
    channelName: watchText(owner is Map ? owner['title'] : null),
    channelId:
        findAll(
          owner,
          'browseId',
        ).whereType<String>().where((s) => s.startsWith('UC')).firstOrNull ??
        '',
    avatar: bestImage(owner is Map ? owner['thumbnail'] : null),
    subscribers: watchText(owner is Map ? owner['subscriberCountText'] : null),
    handle:
        findAll(owner, 'canonicalBaseUrl')
            .whereType<String>()
            .where((s) => s.startsWith('/@'))
            .map((s) => s.substring(1))
            .firstOrNull ??
        '',
    description: watchText(
      secondary is Map
          ? (secondary['attributedDescription'] ?? secondary['description'])
          : null,
    ),
    likes: likeButton?['title'] as String? ?? '',
    views: watchText(
      findAll(
        primary,
        'videoViewCountRenderer',
      ).whereType<Map>().firstOrNull?['viewCount'],
    ),
    date: watchText(
      primary is Map
          ? primary['dateText'] ?? primary['publishedTimeText']
          : null,
    ),
    commentsToken: continuationToken(commentSection),
    related: related,
    chapters: chapters,
    chips: chips,
  );
}
