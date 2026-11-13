import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/features/watch/watch_panel.dart';
import 'package:hivetube/widgets/player/player_controls.dart';

class _FakeMediaPlayerState extends Fake implements PlayerState {
  @override
  List<String> get subtitle => const [];
}

class _FakeMediaPlayerStream extends Fake implements PlayerStream {
  @override
  Stream<List<String>> get subtitle => const Stream.empty();
}

class _FakeMediaPlayer extends Fake implements Player {
  @override
  PlayerState get state => _FakeMediaPlayerState();
  @override
  PlayerStream get stream => _FakeMediaPlayerStream();
}

class _FakePlayback extends Fake implements PlaybackService {
  final Player _player = _FakeMediaPlayer();
  final snapshot = PlaybackSnapshot()..status = PlayerStatus.playing;
  bool stopped = false;
  @override
  PlayRequest? get request => null;
  @override
  PlaybackSnapshot get state => snapshot;
  @override
  Player get player => _player;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  Future<void> setLoop(bool value) async {}
  @override
  Future<void> play(PlayRequest value) async {}
  @override
  Future<void> stop() async {
    stopped = true;
  }
}

class _FakePlaybackController extends PlaybackController {
  _FakePlaybackController(this.service);
  final PlaybackService service;
  @override
  PlaybackService? build() => service;
}

class _OpenPanel extends WatchPanelController {
  @override
  String? build() => 'video';
}

class _NoRelated extends RelatedVideosController {
  _NoRelated() : super('video');
  @override
  Future<List<VideoItem>> build() async => [];
}

class _FakeUi extends PlayerUiController {
  @override
  PlayerUiState build() => const PlayerUiState(playing: true, dismissed: false);
}

class _MovingUi extends PlayerUiController {
  @override
  PlayerUiState build() => const PlayerUiState(
    playing: true,
    dismissed: false,
    panelMode: PlayerPanelMode.moving,
  );
}

class _FullscreenMovingUi extends PlayerUiController {
  @override
  PlayerUiState build() => const PlayerUiState(
    playing: true,
    dismissed: false,
    isFullscreen: true,
    panelMode: PlayerPanelMode.moving,
  );
}

void main() {
  testWidgets('full controls are absent while panel is moving', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerUiProvider.overrideWith(_MovingUi.new)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: SharedPlayer(
                service: _FakePlayback(),
                videoOverride: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('playerOverlay')), findsNothing);
  });

  testWidgets('fullscreen controls remain available while panel is moving', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerUiProvider.overrideWith(_FullscreenMovingUi.new)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: SharedPlayer(
                service: _FakePlayback(),
                videoOverride: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('fullscreenPlayerOverlay')),
      findsOneWidget,
    );
  });

  testWidgets('overlay hides after playing and returns on tap', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerUiProvider.overrideWith(_FakeUi.new)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 203,
                child: SharedPlayer(
                  service: _FakePlayback(),
                  videoOverride: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final overlay = find.byKey(const ValueKey('playerOverlay'));
    expect(tester.widget<AnimatedOpacity>(overlay).opacity, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<AnimatedOpacity>(overlay).opacity, 0);
    await tester.tapAt(tester.getTopLeft(overlay) + const Offset(15, 90));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<AnimatedOpacity>(overlay).opacity, 1);
  });

  testWidgets('mini-player close dismisses panel and stops playback', (
    tester,
  ) async {
    final service = _FakePlayback();
    final container = ProviderContainer(
      overrides: [
        playbackProvider.overrideWith(() => _FakePlaybackController(service)),
        playerUiProvider.overrideWith(_FakeUi.new),
        watchPanelProvider.overrideWith(_OpenPanel.new),
        historyRepoProvider.overrideWithValue(EmptyHistoryRepo()),
        shortMetadataProvider('video').overrideWith(
          (ref) async =>
              const ShortItem(id: 'video', thumbUrl: '', title: 'Video'),
        ),
        relatedVideosProvider('video').overrideWith(_NoRelated.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: WatchPanel(videoOverride: SizedBox.expand()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Minimize'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close player'));
    await tester.pump();
    expect(container.read(watchPanelProvider), isNull);
    expect(service.stopped, isTrue);
  });
}
