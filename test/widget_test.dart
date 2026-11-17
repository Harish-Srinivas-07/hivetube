import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/main.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/theme/app_spacing.dart';

void main() {
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
        expect(find.byTooltip('Subscriptions'), findsOneWidget);
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
