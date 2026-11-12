import '../innertube/json_find.dart';
import '../innertube/continuation.dart';
import 'models.dart';
import 'channel_avatars.dart';

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

String bestImage(dynamic node) {
  try {
    final candidates = <Map>[];
    if (node is Map) {
      final values = node['thumbnails'] ?? node['sources'];
      if (values is List) candidates.addAll(values.whereType<Map>());
      if (node['url'] is String) candidates.add(node);
    }
    for (final key in ['thumbnails', 'sources']) {
      for (final value in findAll(node, key)) {
        if (value is List) candidates.addAll(value.whereType<Map>());
      }
    }
    candidates.sort(
      (a, b) =>
          ((b['width'] as num?) ?? 0).compareTo((a['width'] as num?) ?? 0),
    );
    for (final candidate in candidates) {
      var url = candidate['url'];
      if (url is! String || url.isEmpty) continue;
      if (url.startsWith('//')) url = 'https:$url';
      if (url.startsWith('http://')) url = 'https://${url.substring(7)}';
      if (url.startsWith('https://')) return url;
    }
  } catch (_) {}
  return '';
}

String parseChannelHeaderAvatar(dynamic json) {
  for (final key in ['pageHeaderViewModel', 'c4TabbedHeaderRenderer']) {
    for (final header in findAll(json, key)) {
      final candidates = [
        safeNav(header, ['image']),
        safeNav(header, ['avatar']),
        safeNav(header, ['avatar', 'thumbnails']),
      ];
      for (final candidate in candidates) {
        final image = bestImage(candidate);
        if (image.isNotEmpty) return image;
      }
    }
  }
  return '';
}

List<String> searchUploadDateParams(dynamic json) {
  final params = <String>[];
  for (final group in findAll(json, 'searchFilterGroupRenderer')) {
    if (_text(
          group is Map ? group['title'] : null,
        ).toLowerCase().contains('upload') ==
        false) {
      continue;
    }
    for (final filter in findAll(group, 'searchFilterRenderer')) {
      final label = _text(filter is Map ? filter['label'] : null).toLowerCase();
      if (!['today', 'this week', 'this month'].any(label.contains)) continue;
      final value = safeNav(filter, [
        'navigationEndpoint',
        'searchEndpoint',
        'params',
      ]);
      if (value is String && value.isNotEmpty && !params.contains(value)) {
        params.add(value);
      }
    }
  }
  return params;
}

String _channelAvatar(dynamic value) {
  final supported = safeNav(value, [
    'channelThumbnailSupportedRenderers',
    'channelThumbnailWithLinkRenderer',
    'thumbnail',
  ]);
  final linked = safeNav(value, [
    'channelThumbnailWithLinkRenderer',
    'thumbnail',
  ]);
  final direct = safeNav(value, ['channelThumbnail']);
  final owner = safeNav(value, ['ownerThumbnail']);
  for (final node in [supported, linked, direct, owner]) {
    final image = bestImage(node);
    if (image.isNotEmpty) return image;
  }
  final metadata = safeNav(value, ['metadata', 'lockupMetadataViewModel']);
  for (final avatar in findAll(metadata, 'avatarViewModel')) {
    final image = bestImage(safeNav(avatar, ['image']));
    if (image.isNotEmpty) return image;
  }
  for (final decorated in findAll(metadata, 'decoratedAvatarViewModel')) {
    final image = bestImage(
      safeNav(decorated, ['avatar', 'avatarViewModel', 'image']),
    );
    if (image.isNotEmpty) return image;
  }
  return '';
}

