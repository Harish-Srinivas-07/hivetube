import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/main.dart';

void main() {
  testWidgets(
    'Shorts fills mobile screen with actions, persistent mute and floating nav',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final selection = ShortsSelection()
        ..open(const [
          ShortItem(id: 'first', thumbUrl: '', title: 'First'),
          ShortItem(id: 'second', thumbUrl: '', title: 'Second'),
        ], 0);
      appRouter.go('/shorts');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            shortsSelectionProvider.overrideWith((ref) => selection),
            playbackProvider.overrideWith((ref) => null),
          ],
          child: const HiveTubeApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('Search'), findsNothing);
      expect(find.text('HiveTube'), findsNothing);
      expect(find.byKey(const ValueKey('bottomNavPill')), findsOneWidget);
      expect(find.byKey(const ValueKey('shortsActionRail')), findsOneWidget);
      final page = find.byKey(const ValueKey('shortsPageView'));
      expect(tester.getSize(page), const Size(400, 800));
      expect(find.byTooltip('Mute'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shortsMute')));
      await tester.pump();
      expect(find.byTooltip('Unmute'), findsOneWidget);
      await tester.drag(page, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);
      expect(find.byTooltip('Unmute'), findsOneWidget);
    },
  );
  testWidgets('Home shelf selection opens at the chosen page', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final selection = ShortsSelection()
      ..open(const [
        ShortItem(id: 'one', thumbUrl: '', title: 'One'),
        ShortItem(id: 'two', thumbUrl: '', title: 'Two'),
      ], 1);
    appRouter.go('/shorts');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          shortsSelectionProvider.overrideWith((ref) => selection),
          playbackProvider.overrideWith((ref) => null),
        ],
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Two'), findsOneWidget);
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
    final selection = ShortsSelection()
      ..open(const [ShortItem(id: 'wide', thumbUrl: '', title: 'Wide')], 0);
    appRouter.go('/shorts');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          shortsSelectionProvider.overrideWith((ref) => selection),
          playbackProvider.overrideWith((ref) => null),
        ],
        child: const HiveTubeApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byTooltip('Search'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('shortsPageView'))),
      const Size(450, 800),
    );
  });
}
