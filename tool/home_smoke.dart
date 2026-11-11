import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hivetube/core/innertube/clients.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/innertube/json_find.dart';
import 'package:hivetube/core/yt/yt_charts.dart';
import 'package:hivetube/core/yt/yt_reel.dart';
import 'package:hivetube/core/yt/yt_search.dart';

Future<void> main() async {
  final clients = InnertubeClients(
    jsonDecode(await File('assets/innertube_clients.json').readAsString()),
  );
  for (final (hl, gl) in [('ta', 'IN'), ('hi', 'IN'), ('en', 'US')]) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final http = InnertubeHttp(dio, clients, hl: hl, gl: gl);
    stdout.writeln('\n--- hl=$hl gl=$gl ---');
    try {
      final visitor = await http.post('visitor_id', {});
      http.visitorData =
          safeNav(visitor, ['responseContext', 'visitorData']) as String?;
      final search = await YtSearch(http).videos('music');
      stdout.writeln('Y2 music (${search.items.length}):');
      for (final item in search.items.take(5)) {
        stdout.writeln('  ${item.title} | ${item.channelName}');
      }
      final charts = await YtCharts(http).trending(gl);
      stdout.writeln('Y14 charts (${charts.length}):');
      for (final item in charts.take(5)) {
        stdout.writeln('  ${item.title} | ${item.channelName}');
      }
      final reel = YtReel(http);
      final page = await reel.fetch();
      final metadata = await Future.wait(
        page.items.take(5).map((item) => reel.metadata(item.id)),
      );
      stdout.writeln('Y19 shorts (${page.items.length}):');
      for (var i = 0; i < metadata.length; i++) {
        final item = metadata[i];
        stdout.writeln(
          '  ${item?.title ?? '[unresolved ${page.items[i].id}]'} | ${item?.channelName ?? '[unresolved]'}',
        );
      }
    } catch (error) {
      stdout.writeln('FAILED: $error');
    }
    dio.close();
  }
}
