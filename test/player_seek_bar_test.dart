import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/widgets/player/player_seek_bar.dart';

void main() {
  testWidgets('drag seeks only when released', (tester) async {
    final seeks = <Duration>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: PlayerSeekBar(
                position: Duration.zero,
                buffered: const Duration(seconds: 60),
                duration: const Duration(seconds: 100),
                onScrubStart: (_) {},
                onScrubUpdate: (_) {},
                onScrubEnd: seeks.add,
              ),
            ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(PlayerSeekBar));
    final gesture = await tester.startGesture(
      Offset(rect.left + 20, rect.center.dy),
    );
    await gesture.moveTo(Offset(rect.left + 100, rect.center.dy));
    await tester.pump();
    expect(seeks, isEmpty);
    await gesture.up();
    expect(seeks.single, const Duration(seconds: 50));
  });
}
