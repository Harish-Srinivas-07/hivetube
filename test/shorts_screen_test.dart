import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/watch_info.dart';
import 'package:hivetube/core/yt/yt_comments.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/features/shorts/shorts_feed_provider.dart';
import 'package:hivetube/features/watch/watch_screen.dart';
import 'package:hivetube/main.dart';

class _NoPlayback extends PlaybackController {
  @override
  PlaybackService? build() => null;
}

class _NoFetchShortsFeed extends ShortsFeedController {
  @override
  Future<void> loadInitial({bool refresh = false}) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> loadMore() async {}
}

class _RetapShortsFeed extends _NoFetchShortsFeed {
  int refreshes = 0;

  @override
  ShortsFeedState build() => const ShortsFeedState(
    items: [ShortItem(id: 'old', thumbUrl: '', title: 'Old short')],
    hasLoaded: true,
  );

  @override
  Future<void> refreshForTab() async {
    refreshes++;
    state = const ShortsFeedState(
      items: [ShortItem(id: 'new', thumbUrl: '', title: 'New short')],
      hasLoaded: true,
    );
  }
}

class _SelectedShorts extends ShortsSelectionController {
  _SelectedShorts(this.initial);
  final ShortsSelection initial;
  @override
  ShortsSelection build() => initial;
}

class _CommentsApi extends Fake implements YtComments {
  @override
  Future<CommentPage> page(String token) async => const CommentPage(
    [
      WatchComment(
        id: 'comment',
        author: 'Viewer',
        avatar: '',
        content: 'Hello',
        age: '',
        likes: '',
        replies: '',
        verified: false,
        creator: false,
      ),
    ],
    '',
    null,
    {},
  );
}

class _VideoApi extends Fake implements YtApi {
  @override
  final YtComments comments = _CommentsApi();
}

