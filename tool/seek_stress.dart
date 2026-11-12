import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/innertube/clients.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/streams/net_family.dart';
import 'package:hivetube/core/streams/player_client.dart';
import 'package:hivetube/core/streams/relay_server.dart';
import 'package:hivetube/core/streams/stream_cache.dart';
import 'package:hivetube/core/streams/stream_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'seek stress test across 3 videos (30 seeks each)',
    timeout: const Timeout(Duration(minutes: 10)),
    () async {
      HttpOverrides.global = null;
      MediaKit.ensureInitialized();

      final clients = InnertubeClients(
        jsonDecode(await File('assets/innertube_clients.json').readAsString()),
      );
      final dio = Dio();
      final http = InnertubeHttp(dio, clients);
      final result = await http.post('visitor_id', {});
      http.visitorData = result['responseContext']['visitorData'];

      final network = NetworkFamily();
      final client = PlayerClient(
        network,
        clients,
        () => http.visitorData,
        () async {},
      );
      final cache = StreamCache(client);
      final relay = RelayServer(network, clients['VISIONOS']['ua']);
      final history = EmptyHistoryRepo();
      final service = PlaybackService(cache, relay, history);
      if (service.player.platform is NativePlayer) {
        await (service.player.platform as NativePlayer).setProperty('ao', 'null');
      }

      final videos = [
        ('aqz-KE-bpKQ', 'Normal (10m)'),
        ('7RuRlNAn-UQ', 'Short (<60s)'),
        ('094y1Z2wpJg', 'Long (20m+)'),
      ];

      int totalPass = 0;
      int totalFail = 0;

      for (final (videoId, label) in videos) {
        stdout.writeln('=== Testing $label videoId=$videoId ===');
        final isShort = label.contains('Short');
        await service.play(
          PlayRequest(
            videoId: videoId,
            mode: isShort ? PlaybackMode.short : PlaybackMode.video,
            play: true,
          ),
        );

        final readySw = Stopwatch()..start();
        while ((service.state.duration == Duration.zero ||
                (service.state.status != PlayerStatus.playing &&
                    service.state.status != PlayerStatus.ready) ||
                service.state.position <= const Duration(seconds: 1)) &&
            readySw.elapsedMilliseconds < 30000) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        final duration = service.state.duration;
        stdout.writeln(
          'Loaded $label: duration=${duration.inSeconds}s pos=${service.state.position.inSeconds}s status=${service.state.status}',
        );
        if (duration == Duration.zero) {
          stdout.writeln('FAILED to load $videoId within 15s');
          totalFail += 30;
          continue;
        }

        final dSec = duration.inSeconds;

        // Plan 30 seeks:
        // 1-5: forward seeks while playing
        // 6-10: backward seeks while playing
        // 11-15: seek to 0, near end, mid while paused
        // 16-20: rapid bursts of 5 seeks in 1 s (playing)
        // 21-25: rapid bursts of 5 seeks in 1 s (paused)
        // 26-30: mixed edge seeks (near end, 0, boundary)
        final seekTargets = <({Duration target, bool pauseBefore, bool burst})>[
          (
            target: Duration(seconds: (dSec * 0.1).round()),
            pauseBefore: false,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.2).round()),
            pauseBefore: false,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.35).round()),
            pauseBefore: false,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.5).round()),
            pauseBefore: false,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.7).round()),
            pauseBefore: false,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.4).round()),
            pauseBefore: false,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.25).round()),
            pauseBefore: false,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.15).round()),
            pauseBefore: false,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.05).round()),
            pauseBefore: false,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.3).round()),
            pauseBefore: false,
            burst: false,
          ),
          // Paused seeks
          (target: Duration.zero, pauseBefore: true, burst: false),
          (
            target: Duration(seconds: (dSec * 0.95).round()),
            pauseBefore: true,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.5).round()),
            pauseBefore: true,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.1).round()),
            pauseBefore: true,
            burst: false,
          ),
          (target: Duration.zero, pauseBefore: true, burst: false),
          // Burst while playing (16-20)
          (
            target: Duration(seconds: (dSec * 0.2).round()),
            pauseBefore: false,
            burst: true,
          ),
          (
            target: Duration(seconds: (dSec * 0.4).round()),
            pauseBefore: false,
            burst: true,
          ),
          (
            target: Duration(seconds: (dSec * 0.6).round()),
            pauseBefore: false,
            burst: true,
          ),
          (
            target: Duration(seconds: (dSec * 0.3).round()),
            pauseBefore: false,
            burst: true,
          ),
          (
            target: Duration(seconds: (dSec * 0.5).round()),
            pauseBefore: false,
            burst: true,
          ),
          // Burst while paused (21-25)
          (
            target: Duration(seconds: (dSec * 0.15).round()),
            pauseBefore: true,
            burst: true,
          ),
          (
            target: Duration(seconds: (dSec * 0.35).round()),
            pauseBefore: true,
            burst: true,
          ),
          (
            target: Duration(seconds: (dSec * 0.75).round()),
            pauseBefore: true,
            burst: true,
          ),
          (
            target: Duration(seconds: (dSec * 0.25).round()),
            pauseBefore: true,
            burst: true,
          ),
          (
            target: Duration(seconds: (dSec * 0.85).round()),
            pauseBefore: true,
            burst: true,
          ),
          // Mixed edge seeks (26-30)
          (
            target: Duration(seconds: (dSec * 0.98).round()),
            pauseBefore: false,
            burst: false,
          ),
          (target: Duration.zero, pauseBefore: false, burst: false),
          (
            target: Duration(seconds: (dSec * 0.5).round()),
            pauseBefore: false,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.99).round()),
            pauseBefore: true,
            burst: false,
          ),
          (
            target: Duration(seconds: (dSec * 0.02).round()),
            pauseBefore: false,
            burst: false,
          ),
        ];

        for (var i = 0; i < seekTargets.length; i++) {
          final st = seekTargets[i];
          if (st.pauseBefore) {
            await service.pause();
            final pauseSw = Stopwatch()..start();
            while (service.player.state.playing && pauseSw.elapsedMilliseconds < 500) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
            }
          } else {
            await service.resume();
            final playSw = Stopwatch()..start();
            while (!service.player.state.playing && playSw.elapsedMilliseconds < 500) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final expectedPlaying = !st.pauseBefore;

          stdout.writeln(
            'Seek #${i + 1}/30 to ${st.target.inSeconds}s (paused=${st.pauseBefore}, burst=${st.burst})',
          );
          final sw = Stopwatch()..start();
          await service.seek(st.target);

          if (st.burst) {
            // rapid burst: don't wait between seeks
            await Future<void>.delayed(const Duration(milliseconds: 200));
          } else {
            // wait up to 5s to check pass condition
            bool passed = false;
            while (sw.elapsedMilliseconds < 5000) {
              final posDiff = (service.state.position - st.target)
                  .inMilliseconds
                  .abs();
              final statusMatches = expectedPlaying
                  ? (service.state.status == PlayerStatus.playing)
                  : (service.state.status == PlayerStatus.paused ||
                        service.state.status == PlayerStatus.ready);
              if (posDiff <= 1500 && statusMatches) {
                passed = true;
                break;
              }
              await Future<void>.delayed(const Duration(milliseconds: 100));
            }

            final posDiff = (service.state.position - st.target).inMilliseconds
                .abs();
            if (passed) {
              totalPass++;
              stdout.writeln(
                'PASS #${i + 1}: pos=${service.state.position.inSeconds}s (diff=${posDiff}ms) status=${service.state.status}',
              );
            } else {
              totalFail++;
              stdout.writeln(
                'FAIL #${i + 1}: target=${st.target.inSeconds}s actual=${service.state.position.inSeconds}s diff=${posDiff}ms status=${service.state.status} (expectedPlaying=$expectedPlaying)',
              );
            }
          }
        }
        await service.stop();
      }

      stdout.writeln(
        '=== SEEK STRESS TEST RESULTS: $totalPass PASSED, $totalFail FAILED ===',
      );
      await relay.close();
      network.close();
      dio.close();
    },
  );
}
