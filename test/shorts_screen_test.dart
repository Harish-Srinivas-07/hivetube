import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/watch_info.dart';
import 'package:hivetube/core/yt/yt_comments.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/features/watch/watch_screen.dart';
import 'package:hivetube/main.dart';

class _NoPlayback extends PlaybackController {
  @override
  PlaybackService? build() => null;
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
