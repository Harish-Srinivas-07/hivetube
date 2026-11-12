import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/playback/seek_controller.dart';

void main() {
  group('SeekController unit tests', () {
    test('debounce and last wins: multiple seeks within 120ms only issue the last target', () async {
      final issuedSeeks = <Duration>[];
      var resumed = false;
      var currentPos = Duration.zero;

      final controller = SeekController(
        getDuration: () => const Duration(minutes: 10),
        getPosition: () => currentPos,
        getStatus: () => PlayerStatus.playing,
        isUserPaused: () => false,
        onSeekToPlayer: (target) async {
          issuedSeeks.add(target);
          currentPos = target;
        },
        getPlayerPosition: () => currentPos,
        isPlayerBuffering: () => false,
        onSeekStateChanged: (state, target) {},
        onRecovery: () async {},
        onAudioSyncCheck: () async {},
        onPlaybackResume: () async {
          resumed = true;
        },
        debounceDuration: const Duration(milliseconds: 120),
        settleTimeout: const Duration(milliseconds: 100),
        pollInterval: const Duration(milliseconds: 20),
      );

      // Rapidly call seekTo 5 times
      controller.seekTo(const Duration(seconds: 10));
      controller.seekTo(const Duration(seconds: 20));
      controller.seekTo(const Duration(seconds: 30));
      controller.seekTo(const Duration(seconds: 40));
      controller.seekTo(const Duration(seconds: 50));

      // Wait 150ms for debounce timer to fire
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(issuedSeeks.length, equals(1));
      expect(issuedSeeks.first, equals(const Duration(seconds: 50)));

      // Settle
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(resumed, isTrue);

      controller.dispose();
    });

    test('wasPlaying restored: resumes playback if it was playing before seek', () async {
      var resumed = false;
      var currentPos = Duration.zero;

      final controller = SeekController(
        getDuration: () => const Duration(minutes: 5),
        getPosition: () => currentPos,
        getStatus: () => PlayerStatus.playing,
        isUserPaused: () => false,
        onSeekToPlayer: (target) async => currentPos = target,
        getPlayerPosition: () => currentPos,
        isPlayerBuffering: () => false,
        onSeekStateChanged: (state, target) {},
        onRecovery: () async {},
        onAudioSyncCheck: () async {},
        onPlaybackResume: () async {
          resumed = true;
        },
        debounceDuration: const Duration(milliseconds: 20),
        settleTimeout: const Duration(milliseconds: 50),
        pollInterval: const Duration(milliseconds: 10),
      );

      await controller.seekTo(const Duration(seconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(resumed, isTrue);
      controller.dispose();
    });

    test('ended then seek back: resumes playback on seek back from ended state', () async {
      var resumed = false;
      var currentPos = const Duration(minutes: 10);

      final controller = SeekController(
        getDuration: () => const Duration(minutes: 10),
        getPosition: () => currentPos,
        getStatus: () => PlayerStatus.ended,
        isUserPaused: () => false,
        onSeekToPlayer: (target) async => currentPos = target,
        getPlayerPosition: () => currentPos,
        isPlayerBuffering: () => false,
        onSeekStateChanged: (state, target) {},
        onRecovery: () async {},
        onAudioSyncCheck: () async {},
        onPlaybackResume: () async {
          resumed = true;
        },
        debounceDuration: const Duration(milliseconds: 20),
        settleTimeout: const Duration(milliseconds: 50),
        pollInterval: const Duration(milliseconds: 10),
      );

      // Seek back to 2 minutes
      await controller.seekTo(const Duration(minutes: 2));
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(resumed, isTrue);
      controller.dispose();
    });

    test('stale ignored: canceled or stale generation is discarded', () async {
      final issued = <Duration>[];
      final controller = SeekController(
        getDuration: () => const Duration(minutes: 5),
        getPosition: () => Duration.zero,
        getStatus: () => PlayerStatus.playing,
        isUserPaused: () => false,
        onSeekToPlayer: (t) async => issued.add(t),
        getPlayerPosition: () => Duration.zero,
        isPlayerBuffering: () => false,
        onSeekStateChanged: (state, target) {},
        onRecovery: () async {},
        onAudioSyncCheck: () async {},
        onPlaybackResume: () async {},
        debounceDuration: const Duration(milliseconds: 50),
      );

      controller.seekTo(const Duration(seconds: 15));
      controller.cancel(); // Cancel immediately
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(issued, isEmpty);
      controller.dispose();
    });

    test('timeout to recovery: calls onRecovery when seek does not settle within timeout', () async {
      var recoveryCalled = false;
      var currentPos = Duration.zero;

      final controller = SeekController(
        getDuration: () => const Duration(minutes: 10),
        getPosition: () => currentPos,
        getStatus: () => PlayerStatus.playing,
        isUserPaused: () => false,
        onSeekToPlayer: (target) async {
          // Simulate hung player: position never reaches target
        },
        getPlayerPosition: () => currentPos,
        isPlayerBuffering: () => true, // Buffering forever
        onSeekStateChanged: (state, target) {},
        onRecovery: () async {
          recoveryCalled = true;
        },
        onAudioSyncCheck: () async {},
        onPlaybackResume: () async {},
        debounceDuration: const Duration(milliseconds: 20),
        timeoutDuration: const Duration(milliseconds: 80),
        settleTimeout: const Duration(milliseconds: 200),
        pollInterval: const Duration(milliseconds: 20),
      );

      await controller.seekTo(const Duration(seconds: 300));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(recoveryCalled, isTrue);
      controller.dispose();
    });
  });
}
