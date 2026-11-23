import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/player_interactions.dart';
import 'package:hivetube/core/playback/watch_session.dart';

void main() {
  test('multi-tap seek uses the requested steps, direction and bounds', () {
    for (final entry in {2: 10, 3: 20, 4: 30, 5: 50, 6: 50}.entries) {
      for (final forward in [true, false]) {
        final step = multiTapSeek(
          taps: entry.key,
          forward: forward,
          position: const Duration(seconds: 60),
          duration: const Duration(seconds: 120),
        );
        final signed = forward ? entry.value : -entry.value;
        expect(step.totalSeconds, signed);
        expect(step.target, Duration(seconds: 60 + signed));
      }
    }
    expect(
      multiTapSeek(
        taps: 5,
        forward: false,
        position: const Duration(seconds: 5),
        duration: const Duration(seconds: 100),
      ).target,
      Duration.zero,
    );
    expect(
      multiTapSeek(
        taps: 5,
        forward: true,
        position: const Duration(seconds: 95),
        duration: const Duration(seconds: 100),
      ).target,
      const Duration(seconds: 100),
    );
  });

  test('session tracks previous videos and chooses first unplayed', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = container.read(watchSessionProvider.notifier);
    session.opened(null, 'a');
    session.opened('a', 'b');
    session.opened('b', 'c');
    expect(session.firstUnplayed(['a', 'b', 'd', 'e']), 'd');
    expect(session.popPrevious(), 'b');
    session.opened('c', 'b', record: false);
    expect(session.popPrevious(), 'a');
    expect(session.popPrevious(), isNull);
  });

  test('seek accumulates, switches direction, and clamps', () {
    final first = accumulateSeek(
      position: const Duration(seconds: 20),
      duration: const Duration(seconds: 45),
      seconds: 10,
      previousSeconds: 0,
    );
    final second = accumulateSeek(
      position: const Duration(seconds: 20),
      duration: const Duration(seconds: 45),
      seconds: 10,
      previousSeconds: first.totalSeconds,
      previousTarget: first.target,
    );
    expect(second.target, const Duration(seconds: 40));
    expect(second.totalSeconds, 20);
    final clamped = accumulateSeek(
      position: Duration.zero,
      duration: const Duration(seconds: 45),
      seconds: 10,
      previousSeconds: second.totalSeconds,
      previousTarget: second.target,
    );
    expect(clamped.target, const Duration(seconds: 45));
    final reverse = accumulateSeek(
      position: const Duration(seconds: 4),
      duration: const Duration(seconds: 45),
      seconds: -10,
      previousSeconds: second.totalSeconds,
      previousTarget: second.target,
    );
    expect(reverse.target, Duration.zero);
    expect(reverse.totalSeconds, -10);
  });

  test('panel release uses velocity first and progress otherwise', () {
    expect(panelReleaseTarget(.1, 701), 1);
    expect(panelReleaseTarget(.9, -701), 0);
    expect(panelReleaseTarget(.5, 700), 0);
    expect(panelReleaseTarget(.51, 0), 1);
  });

  test('history persists and resume ignores near-complete playback', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final writer = StoredHistoryRepo(db);
    await writer.save(
      const HistoryEntry('a', Duration(seconds: 30), Duration(seconds: 100)),
    );
    final reader = StoredHistoryRepo(db);
    final saved = (await reader.recent()).single;
    expect(resumePosition(saved), const Duration(seconds: 30));
    expect(
      resumePosition(
        const HistoryEntry('b', Duration(seconds: 97), Duration(seconds: 100)),
      ),
      Duration.zero,
    );
  });
}
