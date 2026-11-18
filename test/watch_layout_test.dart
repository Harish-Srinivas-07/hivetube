import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/downloads/download_manager.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/watch_info.dart';
import 'package:hivetube/core/yt/yt_comments.dart';
import 'package:hivetube/features/watch/watch_screen.dart';
import 'package:hivetube/features/watch/mini_player_inset.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/theme/app_spacing.dart';
import 'package:hivetube/theme/app_colors.dart';
import 'package:hivetube/widgets/sheets/app_sheet.dart';

class _NoPlayer extends PlaybackController {
  @override
  PlaybackService? build() => null;
}

class _DownloadManager extends DownloadManager {
  _DownloadManager(AppDb db)
    : super(db, () async => throw StateError('unused'));

  @override
  Future<void> enqueue(
    MediaCompanion media, {
    bool audioOnly = false,
    int? height,
    WatchInfo? info,
    void Function()? onQueued,
  }) async {
    await db
        .into(db.downloads)
        .insert(
          DownloadsCompanion.insert(
            videoId: media.videoId.value,
            kind: 'audio',
            status: const Value('downloading'),
            createdAt: 1,
          ),
        );
    onQueued?.call();
  }
}

class _FixtureComments extends Fake implements YtComments {
  _FixtureComments(this.pageResult);

  final CommentPage pageResult;

  @override
  Future<CommentPage> page(String token) async => pageResult;
}

class _FixtureYtApi extends Fake implements YtApi {
  _FixtureYtApi(CommentPage comments) : comments = _FixtureComments(comments);

  @override
  final YtComments comments;
}

void main() {
  testWidgets(
    'offline video download reports quality failure and recognizes existing downloads',
    (tester) async {
      tester.view.physicalSize = const Size(400, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      shellRouteVisible.value = true;
      addTearDown(() => shellRouteVisible.value = false);
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final manager = _DownloadManager(db);
      addTearDown(manager.dispose);
      const info = WatchInfo(
        id: 'video',
        title: 'Video',
        channelName: 'Channel',
        channelId: 'c',
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
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            downloadManagerProvider.overrideWithValue(manager),
            playbackProvider.overrideWith(_NoPlayer.new),
            watchInfoProvider('video').overrideWith((ref) async => info),
          ],
          child: const MaterialApp(home: WatchScreen(id: 'video')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Download'));
      await tester.tap(find.text('Download'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Video').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final message = find.text(
        'Could not load video quality. Check your connection.',
      );
      expect(message, findsOneWidget);
      expect(
        tester.getRect(message).bottom,
        lessThanOrEqualTo(840 - AppSpacing.navHeight),
      );
      expect(find.text('Download'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.runAsync(
        () => db
            .into(db.downloads)
            .insert(
              DownloadsCompanion.insert(
                videoId: 'video',
                kind: 'video',
                status: const Value('completed'),
                createdAt: 1,
              ),
            ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('Downloaded'));
      await tester.tap(find.text('Downloaded'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Video').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Already downloaded'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
  testWidgets('download action shows status and feedback above navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    shellRouteVisible.value = true;
    addTearDown(() => shellRouteVisible.value = false);
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final manager = _DownloadManager(db);
    addTearDown(manager.dispose);
    const info = WatchInfo(
      id: 'video',
      title: 'Video',
      channelName: 'Channel',
      channelId: 'c',
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
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          downloadManagerProvider.overrideWithValue(manager),
          playbackProvider.overrideWith(_NoPlayer.new),
          watchInfoProvider('video').overrideWith((ref) async => info),
        ],
        child: const MaterialApp(home: WatchScreen(id: 'video')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Download'));
    await tester.tap(find.text('Download'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Audio only'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Downloading'), findsOneWidget);
    expect(find.text('Added to downloads'), findsOneWidget);
    final snack = tester.getRect(find.text('Added to downloads'));
    expect(snack.bottom, lessThanOrEqualTo(840 - AppSpacing.navHeight));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  });
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('watch details display compact actions in ${theme.brightness}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 840);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      const info = WatchInfo(
        id: 'video',
        title: 'A real video title',
        channelName: 'Channel',
        channelId: 'UCtest',
        avatar: '',
        subscribers: '100K subscribers',
        description: 'Description',
        likes: '249K',
        views: '33,734,934 views',
        date: '1 year ago',
        handle: '@channel',
        commentsToken: 'token',
        related: VideoPage([], null),
        chapters: [],
        chips: {},
      );
      const comments = CommentPage(
        [
          WatchComment(
            id: 'c',
            author: '@viewer',
            avatar: '',
            content: 'A comment preview',
            age: '',
            likes: '',
            replies: '',
            verified: false,
            creator: false,
          ),
        ],
        '6,726 Comments',
        null,
        {},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            playbackProvider.overrideWith(_NoPlayer.new),
            watchInfoProvider('video').overrideWith((ref) async => info),
            watchCommentsProvider(
              'token',
            ).overrideWith((ref) async => comments),
            ytApiProvider.overrideWith((ref) async => _FixtureYtApi(comments)),
            dislikeCountProvider('video').overrideWith((ref) async => 123),
          ],
          child: MaterialApp(
            theme: theme,
            home: const WatchScreen(id: 'video'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('A real video title'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('6.7K'), findsOneWidget);
      expect(find.text('A comment preview'), findsOneWidget);
      final commentsHeader = tester.getRect(
        find.byKey(const ValueKey('commentsPreviewHeader')),
      );
      final commentsItem = tester.getRect(
        find.byKey(const ValueKey('commentsPreviewItem')),
      );
      expect(commentsItem.top - commentsHeader.bottom, AppSpacing.sm);
      expect(find.text('Subscribe'), findsOneWidget);
      expect(tester.takeException(), isNull);
      void expectSheetTheme() {
        final surface = find.byKey(const ValueKey('appSheetSurface'));
        expect(Theme.of(tester.element(surface)).brightness, theme.brightness);
        expect(
          tester.widget<Material>(surface).color,
          theme.brightness == Brightness.dark
              ? AppColors.videoSheet
              : theme.colorScheme.surface,
        );
      }

      await tester.tap(find.text('A real video title'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Description'), findsWidgets);
      expectSheetTheme();
      Navigator.of(
        tester.element(find.byKey(const ValueKey('appSheetSurface'))),
      ).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Comments'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectSheetTheme();
      final commentsHeaderWidget = tester.widget<AppSheetHeader>(
        find.byType(AppSheetHeader),
      );
      expect(commentsHeaderWidget.showClose, isFalse);
      expect(commentsHeaderWidget.compact, isTrue);
      expect(find.byTooltip('Comment guidelines'), findsNothing);
      expect(
        find.text(
          'Remember to keep comments respectful by following the YouTube Community Guidelines.',
        ),
        findsNothing,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('commentItem:c'))).top -
            tester
                .getRect(find.byKey(const ValueKey('commentsSortRow')))
                .bottom,
        AppSpacing.md,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('commentAvatar:c'))).top,
        closeTo(
          tester.getRect(find.byKey(const ValueKey('commentTitle:c'))).top,
          1,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    });
  }
}
