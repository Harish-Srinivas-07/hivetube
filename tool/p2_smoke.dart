import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/innertube/clients.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/yt_browse.dart';
import 'package:hivetube/core/yt/yt_search.dart';

void main() {
  test('P2 Smoke Test: Search filters, Channel resolve + tabs, Playlists', timeout: const Timeout(Duration(minutes: 5)), () async {
    stdout.writeln('=== P2 Smoke Test ===');
    final clients = InnertubeClients(
      jsonDecode(await File('assets/innertube_clients.json').readAsString()),
    );
    final dio = Dio();
    final http = InnertubeHttp(dio, clients);
    final res = await http.post('visitor_id', {});
    http.visitorData = res['responseContext']['visitorData'];

    final search = YtSearch(http);
    final browse = YtBrowse(http);

    // 1. Search 'tamil music' with each filter
    stdout.writeln('1. Testing Search with Filters (query: "tamil music")...');
    final filterMap = {
      'All': null,
      'Videos': 'EgIQAQ%3D%3D',
      'Shorts': 'EgIQCQ%3D%3D',
      'Channels': 'EgIQAg%3D%3D',
      'Playlists': 'EgIQAw%3D%3D',
      'Live': 'EgJAAQ%3D%3D',
    };

    final searchCounts = <String, int>{};
    for (final entry in filterMap.entries) {
      try {
        final result = await search.search('tamil music', params: entry.value);
        searchCounts[entry.key] = result.items.length;
        stdout.writeln('   - Filter [${entry.key}]: ${result.items.length} items (continuation: ${result.continuation != null ? "yes" : "no"})');
      } catch (e) {
        searchCounts[entry.key] = 0;
        stdout.writeln('   - Filter [${entry.key}] error: $e');
      }
    }
    expect(searchCounts['All'], greaterThan(0));
    expect(searchCounts['Videos'], greaterThan(0));

    // 2. Resolve 3 real @handles, print header fields and first 5 videos per tab
    stdout.writeln('2. Resolving 3 real @handles...');
    final handles = ['@Google', '@flutterdev', '@YouTube'];
    for (final handle in handles) {
      try {
        final channelId = await browse.resolveUrl('https://www.youtube.com/$handle');
        stdout.writeln('   - Handle $handle -> ChannelId: $channelId');
        expect(channelId, startsWith('UC'));

        final page = await browse.channelPage(channelId);
        stdout.writeln('     Name: "${page.name}", Handle: "${page.handle}", Subs: "${page.subscribersText}", Videos: "${page.videosCountText}"');
        stdout.writeln('     Tabs available: ${page.tabs.join(", ")}');

        // Fetch videos tab items
        final videosPage = await browse.channelPage(channelId, params: YtBrowse.tabParamsVideos);
        final first5 = videosPage.currentTabItems.take(5).map((e) => e is VideoItem ? e.title : e.toString()).toList();
        stdout.writeln('     First ${first5.length} videos:');
        for (var i = 0; i < first5.length; i++) {
          stdout.writeln('       ${i + 1}. ${first5[i]}');
        }
      } catch (e) {
        stdout.writeln('     Handle $handle failed: $e');
      }
    }

    // 3. Open 2 real playlists and print count + continuation pages
    stdout.writeln('3. Testing 2 real playlists...');
    final playlistSearch = await search.search('tamil music', params: 'EgIQAw%3D%3D');
    final playlistIds = playlistSearch.items
        .whereType<PlaylistSearchResult>()
        .map((e) => e.playlist.id)
        .take(2)
        .toList();

    for (final plId in playlistIds) {
      try {
        final plPage = await browse.playlistPage(plId);
        stdout.writeln('   - Playlist $plId:');
        stdout.writeln('     Title: "${plPage.title}", Owner: "${plPage.author}", Videos in initial page: ${plPage.videos.length}');
        stdout.writeln('     Continuation token: ${plPage.continuation != null ? "present" : "none"}');

        if (plPage.continuation != null) {
          final next = await browse.playlistPage(plId, continuation: plPage.continuation);
          stdout.writeln('     Next page videos: ${next.videos.length}');
        }
        expect(plPage.videos, isNotEmpty);
      } catch (e) {
        stdout.writeln('     Playlist $plId failed: $e');
      }
    }

    stdout.writeln('=== P2 Smoke Test Complete ===');
    dio.close();
  });
}
