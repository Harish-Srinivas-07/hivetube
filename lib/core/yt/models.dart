class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    this.channelId = '',
    this.channelName = '',
    this.thumbUrl = '',
    this.durationText = '',
    this.viewsText = '',
    this.publishedText = '',
    this.publishedAt,
  });
  final String id,
      title,
      channelId,
      channelName,
      thumbUrl,
      durationText,
      viewsText,
      publishedText;
  final DateTime? publishedAt;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'channelId': channelId,
    'channelName': channelName,
    'thumbUrl': thumbUrl,
    'durationText': durationText,
    'viewsText': viewsText,
    'publishedText': publishedText,
    'publishedAt': publishedAt?.toIso8601String(),
  };
  factory VideoItem.fromJson(Map<String, dynamic> j) => VideoItem(
    id: j['id'] as String,
    title: j['title'] as String,
    channelId: j['channelId'] as String? ?? '',
    channelName: j['channelName'] as String? ?? '',
    thumbUrl: j['thumbUrl'] as String? ?? '',
    durationText: j['durationText'] as String? ?? '',
    viewsText: j['viewsText'] as String? ?? '',
    publishedText: j['publishedText'] as String? ?? '',
    publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? ''),
  );
}

class ShortItem {
  const ShortItem({required this.id, required this.thumbUrl, this.title});
  final String id, thumbUrl;
  final String? title;
  Map<String, dynamic> toJson() => {
    'id': id,
    'thumbUrl': thumbUrl,
    'title': title,
  };
  factory ShortItem.fromJson(Map<String, dynamic> j) => ShortItem(
    id: j['id'] as String,
    thumbUrl: j['thumbUrl'] as String,
    title: j['title'] as String?,
  );
}

class HomeSection {
  const HomeSection(this.title, this.items);
  final String title;
  final List<VideoItem> items;
}

class VideoPage {
  const VideoPage(this.items, this.continuation);
  final List<VideoItem> items;
  final String? continuation;
}
