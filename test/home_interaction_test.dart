import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/features/home/home_controller.dart';
import 'package:hivetube/features/home/home_screen.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/features/watch/watch_panel.dart';
import 'package:hivetube/widgets/ui/app_controls.dart';

class _RecordingHome extends HomeController {
  _RecordingHome(this.initialData);

  final HomeData initialData;
  final calls = <String>[];
  final remembered = <String>[];

  @override
  HomeData build() => initialData;

  @override
  void interact() => calls.add('interact');

  @override
  Future<void> rememberChannel(String id, String name, {bool isShort = false}) async {
    remembered.add(id);
  }

  @override
  void select(String chip) {
    calls.add('select:$chip');
    state = AsyncData(initialData.copy(chip: chip));
  }

  @override
  Future<void> refresh() async => calls.add('refresh');

  @override
  Future<void> loadMore() async => calls.add('loadMore');
}

class _TestPlayerUi extends PlayerUiController {
  @override
  PlayerUiState build() => const PlayerUiState();
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
  Future<({String url, String channelId})> Function(
    ({String channelId, String videoId}) key,
  )? avatar,
}) async {
  final container = ProviderContainer(
    overrides: [
      homeProvider.overrideWith(() => _RecordingHome(data)),
      playerUiProvider.overrideWith(_TestPlayerUi.new),
      homeHistoryByIdProvider.overrideWithValue({}),
      channelAvatarProvider.overrideWith(
        (ref, key) =>
            avatar?.call(key) ??
            Future.value((url: '', channelId: key.channelId)),
      ),
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
  return (container: container, router: router);
}

void main() {
  testWidgets('video tap records interaction and opens the watch panel', (
    tester,
  ) async {
    final mounted = await _mount(tester, data: _data());
    await tester.tap(find.text('Video 0').first);
    await tester.pump();

    final home = mounted.container.read(homeProvider.notifier) as _RecordingHome;
    expect(home.calls, contains('interact'));
    expect(home.remembered, contains('video-0'));
    expect(mounted.container.read(watchPanelProvider), 'video-0');
    mounted.router.dispose();
    mounted.container.dispose();
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
    final home = mounted.container.read(homeProvider.notifier) as _RecordingHome;
    expect(home.calls.where((call) => call == 'loadMore').length, 1);
    mounted.router.dispose();
    mounted.container.dispose();
  });

  testWidgets('pull to refresh calls refresh', (tester) async {
    final mounted = await _mount(tester, data: _data());
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 450));
    await tester.pumpAndSettle();
    final home = mounted.container.read(homeProvider.notifier) as _RecordingHome;
    expect(home.calls, contains('refresh'));
    mounted.router.dispose();
    mounted.container.dispose();
  });

  testWidgets('chip tap selects it and updates the selected chip', (tester) async {
    final mounted = await _mount(tester, data: _data());
    await tester.tap(find.text('Music').first);
    await tester.pump();
    final home = mounted.container.read(homeProvider.notifier) as _RecordingHome;
    expect(home.calls, contains('select:Music'));
    final chip = tester.widget<AppChip>(
      find.ancestor(of: find.text('Music').first, matching: find.byType(AppChip)),
    );
    expect(chip.selected, isTrue);
    mounted.router.dispose();
    mounted.container.dispose();
  });

  testWidgets('Shorts shelf tap selects items and navigates to Shorts', (
    tester,
  ) async {
    const shorts = [
      ShortItem(id: 'short-0', thumbUrl: '', title: 'Short 0'),
      ShortItem(id: 'short-1', thumbUrl: '', title: 'Short 1'),
    ];
    final mounted = await _mount(tester, data: _data(shorts: shorts));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Short 0'));
    await tester.tap(find.text('Short 0'));
    await tester.pumpAndSettle();

    final selection = mounted.container.read(shortsSelectionProvider);
    expect(selection.items.map((item) => item.id), ['short-0', 'short-1']);
    expect(selection.index, 0);
    expect(mounted.router.routeInformationProvider.value.uri.path, '/shorts');
    mounted.router.dispose();
    mounted.container.dispose();
  });

  testWidgets('empty state has Retry and partial failures show one banner', (
    tester,
  ) async {
    final empty = await _mount(tester, data: _data(videos: const []));
    expect(find.text('No videos found'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    empty.router.dispose();
    empty.container.dispose();

    final partial = await _mount(
      tester,
      data: _data(errors: const ['source-a', 'source-b']),
    );
    expect(find.text('Some sources could not load'), findsOneWidget);
    partial.router.dispose();
    partial.container.dispose();
  });

  testWidgets('avatar completion does not rebuild feed cards', (tester) async {
    final avatar = Completer<({String url, String channelId})>();
    final builds = <String, int>{};
    final mounted = await _mount(
      tester,
      data: _data(),
      onCardBuilt: (id) => builds.update(
        id,
        (count) => count + 1,
        ifAbsent: () => 1,
      ),
      avatar: (key) => key.channelId == 'channel-0'
          ? avatar.future
          : Future.value((url: '', channelId: key.channelId)),
    );
    final before = Map<String, int>.of(builds);
    avatar.complete((url: '', channelId: 'channel-0'));
    await tester.pump();
    expect(builds, before);
    mounted.router.dispose();
    mounted.container.dispose();
  });
}
