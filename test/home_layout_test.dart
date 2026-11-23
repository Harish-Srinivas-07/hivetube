import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/preview_coordinator.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/features/home/home_cache.dart';
import 'package:hivetube/features/home/home_controller.dart';
import 'package:hivetube/features/shorts/shorts_feed_provider.dart';
import 'package:hivetube/main.dart';
import 'package:hivetube/theme/app_radius.dart';
import 'package:hivetube/widgets/common/video_card.dart';
import 'package:hivetube/widgets/common/thumbnail_with_duration.dart';

class _FailedHome extends HomeController {
  @override
  Future<HomeData> build() async => throw StateError('offline');
}

class _ShortsFeed extends ShortsFeedController {
  @override
  ShortsFeedState build() => const ShortsFeedState();

  @override
  Future<void> prefetch({List<ShortItem> seedItems = const []}) async {}
}

class _History implements HistoryRepo {
  _History(this.entries);
  final List<HistoryEntry> entries;
  @override
  Future<List<HistoryEntry>> recent() async => entries;
  @override
  Future<Set<String>> dislikedChannels() async => {};
  @override
  Future<void> save(HistoryEntry entry) async {}
}

void main() {
  testWidgets('feed cards retain the supplied thumbnail quality', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    const url = 'https://i.ytimg.com/vi/abcdefghijk/hqdefault.jpg';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: VideoCard.feed(
              video: const VideoItem(
                id: 'abcdefghijk',
                title: 'Video',
                thumbUrl: url,
                durationText: '1:00',
              ),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<ThumbnailWithDuration>(find.byType(ThumbnailWithDuration))
          .url,
      url,
    );
  });

  test('saved duration is available without network access', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            videoId: 'abcdefghijk',
            title: 'Video',
            channelId: '',
            channelName: '',
            thumbUrl: '',
            durationSec: const Value(3862),
            updatedAt: 1,
          ),
        );
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        innertubeProvider.overrideWith(
          (ref) async => throw StateError('offline'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(videoDurationProvider('abcdefghijk').future),
      3862,
    );
  });
  testWidgets('missing video durations appear across card layouts', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    const video = VideoItem(id: 'abcdefghijk', title: 'Video');
    final cards = <Widget>[
      VideoCard.feed(video: video, onTap: () {}),
      VideoCard.grid(video: video, onTap: () {}),
      VideoCard.compact(video: video, onTap: () {}),
      VideoCard.searchResult(video: video, onTap: () {}),
      VideoCard.shelf(video: video, onTap: () {}),
      const ThumbnailWithDuration(url: '', videoId: 'abcdefghijk'),
    ];
    for (final card in cards) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            videoDurationProvider(
              'abcdefghijk',
            ).overrideWith((ref) async => 3862),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: SizedBox(width: 360, child: card)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('1:04:22'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
  for (final size in [
    const Size(400, 800),
    const Size(1200, 800),
    const Size(640, 360),
    const Size(1000, 430),
  ]) {
    testWidgets('Home video card layout and real history at $size', (
      tester,
    ) async {
      final visibilityController = VisibilityDetectorController.instance;
      final oldUpdateInterval = visibilityController.updateInterval;
      visibilityController.updateInterval = Duration.zero;
      addTearDown(
        () => visibilityController.updateInterval = oldUpdateInterval,
      );
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      const videos = [
        VideoItem(
          id: 'seen',
          title: 'Watched clip',
          channelName: 'Example',
          thumbUrl: '',
          durationText: '1:00',
        ),
        VideoItem(
          id: 'unseen',
          title: 'Unwatched clip',
          channelName: 'Other',
          thumbUrl: '',
        ),
      ];
      final cache = HomeCache(videos, const [], DateTime.now());
      final history = _History([
        const HistoryEntry('seen', Duration(seconds: 30), Duration(minutes: 1)),
      ]);
      appRouter.go('/home');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            previewPlaybackAllowedProvider.overrideWithValue(false),
            initialHomeCacheProvider.overrideWithValue(cache),
            historyRepoProvider.overrideWithValue(history),
            shortsFeedProvider.overrideWith(_ShortsFeed.new),
          ],
          child: const HiveTubeApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final thumb = find.byKey(const ValueKey('homeThumbnail:seen'));
      expect(thumb, findsOneWidget);
      expect(
        find.byKey(const ValueKey('watchedProgress:seen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('watchedProgress:unseen')),
        findsNothing,
      );
      expect(find.byTooltip('More options'), findsWidgets);
      final clip = tester.widget<ClipRRect>(
        find.descendant(of: thumb, matching: find.byType(ClipRRect)).first,
      );
      if (size.width < 600) {
        expect(tester.getSize(thumb).width, size.width);
        expect(clip.borderRadius, BorderRadius.zero);
      } else {
        expect(clip.borderRadius, AppRadius.mdBorder);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Home load error shows a retry without layout exceptions', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    appRouter.go('/home');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          homeProvider.overrideWith(_FailedHome.new),
          shortsFeedProvider.overrideWith(_ShortsFeed.new),
        ],
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Unable to load Home'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
