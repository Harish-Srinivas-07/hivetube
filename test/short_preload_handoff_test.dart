import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/playback_service.dart';

class _FakePlayers {
  int live = 0;
  int playing = 0;
  int maximumLive = 0;
  int maximumPlaying = 0;

  _FakePlayer create({bool playing = false}) {
    live++;
    if (live > maximumLive) maximumLive = live;
    if (playing) this.playing++;
    if (this.playing > maximumPlaying) maximumPlaying = this.playing;
    return _FakePlayer(this, playing);
  }
}

class _FakePlayer {
  _FakePlayer(this.owner, this.playing);
  final _FakePlayers owner;
  bool playing;

  Future<void> pause() async {
    if (playing) owner.playing--;
    playing = false;
  }

  Future<void> play() async {
    if (!playing) owner.playing++;
    playing = true;
    if (owner.playing > owner.maximumPlaying) {
      owner.maximumPlaying = owner.playing;
    }
  }

  Future<void> dispose() async {
    await pause();
    owner.live--;
  }
}

void main() {
  test(
    'stale handoff is ignored and promotion never overlaps players',
    () async {
      final players = _FakePlayers();
      final first = players.create(playing: true);
      final queue = ShortPreloadQueue();
      final preloadGate = Completer<void>();
      final staleGeneration = queue.begin();
      final stalePreload = queue.run(() async {
        await preloadGate.future;
        if (staleGeneration != queue.generation) return null;
        return players.create();
      });
      queue.begin();
      preloadGate.complete();
      expect(await stalePreload, isNull);
      final next = await queue.run(() async => players.create());
      final pauseGate = Completer<void>();
      var current = true;
      var promoted = false;
      final stale = handoffShortPlayer(
        isCurrent: () => current,
        pausePrevious: () async {
          await first.pause();
          await pauseGate.future;
        },
        promote: () async => promoted = true,
        start: next.play,
      );
      current = false;
      pauseGate.complete();
      expect(await stale, isFalse);
      expect(promoted, isFalse);
      expect(players.playing, 0);

      current = true;
      expect(
        await handoffShortPlayer(
          isCurrent: () => current,
          pausePrevious: first.pause,
          promote: () async {
            promoted = true;
            await first.dispose();
          },
          start: next.play,
        ),
        isTrue,
      );
      expect(promoted, isTrue);
      expect(players.maximumLive, 2);
      expect(players.maximumPlaying, 1);
      expect(players.playing, 1);
      await next.dispose();
    },
  );
}
