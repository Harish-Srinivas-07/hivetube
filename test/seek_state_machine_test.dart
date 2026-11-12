import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/playback/player_interactions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Seek State Machine & Interactions', () {
    test('accumulateSeek handles same-direction accumulation and clamping', () {
      final s1 = accumulateSeek(
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 120),
        seconds: 10,
        previousSeconds: 0,
      );
      expect(s1.totalSeconds, 10);
      expect(s1.target, const Duration(seconds: 40));

      final s2 = accumulateSeek(
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 120),
        seconds: 10,
        previousSeconds: 10,
        previousTarget: s1.target,
      );
      expect(s2.totalSeconds, 20);
      expect(s2.target, const Duration(seconds: 50));

      // Clamps to duration
      final s3 = accumulateSeek(
        position: const Duration(seconds: 110),
        duration: const Duration(seconds: 120),
        seconds: 20,
        previousSeconds: 0,
      );
      expect(s3.target, const Duration(seconds: 120));

      // Clamps to zero
      final s4 = accumulateSeek(
        position: const Duration(seconds: 5),
        duration: const Duration(seconds: 120),
        seconds: -10,
        previousSeconds: 0,
      );
      expect(s4.target, Duration.zero);
    });

    test('PlaybackSnapshot displayPosition respects seekTarget while seeking', () {
      final snapshot = PlaybackSnapshot();
      snapshot.position = const Duration(seconds: 10);
      expect(snapshot.displayPosition, const Duration(seconds: 10));

      snapshot.seekState = SeekState.seeking;
      snapshot.seekTarget = const Duration(seconds: 45);
      expect(snapshot.displayPosition, const Duration(seconds: 45));

      snapshot.seekState = SeekState.idle;
      snapshot.seekTarget = null;
      expect(snapshot.displayPosition, const Duration(seconds: 10));
    });
  });
}
