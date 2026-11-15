import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/watch_info.dart';
import 'package:hivetube/core/yt/yt_comments.dart';
import 'package:hivetube/features/watch/watch_screen.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/theme/app_spacing.dart';

class _NoPlayer extends PlaybackController {
  @override
  PlaybackService? build() => null;
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
            ytApiProvider.overrideWith(
              (ref) async => _FixtureYtApi(comments),
            ),
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
      await tester.tap(find.text('Comments'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
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
        0,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('commentAvatar:c'))).top,
        closeTo(
          tester.getRect(find.byKey(const ValueKey('commentTitle:c'))).top,
          1,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
