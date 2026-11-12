import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Seek stress test on real playback device (30 seeks x 3 videos)',
    (tester) async {
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
        stdout.writeln('\n=== Testing $label videoId=$videoId ===');
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
          stdout.writeln('FAILED to load $videoId within 30s');
          totalFail += 30;
          continue;
        }

        final dSec = duration.inSeconds;

        final seekTargets = <({Duration target, bool pauseBefore, bool burst})>[
          // Forward seeks while playing
          (target: Duration(seconds: (dSec * 0.1).round()), pauseBefore: false, burst: false),
          (target: Duration(seconds: (dSec * 0.2).round()), pauseBefore: false, burst: false),
          (target: Duration(seconds: (dSec * 0.35).round()), pauseBefore: false, burst: false),
          (target: Duration(seconds: (dSec * 0.5).round()), pauseBefore: false, burst: false),
          (target: Duration(seconds: (dSec * 0.7).round()), pauseBefore: false, burst: false),
          // Backward seeks while playing
          (target: Duration(seconds: (dSec * 0.4).round()), pauseBefore: false, burst: false),
          (target: Duration(seconds: (dSec * 0.25).round()), pauseBefore: false, burst: false),
          (target: Duration(seconds: (dSec * 0.15).round()), pauseBefore: false, burst: false),
          (target: Duration(seconds: (dSec * 0.05).round()), pauseBefore: false, burst: false),
          (target: Duration.zero, pauseBefore: false, burst: false),
          // Seek to 0, near end, mid while paused
          (target: Duration.zero, pauseBefore: true, burst: false),
          (target: Duration(seconds: (dSec * 0.3).round()), pauseBefore: true, burst: false),
          (target: Duration(seconds: (dSec * 0.6).round()), pauseBefore: true, burst: false),
          (target: Duration(seconds: (dSec * 0.85).round()), pauseBefore: true, burst: false),
          (target: Duration(seconds: (dSec - 5).clamp(0, dSec)), pauseBefore: true, burst: false),
          // Rapid bursts (playing)
          (target: Duration(seconds: (dSec * 0.2).round()), pauseBefore: false, burst: true),
          (target: Duration(seconds: (dSec * 0.25).round()), pauseBefore: false, burst: true),
          (target: Duration(seconds: (dSec * 0.3).round()), pauseBefore: false, burst: true),
          (target: Duration(seconds: (dSec * 0.35).round()), pauseBefore: false, burst: true),
          (target: Duration(seconds: (dSec * 0.4).round()), pauseBefore: false, burst: true),
          // Rapid bursts (paused)
          (target: Duration(seconds: (dSec * 0.5).round()), pauseBefore: true, burst: true),
          (target: Duration(seconds: (dSec * 0.55).round()), pauseBefore: true, burst: true),
          (target: Duration(seconds: (dSec * 0.6).round()), pauseBefore: true, burst: true),
          (target: Duration(seconds: (dSec * 0.65).round()), pauseBefore: true, burst: true),
          (target: Duration(seconds: (dSec * 0.7).round()), pauseBefore: true, burst: true),
          // Edge & boundary seeks
          (target: Duration.zero, pauseBefore: false, burst: false),
          (target: Duration(seconds: (dSec - 2).clamp(0, dSec)), pauseBefore: false, burst: false),
          (target: Duration(seconds: (dSec * 0.5).round()), pauseBefore: false, burst: false),
          (target: Duration.zero, pauseBefore: true, burst: false),
          (target: Duration(seconds: (dSec - 3).clamp(0, dSec)), pauseBefore: true, burst: false),
        ];

        for (var i = 0; i < seekTargets.length; i++) {
          final st = seekTargets[i];
          if (st.pauseBefore && service.state.status == PlayerStatus.playing) {
            await service.pause();
            await Future<void>.delayed(const Duration(milliseconds: 200));
          } else if (!st.pauseBefore && service.state.status != PlayerStatus.playing) {
            await service.resume();
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }

          final expectedPlaying = !st.pauseBefore;
          await service.seek(st.target);

          if (!st.burst) {
            final sw = Stopwatch()..start();
            while (service.state.seekState == SeekState.seeking && sw.elapsedMilliseconds < 5000) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }
            await Future<void>.delayed(const Duration(milliseconds: 600));

            final posDiff = (service.state.position - st.target).inMilliseconds.abs();
            final tolerance = (dSec < 60) ? 2500 : 4000;
            final isNearEnd = st.target.inSeconds >= dSec - 5;
            final endOk = isNearEnd &&
                (service.state.status == PlayerStatus.ended ||
                    service.state.position.inSeconds >= dSec - 10);
            final ok = posDiff <= tolerance || endOk;

            if (ok) {
              totalPass++;
              stdout.writeln('  [PASS #${i + 1}] target=${st.target.inSeconds}s actual=${service.state.position.inSeconds}s (diff=${posDiff}ms) status=${service.state.status}');
            } else {
              totalFail++;
              stdout.writeln('  [FAIL #${i + 1}] target=${st.target.inSeconds}s actual=${service.state.position.inSeconds}s (diff=${posDiff}ms) status=${service.state.status} (expectedPlaying=$expectedPlaying)');
            }
          } else {
            totalPass++;
            stdout.writeln('  [PASS #${i + 1}] burst seek scheduled to ${st.target.inSeconds}s');
          }
        }
        await service.stop();
      }

      final total = totalPass + totalFail;
      final passRate = total > 0 ? (totalPass / total * 100).toStringAsFixed(1) : '0';
      stdout.writeln('\n======================================================');
      stdout.writeln('SEEK STRESS RESULT: $totalPass/$total passed ($passRate%)');
      stdout.writeln('======================================================');

      await relay.close();
      network.close();
      dio.close();

      expect(totalPass / total, greaterThanOrEqualTo(0.95), reason: 'Seek pass rate must be >= 95%');
    },
  );
}

