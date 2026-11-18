import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/main.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/theme/app_spacing.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/playback/player_ui_state.dart';
import 'package:hivetube/features/watch/watch_panel.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/features/shorts/shorts_feed_provider.dart';
import 'package:hivetube/widgets/floating_nav.dart';

class _NoPlayback extends PlaybackController {
  @override
  PlaybackService? build() => null;
}

class _EmptyShortsFeed extends ShortsFeedController {
  @override
  ShortsFeedState build() => const ShortsFeedState(hasLoaded: true);

  @override
  Future<void> loadInitial({bool refresh = false}) async {}
}

void main() {
  for (final size in [
    const Size(400, 800),
    const Size(800, 400),
    const Size(1200, 800),
  ]) {
    testWidgets('mini player allows navigation and survives resume at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_NoPlayback.new),
          shortsFeedProvider.overrideWith(_EmptyShortsFeed.new),
          shortMetadataProvider('mini').overrideWith((ref) async => null),
        ],
      );
      appRouter.go('/home');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HiveTubeApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      container.read(watchPanelProvider.notifier).open('mini');
      container.read(watchPanelExpandProvider.notifier).minimize();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(playerUiProvider).panelMode, PlayerPanelMode.mini);

      final wide = size.shortestSide >= AppSpacing.navigationBreakpoint;
      final nav = wide
          ? find.byType(NavigationRail)
          : find.byType(FloatingNav);
      final mini = find.descendant(
        of: find.byType(WatchPanel),
        matching: find.byWidgetPredicate(
          (widget) => widget is ClipRRect && widget.key is GlobalKey,
        ),
      );
      expect(tester.getRect(mini).overlaps(tester.getRect(nav)), isFalse);
      Future<void> tapTab(String label, String path) async {
        final nav = wide
            ? find.byType(NavigationRail)
            : find.byType(FloatingNav);
        final target = wide
            ? find.descendant(of: nav, matching: find.text(label))
            : find.descendant(of: nav, matching: find.byTooltip(label));
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(appRouter.routeInformationProvider.value.uri.path, path);
      }

      await tapTab('Library', '/library');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(appRouter.routeInformationProvider.value.uri.path, '/library');
      expect(container.read(watchPanelProvider), 'mini');
      expect(container.read(playerUiProvider).panelMode, PlayerPanelMode.mini);
      await tapTab(wide ? 'Subscriptions' : 'Subs', '/subscriptions');
      await tapTab('Home', '/home');
      await tapTab('Shorts', '/shorts');
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(seconds: 1));
    });
  }
  for (final size in [
    const Size(400, 800),
    const Size(800, 400),
    const Size(1200, 800),
  ]) {
    testWidgets('navigation at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      appRouter.go('/home');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: const HiveTubeApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final wide = size.shortestSide >= 600;
      final nav = !wide
          ? find.byKey(const ValueKey('floatingNavSurface'))
          : find.byType(NavigationRail);
      expect(nav, findsOneWidget);
      expect(find.byKey(const ValueKey('notificationBadge')), findsNothing);
      expect(find.byTooltip('Search'), findsOneWidget);
      if (wide) {
        final labels = size.width > size.height
            ? ['Home', 'Shorts', 'Subs', 'Library']
            : ['Home', 'Shorts', 'Subscriptions', 'Library'];
        for (final label in labels) {
          expect(
            find.descendant(of: nav, matching: find.text(label)),
            findsOneWidget,
          );
        }
      } else {
        final bar = tester.getRect(nav);
        expect(bar.center.dx, closeTo(size.width / 2, 0.1));
        expect(bar.width, lessThan(size.width));
        expect(bar.bottom, closeTo(size.height - AppSpacing.sm, 0.1));
        expect(find.byTooltip('Home'), findsOneWidget);
        expect(find.byTooltip('Shorts'), findsOneWidget);
        expect(find.byTooltip('Subs'), findsOneWidget);
        expect(find.byTooltip('Library'), findsOneWidget);
      }
      expect(find.text('Create'), findsNothing);
      await tester.tap(find.byTooltip('Search'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('Search'), findsOneWidget);
      await tester.tap(
        !wide
            ? find.byTooltip('Library')
            : find.descendant(of: nav, matching: find.text('Library')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('Settings'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Content languages'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Local content'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
