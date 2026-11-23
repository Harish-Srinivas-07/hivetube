import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hivetube/core/innertube/clients.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/innertube/json_find.dart';
import 'package:hivetube/core/yt/yt_next.dart';
import 'package:hivetube/core/yt/yt_comments.dart';
import 'package:hivetube/core/streams/player_client.dart';
import 'package:hivetube/core/streams/net_family.dart';

Future<void> main() async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  final clients = InnertubeClients(
    jsonDecode(await File('assets/innertube_clients.json').readAsString()),
  );
  final http = InnertubeHttp(dio, clients, hl: 'en', gl: 'IN');
  try {
    final visitor = await http.post('visitor_id', {});
    http.visitorData =
        safeNav(visitor, ['responseContext', 'visitorData']) as String?;
    final network = NetworkFamily();
    final playerClient = PlayerClient(
      network,
      clients,
      () => http.visitorData,
      () async {},
      hl: http.hl,
      gl: http.gl,
    );
    for (final id in ['jNQXAC9IVRw', 'aqz-KE-bpKQ', 'dQw4w9WgXcQ']) {
      try {
        final info = await YtNext(http).watch(id);
        final comments = info.commentsToken == null
            ? null
            : await YtComments(http).page(info.commentsToken!);
        var tracks = 0;
        try {
          final player = await playerClient.request(id, 'VISIONOS');
          tracks =
              findAll(
                player,
                'captionTracks',
              ).whereType<List>().firstOrNull?.length ??
              0;
        } catch (_) {}
        stdout.writeln(
          '$id title=${info.title} likes=${info.likes} related=${info.related.items.length} chips=${info.chips.keys.toList()} chapters=${info.chapters.length} captions=$tracks comments=${comments?.items.length ?? 0} reply=${comments?.items.any((v) => v.replyToken != null) ?? false}',
        );
      } catch (e) {
        stdout.writeln('$id FAILED: $e');
      }
    }
    network.close();
  } finally {
    dio.close(force: true);
  }
}
