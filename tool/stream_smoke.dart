import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hivetube/core/innertube/clients.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/streams/net_family.dart';
import 'package:hivetube/core/streams/player_client.dart';
import 'package:hivetube/core/streams/relay_server.dart';
import 'package:hivetube/core/streams/stream_cache.dart';
import 'package:hivetube/core/streams/stream_selector.dart';
import 'package:hivetube/core/yt/yt_reel.dart';
import 'package:hivetube/core/yt/yt_search.dart';

Future<void> main() async {
  final clients = InnertubeClients(
    jsonDecode(await File('assets/innertube_clients.json').readAsString()),
  );
  final dio = Dio();
  final http = InnertubeHttp(dio, clients);
  Future<void> visitor() async {
    final result = await http.post('visitor_id', {});
    http.visitorData = result['responseContext']['visitorData'];
  }

  await visitor();
  final shorts = await YtReel(http).fetch(count: 1);
  final music = await YtSearch(http).videos('music official audio');
  final samples = <(String, String, PlaybackMode)>[
    ('normal', 'aqz-KE-bpKQ', PlaybackMode.video),
    if (shorts.items.isNotEmpty)
      ('short', shorts.items.first.id, PlaybackMode.short),
    if (music.items.isNotEmpty)
      ('music', music.items.first.id, PlaybackMode.audio),
  ];
  final network = NetworkFamily();
  final client = PlayerClient(
    network,
    clients,
    () => http.visitorData,
    visitor,
  );
  final cache = StreamCache(client);
  final relay = RelayServer(network, clients['VISIONOS']['ua']);
  for (final (label, id, mode) in samples) {
    try {
      final result = await cache.resolve(id, mode);
      final video = mode == PlaybackMode.audio
          ? null
          : result.videos.firstOrNull;
      final audio = result.audio!;
      stdout.writeln(
        '$label $id: video=${video == null ? 'none' : '${video.itag}/${video.height}p'} audio=${audio.itag}; probe video=${video == null
            ? 'n/a'
            : video.length > 1064960
            ? 'past 1 MiB, >=16 KiB OK'
            : 'from 0, >=16 KiB OK'}; audio=${audio.length > 1064960 ? 'past 1 MiB, >=16 KiB OK' : 'from 0, >=16 KiB OK'}',
      );
      final format = video ?? audio;
      final url = await relay.register(format);
      final end = (5 * 1024 * 1024 - 1).clamp(0, format.length - 1);
      final timer = Stopwatch()..start();
      final request = await HttpClient().getUrl(url);
      request.headers.set('Range', 'bytes=0-$end');
      final response = await request.close();
      var bytes = 0;
      await for (final chunk in response) {
        bytes += chunk.length;
      }
      timer.stop();
      stdout.writeln(
        '$label relay: HTTP ${response.statusCode} bytes=$bytes seconds=${(timer.elapsedMilliseconds / 1000).toStringAsFixed(2)} MiB/s=${(bytes / 1048576 / (timer.elapsedMilliseconds / 1000)).toStringAsFixed(2)}',
      );
    } catch (e) {
      stdout.writeln('$label $id: FAILED $e');
    }
  }
  await relay.close();
  network.close();
  dio.close();
}
