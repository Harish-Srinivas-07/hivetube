import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/main.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/yt_search.dart';
import 'package:hivetube/features/downloads/downloads_screen.dart';
import 'package:hivetube/theme/app_spacing.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/core/playback/picture_in_picture.dart';
import 'package:hivetube/features/watch/watch_panel.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/features/shorts/shorts_feed_provider.dart';
import 'package:hivetube/features/search/search_screen.dart';
import 'package:hivetube/widgets/floating_nav.dart';
import 'package:hivetube/widgets/sheets/app_sheet.dart';

class _NoPlayback extends PlaybackController {
  @override
  PlaybackService? build() => null;
}

class _TestPip extends PictureInPictureController {
  @override
  bool build() => false;
  void setActive(bool value) => state = value;
}

class _EmptyShortsFeed extends ShortsFeedController {
  @override
  ShortsFeedState build() => const ShortsFeedState(hasLoaded: true);

  @override
  Future<void> loadInitial({bool refresh = false}) async {}
}

class _SearchApi extends Fake implements YtApi {
  @override
  YtSearch get search => _ShortsSearch();
}

class _ShortsSearch extends Fake implements YtSearch {
  @override
  Future<SearchResultPage> search(
    String query, {
    String? continuation,
    String? params,
    CancelToken? cancelToken,
  }) async => const SearchResultPage(
    items: [
      ShortsShelfSearchResult([
        ShortItem(id: 'short-one', thumbUrl: '', title: 'Search short'),
      ]),
    ],
  );
}

