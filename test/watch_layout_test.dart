import 'dart:async';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/downloads/download_manager.dart';
import 'package:hivetube/core/downloads/download_export.dart';
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
import 'package:hivetube/widgets/ui/app_controls.dart';

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

  @override
  Future<void> remove(DownloadRow row) async {
    await (db.delete(
      db.downloads,
    )..where((item) => item.id.equals(row.id))).go();
  }
}

class _DownloadExporter extends DownloadExportService {
  DownloadRow? exported;
  @override
  Future<void> export(DownloadRow row, String title) async {
    exported = row;
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
  testWidgets('missing watch channel name loads from the channel page', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final channel = Completer<ChannelPageData?>();
    const info = WatchInfo(
      id: 'video',
      title: 'Video',
      channelName: '',
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
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_NoPlayer.new),
          watchInfoProvider('video').overrideWith((ref) async => info),
          watchChannelFallbackProvider(
            'UCtest',
          ).overrideWith((ref) => channel.future),
          dislikeCountProvider('video').overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: WatchScreen(id: 'video')),
      ),
    );
    await tester.pump();
    expect(find.text('Channel'), findsOneWidget);
    channel.complete(
      const ChannelPageData(id: 'UCtest', name: 'Actual channel'),
    );
    await tester.pump();
    expect(find.text('Actual channel'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'downloaded video offers export and removal from the watch screen',
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
      final exporter = _DownloadExporter();
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
            downloadExportProvider.overrideWithValue(exporter),
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
                path: const Value('/saved/video.mp4'),
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
      expect(find.text('Remove download'), findsOneWidget);
      await tester.tap(find.text('Save to Gallery and Downloads'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(exporter.exported?.videoId, 'video');
      await tester.tap(find.text('Downloaded'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Remove download'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(await db.select(db.downloads).get(), isEmpty);
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
    final initialButton = find.widgetWithText(AppButton, 'Download');
    final initialColor = tester
        .widget<Material>(
          find
              .descendant(of: initialButton, matching: find.byType(Material))
              .first,
        )
        .color!;
    await tester.tap(find.text('Download'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Audio only'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Downloading'), findsOneWidget);
    final downloadingButton = find.widgetWithText(AppButton, 'Downloading');
    expect(
      tester.widget<AppButton>(downloadingButton).icon,
      LucideIcons.loaderCircle,
    );
    final downloadingColor = tester
        .widget<Material>(
          find
              .descendant(
                of: downloadingButton,
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;
    expect(
      downloadingColor.computeLuminance(),
      lessThan(initialColor.computeLuminance()),
    );
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
        final videoBottom = tester
            .getRect(find.byKey(const ValueKey('watchVideoAspectRatio')))
            .bottom;
        expect(tester.getRect(surface).top, greaterThanOrEqualTo(videoBottom));
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
