import 'package:drift/native.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/streams/stream_selector.dart';
import 'package:hivetube/core/yt/watch_info.dart';
import 'package:hivetube/core/yt/yt_comments.dart';
import 'package:hivetube/features/channel/channel_screen.dart';
import 'package:hivetube/features/watch/mini_player_inset.dart';
import 'package:hivetube/features/watch/watch_panel.dart';
import 'package:hivetube/features/watch/watch_screen.dart';
import 'package:hivetube/widgets/player/player_controls.dart';
import 'package:hivetube/widgets/common/channel_avatar.dart';

class _FakeMediaPlayerState extends Fake implements PlayerState {
  int? videoWidth;
  int? videoHeight;
  @override
  int? get width => videoWidth;
  @override
  int? get height => videoHeight;
  @override
  List<String> get subtitle => const [];
}

class _FakeMediaPlayerStream extends Fake implements PlayerStream {
  @override
  Stream<List<String>> get subtitle => const Stream.empty();
}

class _FakeMediaPlayer extends Fake implements Player {
  final _state = _FakeMediaPlayerState();
  @override
  PlayerState get state => _state;
  @override
  PlayerStream get stream => _FakeMediaPlayerStream();
}

class _FakeVideoController extends Fake implements VideoController {
  _FakeVideoController(this.player);
  @override
  final Player player;
}

class _MockPlaybackService extends Fake implements PlaybackService {
  final Player _player = _FakeMediaPlayer();
  PlayRequest? _request;
  final PlaybackSnapshot _snapshot = PlaybackSnapshot()
    ..status = PlayerStatus.playing
    ..playing = true
    ..duration = const Duration(minutes: 5)
    ..position = const Duration(minutes: 1);
  bool stopped = false;
  int toggleCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  final List<VoidCallback> _listeners = [];

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  @override
  PlaybackSnapshot get state => _snapshot;

  @override
  Player get player => _player;

  @override
  VideoController get controller => _FakeVideoController(_player);

  @override
  PlayRequest? get request => _request;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<void> setLoop(bool value) async {}

  @override
  Future<void> play(PlayRequest value) async {
    _request = value;
    stopped = false;
    _snapshot.playing = true;
    _snapshot.status = PlayerStatus.playing;
    _notifyListeners();
  }

  @override
  Future<void> playVideoRequest(PlayRequest value) => play(value);

  @override
  Future<void> stop() async {
    stopped = true;
    _snapshot.status = PlayerStatus.idle;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _snapshot.playing = false;
    _snapshot.status = PlayerStatus.paused;
    _notifyListeners();
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    _snapshot.playing = true;
    _snapshot.status = PlayerStatus.playing;
    _notifyListeners();
  }

  @override
  Future<void> seek(Duration position) async {
    _snapshot.position = position;
  }

  @override
  Future<void> togglePlay() async {
    toggleCalls++;
    if (_snapshot.playing) {
      await pause();
    } else {
      await resume();
    }
  }
}

class _MockPlaybackController extends PlaybackController {
  _MockPlaybackController(this.service);
  final PlaybackService service;
  @override
  PlaybackService? build() => service;
}

class _NoRelated extends RelatedVideosController {
  _NoRelated() : super('vid1');

  @override
  Future<List<VideoItem>> build() async => [];
}

const _dummyComments = CommentPage([], '0 Comments', null, {});

class _FakeUi extends PlayerUiController {
  @override
  PlayerUiState build() => const PlayerUiState(
    playing: true,
    dismissed: false,
    duration: Duration(minutes: 5),
    position: Duration(minutes: 1),
  );
}

class _ListeningUi extends PlayerUiController {
  @override
  PlayerUiState build() {
    final service = ref.watch(playbackProvider);
    if (service == null) return const PlayerUiState(dismissed: false);
    void changed() {
      state = state.copyWith(
        playing: service.state.playing,
        recovering: service.state.recovering,
      );
    }

    service.addListener(changed);
    ref.onDispose(() => service.removeListener(changed));
    return PlayerUiState(playing: service.state.playing, dismissed: false);
  }
}

