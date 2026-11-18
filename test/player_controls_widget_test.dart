import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/features/watch/watch_panel.dart';
import 'package:hivetube/widgets/player/player_controls.dart';
import 'package:hivetube/widgets/player/player_seek_bar.dart';
import 'package:hivetube/theme/app_spacing.dart';
import 'package:hivetube/theme/app_text_styles.dart';

class _FakeMediaPlayerState extends Fake implements PlayerState {
  _FakeMediaPlayerState(this.width, this.height);

  @override
  final int? width;
  @override
  final int? height;

  @override
  List<String> get subtitle => const [];
}

class _FakeMediaPlayerStream extends Fake implements PlayerStream {
  @override
  Stream<List<String>> get subtitle => const Stream.empty();
}

class _FakeMediaPlayer extends Fake implements Player {
  _FakeMediaPlayer({this.width, this.height});

  final int? width;
  final int? height;

  @override
  PlayerState get state => _FakeMediaPlayerState(width, height);
  @override
  PlayerStream get stream => _FakeMediaPlayerStream();
}

class _FakeVideoController extends Fake implements VideoController {
  _FakeVideoController(this.player);

  @override
  final Player player;
}

class _FakePlayback extends Fake implements PlaybackService {
  _FakePlayback({int? width, int? height})
    : _player = _FakeMediaPlayer(width: width, height: height),
      _controller = _FakeVideoController(
        _FakeMediaPlayer(width: width, height: height),
      );

  final _FakeMediaPlayer _player;
  final VideoController _controller;
  final snapshot = PlaybackSnapshot()..status = PlayerStatus.playing;
  bool stopped = false;
  @override
  PlayRequest? get request => null;
  @override
  PlaybackSnapshot get state => snapshot;
  @override
  Player get player => _player;
  @override
  VideoController get controller => _controller;
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
  testWidgets('watch captions use fullscreen styling near the bottom', (
    tester,
  ) async {
    final service = _FakePlayback()
      ..state.selectedCaption = 0
      ..state.subtitleText = 'A lyric line';
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
                  service: service,
                  videoOverride: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final caption = find.text('A lyric line');
    expect(caption, findsOneWidget);
    expect(tester.widget<Text>(caption).style, AppTextStyles.playerCaption);
    expect(tester.widget<Text>(caption).style!.backgroundColor, isNull);
    final player = tester.getRect(find.byType(SharedPlayer));
    expect(tester.getCenter(caption).dy, greaterThan(player.center.dy));
    await tester.pumpWidget(const SizedBox.shrink());
  });
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
    final service = _FakePlayback()..state.captions = [{}];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerUiProvider.overrideWith(_FullscreenMovingUi.new)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: SharedPlayer(
                service: service,
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
    expect(
      tester.getRect(find.byTooltip('Minimize player')).left,
      lessThan(tester.getRect(find.text('HiveTube')).left),
    );
    final autoplay = find.ancestor(
      of: find.text('Autoplay'),
      matching: find.byType(Material),
    );
    final captions = tester.getRect(find.byTooltip('Captions'));
    final settings = tester.getRect(find.byTooltip('Settings'));
    expect(captions.left - tester.getRect(autoplay.first).right, AppSpacing.lg);
    expect(settings.left - captions.right, AppSpacing.lg);
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

  for (final sourceSize in [
    (label: '16:9', width: 1920, height: 1080),
    (label: '9:16', width: 1080, height: 1920),
  ]) {
    testWidgets(
      'inline footer stays 8 px above the seek bar for ${sourceSize.label}',
      (tester) async {
        final service = _FakePlayback(
          width: sourceSize.width,
          height: sourceSize.height,
        );
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
                      service: service,
                      videoOverride: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final footer = tester.getRect(
          find.byKey(const ValueKey('inlinePlayerFooter')),
        );
        final seekBar = tester.getRect(find.byType(PlayerSeekBar));
        expect(seekBar.top - footer.bottom, AppSpacing.sm);
        expect(tester.takeException(), isNull);
      },
    );
  }

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
