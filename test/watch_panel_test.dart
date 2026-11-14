import 'package:drift/native.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:media_kit/media_kit.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/watch_info.dart';
import 'package:hivetube/core/yt/yt_comments.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/features/watch/mini_player_inset.dart';
import 'package:hivetube/features/watch/watch_panel.dart';
import 'package:hivetube/features/watch/watch_screen.dart';
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
      shortMetadataProvider('vid1').overrideWith((ref) async => null),
      relatedVideosProvider('vid1').overrideWith(_NoRelated.new),
      watchInfoProvider(
        'vid1',
      ).overrideWith((ref) => Completer<WatchInfo>().future),
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
                const Positioned.fill(
                  child: WatchPanel(videoOverride: SizedBox.expand()),
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
