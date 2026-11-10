import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/innertube/clients.dart';
import 'package:hivetube/core/innertube/json_find.dart';
import 'package:hivetube/core/yt/yt_browse.dart';
import 'package:hivetube/core/yt/yt_charts.dart';
import 'package:hivetube/core/yt/yt_reel.dart';
import 'package:hivetube/core/yt/yt_search.dart';
import 'package:hivetube/core/yt/yt_rss.dart';

Future<void> main() async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  final http = InnertubeHttp(
    dio,
    InnertubeClients(
      jsonDecode(await File('assets/innertube_clients.json').readAsString())
          as Map<String, dynamic>,
    ),
  );
  Future<void> run(String name, Future<int> Function() action) async {
    try {
      stdout.writeln('$name: ${await action()}');
    } catch (error) {
      stdout.writeln('$name: FAILED ($error)');
    }
  }

  await run('Y1', () async {
    final result = await http.post('visitor_id', {});
    http.visitorData =
        safeNav(result, ['responseContext', 'visitorData']) as String?;
    return http.visitorData == null ? 0 : 1;
  });
  final browse = YtBrowse(http);
  final search = await YtSearch(http).videos('lofi hip hop');
  stdout.writeln('Y2: ${search.items.length}');
  final channels = search.items
      .map((e) => e.channelId)
      .where((id) => id.startsWith('UC'))
      .toSet();
  var rssSucceeded = false;
  for (final channel in channels) {
    try {
      final items = await YtRss(dio).uploads(channel);
      stdout.writeln('Y17: ${items.length} (channel $channel)');
      rssSucceeded = true;
      break;
    } catch (error) {
      stdout.writeln('Y17 channel $channel: FAILED ($error)');
    }
  }
  if (!rssSucceeded) {
    stdout.writeln('Y17: FAILED (no reachable feed from search results)');
  }
  final reel = await YtReel(http).fetch();
  stdout.writeln(
    'Y19: ${reel.items.length}; continuations: ${reel.continuationCount}',
  );
  await Future.wait([
    run('Y9', () async => (await browse.home()).items.length),
    run('Y10', () async => (await browse.live()).items.length),
    run('Y11', () async => (await browse.gaming()).items.length),
    run('Y14', () async => (await YtCharts(http).trending('US')).length),
  ]);
  dio.close();
}
