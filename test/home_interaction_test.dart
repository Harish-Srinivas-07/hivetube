import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/features/home/home_controller.dart';
import 'package:hivetube/features/home/home_screen.dart';
import 'package:hivetube/features/shorts/shorts_feed_provider.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/features/watch/watch_panel.dart';
import 'package:hivetube/widgets/ui/app_controls.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _RecordingHome extends HomeController {
  _RecordingHome(this.initialData);

  final HomeData initialData;
  final calls = <String>[];
  final remembered = <String>[];
  Completer<void>? refreshGate;

  @override
  HomeData build() => initialData;

  @override
  void interact() => calls.add('interact');

  @override
  Future<void> rememberChannel(
    String id,
    String name, {
    bool isShort = false,
  }) async {
    remembered.add(id);
  }

  @override
  void select(String chip) {
    calls.add('select:$chip');
    state = AsyncData(initialData.copy(chip: chip));
  }

  @override
  Future<void> refresh() async {
    calls.add('refresh');
    final previous = state.value!;
    state = AsyncData(previous.copy(isRefreshing: true));
    await refreshGate?.future;
    state = AsyncData(previous.copy(isRefreshing: false));
  }

  @override
  void applyFreshFeed() {
    calls.add('applyFreshFeed');
    state = AsyncData(initialData.copy(hasFreshFeed: false));
  }

  @override
  Future<void> loadMore() async => calls.add('loadMore');
}

class _TestPlayerUi extends PlayerUiController {
  @override
  PlayerUiState build() => const PlayerUiState();
}

class _ShortsFeed extends ShortsFeedController {
  @override
  ShortsFeedState build() => const ShortsFeedState();

  @override
  Future<void> prefetch({List<ShortItem> seedItems = const []}) async {}
}

List<VideoItem> _videos() => List.generate(
  10,
  (i) => VideoItem(
    id: 'video-$i',
    title: 'Video $i',
    channelId: 'channel-$i',
    channelName: 'Channel $i',
  ),
);

HomeData _data({
  List<VideoItem>? videos,
  List<ShortItem> shorts = const [],
  List<String> errors = const [],
  Map<String, String> continuations = const {},
}) => HomeData(
  videos: videos ?? _videos(),
  shorts: shorts,
  errors: errors,
  continuations: continuations,
);

Future<({ProviderContainer container, GoRouter router})> _mount(
  WidgetTester tester, {
  required HomeData data,
  void Function(String id)? onCardBuilt,
  bool offline = false,
  Future<({String url, String channelId})> Function(
    ({String channelId, String videoId}) key,
  )?
  avatar,
}) async {
  final container = ProviderContainer(
    overrides: [
      homeProvider.overrideWith(() => _RecordingHome(data)),
      isOfflineProvider.overrideWithValue(offline),
      playerUiProvider.overrideWith(_TestPlayerUi.new),
      homeHistoryByIdProvider.overrideWithValue({}),
      channelAvatarProvider.overrideWith(
        (ref, key) =>
            avatar?.call(key) ??
            Future.value((url: '', channelId: key.channelId)),
      ),
      shortsFeedProvider.overrideWith(_ShortsFeed.new),
    ],
  );
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomeScreen(onCardBuilt: onCardBuilt),
      ),
      GoRoute(
        path: '/shorts',
        builder: (context, state) => const Scaffold(body: Text('Shorts route')),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  addTearDown(router.dispose);
  addTearDown(container.dispose);
  return (container: container, router: router);
}

