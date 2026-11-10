import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/main.dart';

void main() {
  for (final width in [400.0, 1200.0]) {
    testWidgets('navigation at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      appRouter.go('/home');
      await tester.pumpWidget(const ProviderScope(child: HiveTubeApp()));
      await tester.pump(const Duration(milliseconds: 500));

      final nav = width < 600
          ? find.byType(NavigationBar)
          : find.byType(NavigationRail);
      expect(nav, findsOneWidget);
      expect(
        width < 600 ? find.byType(NavigationRail) : find.byType(NavigationBar),
        findsNothing,
      );
      expect(find.text('Search HiveTube'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
      for (final label in ['Home', 'Shorts', 'Subscriptions', 'Library']) {
        final destination = find.descendant(
          of: nav,
          matching: find.text(label),
        );
        expect(destination, findsOneWidget);
        await tester.tap(destination);
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.descendant(
            of: find.byType(Scaffold),
            matching: find.text(label),
          ),
          findsWidgets,
        );
        if (label != 'Home') expect(find.text(label), findsNWidgets(2));
      }
      await tester.tap(find.text('Search HiveTube'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).autofocus,
        isTrue,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Search HiveTube'), findsOneWidget);
    });
  }
}
