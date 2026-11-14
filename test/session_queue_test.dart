import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/session_queue.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/features/watch/queue_sheet.dart';
import 'package:hivetube/features/watch/watch_rules.dart';

void main() {
  test('queue adds, prioritizes, reorders, and clears items', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(sessionQueueProvider.notifier);
    const first = VideoItem(id: 'first', title: 'First');
    const second = VideoItem(id: 'second', title: 'Second');
    const third = VideoItem(id: 'third', title: 'Third');

    controller.add(first);
    controller.add(second);
    controller.playNext(third);
    final queued = container.read(sessionQueueProvider);
    expect(queued.map((entry) => entry.video.id), ['third', 'first', 'second']);
    expect(
      selectUpNext(
        queue: queued.map((entry) => entry.video).toList(),
        related: const [VideoItem(id: 'related', title: 'Related')],
        finished: const {},
        currentId: 'now',
      )?.id,
      'third',
    );

    controller.reorder(0, 2);
    expect(
      container.read(sessionQueueProvider).map((entry) => entry.video.id),
      ['first', 'second', 'third'],
    );
    expect(controller.takeNext()?.video.id, 'first');
    controller.clear();
    expect(container.read(sessionQueueProvider), isEmpty);
  });

  testWidgets('queue sheet renders and reorders queue rows', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showQueueSheet(
                  context,
                  current: const VideoItem(id: 'now', title: 'Now playing'),
                  onPlay: (_) {},
                ),
                child: const Text('Open queue'),
              ),
            ),
          ),
        ),
      ),
    );
    final queue = container.read(sessionQueueProvider.notifier);
    queue
      ..add(const VideoItem(id: 'one', title: 'One'))
      ..add(const VideoItem(id: 'two', title: 'Two'))
      ..add(const VideoItem(id: 'three', title: 'Three'));
    await tester.pump();
    await tester.tap(find.text('Open queue'));
    await tester.pumpAndSettle();

    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Now playing'), findsNWidgets(2));
    expect(find.text('One'), findsOneWidget);

    final row = find.byKey(const ValueKey('queue:one'));
    final gesture = await tester.startGesture(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 400));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      container.read(sessionQueueProvider).map((entry) => entry.video.id),
      ['two', 'three', 'one'],
    );
  });
}
