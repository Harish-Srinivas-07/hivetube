import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:hivetube/core/content/caption_probe.dart';
import 'package:hivetube/core/content/channel_language_cache.dart';
import 'package:hivetube/core/content/content_filter.dart';
import 'package:hivetube/core/content/language_profile.dart';
import 'package:hivetube/core/innertube/clients.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/streams/net_family.dart';
import 'package:hivetube/core/streams/player_client.dart';
import 'package:hivetube/core/streams/stream_cache.dart';
import 'package:hivetube/core/streams/stream_selector.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/yt_browse.dart';
import 'package:hivetube/core/yt/yt_charts.dart';
import 'package:hivetube/core/yt/yt_next.dart';
import 'package:hivetube/core/yt/yt_reel.dart';
import 'package:hivetube/core/yt/yt_rss.dart';
import 'package:hivetube/core/yt/yt_search.dart';

Future<void> main(List<String> args) async {
  stdout.writeln('=== HIVETUBE LIVE TRAFFIC PROBE ===');

  // Load language profiles
  await LanguageProfileRegistry.instance.ensureLoaded();

  // Load clients
  final clientsRaw = await File('assets/innertube_clients.json').readAsString();
  final clients = InnertubeClients(jsonDecode(clientsRaw));

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  // App settings defaults: hl=en, gl=IN (or from settings)
  final http = InnertubeHttp(dio, clients, hl: 'en', gl: 'IN');

  // Visitor data
  stdout.writeln('\n1. Fetching visitorData...');
  try {
    final vResult = await http.post('visitor_id', {});
    http.visitorData = vResult['responseContext']?['visitorData'];
    stdout.writeln(
      '  VisitorData: ${http.visitorData?.substring(0, min(20, http.visitorData?.length ?? 0))}... OK',
    );
  } catch (e) {
    stdout.writeln('  VisitorData failed: $e');
  }

  final browse = YtBrowse(http);
  final search = YtSearch(http);
  final next = YtNext(http);
  final reel = YtReel(http);
  final charts = YtCharts(http);
  var searchSample = <VideoItem>[];

  final filter = ContentFilter(
    channelCache: ChannelLanguageCache.instance,
    registry: LanguageProfileRegistry.instance,
  );

  final preferred = {'ta', 'en'};
  final hidden = {'hi'};
  String errorLabel(Object error) => error is DioException
      ? 'HTTP ${error.response?.statusCode ?? error.type}: ${error.message}'
      : error.toString();

  void checkFilter(String name, List<VideoItem> items) {
    int keptCount = 0;
    final reasons = <String, int>{};
    for (final item in items) {
      final res = filter.evaluate(
        id: item.id,
        title: item.title,
        channelId: item.channelId,
        channelName: item.channelName,
        shownLanguages: preferred,
        hiddenLanguages: hidden,
        strictHome: true,
      );
      if (res.kept) {
        keptCount++;
      } else {
        reasons[res.reason] = (reasons[res.reason] ?? 0) + 1;
      }
    }
    final feed = filter.filterVideos(
      items,
      shownLanguages: preferred,
      hiddenLanguages: hidden,
      strictHome: true,
      source: name,
    );
    stdout.writeln(
      '    -> Filter (feed): before=${items.length}, kept=${feed.items.length}',
    );
    stdout.writeln(
      '    -> Evaluate (strict single): before=${items.length}, kept=$keptCount, dropped=${items.length - keptCount}',
    );
    if (reasons.isNotEmpty) {
      stdout.writeln('       Drop reasons: $reasons');
    }
    for (final item in items.take(3)) {
      final res = filter.evaluate(
        id: item.id,
        title: item.title,
        channelId: item.channelId,
        channelName: item.channelName,
        shownLanguages: preferred,
        hiddenLanguages: hidden,
        strictHome: true,
      );
      stdout.writeln(
        '       Sample: "${item.title}" | ch: "${item.channelName}" -> lang: ${res.finalLanguage}, kept: ${res.kept} (${res.reason})',
      );
    }
  }

  // 1. browse FEwhat_to_watch
  stdout.writeln('\n2. Testing browse FEwhat_to_watch...');
  try {
    final res = await browse.home();
    stdout.writeln(
      '  Status: OK, items: ${res.items.length}, continuation: ${res.continuation != null}',
    );
    if (res.items.isEmpty) {
      final rawBrowse = await http.post('browse', {
        'browseId': 'FEwhat_to_watch',
      });
      final contents = rawBrowse['contents'];
      stdout.writeln(
        '  contents type: ${contents.runtimeType}, keys: ${contents is Map ? contents.keys.toList() : null}',
      );
      final rawStr = jsonEncode(rawBrowse);
      final renderers = RegExp(
        r'"([a-zA-Z0-9]+(?:Renderer|ViewModel))":',
      ).allMatches(rawStr).map((m) => m.group(1)!).toSet();
      stdout.writeln('  Renderers found in browse: ${renderers.toList()}');
    }
    checkFilter('browse:home', res.items);
  } catch (e) {
    stdout.writeln('  browse FEwhat_to_watch FAILED: $e');
  }

  // 2. search (language-profile query and Shorts query)
  stdout.writeln('\n3. Testing search ("tamil latest songs")...');
  try {
    final res = await search.videos('tamil latest songs');
    searchSample = res.items;
    stdout.writeln('  Status: OK, items: ${res.items.length}');
    checkFilter('search:ta', res.items);
  } catch (e) {
    stdout.writeln('  search videos FAILED: $e');
  }

  stdout.writeln('\n4. Testing search Shorts (params EgIQCQ%3D%3D)...');
  try {
    final res = await search.shortsPage('trending shorts');
    stdout.writeln('  Status: OK, items: ${res.items.length}');
    final asVideos = [
      for (final s in res.items)
        VideoItem(
          id: s.id,
          title: s.title ?? '',
          channelId: s.channelId ?? '',
          channelName: s.channelName ?? '',
          channelAvatarUrl: '',
          thumbUrl: s.thumbUrl,
          isShort: true,
        ),
    ];
    checkFilter('search:shorts', asVideos);
  } catch (e) {
    stdout.writeln('  search shortsPage FAILED: $e');
  }

  // 3. next (related of known video)
  const knownVideoId = 'aqz-KE-bpKQ'; // Big Buck Bunny / common test ID
  stdout.writeln('\n5. Testing next (related of $knownVideoId)...');
  try {
    final res = await next.related(knownVideoId);
    stdout.writeln('  Status: OK, items: ${res.items.length}');
    checkFilter('next:related', res.items);
    final watchInfo = await next.watch(knownVideoId);
    stdout.writeln(
      '  WatchInfo title: "${watchInfo.title}", related in watchInfo: ${watchInfo.related.items.length}',
    );
    checkFilter('watchInfo:related', watchInfo.related.items);
  } catch (e) {
    stdout.writeln('  next.related FAILED: $e');
  }

  // 4. reel / reel_watch_sequence
  stdout.writeln(
    '\n6. Testing reel/reel_watch_sequence (sequenceParams CA8%3D)...',
  );
  try {
    final res = await reel.fetch(count: 10);
    stdout.writeln('  Status: OK, items: ${res.items.length}');
    for (final s in res.items.take(3)) {
      stdout.writeln(
        '    Short ID: ${s.id}, title: ${s.title}, channel: ${s.channelName}',
      );
    }
    final asVideos = [
      for (final s in res.items)
        VideoItem(
          id: s.id,
          title: s.title ?? '',
          channelId: s.channelId ?? '',
          channelName: s.channelName ?? '',
          channelAvatarUrl: '',
          thumbUrl: s.thumbUrl,
          isShort: true,
        ),
    ];
    checkFilter('reel:fetch', asVideos);
  } catch (e) {
    stdout.writeln('  reel.fetch FAILED: $e');
  }

  // 5. chart browse
  stdout.writeln('\n7. Testing chart browse (gl=IN)...');
  try {
    final res = await charts.trending('IN');
    stdout.writeln('  Status: OK, items: ${res.length}');
    checkFilter('charts:trending', res);
  } catch (e) {
    stdout.writeln('  charts.trending FAILED: $e');
  }

  // 6. player (stream resolution for one video and one Short)
  stdout.writeln('\n8. Testing stream resolution (player endpoint)...');
  final network = NetworkFamily();
  final playerClient = PlayerClient(
    network,
    clients,
    () => http.visitorData,
    () async {
      final v = await http.post('visitor_id', {});
      http.visitorData = v['responseContext']?['visitorData'];
    },
  );
  final cache = StreamCache(playerClient);

  // Video resolution
  try {
    stdout.writeln('  Resolving video stream ($knownVideoId)...');
    final vStreams = await cache.resolve(knownVideoId, PlaybackMode.video);
    final vFormat = vStreams.videos.firstOrNull;
    final aFormat = vStreams.audio;
    stdout.writeln(
      '    Video: itag=${vFormat?.itag}, ${vFormat?.height}p, mime=${vFormat?.mimeType}',
    );
    stdout.writeln(
      '    Audio: itag=${aFormat?.itag}, mime=${aFormat?.mimeType}',
    );
  } catch (e) {
    stdout.writeln('  Video stream resolution FAILED: $e');
  }

  // Short resolution (resolve 3 real short IDs)
  final shortIds = <String>['vX1zLqQ-c88'];
  try {
    final reelSample = await reel.fetch(count: 3);
    if (reelSample.items.isNotEmpty) {
      shortIds.clear();
      shortIds.addAll(reelSample.items.map((e) => e.id).take(3));
    }
  } catch (_) {}

  for (final sid in shortIds) {
    try {
      stdout.writeln('  Resolving short stream ($sid)...');
      final sStreams = await cache.resolve(
        sid,
        PlaybackMode.short,
        quality: 720,
      );
      final vFormat = sStreams.videos.firstOrNull;
      final aFormat = sStreams.audio;
      stdout.writeln(
        '    Short Video: itag=${vFormat?.itag}, ${vFormat?.height}p, mime=${vFormat?.mimeType}',
      );
      stdout.writeln(
        '    Short Audio: itag=${aFormat?.itag}, mime=${aFormat?.mimeType}',
      );
    } catch (e) {
      stdout.writeln('  Short stream ($sid) resolution FAILED: $e');
    }
  }

  // 9. Live Home path: Y9, RSS, language-profile searches, ASR probe, strict filter.
  stdout.writeln('\n9. Testing live Home feed path...');
  final captionProbe = CaptionProbeService(http, ChannelLanguageCache.instance);
  final shownBySource = <String, List<VideoItem>>{};
  final videoById = <String, VideoItem>{};

  Future<void> processSource(String source, List<VideoItem> fetched) async {
    final prefiltered = filter
        .filterVideos(
          fetched,
          shownLanguages: preferred,
          hiddenLanguages: hidden,
          strictHome: true,
          source: source,
        )
        .items;
    final included = prefiltered.map((item) => item.id).toSet();
    final candidates = [
      ...prefiltered,
      ...fetched.where(
        (item) =>
            !included.contains(item.id) &&
            filter.isAmbiguous(
              title: item.title,
              channelId: item.channelId,
              channelName: item.channelName,
            ),
      ),
    ];
    final ambiguous = candidates
        .where(
          (item) => filter.isAmbiguous(
            title: item.title,
            channelId: item.channelId,
            channelName: item.channelName,
          ),
        )
        .take(20)
        .map(
          (item) => (
            videoId: item.id,
            channelId: item.channelId,
            channelName: item.channelName,
          ),
        )
        .toList();
    Map<String, String?> probeResults = const {};
    if (ambiguous.isNotEmpty) {
      probeResults = await captionProbe.probeBatch(ambiguous, asrOnly: true);
      stdout.writeln(
        '    VISIONOS ASR results: ${ambiguous.map((item) => '${item.videoId}=${probeResults[item.videoId] ?? 'no-track'}').join(', ')}',
      );
    }
    final result = filter
        .filterVideos(
          candidates,
          shownLanguages: preferred,
          hiddenLanguages: hidden,
          strictHome: true,
          probeResults: probeResults,
          source: '$source:after_probe',
        )
        .items;
    shownBySource[source] = result;
    for (final item in result) {
      videoById.putIfAbsent(item.id, () => item);
    }
    stdout.writeln(
      '  $source: fetched=${fetched.length} -> after_filter=${prefiltered.length} -> '
      'probe=${probeResults.values.whereType<String>().length}/${ambiguous.length} classified -> '
      'shown=${result.length}',
    );
  }

  // Signed-out Y9 is expected to be empty, but measure its raw and filtered counts.
  try {
    final home = await browse.home();
    await processSource('browse:FEwhat_to_watch', home.items);
  } catch (e) {
    stdout.writeln('  browse:FEwhat_to_watch ERROR: ${errorLabel(e)}');
  }

  // Use explicit channel IDs when supplied; otherwise hit the three RSS smoke
  // channels used by this repository, all without login.
  final suppliedChannels = args.where((arg) => arg.startsWith('UC')).take(6);
  final rssChannels = suppliedChannels.isEmpty
      ? [
          ('UCK8sQmJBp8GCxrOtXWBpyEA', '@Google'),
          ('UCwXdFgeE9KYzlDdR7TG9cMw', '@flutterdev'),
          ('UCBR8-60-B28hp2BmDPdntcQ', '@YouTube'),
          ...searchSample
              .where((item) => item.channelId.startsWith('UC'))
              .map((item) => (item.channelId, item.channelName))
              .take(3),
        ]
      : suppliedChannels.map((id) => (id, id)).toList();
  for (final (channelId, channelName) in rssChannels) {
    final source = 'rss:$channelName';
    try {
      final response = await dio.get<String>(
        'https://www.youtube.com/feeds/videos.xml',
        queryParameters: {'channel_id': channelId},
        options: Options(responseType: ResponseType.plain),
      );
      final all = parseRss(response.data ?? '');
      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      final fresh = all
          .where(
            (item) =>
                item.publishedAt != null &&
                !item.publishedAt!.isBefore(cutoff) &&
                !item.publishedAt!.isAfter(DateTime.now()),
          )
          .toList();
      stdout.writeln(
        '  $source HTTP ${response.statusCode}: fetched=${all.length}, fresh14d=${fresh.length}',
      );
      await processSource(source, fresh);
    } catch (e) {
      stdout.writeln('  $source ERROR: ${errorLabel(e)}');
      try {
        final fallback = await browse.channelVideos(channelId);
        final fallbackSource = 'Y7:$channelName';
        stdout.writeln(
          '  $fallbackSource fallback fetched=${fallback.items.length}',
        );
        await processSource(fallbackSource, fallback.items);
      } catch (fallbackError) {
        stdout.writeln('  Y7:$channelName ERROR: ${errorLabel(fallbackError)}');
      }
    }
  }

  final homeQueries = LanguageProfileRegistry.instance.buildQueries(
    shownLanguages: preferred,
    chip: 'All',
    localRatio: 0.6,
    random: Random(42),
  );
  stdout.writeln('  Home search queries (${homeQueries.length}): $homeQueries');
  for (final query in homeQueries.take(4)) {
    final source = 'search:$query';
    try {
      var page = await search.videos(query);
      var fetchedCount = page.items.length;
      var requestCount = 1;
      String? activeParams;
      if (page.searchDateFilters.isNotEmpty) {
        activeParams = page.searchDateFilters.length > 1
            ? page.searchDateFilters[1]
            : page.searchDateFilters.first;
        page = await search.videos(query, params: activeParams);
        fetchedCount += page.items.length;
        requestCount++;
      }
      if (page.searchSortParams.isNotEmpty) {
        activeParams = page.searchSortParams.first;
        page = await search.videos(query, params: activeParams);
        fetchedCount += page.items.length;
        requestCount++;
      }
      stdout.writeln(
        '  $source requests=$requestCount fetched_across_requests=$fetchedCount final_page=${page.items.length} params=$activeParams',
      );
      await processSource(source, page.items);
      if (videoById.isNotEmpty) break;
    } catch (e) {
      stdout.writeln('  $source ERROR: ${errorLabel(e)}');
    }
  }

  final shown = videoById.values.toList();
  if (shown.isEmpty) {
    final counts = shownBySource.map(
      (source, items) => MapEntry(source, items.length),
    );
    stdout.writeln('FAIL: strict filter | sources=$counts, no visible videos');
  } else {
    final sources = shownBySource.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList();
    final first3 = shown
        .take(3)
        .map((item) => '${item.id}: ${item.title}')
        .join('; ');
    stdout.writeln(
      'PROOF: ${shown.length} videos | client=VISIONOS | sources=$sources | first3=$first3',
    );
  }

  exit(0);
}
