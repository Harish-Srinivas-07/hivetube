class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    this.channelId = '',
    this.channelName = '',
    this.channelAvatarUrl = '',
    this.thumbUrl = '',
    this.durationText = '',
    this.viewsText = '',
    this.publishedText = '',
    this.publishedAt,
    this.isShort = false,
    this.isLive = false,
  });
  final String id,
      title,
      channelId,
      channelName,
      channelAvatarUrl,
      thumbUrl,
      durationText,
      viewsText,
      publishedText;
  final DateTime? publishedAt;
  final bool isShort, isLive;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'channelId': channelId,
    'channelName': channelName,
    'channelAvatarUrl': channelAvatarUrl,
    'thumbUrl': thumbUrl,
    'durationText': durationText,
    'viewsText': viewsText,
    'publishedText': publishedText,
    'publishedAt': publishedAt?.toIso8601String(),
    'isShort': isShort,
    'isLive': isLive,
  };
  factory VideoItem.fromJson(Map<String, dynamic> j) => VideoItem(
    id: j['id'] as String,
    title: j['title'] as String,
    channelId: j['channelId'] as String? ?? '',
    channelName: j['channelName'] as String? ?? '',
    channelAvatarUrl: j['channelAvatarUrl'] as String? ?? '',
    thumbUrl: j['thumbUrl'] as String? ?? '',
    durationText: j['durationText'] as String? ?? '',
    viewsText: j['viewsText'] as String? ?? '',
    publishedText: j['publishedText'] as String? ?? '',
    publishedAt: DateTime.tryParse(j['publishedAt'] as String? ?? ''),
    isShort: j['isShort'] as bool? ?? false,
    isLive: j['isLive'] as bool? ?? false,
  );
}

class ShortItem {
  const ShortItem({
    required this.id,
    required this.thumbUrl,
    this.title,
    this.channelName,
    this.channelId,
    this.channelAvatarUrl,
    this.viewsText,
  });
  final String id, thumbUrl;
  final String? title, channelName, channelId, channelAvatarUrl, viewsText;
  Map<String, dynamic> toJson() => {
    'id': id,
    'thumbUrl': thumbUrl,
    'title': title,
    'channelName': channelName,
    'channelId': channelId,
    'channelAvatarUrl': channelAvatarUrl,
    'viewsText': viewsText,
  };
  factory ShortItem.fromJson(Map<String, dynamic> j) => ShortItem(
    id: j['id'] as String,
    thumbUrl: j['thumbUrl'] as String,
    title: j['title'] as String?,
    channelName: j['channelName'] as String?,
    channelId: j['channelId'] as String?,
    channelAvatarUrl: j['channelAvatarUrl'] as String?,
    viewsText: j['viewsText'] as String?,
  );
}

class HomeSection {
  const HomeSection(this.title, this.items);
  final String title;
  final List<VideoItem> items;
}

class VideoPage {
  const VideoPage(
    this.items,
    this.continuation, {
    this.searchDateFilters = const [],
  });
  final List<VideoItem> items;
  final String? continuation;
  final List<String> searchDateFilters;
}

class ShortPage {
  const ShortPage(this.items, this.continuation);
  final List<ShortItem> items;
  final String? continuation;
}

class ChannelItem {
  const ChannelItem({
    required this.id,
    required this.title,
    this.handle = '',
    this.avatarUrl = '',
    this.subscriberCountText = '',
    this.videoCountText = '',
    this.description = '',
  });
  final String id,
      title,
      handle,
      avatarUrl,
      subscriberCountText,
      videoCountText,
      description;
}

class PlaylistItem {
  const PlaylistItem({
    required this.id,
    required this.title,
    this.channelName = '',
    this.channelId = '',
    this.thumbUrl = '',
    this.videoCountText = '',
  });
  final String id, title, channelName, channelId, thumbUrl, videoCountText;
}

enum SearchFilterType {
  all,
  videos,
  shorts,
  channels,
  playlists,
  live,
}

class SearchFilterChip {
  const SearchFilterChip({
    required this.label,
    required this.params,
    required this.type,
  });
  final String label;
  final String params;
  final SearchFilterType type;
}

sealed class SearchResultItem {
  const SearchResultItem();
}

class VideoSearchResult extends SearchResultItem {
  const VideoSearchResult(this.video);
  final VideoItem video;
}

class ChannelSearchResult extends SearchResultItem {
  const ChannelSearchResult(this.channel);
  final ChannelItem channel;
}

class PlaylistSearchResult extends SearchResultItem {
  const PlaylistSearchResult(this.playlist);
  final PlaylistItem playlist;
}

class ShortsShelfSearchResult extends SearchResultItem {
  const ShortsShelfSearchResult(this.shorts);
  final List<ShortItem> shorts;
}

class SearchResultPage {
  const SearchResultPage({
    required this.items,
    this.continuation,
    this.filters = const [],
  });
  final List<SearchResultItem> items;
  final String? continuation;
  final List<SearchFilterChip> filters;
}

class ChannelPageData {
  const ChannelPageData({
    required this.id,
    required this.name,
    this.handle = '',
    this.avatarUrl = '',
    this.bannerUrl = '',
    this.subscribersText = '',
    this.videosCountText = '',
    this.description = '',
    this.tabs = const [],
    this.currentTabItems = const [],
    this.continuation,
    this.sortChips = const [],
  });
  final String id,
      name,
      handle,
      avatarUrl,
      bannerUrl,
      subscribersText,
      videosCountText,
      description;
  final List<String> tabs;
  final List<dynamic> currentTabItems;
  final String? continuation;
  final List<({String label, String params})> sortChips;
}

class PlaylistPageData {
  const PlaylistPageData({
    required this.id,
    required this.title,
    this.author = '',
    this.authorId = '',
    this.thumbUrl = '',
    this.videoCountText = '',
    this.description = '',
    this.videos = const [],
    this.continuation,
  });
  final String id,
      title,
      author,
      authorId,
      thumbUrl,
      videoCountText,
      description;
  final List<VideoItem> videos;
  final String? continuation;
}
