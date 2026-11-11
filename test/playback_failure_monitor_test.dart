import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/playback_failure_monitor.dart';

void main() {
  testWidgets('playback progress cancels a nonfatal player error', (
    tester,
  ) async {
    final monitor = PlaybackFailureMonitor();
    var recoveries = 0;
    monitor.report(const Duration(seconds: 10), () => recoveries++);
    await tester.pump(const Duration(seconds: 1));
    monitor.positionChanged(const Duration(seconds: 11));
    await tester.pump(const Duration(seconds: 4));
    expect(recoveries, 0);
  });

  testWidgets(
    'a stalled player triggers only one recovery for repeated errors',
    (tester) async {
      final monitor = PlaybackFailureMonitor();
      var recoveries = 0;
      monitor.report(const Duration(seconds: 10), () => recoveries++);
      await tester.pump(const Duration(seconds: 2));
      monitor.report(const Duration(seconds: 10), () => recoveries++);
      monitor.positionChanged(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(recoveries, 1);
    },
  );

  testWidgets('cancellation prevents recovery after pause or media change', (
    tester,
  ) async {
    final monitor = PlaybackFailureMonitor();
    var recoveries = 0;
    monitor.report(Duration.zero, () => recoveries++);
    monitor.cancel();
    await tester.pump(const Duration(seconds: 4));
    expect(recoveries, 0);
  });
}
