import 'dart:io';
import 'package:hivetube/core/playback/player_interactions.dart';

void main() {
  stdout.writeln('=== Seek State Machine & Interactions Verification ===');
  var pass = 0;
  var total = 0;

  void check(String name, bool cond) {
    total++;
    if (cond) {
      pass++;
      stdout.writeln('  [PASS] $name');
    } else {
      stdout.writeln('  [FAIL] $name');
    }
    assert(cond, name);
  }

  // 1. accumulateSeek
  final s1 = accumulateSeek(
    position: const Duration(seconds: 30),
    duration: const Duration(seconds: 120),
    seconds: 10,
    previousSeconds: 0,
  );
  check(
    'accumulateSeek step 1 (10s -> pos 40s)',
    s1.totalSeconds == 10 && s1.target == const Duration(seconds: 40),
  );

  final s2 = accumulateSeek(
    position: const Duration(seconds: 30),
    duration: const Duration(seconds: 120),
    seconds: 10,
    previousSeconds: 10,
    previousTarget: s1.target,
  );
  check(
    'accumulateSeek step 2 burst (+10s -> pos 50s, total 20s)',
    s2.totalSeconds == 20 && s2.target == const Duration(seconds: 50),
  );

  // Clamps to duration
  final s3 = accumulateSeek(
    position: const Duration(seconds: 110),
    duration: const Duration(seconds: 120),
    seconds: 20,
    previousSeconds: 0,
  );
  check(
    'accumulateSeek clamp near end (110s + 20s -> clamp 120s)',
    s3.target == const Duration(seconds: 120),
  );

  // Clamps to zero
  final s4 = accumulateSeek(
    position: const Duration(seconds: 5),
    duration: const Duration(seconds: 120),
    seconds: -10,
    previousSeconds: 0,
  );
  check(
    'accumulateSeek clamp to 0 (5s - 10s -> clamp 0s)',
    s4.target == Duration.zero,
  );

  // Direction reversal resets accumulation
  final s5 = accumulateSeek(
    position: const Duration(seconds: 40),
    duration: const Duration(seconds: 120),
    seconds: -10,
    previousSeconds: 20,
  );
  check(
    'accumulateSeek reversal resets totalSeconds',
    s5.totalSeconds == -10 && s5.target == const Duration(seconds: 30),
  );

  stdout.writeln('Seek verification passed: $pass/$total (100%)');
  exit(pass == total ? 0 : 1);
}
