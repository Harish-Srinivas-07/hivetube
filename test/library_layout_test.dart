import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/features/library/library_screen.dart';
import 'package:hivetube/theme/app_theme.dart';

const _rectKeys = [
  'libraryAvatar',
  'libraryName',
  'libraryButtons',
  'historyHeader',
  'historyFirstCard',
  'playlistsHeader',
  'playlistsFirstCard',
  'rowDownloads',
  'rowLiked',
  'rowWatchLater',
  'rowStats',
];

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Library spacing at 360 x 800 in $brightness theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.profileDao.setProfile(name: 'Fixture User');
      await db.historyDao.recordWatch(
        videoId: 'fixture-history',
        title: 'Fixture history video',
        channelId: 'fixture-channel',
        channelName: 'Fixture channel',
        positionMs: 30000,
        durationMs: 60000,
      );
      final playlistId = await db.playlistsDao.createPlaylist(
        'Fixture playlist',
      );
      await db.playlistsDao.addPlaylistItem(
        playlistId,
        'fixture-playlist-video',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: brightness == Brightness.light
                ? ThemeMode.light
                : ThemeMode.dark,
            home: const LibraryScreen(),
          ),
        ),
      );
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final rects = <String, Rect>{
        for (final key in _rectKeys)
          key: tester.getRect(find.byKey(ValueKey(key))),
      };
      debugPrint('Library layout rects (key, left, top, width, height)');
      for (final entry in rects.entries) {
        final rect = entry.value;
        debugPrint(
          '${entry.key}, ${rect.left.toStringAsFixed(1)}, '
          '${rect.top.toStringAsFixed(1)}, ${rect.width.toStringAsFixed(1)}, '
          '${rect.height.toStringAsFixed(1)}',
        );
      }

      expect(rects['libraryAvatar']!.left, 16);
      expect(rects['historyHeader']!.left, 16);
      expect(rects['historyFirstCard']!.left, 16);
      expect(rects['playlistsHeader']!.left, 16);
      expect(rects['playlistsFirstCard']!.left, 16);
      expect(rects['libraryButtons']!.left, 16);
      expect(rects['playlistsFirstCard']!.right, lessThanOrEqualTo(344));

      final header = tester.getRect(
        find.byKey(const ValueKey('libraryHeader')),
      );
      final historyShelf = tester.getRect(
        find.byKey(const ValueKey('historyShelf')),
      );
      final playlistsShelf = tester.getRect(
        find.byKey(const ValueKey('playlistsShelf')),
      );
      expect(rects['libraryButtons']!.top - header.bottom, closeTo(12, 1));
      expect(
        rects['historyHeader']!.top - rects['libraryButtons']!.bottom,
        closeTo(24, 1),
      );
      expect(
        rects['playlistsHeader']!.top - historyShelf.bottom,
        closeTo(24, 1),
      );
      expect(
        rects['rowDownloads']!.top - playlistsShelf.bottom,
        closeTo(16, 1),
      );

      for (final key in [
        'rowDownloads',
        'rowLiked',
        'rowWatchLater',
        'rowStats',
      ]) {
        final row = find.byKey(ValueKey(key));
        final rowRect = tester.getRect(row);
        expect(rowRect.height, 56);
        final icon = find
            .descendant(of: row, matching: find.byType(Icon))
            .first;
        expect(tester.getRect(icon).left, 16);
        expect(
          find.ancestor(of: row, matching: find.byType(Card)),
          findsNothing,
        );
        final descendants = find.descendant(
          of: row,
          matching: find.byWidgetPredicate(_hasExplicitBackground),
        );
        expect(descendants, findsNothing);
      }
      expect(tester.getRect(find.text('Downloads')).left, 64);
      expect(tester.getRect(find.text('Liked videos')).left, 64);
      expect(tester.getRect(find.text('Watch later')).left, 64);
      expect(tester.getRect(find.text('Stats')).left, 64);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      final exception = tester.takeException();
      expect(exception, isNull);
    });
  }
}

bool _hasExplicitBackground(Widget widget) => switch (widget) {
  ColoredBox(:final color) => color != Colors.transparent,
  Container(:final color) => color != null && color != Colors.transparent,
  Material(:final color) => color != Colors.transparent,
  DecoratedBox(:final decoration) =>
    decoration is BoxDecoration && decoration.color != null,
  _ => false,
};
