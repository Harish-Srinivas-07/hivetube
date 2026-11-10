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
  await Future.wait([
    run('Y9', () async => (await browse.home()).items.length),
    run('Y10', () async => (await browse.live()).items.length),
    run('Y11', () async => (await browse.gaming()).items.length),
    run('Y14', () async => (await YtCharts(http).trending('US')).length),
    run('Y19', () async => (await YtReel(http).shorts()).length),
    run(
      'Y2',
      () async => (await YtSearch(http).videos('lofi hip hop')).items.length,
    ),
  ]);
  dio.close();
}
