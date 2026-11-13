import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
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
import 'package:hivetube/core/yt/yt_search.dart';

Future<void> main() async {
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
    stdout.writeln('  VisitorData: ${http.visitorData?.substring(0, min(20, http.visitorData?.length ?? 0))}... OK');
  } catch (e) {
    stdout.writeln('  VisitorData failed: $e');
  }

  final browse = YtBrowse(http);
  final search = YtSearch(http);
  final next = YtNext(http);
  final reel = YtReel(http);
  final charts = YtCharts(http);

  final filter = ContentFilter(
    channelCache: ChannelLanguageCache.instance,
    registry: LanguageProfileRegistry.instance,
  );

  final preferred = {'ta', 'en'};
  final hidden = {'hi'};

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
    stdout.writeln('    -> Filter (feed): before=${items.length}, kept=${feed.items.length}');
    stdout.writeln('    -> Evaluate (strict single): before=${items.length}, kept=$keptCount, dropped=${items.length - keptCount}');
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
      stdout.writeln('       Sample: "${item.title}" | ch: "${item.channelName}" -> lang: ${res.finalLanguage}, kept: ${res.kept} (${res.reason})');
    }
  }

  // 1. browse FEwhat_to_watch
  stdout.writeln('\n2. Testing browse FEwhat_to_watch...');
  try {
    final res = await browse.home();
    stdout.writeln('  Status: OK, items: ${res.items.length}, continuation: ${res.continuation != null}');
    if (res.items.isEmpty) {
      final rawBrowse = await http.post('browse', {'browseId': 'FEwhat_to_watch'});
      final contents = rawBrowse['contents'];
      stdout.writeln('  contents type: ${contents.runtimeType}, keys: ${contents is Map ? contents.keys.toList() : null}');
      final rawStr = jsonEncode(rawBrowse);
      final renderers = RegExp(r'"([a-zA-Z0-9]+(?:Renderer|ViewModel))":').allMatches(rawStr).map((m) => m.group(1)!).toSet();
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
    stdout.writeln('  WatchInfo title: "${watchInfo.title}", related in watchInfo: ${watchInfo.related.items.length}');
    checkFilter('watchInfo:related', watchInfo.related.items);
  } catch (e) {
    stdout.writeln('  next.related FAILED: $e');
  }

  // 4. reel / reel_watch_sequence
  stdout.writeln('\n6. Testing reel/reel_watch_sequence (sequenceParams CA8%3D)...');
  try {
    final res = await reel.fetch(count: 10);
    stdout.writeln('  Status: OK, items: ${res.items.length}');
    for (final s in res.items.take(3)) {
      stdout.writeln('    Short ID: ${s.id}, title: ${s.title}, channel: ${s.channelName}');
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
    stdout.writeln('    Video: itag=${vFormat?.itag}, ${vFormat?.height}p, mime=${vFormat?.mimeType}');
    stdout.writeln('    Audio: itag=${aFormat?.itag}, mime=${aFormat?.mimeType}');
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
      final sStreams = await cache.resolve(sid, PlaybackMode.short, quality: 720);
      final vFormat = sStreams.videos.firstOrNull;
      final aFormat = sStreams.audio;
      stdout.writeln('    Short Video: itag=${vFormat?.itag}, ${vFormat?.height}p, mime=${vFormat?.mimeType}');
      stdout.writeln('    Short Audio: itag=${aFormat?.itag}, mime=${aFormat?.mimeType}');
    } catch (e) {
      stdout.writeln('  Short stream ($sid) resolution FAILED: $e');
    }
  }

  // 9. Home Feed Simulation: fetch home queries, filter, and count kept
  stdout.writeln('\n9. Testing simulated Home feed...');
  try {
    final homeQueries = LanguageProfileRegistry.instance.buildQueries(
      shownLanguages: preferred,
      chip: 'All',
      localRatio: 0.6,
      random: Random(42),
    );
    stdout.writeln('  Home queries (${homeQueries.length}): $homeQueries');
    final homeItems = <VideoItem>[];
    for (final q in homeQueries.take(3)) {
      final res = await search.videos(q);
      final kept = filter.filterVideos(
        res.items,
        shownLanguages: preferred,
        hiddenLanguages: hidden,
        strictHome: true,
        source: 'search:$q',
      ).items;
      stdout.writeln('    Query "$q": fetched=${res.items.length}, kept=${kept.length}');
      homeItems.addAll(kept);
    }
    stdout.writeln('  Total Home kept items: ${homeItems.length}');
  } catch (e) {
    stdout.writeln('  Home feed simulation FAILED: $e');
  }

  exit(0);
}