void main() {
  test('offline state requires an explicit disconnected result', () async {
    final changes = StreamController<List<ConnectivityResult>>();
    final container = ProviderContainer(
      overrides: [connectivityProvider.overrideWith((ref) => changes.stream)],
    );
    final subscription = container.listen(isOfflineProvider, (_, _) {});
    expect(container.read(isOfflineProvider), isFalse);
    changes.add([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(isOfflineProvider), isTrue);
    changes.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(isOfflineProvider), isFalse);
    subscription.close();
    container.dispose();
    await changes.close();
  });
  testWidgets('offline Home shows the downloads shortcut', (tester) async {
    await _mount(tester, data: _data(videos: []), offline: true);
    expect(find.text('Go to downloads'), findsOneWidget);
  });
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('fresh feed button applies the waiting feed', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final mounted = await _mount(
      tester,
      data: _data().copy(hasFreshFeed: true),
    );
    expect(find.text('Video 0'), findsWidgets);
    expect(find.text('Refresh feed'), findsOneWidget);
    final button = find.byWidgetPredicate(
      (widget) => widget is AppButton && widget.label == 'Refresh feed',
    );
    final initial = tester.getRect(button);
    expect(
      initial.width,
      lessThan(tester.getSize(find.byType(Scaffold).first).width),
    );
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -200),
    );
    await tester.pump();
    expect(tester.getTopLeft(button).dy, lessThan(initial.top));
    await tester.tap(find.text('Refresh feed'));
    await tester.pump();
    final home =
        mounted.container.read(homeProvider.notifier) as _RecordingHome;
    expect(home.calls, contains('applyFreshFeed'));
    expect(find.text('Refresh feed'), findsNothing);
  });

  testWidgets('video tap records interaction and opens the watch panel', (
    tester,
  ) async {
    final mounted = await _mount(tester, data: _data());
    await tester.tap(find.text('Video 0').first);
    await tester.pump();

    final home =
        mounted.container.read(homeProvider.notifier) as _RecordingHome;
    expect(home.calls, contains('interact'));
    expect(home.remembered, contains('video-0'));
    expect(mounted.container.read(watchPanelProvider), 'video-0');
  });

  testWidgets('load more fires once for repeated notifications at the end', (
    tester,
  ) async {
    final mounted = await _mount(
      tester,
      data: _data(continuations: const {'mixer': 'more'}),
    );
    final scrollable = find.byType(CustomScrollView);
    await tester.drag(scrollable, const Offset(0, -5000));
    await tester.pumpAndSettle();
    final home =
        mounted.container.read(homeProvider.notifier) as _RecordingHome;
    expect(home.calls.where((call) => call == 'loadMore').length, 1);
  });

  testWidgets('pull to refresh calls refresh', (tester) async {
    final mounted = await _mount(tester, data: _data());
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 450));
    await tester.pumpAndSettle();
    final home =
        mounted.container.read(homeProvider.notifier) as _RecordingHome;
    expect(home.calls, contains('refresh'));
  });

  testWidgets('chip tap selects it and updates the selected chip', (
    tester,
  ) async {
    final mounted = await _mount(tester, data: _data());
    await tester.tap(find.text('Music').first);
    await tester.pump();
    final home =
        mounted.container.read(homeProvider.notifier) as _RecordingHome;
    expect(home.calls, contains('select:Music'));
    final chip = tester.widget<AppChip>(
      find.ancestor(
        of: find.text('Music').first,
        matching: find.byType(AppChip),
      ),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('Shorts shelf tap selects items and navigates to Shorts', (
    tester,
  ) async {
    const shorts = [
      ShortItem(id: 'short-0', thumbUrl: '', title: 'Short 0'),
      ShortItem(id: 'short-1', thumbUrl: '', title: 'Short 1'),
    ];
    final mounted = await _mount(tester, data: _data(shorts: shorts));
    await tester.scrollUntilVisible(
      find.text('Short 0'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Short 0'));
    await tester.pumpAndSettle();

    final selection = mounted.container.read(shortsSelectionProvider);
    expect(selection.items.map((item) => item.id), ['short-0', 'short-1']);
    expect(selection.index, 0);
    expect(mounted.router.routeInformationProvider.value.uri.path, '/shorts');
  });

  testWidgets('empty state has Retry and partial failures show one banner', (
    tester,
  ) async {
    await _mount(tester, data: _data(videos: const []));
    expect(find.text('No videos found'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await _mount(tester, data: _data(errors: const ['source-a', 'source-b']));
    expect(find.text('Some sources could not load'), findsOneWidget);
  });

  testWidgets('partial failure retry shows progress and keeps videos', (
    tester,
  ) async {
    final mounted = await _mount(tester, data: _data(errors: const ['Feed']));
    final home =
        mounted.container.read(homeProvider.notifier) as _RecordingHome;
    home.refreshGate = Completer<void>();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(home.calls.where((call) => call == 'refresh').length, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Video 0'), findsWidgets);
    home.refreshGate!.complete();
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('avatar completion does not rebuild feed cards', (tester) async {
    final avatar = Completer<({String url, String channelId})>();
    final builds = <String, int>{};
    await _mount(
      tester,
      data: _data(),
      onCardBuilt: (id) =>
          builds.update(id, (count) => count + 1, ifAbsent: () => 1),
      avatar: (key) => key.channelId == 'channel-0'
          ? avatar.future
          : Future.value((url: '', channelId: key.channelId)),
    );
    final before = Map<String, int>.of(builds);
    avatar.complete((url: '', channelId: 'channel-0'));
    await tester.pump();
    expect(builds, before);
  });
}
