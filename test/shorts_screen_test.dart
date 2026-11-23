import 'dart:async';
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
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
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class _PlayerState extends Fake implements PlayerState {
  @override
  int? get width => null;
  @override
  int? get height => null;
  @override
  bool get playing => false;
  @override
  List<String> get subtitle => const [];
}

class _PlayerStream extends Fake implements PlayerStream {
  @override
  Stream<int?> get width => const Stream.empty();
  @override
  Stream<int?> get height => const Stream.empty();
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Stream<List<String>> get subtitle => const Stream.empty();
}

class _Player extends Fake implements Player {
  @override
  PlayerState get state => _PlayerState();
  @override
  PlayerStream get stream => _PlayerStream();
  @override
  PlatformPlayer? get platform => null;
}

class _VideoController extends Fake implements VideoController {
  @override
  final Player player = _Player();
  @override
  final ValueNotifier<PlatformVideoController?> notifier = ValueNotifier(null);
  @override
  Future<void> get waitUntilFirstFrameRendered => Completer<void>().future;
}

class _ShortPlayback extends Fake implements PlaybackService {
  @override
  final state = PlaybackSnapshot();
  @override
  final VideoController controller = _VideoController();
  @override
  PlayRequest? request;
  int pauses = 0;
  final played = <String>[];
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void cancelShortPreloads({bool disposePlayer = false}) {}
  @override
  int beginShortPreloadCycle() => 0;
  @override
  Future<void> preloadShort(String id, {required int generation}) async {}
  @override
  Future<void> setVisible(bool visible) async {}
  @override
  Future<void> setLoop(bool value) async {}
  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<bool> playShort(String id) async {
    played.add(id);
    request = PlayRequest.short(id);
    return false;
  }

  @override
  bool isFrameReadyFor(String id) => false;
}

class _ShortPlaybackController extends PlaybackController {
  _ShortPlaybackController(this.service);
  final PlaybackService service;
  @override
  PlaybackService? build() => service;
}

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
  testWidgets('reselecting a shelf Short opens and plays the chosen page', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final service = _ShortPlayback();
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        playbackProvider.overrideWith(() => _ShortPlaybackController(service)),
        shortsFeedProvider.overrideWith(_NoFetchShortsFeed.new),
        shortMetadataProvider('first').overrideWith((ref) async => null),
        shortMetadataProvider('second').overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const ShortsScreen())],
    );
    addTearDown(router.dispose);
    const items = [
      ShortItem(id: 'first', thumbUrl: '', title: 'First short'),
      ShortItem(id: 'second', thumbUrl: '', title: 'Second short'),
    ];
    container.read(shortsSelectionProvider.notifier).open(items, 0);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(service.played.last, 'first');
    container.read(shortsSelectionProvider.notifier).open(items, 1);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('shortsPageView')),
    );
    expect(pageView.controller!.page, 1);
    expect(find.text('Second short …more', findRichText: true), findsOneWidget);
    expect(service.played.last, 'second');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('selecting a Home Short starts it without a competing pause', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final service = _ShortPlayback();
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        playbackProvider.overrideWith(() => _ShortPlaybackController(service)),
        shortsFeedProvider.overrideWith(_NoFetchShortsFeed.new),
        shortMetadataProvider('first').overrideWith((ref) async => null),
        shortMetadataProvider('selected').overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const ShortsScreen())],
    );
    addTearDown(router.dispose);
    container.read(shortsSelectionProvider.notifier).open(const [
      ShortItem(id: 'first', thumbUrl: ''),
    ], 0);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    container.read(shortsSelectionProvider.notifier).open(const [
      ShortItem(id: 'selected', thumbUrl: ''),
    ], 0);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(service.played.last, 'selected');
    expect(service.pauses, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('hidden Shorts waits until visible to adopt a selection', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        playbackProvider.overrideWith(_NoPlayback.new),
        shortsFeedProvider.overrideWith(_NoFetchShortsFeed.new),
        shortMetadataProvider('selected').overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (_, enabled, _) =>
                TickerMode(enabled: enabled, child: const ShortsScreen()),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final screen = UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    );
    await tester.pumpWidget(screen);
    container.read(shortsSelectionProvider.notifier).open(const [
      ShortItem(id: 'selected', thumbUrl: '', title: 'Selected'),
    ], 0);
    await tester.pump();
    await tester.pump();
    expect(container.read(shortsFeedProvider).items, isEmpty);
    visible.value = true;
    await tester.pump();
    await tester.pump();
    expect(container.read(shortsFeedProvider).items.single.id, 'selected');
    await tester.pumpWidget(const SizedBox.shrink());
  });
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