Widget _buildTestApp({
  required PlaybackService service,
  required void Function(WidgetRef ref) onRef,
  Widget? child,
  bool listenPlayback = false,
  GlobalKey? miniPlayerKey,
  WatchInfo? savedInfo,
}) {
  final db = AppDb(NativeDatabase.memory());
  addTearDown(db.close);
  return ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      playbackProvider.overrideWith(() => _MockPlaybackController(service)),
      playerUiProvider.overrideWith(
        listenPlayback ? _ListeningUi.new : _FakeUi.new,
      ),
      relatedVideosProvider('vid1').overrideWith(_NoRelated.new),
      watchInfoProvider('vid1').overrideWith(
        (ref) => savedInfo == null
            ? Completer<WatchInfo>().future
            : Future.value(savedInfo),
      ),
      watchCommentsProvider(
        'cToken',
      ).overrideWith((ref) async => _dummyComments),
      dislikeCountProvider('vid1').overrideWith((ref) async => 0),
      historyRepoProvider.overrideWithValue(EmptyHistoryRepo()),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) {
          onRef(ref);
          return Scaffold(
            body: Stack(
              children: [
                child ?? const SizedBox.expand(),
                Positioned.fill(
                  child: WatchPanel(
                    videoOverride: const SizedBox.expand(),
                    miniPlayerKey: miniPlayerKey,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets('audio-only playback shows the saved video thumbnail', (
    tester,
  ) async {
    final service = _MockPlaybackService()..state.mode = PlaybackMode.audio;
    late WidgetRef capturedRef;
    await tester.pumpWidget(
      _buildTestApp(
        service: service,
        onRef: (ref) => capturedRef = ref,
        savedInfo: const WatchInfo(
          id: 'vid1',
          title: 'Downloaded audio',
          channelName: 'Test channel',
          channelId: 'UCtest',
          avatar: '',
          subscribers: '',
          description: '',
          likes: '',
          views: '',
          date: '',
          handle: '',
          commentsToken: null,
          related: VideoPage([], null),
          chapters: [],
          chips: {},
          thumbnail: 'https://example.com/audio-cover.jpg',
        ),
      ),
    );
    capturedRef.read(watchPanelProvider.notifier).open('vid1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester
          .widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first)
          .imageUrl,
      'https://example.com/audio-cover.jpg',
    );
    expect(service.state.frameReadyId, isNull);
  });

  testWidgets('watch panel ignores dimensions from the preceding Short', (
    tester,
  ) async {
    final service = _MockPlaybackService();
    final player = service.player as _FakeMediaPlayer;
    player._state.videoWidth = 1080;
    player._state.videoHeight = 1920;
    service.state.frameReadyId = 'short';
    late WidgetRef capturedRef;
    final playerKey = GlobalKey();
    await tester.pumpWidget(
      _buildTestApp(
        service: service,
        onRef: (ref) => capturedRef = ref,
        miniPlayerKey: playerKey,
      ),
    );
    capturedRef.read(watchPanelProvider.notifier).open('vid1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final size = tester.getSize(find.byKey(playerKey));
    expect(size.width / size.height, closeTo(16 / 9, .001));
    expect(videoAspectRatioFromController(service, videoId: 'vid1'), isNull);
    service.state.frameReadyId = 'vid1';
    expect(
      videoAspectRatioFromController(service, videoId: 'vid1'),
      closeTo(9 / 16, .001),
    );
  });
  testWidgets('watch channel tap pushes a visible channel route', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final navigatorKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/channel/:id',
          builder: (_, state) =>
              ChannelScreen(channelId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    var minimized = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(
            () => _MockPlaybackController(_MockPlaybackService()),
          ),
          playerUiProvider.overrideWith(_FakeUi.new),
          watchInfoProvider('vid1').overrideWith(
            (ref) async => const WatchInfo(
              id: 'vid1',
              title: 'Video',
              channelName: 'Test channel',
              channelId: 'UCtest',
              avatar: '',
              subscribers: '',
              description: '',
              likes: '',
              views: '',
              date: '',
              handle: '',
              commentsToken: null,
              related: VideoPage([], null),
              chapters: [],
              chips: {},
            ),
          ),
          dislikeCountProvider('vid1').overrideWith((ref) async => 0),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => StatefulBuilder(
            builder: (context, setState) => Stack(
              children: [
                child!,
                if (!minimized)
                  WatchScreen(
                    id: 'vid1',
                    embedded: true,
                    placeholderVideo: true,
                    navigatorContext: () => navigatorKey.currentContext,
                    onMinimize: () => setState(() => minimized = true),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Test channel').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(minimized, isTrue);
    expect(find.byType(ChannelScreen), findsOneWidget);
    expect(find.byType(WatchScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recommended channel avatar opens channel from player overlay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final navigatorKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/channel/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Channel ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    var minimized = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          isOfflineProvider.overrideWithValue(false),
          playbackProvider.overrideWith(
            () => _MockPlaybackController(_MockPlaybackService()),
          ),
          playerUiProvider.overrideWith(_FakeUi.new),
          watchInfoProvider('vid1').overrideWith(
            (ref) async => const WatchInfo(
              id: 'vid1',
              title: 'Video',
              channelName: 'Original channel',
              channelId: 'UCoriginal',
              avatar: '',
              subscribers: '',
              description: '',
              likes: '',
              views: '',
              date: '',
              handle: '',
              commentsToken: null,
              chapters: [],
              chips: {},
              related: VideoPage([
                VideoItem(
                  id: 'related',
                  title: 'A recommended video',
                  channelId: 'UCrecommended',
                  channelName: 'Recommended channel',
                  channelAvatarUrl: 'https://example.com/avatar.jpg',
                ),
              ], null),
            ),
          ),
          dislikeCountProvider('vid1').overrideWith((ref) async => 0),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => StatefulBuilder(
            builder: (context, setState) => Stack(
              children: [
                child!,
                if (!minimized)
                  Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => WatchScreen(
                        id: 'vid1',
                        embedded: true,
                        placeholderVideo: true,
                        navigatorContext: () => navigatorKey.currentContext,
                        onMinimize: () => setState(() => minimized = true),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final avatar = find.byWidgetPredicate(
      (widget) =>
          widget is ChannelAvatar && widget.name == 'Recommended channel',
    );
    expect(avatar, findsWidgets);
    await tester.tap(avatar.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(minimized, isTrue);
    expect(find.text('Channel UCrecommended'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'expanded player pause does not resume during WatchPanel rebuild',
    (tester) async {
      final service = _MockPlaybackService();
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        _buildTestApp(
          service: service,
          onRef: (r) => capturedRef = r,
          listenPlayback: true,
        ),
      );
      capturedRef.read(watchPanelProvider.notifier).open('vid1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        capturedRef.read(playerUiProvider).panelMode,
        PlayerPanelMode.expanded,
      );
      expect(
        find.byKey(const ValueKey('playerPlayPauseButton')),
        findsOneWidget,
      );

      service.pauseCalls = 0;
      service.resumeCalls = 0;
      await tester.tap(find.byKey(const ValueKey('playerPlayPauseButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(service.pauseCalls, 1);
      expect(service.resumeCalls, 0);
      expect(service.state.status, PlayerStatus.paused);
    },
  );

  testWidgets('mini card always shows only play and close controls', (
    tester,
  ) async {
    final service = _MockPlaybackService();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      _buildTestApp(service: service, onRef: (r) => capturedRef = r),
    );
    expect(find.byType(WatchPanel), findsOneWidget);

    // Open video in mini mode
    capturedRef.read(watchPanelProvider.notifier).open('vid1');
    capturedRef.read(watchPanelExpandProvider.notifier).minimize();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Pause'),
      findsOneWidget,
      reason:
          'progress=${capturedRef.read(watchPanelProgressProvider).value}, '
          'mode=${capturedRef.read(playerUiProvider).panelMode}',
    );
    expect(find.byTooltip('Close player'), findsOneWidget);
    expect(find.byTooltip('Expand'), findsNothing);
    expect(find.byTooltip('Previous'), findsNothing);
    expect(find.byTooltip('Next'), findsNothing);
    expect(find.byType(SharedPlayer), findsOneWidget);
  });

  testWidgets('tap mini body expands and play toggles playback', (
    tester,
  ) async {
    final service = _MockPlaybackService();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      _buildTestApp(service: service, onRef: (r) => capturedRef = r),
    );
    capturedRef.read(watchPanelProvider.notifier).open('vid1');
    capturedRef.read(watchPanelExpandProvider.notifier).minimize();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('miniPlayerDragSurface')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(WatchScreen), findsOneWidget);

    capturedRef.read(watchPanelExpandProvider.notifier).minimize();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(service.toggleCalls, 1);
  });

  testWidgets('swipe up expands watch panel', (tester) async {
    final service = _MockPlaybackService();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      _buildTestApp(service: service, onRef: (r) => capturedRef = r),
    );
    capturedRef.read(watchPanelProvider.notifier).open('vid1');
    capturedRef.read(watchPanelExpandProvider.notifier).minimize();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Swipe up on mini player
    await tester.fling(
      find.byKey(const ValueKey('miniPlayerDragSurface')),
      const Offset(0, -300),
      2000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Should be expanded: WatchScreen content is visible
    expect(find.byType(WatchScreen), findsOneWidget);
  });

  testWidgets('mini downward drag snaps without stopping playback', (
    tester,
  ) async {
    final service = _MockPlaybackService();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      _buildTestApp(service: service, onRef: (r) => capturedRef = r),
    );
    capturedRef.read(watchPanelProvider.notifier).open('vid1');
    capturedRef.read(watchPanelExpandProvider.notifier).minimize();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Swipe down on mini player
    await tester.drag(
      find.byKey(const ValueKey('miniPlayerDragSurface')),
      const Offset(0, 100),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(capturedRef.read(watchPanelProvider), 'vid1');
    expect(service.stopped, isFalse);
  });

  testWidgets('free drag snaps to all four corners', (tester) async {
    final service = _MockPlaybackService();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      _buildTestApp(service: service, onRef: (r) => capturedRef = r),
    );
    capturedRef.read(watchPanelProvider.notifier).open('vid1');
    capturedRef.read(watchPanelExpandProvider.notifier).minimize();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(capturedRef.read(miniCornerProvider), MiniCorner.br);

    final dragFinder = find.byKey(const ValueKey('miniPlayerDragSurface'));
    for (final step in [
      (const Offset(-600, 0), MiniCorner.bl),
      (const Offset(0, -500), MiniCorner.tl),
      (const Offset(600, 0), MiniCorner.tr),
      (const Offset(0, 500), MiniCorner.br),
    ]) {
      await tester.drag(dragFinder, step.$1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(capturedRef.read(miniCornerProvider), step.$2);
    }
  });

  testWidgets('bottom padding is applied via MiniPlayerInset', (tester) async {
    double capturedInset = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: MiniPlayerInset(
          bottom: 120.0,
          child: Builder(
            builder: (context) {
              capturedInset = MiniPlayerInset.of(context);
              return const CustomScrollView(slivers: [SliverBottomInset()]);
            },
          ),
        ),
      ),
    );
    expect(capturedInset, 120.0);
  });

  testWidgets('Back order sequence: expanded player minimises on back', (
    tester,
  ) async {
    final service = _MockPlaybackService();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      _buildTestApp(service: service, onRef: (r) => capturedRef = r),
    );
    capturedRef.read(watchPanelProvider.notifier).open('vid1');
    // Opens expanded by default
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(WatchScreen), findsOneWidget);

    // Simulate system back
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Video is still playing, but minimised
    expect(capturedRef.read(watchPanelProvider), 'vid1');
  });

  testWidgets('hidden on Shorts and playback handed over', (tester) async {
    final service = _MockPlaybackService();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      _buildTestApp(service: service, onRef: (r) => capturedRef = r),
    );
    capturedRef.read(watchPanelProvider.notifier).open('vid1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(capturedRef.read(watchPanelProvider), 'vid1');

    // Close panel as happens when entering Shorts
    capturedRef.read(watchPanelProvider.notifier).close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(capturedRef.read(watchPanelProvider), isNull);
    expect(service.stopped, isTrue);
  });

  testWidgets('nav pill hides when panel expands', (tester) async {
    final service = _MockPlaybackService();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      _buildTestApp(service: service, onRef: (r) => capturedRef = r),
    );

    capturedRef.read(watchPanelProvider.notifier).open('vid1');
    capturedRef.read(watchPanelExpandProvider.notifier).expand();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      capturedRef.read(playerUiProvider).panelMode,
      PlayerPanelMode.expanded,
    );
  });
}