void main() {
  testWidgets('re-tapping Shorts replaces the visible feed', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const ShortsScreen())],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        playbackProvider.overrideWith(_NoPlayback.new),
        shortsFeedProvider.overrideWith(_RetapShortsFeed.new),
        shortMetadataProvider('old').overrideWith((ref) async => null),
        shortMetadataProvider('new').overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('old')), findsOneWidget);
    container.read(tabRefreshProvider.notifier).request(1);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('new')), findsOneWidget);
    expect(
      (container.read(shortsFeedProvider.notifier) as _RetapShortsFeed)
          .refreshes,
      1,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a routed Short with channel details has a Material ancestor', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    appRouter.go('/home');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_NoPlayback.new),
          shortsFeedProvider.overrideWith(_NoFetchShortsFeed.new),
          shortsSelectionProvider.overrideWith(
            () => _SelectedShorts(
              const ShortsSelection(
                items: [
                  ShortItem(
                    id: 'channel-short',
                    thumbUrl: '',
                    title: 'A short',
                    channelName: 'Channel',
                    channelId: 'UCchannel',
                  ),
                ],
              ),
            ),
          ),
          shortMetadataProvider(
            'channel-short',
          ).overrideWith((ref) async => null),
        ],
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    appRouter.push('/shorts-player');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('@Channel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(appRouter.routeInformationProvider.value.uri.path, '/home');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  test(
    'watch metadata uses video description when secondary info is empty',
    () {
      final info = parseWatchInfo({
        'videoSecondaryInfoRenderer': {
          'attributedDescription': {'content': ''},
        },
        'videoDetails': {'shortDescription': 'Full Short description'},
      }, 'current');
      expect(info.description, 'Full Short description');
    },
  );

  testWidgets('tapping a truncated Short title opens its description', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final info = Completer<WatchInfo>();
    appRouter.go('/shorts');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_NoPlayback.new),
          shortsFeedProvider.overrideWith(_NoFetchShortsFeed.new),
          shortsSelectionProvider.overrideWith(
            () => _SelectedShorts(
              const ShortsSelection(
                items: [
                  ShortItem(
                    id: 'current',
                    thumbUrl: '',
                    title:
                        'A very long Short title that fills the available lines and hides the more link completely',
                  ),
                ],
              ),
            ),
          ),
          shortMetadataProvider('current').overrideWith((ref) async => null),
          watchInfoProvider('current').overrideWith((ref) => info.future),
        ],
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('shortsDetailsTitle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Details'), findsOneWidget);
    info.complete(
      const WatchInfo(
        id: 'current',
        title: 'Current',
        channelName: '',
        channelId: '',
        avatar: '',
        subscribers: '',
        description: 'Full Short description',
        likes: '',
        views: '',
        date: '',
        handle: '',
        commentsToken: null,
        related: VideoPage([], null),
        chapters: [],
        chips: {},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Full Short description'), findsOneWidget);
  });
  testWidgets('Shorts comments opens immediately and loads current comments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final info = Completer<WatchInfo>();
    appRouter.go('/shorts');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_NoPlayback.new),
          shortsSelectionProvider.overrideWith(
            () => _SelectedShorts(
              const ShortsSelection(
                items: [
                  ShortItem(id: 'current', thumbUrl: '', title: 'Current'),
                ],
              ),
            ),
          ),
          watchInfoProvider('current').overrideWith((ref) => info.future),
          ytApiProvider.overrideWith((ref) async => _VideoApi()),
        ],
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Comments'));
    await tester.pump(const Duration(milliseconds: 500));
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(
        of: sheet,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    info.complete(
      const WatchInfo(
        id: 'current',
        title: 'Current',
        channelName: '',
        channelId: '',
        avatar: '',
        subscribers: '',
        description: '',
        likes: '',
        views: '',
        date: '',
        handle: '',
        commentsToken: 'token',
        related: VideoPage([], null),
        chapters: [],
        chips: {},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.descendant(of: sheet, matching: find.text('Hello')),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 100));
    await tester.pump(const Duration(milliseconds: 500));
  });
  testWidgets(
    'Shorts fills mobile screen with actions, persistent mute and floating nav',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      const selection = ShortsSelection(
        items: [
          ShortItem(id: 'first', thumbUrl: '', title: 'First'),
          ShortItem(id: 'second', thumbUrl: '', title: 'Second'),
        ],
        index: 0,
      );
      appRouter.go('/shorts');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            shortsSelectionProvider.overrideWith(
              () => _SelectedShorts(selection),
            ),
            playbackProvider.overrideWith(_NoPlayback.new),
          ],
          child: const HiveTubeApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('Search'), findsOneWidget);
      expect(find.text('HiveTube'), findsNothing);
      expect(find.byKey(const ValueKey('floatingNavSurface')), findsOneWidget);
      expect(find.byKey(const ValueKey('shortsActionRail')), findsOneWidget);
      final page = find.byKey(const ValueKey('shortsPageView'));
      expect(tester.getSize(page), const Size(400, 800));
      expect(find.byTooltip('Mute'), findsOneWidget);
      await tester.tap(find.byTooltip('More'));
      await tester.pump(const Duration(milliseconds: 500));
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Share')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Copy link')),
        findsNothing,
      );
      await tester.tapAt(const Offset(10, 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('shortsMute')));
      await tester.pump();
      expect(find.byTooltip('Unmute').hitTestable(), findsOneWidget);
      await tester.drag(page, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Second …more', findRichText: true), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('second')),
          matching: find.byTooltip('Unmute'),
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('Home shelf selection opens at the chosen page', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    const selection = ShortsSelection(
      items: [
        ShortItem(id: 'one', thumbUrl: '', title: 'One'),
        ShortItem(id: 'two', thumbUrl: '', title: 'Two'),
      ],
      index: 1,
    );
    appRouter.go('/shorts');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          shortsSelectionProvider.overrideWith(
            () => _SelectedShorts(selection),
          ),
          playbackProvider.overrideWith(_NoPlayback.new),
        ],
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Two …more', findRichText: true), findsOneWidget);
  });
  testWidgets('wide Shorts keeps rail and centers a portrait page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    const selection = ShortsSelection(
      items: [ShortItem(id: 'wide', thumbUrl: '', title: 'Wide')],
      index: 0,
    );
    appRouter.go('/shorts');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          shortsSelectionProvider.overrideWith(
            () => _SelectedShorts(selection),
          ),
          playbackProvider.overrideWith(_NoPlayback.new),
        ],
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('shortsPageView'))),
      const Size(450, 800),
    );
  });
}
