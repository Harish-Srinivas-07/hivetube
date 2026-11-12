import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/main.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';

void main() {
  for (final width in [400.0, 1200.0]) {
    testWidgets('navigation at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
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
      final nav = width < 600
          ? find.byKey(const ValueKey('bottomNavPill'))
          : find.byType(NavigationRail);
      expect(nav, findsOneWidget);
      expect(find.byKey(const ValueKey('notificationBadge')), findsNothing);
      expect(find.byTooltip('Search'), findsOneWidget);
      if (width >= 600) {
        for (final label in ['Home', 'Shorts', 'Subscriptions', 'You']) {
          expect(
            find.descendant(of: nav, matching: find.text(label)),
            findsOneWidget,
          );
        }
      } else {
        final pill = tester.getRect(
          find.descendant(
            of: nav,
            matching: find.byKey(const ValueKey('floatingNavSurface')),
          ),
        );
        expect(pill.center.dx, closeTo(width / 2, 0.1));
        expect(pill.width, lessThan(width - 32));
        expect(pill.bottom, closeTo(792, 0.1));
        expect(find.byTooltip('Home'), findsOneWidget);
        expect(find.byTooltip('Shorts'), findsOneWidget);
        expect(find.byTooltip('Subscriptions'), findsOneWidget);
        expect(find.byTooltip('You'), findsOneWidget);
      }
      expect(find.text('Create'), findsNothing);
      await tester.tap(find.byTooltip('Search'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('Search'), findsOneWidget);
      await tester.tap(
        width < 600
            ? find.byTooltip('You')
            : find.descendant(of: nav, matching: find.text('You')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Local content'), findsOneWidget);
    });
  }
}
