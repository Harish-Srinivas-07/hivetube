import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
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
      expect(find.byTooltip('Search'), findsNothing);
      expect(find.text('HiveTube'), findsNothing);
      expect(find.byKey(const ValueKey('bottomNavPill')), findsOneWidget);
      expect(find.byKey(const ValueKey('shortsActionRail')), findsOneWidget);
      final page = find.byKey(const ValueKey('shortsPageView'));
      expect(tester.getSize(page), const Size(400, 800));
      expect(find.byTooltip('Mute'), findsOneWidget);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Share')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Copy link')),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
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
    expect(find.byTooltip('Search'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('shortsPageView'))),
      const Size(450, 800),
    );
  });
}
