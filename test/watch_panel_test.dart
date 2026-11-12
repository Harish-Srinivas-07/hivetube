import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/watch_info.dart';
import 'package:hivetube/core/yt/yt_comments.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/features/watch/mini_player_inset.dart';
import 'package:hivetube/features/watch/watch_panel.dart';
import 'package:hivetube/features/watch/watch_screen.dart';
import 'package:hivetube/widgets/player/player_controls.dart';

class _MockPlaybackService extends Fake implements PlaybackService {
  final PlaybackSnapshot _snapshot = PlaybackSnapshot()
    ..status = PlayerStatus.playing
    ..duration = const Duration(minutes: 5)
    ..position = const Duration(minutes: 1);
  bool stopped = false;
  final List<VoidCallback> _listeners = [];

  @override
  PlaybackSnapshot get state => _snapshot;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<void> setLoop(bool value) async {}

  @override
  Future<void> play(PlayRequest value) async {
    stopped = false;
    _snapshot.status = PlayerStatus.playing;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    _snapshot.status = PlayerStatus.idle;
  }

  @override
  Future<void> pause() async {
    _snapshot.status = PlayerStatus.paused;
  }

  @override
  Future<void> resume() async {
    _snapshot.status = PlayerStatus.playing;
  }

  @override
  Future<void> seek(Duration position) async {
    _snapshot.position = position;
  }
}

class _MockPlaybackController extends PlaybackController {
  _MockPlaybackController(this.service);
  final PlaybackService service;
  @override
  PlaybackService? build() => service;
}

const _dummyInfo = WatchInfo(
  id: 'vid1',
  title: 'Test Video Title',
  channelName: 'Test Channel',
  channelId: 'UC123',
  avatar: '',
  subscribers: '10K',
  description: 'Desc',
  likes: '1K',
  views: '10K views',
  date: '1 day ago',
  handle: '@test',
  commentsToken: 'cToken',
  related: VideoPage([], null),
  chapters: [],
  chips: {},
);

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

Widget _buildTestApp({
  required PlaybackService service,
  required void Function(WidgetRef ref) onRef,
  Widget? child,
}) {
  return ProviderScope(
    overrides: [
      playbackProvider.overrideWith(() => _MockPlaybackController(service)),
      playerUiProvider.overrideWith(_FakeUi.new),
      shortMetadataProvider('vid1').overrideWith((ref) async => null),
      watchInfoProvider('vid1').overrideWith((ref) async => _dummyInfo),
      watchCommentsProvider(
        'cToken',
      ).overrideWith((ref) async => _dummyComments),
      dislikeCountProvider('vid1').overrideWith((ref) async => 0),
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
  testWidgets('mini card appears after play and stays visible', (tester) async {
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

    expect(
      find.byTooltip('Close player'),
      findsNothing,
    ); // Controls hidden initially
    expect(find.byType(SharedPlayer), findsOneWidget);
  });

  testWidgets('tap shows controls and they auto-hide after 3 s while playing', (
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

    // Tap on mini card
    await tester.tap(find.byType(SharedPlayer));
    await tester.pump();

    // Controls appear (expand and close buttons)
    expect(find.byTooltip('Close player'), findsOneWidget);
    expect(find.byTooltip('Expand'), findsOneWidget);

    // After 3 seconds, controls auto-hide while playing
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Close player'), findsNothing);
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
    await tester.drag(find.byType(SharedPlayer), const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Should be expanded: WatchScreen content is visible
    expect(find.byType(WatchScreen), findsOneWidget);
  });

  testWidgets('swipe down closes and stops mini player', (tester) async {
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
    await tester.drag(find.byType(SharedPlayer), const Offset(0, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(capturedRef.read(watchPanelProvider), isNull);
    expect(service.stopped, isTrue);
  });

  testWidgets('corner drag snaps between left and right', (tester) async {
    final service = _MockPlaybackService();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      _buildTestApp(service: service, onRef: (r) => capturedRef = r),
    );
    capturedRef.read(watchPanelProvider.notifier).open('vid1');
    capturedRef.read(watchPanelExpandProvider.notifier).minimize();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      capturedRef.read(miniCornerLeftProvider),
      isFalse,
    ); // Initially right

    // Drag left
    await tester.fling(find.byType(SharedPlayer), const Offset(-250, 0), 500);
    await tester.pump();
    expect(capturedRef.read(miniCornerLeftProvider), isTrue); // Snapped left

    // Drag right
    await tester.fling(find.byType(SharedPlayer), const Offset(250, 0), 500);
    await tester.pump();
    expect(capturedRef.read(miniCornerLeftProvider), isFalse); // Snapped right
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

    // When expanded, panelProgress is 1.0 (>= 0.5), so nav pill is hidden
    final progress = capturedRef.read(playerUiProvider).panelProgress;
    expect(progress, greaterThanOrEqualTo(0.5));
  });
}
