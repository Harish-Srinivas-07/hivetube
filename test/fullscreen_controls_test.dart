import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/widgets/player/player_controls.dart';

class _FakePlayerState extends Fake implements PlayerState {
  @override
  List<String> get subtitle => const [];
}

class _FakePlayerStream extends Fake implements PlayerStream {
  @override
  Stream<List<String>> get subtitle => const Stream.empty();
}

class _FakePlayer extends Fake implements Player {
  @override
  PlayerState get state => _FakePlayerState();
  @override
  PlayerStream get stream => _FakePlayerStream();
}

class _FakePlayback extends Fake implements PlaybackService {
  final Player _player = _FakePlayer();
  final PlaybackSnapshot snapshot = PlaybackSnapshot()
    ..status = PlayerStatus.playing
    ..playing = true;
  int toggleCount = 0;

  @override
  PlaybackSnapshot get state => snapshot;
  @override
  Player get player => _player;
  @override
  PlayRequest? get request => null;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  Future<void> togglePlay() async => toggleCount++;
}

class _FullscreenUi extends PlayerUiController {
  @override
  PlayerUiState build() =>
      const PlayerUiState(playing: true, dismissed: false, isFullscreen: true);
}

void main() {
  testWidgets('fullscreen exposes working controls only', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakePlayback();
    var previousCount = 0;
    var nextCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerUiProvider.overrideWith(_FullscreenUi.new)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: SharedPlayer(
                service: service,
                onPrevious: () => previousCount++,
                onNext: () => nextCount++,
                videoOverride: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final label in [
      'Cast',
      'Live chat',
      'Comments',
      'More options',
      'Like',
      'Dislike',
      'Save',
    ]) {
      expect(find.byTooltip(label), findsNothing, reason: label);
    }

    for (final label in [
      'Exit fullscreen',
      'Settings',
      'Previous',
      'Pause',
      'Next',
    ]) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }

    await tester.tap(find.byTooltip('Previous'));
    await tester.tap(find.byTooltip('Next'));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(previousCount, 1);
    expect(nextCount, 1);
    expect(service.toggleCount, 1);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('appSheetSurface')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Exit fullscreen'));
    await tester.pump();
  });
}
