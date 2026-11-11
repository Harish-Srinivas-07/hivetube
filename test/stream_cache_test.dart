import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/innertube/clients.dart';
import 'package:hivetube/core/streams/net_family.dart';
import 'package:hivetube/core/streams/player_client.dart';
import 'package:hivetube/core/streams/stream_cache.dart';
import 'package:hivetube/core/streams/stream_selector.dart';

class FixtureClient extends PlayerClient {
  FixtureClient(NetworkFamily network)
    : super(
        network,
        InnertubeClients({
          'VISIONOS': {'ua': 'test'},
        }),
        () => null,
        () async {},
      );
  int calls = 0;
  StreamError? verdict;
  Completer<void>? gate;
  @override
  Future<Map<String, dynamic>> resolve(String id) async {
    calls++;
    if (gate != null) await gate!.future;
    if (verdict != null) throw StreamException(verdict!);
    return {
      'streamingData': {
        'adaptiveFormats': [
          {
            'itag': 140,
            'url': 'https://example.com/a?expire=2000000000',
            'mimeType': 'audio/mp4',
          },
          {
            'itag': 137,
            'url': 'https://example.com/v?expire=2000000000',
            'mimeType': 'video/mp4; codecs="avc1"',
            'height': 1080,
          },
        ],
      },
    };
  }
}

class FixtureCache extends StreamCache {
  FixtureCache(super.player, {required super.clock});
  @override
  Future<bool> probe(StreamFormat format) async => true;
}

void main() {
  late NetworkFamily network;
  late FixtureClient client;
  late FixtureCache cache;
  var now = DateTime.fromMillisecondsSinceEpoch(1900000000 * 1000);
  setUp(() {
    network = NetworkFamily();
    client = FixtureClient(network);
    cache = FixtureCache(client, clock: () => now);
  });
  tearDown(() => network.close());
  test(
    'coalesces concurrent resolutions and expires after twenty minutes',
    () async {
      client.gate = Completer<void>();
      final a = cache.resolve('id', PlaybackMode.video);
      final b = cache.resolve('id', PlaybackMode.video);
      await Future<void>.delayed(Duration.zero);
      expect(client.calls, 1);
      client.gate!.complete();
      await Future.wait([a, b]);
      await cache.resolve('id', PlaybackMode.video);
      expect(client.calls, 1);
      now = now.add(const Duration(minutes: 21));
      await cache.resolve('id', PlaybackMode.video);
      expect(client.calls, 2);
      cache.clearCache();
      await cache.resolve('id', PlaybackMode.video);
      expect(client.calls, 3);
    },
  );
  test('permanent verdict is cached for ten minutes', () async {
    client.verdict = StreamError.ageRestricted;
    await expectLater(
      cache.resolve('blocked', PlaybackMode.video),
      throwsA(isA<StreamException>()),
    );
    await expectLater(
      cache.resolve('blocked', PlaybackMode.video),
      throwsA(isA<StreamException>()),
    );
    expect(client.calls, 1);
    now = now.add(const Duration(minutes: 11));
    await expectLater(
      cache.resolve('blocked', PlaybackMode.video),
      throwsA(isA<StreamException>()),
    );
    expect(client.calls, 2);
  });
}