String _channelId(dynamic value) {
  final scopes = [
    safeNav(value, ['ownerText']),
    safeNav(value, ['shortBylineText']),
    safeNav(value, ['longBylineText']),
    safeNav(value, ['byline']),
    safeNav(value, ['metadata']),
  ];
  for (final scope in scopes) {
    final ids = findAll(
      scope,
      'browseId',
    ).whereType<String>().where((id) => id.startsWith('UC'));
    if (ids.isNotEmpty) return ids.first;
  }
  return '';
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
      if (key == 'lockupViewModel' &&
          value['contentType'] != null &&
          value['contentType'] != 'LOCKUP_CONTENT_TYPE_VIDEO') {
        continue;
      }
      final id = value['videoId'] ?? value['contentId'];
      if (id is! String || id.isEmpty || !seen.add(id)) continue;
      final title = _text(value['title']).isNotEmpty
          ? _text(value['title'])
          : _text(
              safeNav(value, ['metadata', 'lockupMetadataViewModel', 'title']),
            );
      if (title.isEmpty) continue;
      final metadata = safeNav(value, [
        'metadata',
        'lockupMetadataViewModel',
        'metadata',
        'contentMetadataViewModel',
      ]);
      final rows = metadata is Map ? metadata['metadataRows'] : null;
      final firstRow = rows is List && rows.isNotEmpty ? rows.first : null;
      final parts = firstRow is Map ? firstRow['metadataParts'] : null;
      final firstPart = parts is List && parts.isNotEmpty ? parts.first : null;
      final channelPart = parts is List
          ? parts
                .whereType<Map>()
                .where(
                  (part) => findAll(
                    part,
                    'browseId',
                  ).whereType<String>().any((id) => id.startsWith('UC')),
                )
                .firstOrNull
          : null;
      final lockupChannel = _text(
        (channelPart ?? firstPart) is Map
            ? (channelPart ?? firstPart)['text']
            : null,
      );
      final channel = [
        _text(value['ownerText']),
        _text(value['shortBylineText']),
        _text(value['longBylineText']),
        lockupChannel,
      ].firstWhere((name) => name.isNotEmpty, orElse: () => '');
      final channelId = _channelId(value);
      final parsedAvatar = _channelAvatar(value);
      final avatar = parsedAvatar.isNotEmpty
          ? parsedAvatar
          : (channelId.isNotEmpty
                ? ChannelAvatarCache.instance.get(channelId) ?? ''
                : '');
      if (parsedAvatar.isNotEmpty && channelId.isNotEmpty) {
        ChannelAvatarCache.instance.put(channelId, parsedAvatar);
      }
      items.add(
        VideoItem(
          id: id,
          title: title,
          channelId: channelId,
          channelName: channel,
          channelAvatarUrl: avatar,
          thumbUrl: _thumbnail(value['thumbnail'] ?? value['contentImage'], id),
          durationText: _text(value['lengthText']),
          viewsText: _text(value['viewCountText']),
          publishedText: _text(value['publishedTimeText']),
          isShort: findAll(
            value,
            'url',
          ).whereType<String>().any((url) => url.startsWith('/shorts/')),
        ),
      );
    }
  }
  return VideoPage(
    items,
    continuationToken(json),
    searchDateFilters: searchUploadDateParams(json),
  );
}

