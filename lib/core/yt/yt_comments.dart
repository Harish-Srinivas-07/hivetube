import '../innertube/innertube_http.dart';
import '../innertube/json_find.dart';
import 'watch_info.dart';

class WatchComment {
  const WatchComment({
    required this.id,
    required this.author,
    required this.avatar,
    required this.content,
    required this.age,
    required this.likes,
    required this.replies,
    required this.verified,
    required this.creator,
    this.pinned = '',
    this.replyToken,
  });
  final String id, author, avatar, content, age, likes, replies, pinned;
  final bool verified, creator;
  final String? replyToken;
}

class CommentPage {
  const CommentPage(this.items, this.count, this.continuation, this.sorts);
  final List<WatchComment> items;
  final String count;
  final String? continuation;
  final Map<String, String> sorts;
}

CommentPage parseComments(dynamic json) {
  final payloads = <String, Map>{};
  for (final v in findAll(json, 'commentEntityPayload').whereType<Map>()) {
    if (v['key'] is String) payloads[v['key']] = v;
  }
  final comments = <WatchComment>[];
  for (final thread in findAll(
    json,
    'commentThreadRenderer',
  ).whereType<Map>()) {
    final model = findAll(
      thread,
      'commentViewModel',
    ).whereType<Map>().where((m) => m['commentKey'] is String).firstOrNull;
    final payload = payloads[model?['commentKey']];
    if (payload == null) continue;
    final props = payload['properties'] is Map
        ? payload['properties'] as Map
        : {};
    final author = payload['author'] is Map ? payload['author'] as Map : {};
    final toolbar = payload['toolbar'] is Map ? payload['toolbar'] as Map : {};
    final replies = findAll(
      thread['replies'],
      'token',
    ).whereType<String>().firstOrNull;
    final dynamic thumbs = author['thumbnails'];
    final dynamic avatar = author['avatarThumbnailUrl'] ??
        (thumbs is List && thumbs.isNotEmpty ? thumbs.last['url'] : null) ??
        '';
    comments.add(
      WatchComment(
        id: '${props['commentId'] ?? ''}',
        author: '${author['displayName'] ?? ''}',
        avatar: '$avatar',
        content: watchText(props['content']),
        age: '${props['publishedTime'] ?? ''}',
        likes: '${toolbar['likeCountNotliked'] ?? ''}',
        replies: '${toolbar['replyCount'] ?? ''}',
        verified: author['isVerified'] == true,
        creator: author['isCreator'] == true,
        pinned: '${model?['pinnedText'] ?? ''}',
        replyToken: replies,
      ),
    );
  }
  // Reply responses can contain unthreaded comment view models.
  if (comments.isEmpty) {
    for (final payload in payloads.values) {
      final props = payload['properties'] is Map
          ? payload['properties'] as Map
          : {};
      final author = payload['author'] is Map ? payload['author'] as Map : {};
      final toolbar = payload['toolbar'] is Map
          ? payload['toolbar'] as Map
          : {};
      comments.add(
        WatchComment(
          id: '${props['commentId'] ?? ''}',
          author: '${author['displayName'] ?? ''}',
          avatar: '${author['avatarThumbnailUrl'] ?? ''}',
          content: watchText(props['content']),
          age: '${props['publishedTime'] ?? ''}',
          likes: '${toolbar['likeCountNotliked'] ?? ''}',
          replies: '${toolbar['replyCount'] ?? ''}',
          verified: author['isVerified'] == true,
          creator: author['isCreator'] == true,
        ),
      );
    }
  }
  final header = findAll(
    json,
    'commentsHeaderRenderer',
  ).whereType<Map>().firstOrNull;
  final sorts = <String, String>{};
  for (final menu in findAll(
    header,
    'sortFilterSubMenuRenderer',
  ).whereType<Map>()) {
    final options = menu['subMenuItems'];
    if (options is! List) continue;
    for (final option in options.whereType<Map>()) {
      final title = '${option['title'] ?? ''}';
      final token = findAll(option, 'token').whereType<String>().firstOrNull;
      if (title.isNotEmpty && token != null) sorts[title] = token;
    }
  }
  String? next;
  for (final command in [
    ...findAll(json, 'appendContinuationItemsAction'),
    ...findAll(json, 'reloadContinuationItemsCommand'),
  ].whereType<Map>()) {
    final items = command['continuationItems'];
    if (items is List) {
      for (final item in items.whereType<Map>()) {
        final token = findAll(
          item['continuationItemRenderer'],
          'token',
        ).whereType<String>().firstOrNull;
        if (token != null) next = token;
      }
    }
  }
  return CommentPage(comments, watchText(header?['countText']), next, sorts);
}

class YtComments {
  YtComments(this.http);
  final InnertubeHttp http;
  Future<CommentPage> page(String token) async =>
      parseComments(await http.post('next', {'continuation': token}));
}
