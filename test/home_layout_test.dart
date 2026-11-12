import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/features/home/home_cache.dart';
import 'package:hivetube/features/home/home_controller.dart';
import 'package:hivetube/main.dart';
import 'package:hivetube/theme/app_radius.dart';

class _FailedHome extends HomeController {
  @override
  Future<HomeData> build() async => throw StateError('offline');
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
  for (final width in [400.0, 1200.0]) {
    testWidgets('Home video card layout and real history at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
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
            initialHomeCacheProvider.overrideWithValue(cache),
            historyRepoProvider.overrideWithValue(history),
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
      if (width < 600) {
        expect(tester.getSize(thumb).width, width);
        expect(clip.borderRadius, BorderRadius.zero);
      } else {
        expect(clip.borderRadius, AppRadius.mdBorder);
      }
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