List<ShortItem> parseShorts(dynamic json) {
  final results = <ShortItem>[];
  final seen = <String>{};
  for (final key in ['shortsLockupViewModel', 'reelItemRenderer']) {
    for (final v in findAll(json, key)) {
      if (v is! Map) continue;
      final id =
          v['videoId'] ?? findAll(v, 'videoId').whereType<String>().firstOrNull;
      if (id is String && id.isNotEmpty && seen.add(id)) {
        results.add(
          ShortItem(
            id: id,
            thumbUrl: _thumbnail(v, id),
            viewsText: _text(v['viewCountText']).isNotEmpty
                ? _text(v['viewCountText'])
                : _text(
                    v['overlayMetadata'] is Map
                        ? (v['overlayMetadata'] as Map)['secondaryText']
                        : null,
                  ),
            title:
                _text(safeNav(v, ['overlayMetadata', 'primaryText'])).isNotEmpty
                ? _text(safeNav(v, ['overlayMetadata', 'primaryText']))
                : _text(v['headline']).isNotEmpty
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
  final avatar = bestImage(owner is Map ? owner['thumbnail'] : null);
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

ChannelItem? parseChannelItem(dynamic v) {
  if (v is! Map) return null;
  final id = v['channelId'] ?? _channelId(v);
  if (id is! String || id.isEmpty) return null;
  final title = _text(v['title']);
  final handle = _text(v['subscriberCountText']).startsWith('@')
      ? _text(v['subscriberCountText'])
      : (_text(v['videoCountText']).startsWith('@')
          ? _text(v['videoCountText'])
          : '');
  final subCount = handle.startsWith('@')
      ? _text(v['videoCountText'])
      : _text(v['subscriberCountText']);
  final avatar = _channelAvatar(v).isNotEmpty
      ? _channelAvatar(v)
      : bestImage(v['thumbnail']);
  return ChannelItem(
    id: id,
    title: title.isNotEmpty ? title : id,
    handle: handle,
    avatarUrl: avatar,
    subscriberCountText: subCount,
    description: _text(v['descriptionSnippet']),
  );
}

PlaylistItem? parsePlaylistItem(dynamic v) {
  if (v is! Map) return null;
  final id = v['playlistId'] ??
      safeNav(v, ['navigationEndpoint', 'watchEndpoint', 'playlistId']);
  if (id is! String || id.isEmpty) return null;
  final title = _text(v['title']).isNotEmpty
      ? _text(v['title'])
      : _text(safeNav(v, ['metadata', 'lockupMetadataViewModel', 'title']));
  final channel = [
    _text(v['longBylineText']),
    _text(v['shortBylineText']),
  ].firstWhere((s) => s.isNotEmpty, orElse: () => '');
  return PlaylistItem(
    id: id,
    title: title.isNotEmpty ? title : 'Playlist',
    channelName: channel,
    channelId: _channelId(v),
    thumbUrl: bestImage(v['thumbnail'] ?? v['thumbnails']),
    videoCountText: _text(v['videoCount'] ?? v['videoCountShortText']),
  );
}

List<SearchFilterChip> parseSearchFilterChips(dynamic json) {
  final chips = <SearchFilterChip>[];
  final seen = <String>{};
  for (final group in findAll(json, 'searchFilterGroupRenderer')) {
    for (final filter in findAll(group, 'searchFilterRenderer')) {
      final label = _text(filter is Map ? filter['label'] : null).trim();
      final params = safeNav(filter, [
        'navigationEndpoint',
        'searchEndpoint',
        'params',
      ]);
      if (label.isEmpty || params is! String || params.isEmpty) continue;
      if (!seen.add(params)) continue;

      final lower = label.toLowerCase();
      var type = SearchFilterType.all;
      if (lower.contains('video')) {
        type = SearchFilterType.videos;
      } else if (lower.contains('short')) {
        type = SearchFilterType.shorts;
      } else if (lower.contains('channel')) {
        type = SearchFilterType.channels;
      } else if (lower.contains('playlist')) {
        type = SearchFilterType.playlists;
      } else if (lower.contains('live')) {
        type = SearchFilterType.live;
      }

      chips.add(SearchFilterChip(label: label, params: params, type: type));
    }
  }
  return chips;
}

SearchResultPage parseSearchResults(dynamic json) {
  final items = <SearchResultItem>[];
  final seenVideos = <String>{};
  final seenChannels = <String>{};
  final seenPlaylists = <String>{};

  for (final section in findAll(json, 'itemSectionRenderer')) {
    final contents = safeNav(section, ['contents']);
    if (contents is! List) continue;
    for (final node in contents) {
      if (node is! Map) continue;
      if (node.containsKey('channelRenderer')) {
        final ch = parseChannelItem(node['channelRenderer']);
        if (ch != null && seenChannels.add(ch.id)) {
          items.add(ChannelSearchResult(ch));
        }
      } else if (node.containsKey('playlistRenderer')) {
        final pl = parsePlaylistItem(node['playlistRenderer']);
        if (pl != null && seenPlaylists.add(pl.id)) {
          items.add(PlaylistSearchResult(pl));
        }
      } else if (node.containsKey('reelShelfRenderer')) {
        final shorts = parseShorts(node['reelShelfRenderer']);
        if (shorts.isNotEmpty) {
          items.add(ShortsShelfSearchResult(shorts));
        }
      } else if (node.containsKey('videoRenderer')) {
        final v = node['videoRenderer'];
        final id = v['videoId'] as String?;
        if (id != null && seenVideos.add(id)) {
          final videoItems = parseVideos({'videoRenderer': v}).items;
          if (videoItems.isNotEmpty) {
            items.add(VideoSearchResult(videoItems.first));
          }
        }
      }
    }
  }

  // Fallback if structured sections were not matched
  if (items.isEmpty) {
    for (final v in parseVideos(json).items) {
      if (seenVideos.add(v.id)) {
        items.add(VideoSearchResult(v));
      }
    }
  }

  final filters = parseSearchFilterChips(json);
  final continuation = continuationToken(json);
  return SearchResultPage(
    items: items,
    continuation: continuation,
    filters: filters,
  );
}

ChannelPageData parseChannelPage(dynamic json, String channelId) {
  String name = '';
  String handle = '';
  String avatar = '';
  String banner = '';
  String subs = '';
  String videosCount = '';
  String desc = '';

  for (final header in [
    ...findAll(json, 'pageHeaderViewModel'),
    ...findAll(json, 'c4TabbedHeaderRenderer'),
  ]) {
    if (header is! Map) continue;
    if (name.isEmpty) {
      name = _text(header['title'] ?? safeNav(header, ['pageTitle']));
    }
    if (handle.isEmpty) {
      final handleText = _text(header['channelHandleText']);
      if (handleText.isNotEmpty) {
        handle = handleText;
      }
    }
    if (avatar.isEmpty) {
      avatar = bestImage(header['avatar'] ?? header['image']);
    }
    if (banner.isEmpty) {
      banner = bestImage(header['banner']);
    }
    if (subs.isEmpty) {
      subs = _text(header['subscriberCountText']);
    }
    if (videosCount.isEmpty) {
      videosCount = _text(header['videosCountText']);
    }
  }

  final tabs = <String>[];
  for (final tab in findAll(json, 'tabRenderer')) {
    if (tab is Map && tab['title'] != null) {
      final title = _text(tab['title']);
      if (title.isNotEmpty && !tabs.contains(title)) {
        tabs.add(title);
      }
    }
  }

  final sortChips = <({String label, String params})>[];
  for (final chip in findAll(json, 'chipCloudChipRenderer')) {
    final text = _text(safeNav(chip, ['text']));
    final params = safeNav(chip, [
      'navigationEndpoint',
      'continuationEndpoint',
      'continuationCommand',
      'token',
    ]);
    if (text.isNotEmpty && params is String) {
      sortChips.add((label: text, params: params));
    }
  }

  final videoItems = parseVideos(json).items;
  final shortItems = parseShorts(json);
  final currentItems = videoItems.isNotEmpty ? videoItems : shortItems;
  final continuation = continuationToken(json);

  return ChannelPageData(
    id: channelId,
    name: name.isNotEmpty ? name : channelId,
    handle: handle,
    avatarUrl: avatar,
    bannerUrl: banner,
    subscribersText: subs,
    videosCountText: videosCount,
    description: desc,
    tabs: tabs,
    currentTabItems: currentItems,
    continuation: continuation,
    sortChips: sortChips,
  );
}

PlaylistPageData parsePlaylistPage(dynamic json, String playlistId) {
  String title = 'Playlist';
  String author = '';
  String authorId = '';
  String thumb = '';
  String count = '';
  String desc = '';

  for (final header in [
    ...findAll(json, 'playlistHeaderRenderer'),
    ...findAll(json, 'pageHeaderViewModel'),
  ]) {
    if (header is! Map) continue;
    if (title == 'Playlist') {
      final t = _text(header['title']);
      if (t.isNotEmpty) title = t;
    }
    if (author.isEmpty) {
      author = _text(header['ownerText']);
    }
    if (authorId.isEmpty) {
      authorId = _channelId(header);
    }
    if (thumb.isEmpty) {
      thumb = bestImage(header['thumbnail'] ?? header['thumbnails']);
    }
    if (count.isEmpty) {
      count = _text(header['numVideosText'] ?? header['stats']);
    }
    if (desc.isEmpty) {
      desc = _text(header['descriptionText']);
    }
  }

  final videos = <VideoItem>[];
  final seen = <String>{};
  for (final renderer in [
    ...findAll(json, 'playlistVideoRenderer'),
    ...findAll(json, 'compactVideoRenderer'),
    ...findAll(json, 'videoRenderer'),
  ]) {
    if (renderer is! Map) continue;
    final id = renderer['videoId'] as String?;
    if (id == null || id.isEmpty || !seen.add(id)) continue;
    final parsed = parseVideos({'videoRenderer': renderer}).items;
    if (parsed.isNotEmpty) {
      videos.add(parsed.first);
    }
  }

  return PlaylistPageData(
    id: playlistId,
    title: title,
    author: author,
    authorId: authorId,
    thumbUrl: thumb,
    videoCountText: count,
    description: desc,
    videos: videos,
    continuation: continuationToken(json),
  );
}

String parseBrowseIdFromResolve(dynamic json) {
  for (final endpoint in findAll(json, 'browseEndpoint')) {
    if (endpoint is Map && endpoint['browseId'] is String) {
      return endpoint['browseId'] as String;
    }
  }
  return '';
}