void main() {
  testWidgets('entering PiP dismisses player sheets and restores the app', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        playbackProvider.overrideWith(_NoPlayback.new),
        shortsFeedProvider.overrideWith(_EmptyShortsFeed.new),
        pictureInPictureProvider.overrideWith(_TestPip.new),
      ],
    );
    appRouter.go('/home');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final playerContext = tester.element(find.byType(WatchPanel));
    showAppSheet<void>(
      playerContext,
      title: 'Player options',
      builder: (_, _) => const Text('Sheet content'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sheet content'), findsOneWidget);
    (container.read(pictureInPictureProvider.notifier) as _TestPip).setActive(
      true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sheet content'), findsNothing);
    (container.read(pictureInPictureProvider.notifier) as _TestPip).setActive(
      false,
    );
    await tester.pump();
    expect(find.byTooltip('Search'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('system back preserves routed screens and returns Shorts home', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    appRouter.go('/home');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_NoPlayback.new),
          shortsFeedProvider.overrideWith(_EmptyShortsFeed.new),
          shortMetadataProvider('back-video').overrideWith((ref) async => null),
        ],
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    appRouter.push('/search');
    await tester.pump(const Duration(milliseconds: 500));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WatchPanel)),
    );
    container.read(watchPanelProvider.notifier).open('back-video');
    container.read(watchPanelExpandProvider.notifier).expand();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      container.read(playerUiProvider).panelMode,
      PlayerPanelMode.expanded,
    );
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(watchPanelProvider), 'back-video');
    expect(container.read(playerUiProvider).panelMode, PlayerPanelMode.mini);
    expect(find.byType(SearchScreen), findsOneWidget);
    calls.clear();
    const NavigationNotification(
      canHandlePop: false,
    ).dispatch(tester.element(find.byType(WatchPanel)));
    await tester.pump();
    expect(
      calls
          .where(
            (call) => call.method == 'SystemNavigator.setFrameworkHandlesBack',
          )
          .last
          .arguments,
      isTrue,
    );
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SearchScreen), findsNothing);
    expect(appRouter.routeInformationProvider.value.uri.path, '/home');

    appRouter.go('/shorts');
    await tester.pump(const Duration(milliseconds: 500));
    calls.clear();
    const NavigationNotification(
      canHandlePop: false,
    ).dispatch(tester.element(find.byType(WatchPanel)));
    await tester.pump();
    expect(
      calls
          .where(
            (call) => call.method == 'SystemNavigator.setFrameworkHandlesBack',
          )
          .last
          .arguments,
      isTrue,
    );
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(appRouter.routeInformationProvider.value.uri.path, '/home');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('search short returns to the same search screen', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    appRouter.go('/home');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_NoPlayback.new),
          shortsFeedProvider.overrideWith(_EmptyShortsFeed.new),
          ytApiProvider.overrideWith((ref) async => _SearchApi()),
          shortMetadataProvider('short-one').overrideWith((ref) async => null),
        ],
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    appRouter.push('/search?q=music');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final searchState = tester.state(find.byType(SearchScreen));
    await tester.tap(find.text('Search short').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ShortsScreen), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(
      identical(tester.state(find.byType(SearchScreen)), searchState),
      isTrue,
    );
    appRouter.push('/watch/deep-video');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SearchScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WatchPanel)),
    );
    expect(container.read(watchPanelProvider), 'deep-video');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(
      identical(tester.state(find.byType(SearchScreen)), searchState),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('downloaded video minimizes back to Downloads', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            videoId: 'download-one',
            title: 'Saved video',
            channelId: 'channel',
            channelName: 'Channel',
            thumbUrl: '',
            updatedAt: 1,
          ),
        );
    await db
        .into(db.downloads)
        .insert(
          DownloadsCompanion.insert(
            videoId: 'download-one',
            kind: 'video',
            status: const Value('completed'),
            createdAt: 1,
          ),
        );
    appRouter.go('/home');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_NoPlayback.new),
          shortsFeedProvider.overrideWith(_EmptyShortsFeed.new),
          shortMetadataProvider(
            'download-one',
          ).overrideWith((ref) async => null),
        ],
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    rootNavigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const DownloadsScreen()),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final downloadsState = tester.element(find.byType(DownloadsScreen));
    await tester.tap(find.text('Saved video').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DownloadsScreen), findsOneWidget);
    expect(
      identical(tester.element(find.byType(DownloadsScreen)), downloadsState),
      isTrue,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WatchPanel)),
    );
    expect(container.read(playerUiProvider).panelMode, PlayerPanelMode.mini);
    expect(container.read(watchPanelProvider), 'download-one');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  for (final size in [
    const Size(400, 800),
    const Size(800, 400),
    const Size(1200, 800),
  ]) {
    testWidgets('mini player allows navigation and survives resume at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_NoPlayback.new),
          shortsFeedProvider.overrideWith(_EmptyShortsFeed.new),
          shortMetadataProvider('mini').overrideWith((ref) async => null),
        ],
      );
      appRouter.go('/home');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HiveTubeApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      container.read(watchPanelProvider.notifier).open('mini');
      container.read(watchPanelExpandProvider.notifier).minimize();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(playerUiProvider).panelMode, PlayerPanelMode.mini);

      final wide = size.shortestSide >= AppSpacing.navigationBreakpoint;
      final nav = wide ? find.byType(NavigationRail) : find.byType(FloatingNav);
      final mini = find.descendant(
        of: find.byType(WatchPanel),
        matching: find.byWidgetPredicate(
          (widget) => widget is ClipRRect && widget.key is GlobalKey,
        ),
      );
      expect(tester.getRect(mini).overlaps(tester.getRect(nav)), isFalse);
      Future<void> tapTab(String label, String path) async {
        final nav = wide
            ? find.byType(NavigationRail)
            : find.byType(FloatingNav);
        final target = wide
            ? find.descendant(of: nav, matching: find.text(label))
            : find.descendant(of: nav, matching: find.byTooltip(label));
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(appRouter.routeInformationProvider.value.uri.path, path);
      }

      await tapTab('Library', '/library');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(appRouter.routeInformationProvider.value.uri.path, '/library');
      expect(container.read(watchPanelProvider), 'mini');
      expect(container.read(playerUiProvider).panelMode, PlayerPanelMode.mini);
      await tapTab(wide ? 'Subscriptions' : 'Subs', '/subscriptions');
      await tapTab('Home', '/home');
      await tapTab('Shorts', '/shorts');
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(seconds: 1));
    });
  }
  for (final size in [
    const Size(400, 800),
    const Size(800, 400),
    const Size(1200, 800),
  ]) {
    testWidgets('navigation at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      appRouter.go('/home');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: const HiveTubeApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final wide = size.shortestSide >= 600;
      final nav = !wide
          ? find.byKey(const ValueKey('floatingNavSurface'))
          : find.byType(NavigationRail);
      expect(nav, findsOneWidget);
      expect(find.byKey(const ValueKey('notificationBadge')), findsNothing);
      expect(find.byTooltip('Search'), findsOneWidget);
      if (wide) {
        final labels = size.width > size.height
            ? ['Home', 'Shorts', 'Subs', 'Library']
            : ['Home', 'Shorts', 'Subscriptions', 'Library'];
        for (final label in labels) {
          expect(
            find.descendant(of: nav, matching: find.text(label)),
            findsOneWidget,
          );
        }
      } else {
        final bar = tester.getRect(nav);
        expect(bar.center.dx, closeTo(size.width / 2, 0.1));
        expect(bar.width, lessThan(size.width));
        expect(bar.bottom, closeTo(size.height - AppSpacing.sm, 0.1));
        expect(find.byTooltip('Home'), findsOneWidget);
        expect(find.byTooltip('Shorts'), findsOneWidget);
        expect(find.byTooltip('Subs'), findsOneWidget);
        expect(find.byTooltip('Library'), findsOneWidget);
      }
      expect(find.text('Create'), findsNothing);
      await tester.tap(find.byTooltip('Search'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('Search'), findsOneWidget);
      await tester.tap(
        !wide
            ? find.byTooltip('Library')
            : find.descendant(of: nav, matching: find.text('Library')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Content languages'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Local content'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
