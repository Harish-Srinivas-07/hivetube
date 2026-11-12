import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/widgets/player/player_settings_menu.dart';
import 'package:hivetube/widgets/video_options_menu.dart';

class _Playback extends Fake implements PlaybackService {
  final snapshot = PlaybackSnapshot()..heights = [1080, 720];
  final listeners = <VoidCallback>[];
  @override
  PlaybackSnapshot get state => snapshot;
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  @override
  void setQuality(int? quality) {
    snapshot.quality = quality;
    for (final listener in [...listeners]) {
      listener();
    }
  }

  @override
  Future<void> setRate(double value) async {
    snapshot.rate = value;
    for (final listener in [...listeners]) {
      listener();
    }
  }
}

void main() {
  testWidgets('player sheet navigates and applies quality and speed', (
    tester,
  ) async {
    final service = _Playback();
    final session = PlayerSettingsSession(service);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showPlayerSettingsMenu(context, session: session),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('Playback speed'), findsOneWidget);
    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('720p'));
    await tester.pumpAndSettle();
    expect(service.state.quality, 720);
    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playback speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();
    expect(service.state.rate, 1.5);
    expect(tester.takeException(), isNull);
  });
  testWidgets('video menu closes and runs only the selected action', (
    tester,
  ) async {
    var next = 0, queue = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showVideoOptionsMenu(
                context,
                videoId: 'video',
                onPlayNext: () => next++,
                onAddToQueue: () => queue++,
              ),
              child: const Text('Open menu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    await tester.tap(find.text('Add to queue'));
    await tester.pumpAndSettle();
    expect(queue, 1);
    expect(next, 0);
    expect(find.text('Add to queue'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
