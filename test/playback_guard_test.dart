import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/load_guard.dart';

void main() {
  test('new loads invalidate previous generations', () {
    final guard = LoadGuard();
    final old = guard.next();
    final current = guard.next();
    expect(guard.isCurrent(old), isFalse);
    expect(guard.isCurrent(current), isTrue);
  });
  test('recovery stops after three and resets after sixty seconds playing', () {
    final budget = RecoveryBudget();
    final start = DateTime(2026);
    expect(
      [budget.take(), budget.take(), budget.take(), budget.take()],
      [true, true, true, false],
    );
    budget.playing(start);
    budget.tick(start.add(const Duration(seconds: 59)));
    expect(budget.take(), isFalse);
    budget.tick(start.add(const Duration(seconds: 60)));
    expect(budget.take(), isTrue);
    budget.paused();
    budget.tick(start.add(const Duration(hours: 1)));
    expect(budget.attempts, 1);
  });
}
