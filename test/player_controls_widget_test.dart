import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/settings/app_settings.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/core/playback/picture_in_picture.dart';
import 'package:hivetube/core/streams/stream_selector.dart';
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
  Future<void> playVideoRequest(PlayRequest value) => play(value);
  @override
  Future<void> setAudioOnly(bool enabled) async {
    snapshot.mode = enabled ? PlaybackMode.audio : PlaybackMode.video;
  }

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

class _ProgressUi extends PlayerUiController {
  _ProgressUi(this.fullscreen);
  final bool fullscreen;
  @override
  PlayerUiState build() => PlayerUiState(
    playing: true,
    dismissed: false,
    isFullscreen: fullscreen,
    position: const Duration(seconds: 40),
    duration: const Duration(minutes: 3),
  );
  void updatePosition(Duration value) =>
      state = state.copyWith(position: value);
}

class _AudioSettings extends AppSettingsController {
  @override
  AppSettings build() => const AppSettings(gl: 'IN');
  @override
  Future<void> setAudioOnly(bool enabled) async {
    state = state.copyWith(audioOnly: enabled);
  }
}

class _AutoplaySettings extends AppSettingsController {
  @override
  AppSettings build() => const AppSettings(gl: 'IN', autoplay: true);

  @override
  Future<void> setAutoplay(bool enabled) async {
    state = state.copyWith(autoplay: enabled);
  }
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

class _FullscreenCaptionsUi extends PlayerUiController {
  @override
  PlayerUiState build() => const PlayerUiState(
    playing: true,
    dismissed: false,
    isFullscreen: true,
    overlayVisible: false,
  );
}

void main() {
  testWidgets('fullscreen audio-only control follows Background play', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final service = _FakePlayback()
      ..state.mode = PlaybackMode.video
      ..state.position = const Duration(seconds: 42);
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        initialAppSettingsProvider.overrideWithValue(
          const AppSettings(gl: 'IN', backgroundPlay: false),
        ),
        playbackProvider.overrideWith(() => _FakePlaybackController(service)),
        playerUiProvider.overrideWith(() => _ProgressUi(true)),
      ],
    );
    addTearDown(container.dispose);
    container.read(playbackProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: SharedPlayer(
                service: service,
                videoOverride: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Audio only'), findsNothing);
    await container.read(appSettingsProvider.notifier).setBackgroundPlay(true);
    await tester.pump();
    expect(find.byTooltip('Audio only'), findsOneWidget);
    await tester.tap(find.byTooltip('Audio only'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(appSettingsProvider).audioOnly, isTrue);
    expect(service.state.mode, PlaybackMode.audio);
    expect(find.byTooltip('Disable audio only'), findsOneWidget);
    await container.read(appSettingsProvider.notifier).setBackgroundPlay(false);
    await tester.pump();
    expect(find.byTooltip('Audio only'), findsNothing);
    expect(find.byTooltip('Disable audio only'), findsNothing);
    expect(service.state.mode, PlaybackMode.video);
    expect(service.state.position, const Duration(seconds: 42));
    expect(await db.getValue('settings_audio_only'), 'false');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('audio-only setting makes PiP ineligible immediately', () async {
    final service = _FakePlayback()
      ..state.mode = PlaybackMode.video
      ..state.playing = true;
    final container = ProviderContainer(
      overrides: [
        playbackProvider.overrideWith(() => _FakePlaybackController(service)),
        appSettingsProvider.overrideWith(_AudioSettings.new),
      ],
    );
    addTearDown(container.dispose);
    final pip = container.read(pictureInPictureProvider.notifier);
    expect(pip.eligible, isTrue);
    await container.read(appSettingsProvider.notifier).setAudioOnly(true);
    expect(pip.eligible, isFalse);
  });
  for (final fullscreen in [false, true]) {
    testWidgets(
      'audio-only thumbnail keeps player controls in fullscreen=$fullscreen',
      (tester) async {
        final service = _FakePlayback()
          ..state.mode = PlaybackMode.video
          ..state.frameReadyId = 'video';
        final container = ProviderContainer(
          overrides: [
            playerUiProvider.overrideWith(() => _ProgressUi(fullscreen)),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 400,
                  height: 225,
                  child: SharedPlayer(
                    service: service,
                    requestVideoId: 'video',
                    thumbnailUrl: 'https://example.com/cover.jpg',
                    videoOverride: const SizedBox.expand(
                      key: ValueKey('visible-video'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final playerRect = tester.getRect(find.byType(SharedPlayer));
        expect(find.byKey(const ValueKey('visible-video')), findsOneWidget);
        await service.setAudioOnly(true);
        service.state.frozenFrame = Uint8List.fromList([1, 2, 3]);
        (container.read(playerUiProvider.notifier) as _ProgressUi)
            .updatePosition(const Duration(seconds: 42));
        await tester.pump();
        expect(find.byKey(const ValueKey('visible-video')), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Image && widget.image is MemoryImage,
          ),
          findsNothing,
        );
        expect(tester.getRect(find.byType(SharedPlayer)), playerRect);
        expect(
          tester
              .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
              .imageUrl,
          'https://example.com/cover.jpg',
        );
        void expectPosition(int seconds) {
          if (fullscreen) {
            expect(
              tester.widget<Slider>(find.byType(Slider)).value,
              seconds * 1000,
            );
          } else {
            expect(
              tester.widget<PlayerSeekBar>(find.byType(PlayerSeekBar)).position,
              Duration(seconds: seconds),
            );
          }
        }

        expectPosition(42);
        (container.read(playerUiProvider.notifier) as _ProgressUi)
            .updatePosition(const Duration(seconds: 55));
        await tester.pump();
        expectPosition(55);
        await service.setAudioOnly(false);
        service.state.frozenFrame = null;
        (container.read(playerUiProvider.notifier) as _ProgressUi)
            .updatePosition(const Duration(seconds: 56));
        await tester.pump();
        expect(find.byKey(const ValueKey('visible-video')), findsOneWidget);
        expectPosition(56);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('player top controls have evenly spaced centers', (tester) async {
    final service = _FakePlayback()..state.captions = [{}];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerUiProvider.overrideWith(_FakeUi.new)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 225,
              child: SharedPlayer(
                service: service,
                videoOverride: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    final autoplay = tester.getCenter(find.byTooltip('Autoplay off'));
    final captions = tester.getCenter(find.byTooltip('Captions'));
    final settings = tester.getCenter(find.byTooltip('Settings'));
    expect(captions.dx - autoplay.dx, settings.dx - captions.dx);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fullscreen captions sit near the bottom and clear controls', (
    tester,
  ) async {
    final service = _FakePlayback()
      ..state.selectedCaption = 0
      ..state.subtitleText = 'A fullscreen lyric';
    final container = ProviderContainer(
      overrides: [playerUiProvider.overrideWith(_FullscreenCaptionsUi.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 640,
                height: 360,
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
    final player = tester.getRect(find.byType(SharedPlayer));
    final caption = find.text('A fullscreen lyric');
    final hiddenBottom = player.bottom - tester.getRect(caption).bottom;
    expect(hiddenBottom, AppSpacing.xl);

    container.read(playerUiProvider.notifier).setOverlayVisible(true);
    await tester.pump();
    final visibleBottom = player.bottom - tester.getRect(caption).bottom;
    expect(visibleBottom, greaterThan(hiddenBottom));
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
    var nextCalls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerUiProvider.overrideWith(_FullscreenMovingUi.new),
          contentPrefsProvider.overrideWith(_AutoplaySettings.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 500,
              child: SharedPlayer(
                service: service,
                onNext: () => nextCalls++,
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
    final thumb = find.byKey(const ValueKey('fullscreenAutoplayThumb'));
    final startX = tester.getCenter(thumb).dx;
    expect(find.text('Autoplay'), findsOneWidget);
    expect(startX, lessThan(tester.getCenter(find.text('Autoplay')).dx));
    expect(find.byTooltip('Captions'), findsOneWidget);
    expect(find.byIcon(LucideIcons.settings), findsOneWidget);
    expect(find.text('More videos / Play next'), findsNothing);
    await tester.tap(find.byTooltip('Next'));
    expect(nextCalls, 1);
    await tester.dragFrom(const Offset(400, 350), const Offset(0, -100));
    await tester.pump();
    expect(find.text('More videos'), findsNothing);
    await tester.tap(find.text('Autoplay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final middleX = tester.getCenter(thumb).dx;
    await tester.pump(const Duration(milliseconds: 150));
    final endX = tester.getCenter(thumb).dx;
    expect(find.text('Paused'), findsOneWidget);
    expect(endX, greaterThan(tester.getCenter(find.text('Paused')).dx));
    expect(middleX, greaterThan(startX));
    expect(middleX, lessThan(endX));
    expect(
      find.descendant(of: thumb, matching: find.byIcon(Icons.pause_rounded)),
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
