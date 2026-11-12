import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:hivetube/core/innertube/clients.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/innertube/json_find.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/yt_browse.dart';
import 'package:hivetube/core/yt/yt_charts.dart';
import 'package:hivetube/core/yt/yt_search.dart';
import 'package:hivetube/features/home/home_mixer.dart';
import 'package:hivetube/features/home/home_variety.dart';

Future<void> main() async {
  final clients = InnertubeClients(
    jsonDecode(await File('assets/innertube_clients.json').readAsString()),
  );
  const runs = [
    (name: 'Tamil', hl: 'ta', shown: {'ta'}),
    (name: 'Telugu', hl: 'te', shown: {'te'}),
    (name: 'English only', hl: 'en', shown: {'en'}),
  ];

  for (final run in runs) {
    final seed = DateTime.now().microsecondsSinceEpoch;
    final random = Random(seed);
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
      ),
    );
    final http = InnertubeHttp(dio, clients, hl: run.hl, gl: 'IN');
    final search = YtSearch(http);
    final browse = YtBrowse(http);
    final sources = <HomeSource>[];
    List<VideoItem> rank(List<VideoItem> items) => rankHomeItems(
      items,
      preferred: run.shown,
      hidden: const {'hi'},
      seen: const {},
      random: random,
    );
    void addSearch(String query) {
      String? params;
      final local = isLocalLanguageQuery(query, run.shown);
      sources.add(
        HomeSource(
          weight: local ? 3 : 1,
          transform: rank,
          fetch: (cursor) async {
            if (cursor != null) {
              return search.videos(query, params: params, continuation: cursor);
            }
            var page = await search.videos(query);
            if (page.searchDateFilters.isNotEmpty) {
              params =
                  page.searchDateFilters[random.nextInt(
                    page.searchDateFilters.length,
                  )];
              page = await search.videos(query, params: params);
            }
            if (page.continuation != null && random.nextBool()) {
              page = await search.videos(
                query,
                params: params,
                continuation: page.continuation,
              );
            }
            return page;
          },
        ),
      );
    }

    try {
      stdout.writeln(
        '\nHome smoke: ${run.name}; hl=${run.hl}; gl=IN; hidden=Hindi; seed=$seed; cache=bypassed',
      );
      final visitor = await http.post('visitor_id', {});
      http.visitorData =
          safeNav(visitor, ['responseContext', 'visitorData']) as String?;
      final queries = chooseHomeQueries(
        chip: 'All',
        hasHistory: false,
        localRatio: .6,
        shownLanguages: run.shown,
        random: random,
      );
      for (final query in queries) {
        addSearch(query);
      }
      sources.add(
        HomeSource(
          weight: 1,
          transform: rank,
          fetch: (cursor) => browse.home(continuation: cursor),
        ),
      );
      sources.addAll([
        HomeSource(
          weight: 1,
          transform: rank,
          fetch: (cursor) => browse.live(continuation: cursor),
        ),
        HomeSource(
          weight: 1,
          transform: rank,
          fetch: (cursor) => browse.gaming(continuation: cursor),
        ),
        HomeSource(
          weight: 1,
          transform: rank,
          fetch: (cursor) => browse.podcasts(continuation: cursor),
        ),
      ]);
      final mixer = HomeMixer(sources);
      await mixer.start();
      final items = await mixer.next(20);
      final scripts = <String, int>{};
      for (final language in [
        'ta',
        'te',
        'hi',
        'ml',
        'kn',
        'bn',
        'gu',
        'pa',
        'or',
        'ur',
        'en',
      ]) {
        scripts[language] = items
            .where(
              (item) =>
                  scriptLanguage('${item.title} ${item.channelName}') ==
                  language,
            )
            .length;
      }
      final preferredCount = items.where((item) {
        final text = '${item.title} ${item.channelName}';
        return run.shown.any((language) {
          if (language == 'en') return scriptLanguage(text) == 'en';
          return scriptLanguage(text) == language ||
              (languageTerms[language] ?? const []).any(
                text.toLowerCase().contains,
              );
        });
      }).length;
      final charts = rank(await YtCharts(http).trending('IN'));
      stdout.writeln(
        'Counts: items=${items.length}; scripts=$scripts; preferred-script-or-keyword=$preferredCount/${items.length}; filtered-Y14=${charts.length}',
      );
      for (final item in items.take(10)) {
        stdout.writeln('  ${item.title} | ${item.channelName}');
      }
    } catch (error) {
      stdout.writeln('FAILED: $error');
    } finally {
      dio.close(force: true);
    }
  }
}
