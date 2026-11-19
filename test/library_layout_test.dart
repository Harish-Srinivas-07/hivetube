import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/features/library/library_screen.dart';
import 'package:hivetube/theme/app_sizes.dart';
import 'package:hivetube/theme/app_spacing.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/theme/app_colors.dart';
import 'package:visibility_detector/visibility_detector.dart';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('offline downloads shortcut is above history', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          isOfflineProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final downloads = tester.getRect(
      find.byKey(const ValueKey('downloadsShortcut')),
    );
    final history = tester.getRect(find.byKey(const ValueKey('historyHeader')));
    expect(downloads.bottom, lessThanOrEqualTo(history.top));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Library layout at 360 x 800 in $brightness theme', (
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

      final avatar = tester.getRect(
        find.byKey(const ValueKey('libraryAvatar')),
      );
      final profileName = tester.getRect(
        find.byKey(const ValueKey('libraryName')),
      );
      final buttons = tester.getRect(
        find
            .ancestor(of: find.text('Edit profile'), matching: find.byType(Row))
            .first,
      );
      final historyHeader = tester.getRect(
        find.byKey(const ValueKey('historyHeader')),
      );
      final historyShelf = tester.getRect(
        find.byKey(const ValueKey('historyShelf')),
      );
      final likedRow = tester.getRect(find.byKey(const ValueKey('rowLiked')));
      final watchLaterRow = tester.getRect(
        find.byKey(const ValueKey('rowWatchLater')),
      );
      final playlistRow = tester.getRect(
        find.byKey(ValueKey('playlist-$playlistId')),
      );

      expect(avatar.left, AppSpacing.lg);
      expect(profileName.left, greaterThan(avatar.right));
      expect(buttons.left, AppSpacing.lg);
      expect(buttons.right, 360 - AppSpacing.lg);
      expect(buttons.height, AppSizes.buttonLarge);
      expect(historyHeader.left, AppSpacing.lg);
      expect(historyShelf.left, 0);
      expect(historyShelf.right, 360);
      expect(likedRow.left, 0);
      expect(watchLaterRow.left, 0);
      expect(playlistRow.left, 0);
      expect(historyHeader.top, greaterThan(buttons.bottom));
      expect(likedRow.top, greaterThan(historyShelf.bottom));
      expect(watchLaterRow.top, greaterThanOrEqualTo(likedRow.bottom));
      expect(playlistRow.top, greaterThanOrEqualTo(watchLaterRow.bottom));
      expect(
        tester.getSize(find.byKey(const ValueKey('libraryBottomInset'))).height,
        AppSizes.bottomNav + AppSpacing.xl,
      );

      Future<void> expectMenuTheme(Finder button) async {
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final surface = find.byKey(const ValueKey('appSheetSurface'));
        expect(surface, findsOneWidget);
        expect(Theme.of(tester.element(surface)).brightness, brightness);
        expect(
          tester.widget<Material>(surface).color,
          brightness == Brightness.dark
              ? AppColors.videoSheet
              : AppTheme.light.colorScheme.surface,
        );
        Navigator.of(tester.element(surface)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await expectMenuTheme(
        find
            .descendant(
              of: find.byKey(const ValueKey('historyShelf')),
              matching: find.byTooltip('More options'),
            )
            .first,
      );
      await expectMenuTheme(
        find.descendant(
          of: find.byKey(ValueKey('playlist-$playlistId')),
          matching: find.byTooltip('More options'),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
