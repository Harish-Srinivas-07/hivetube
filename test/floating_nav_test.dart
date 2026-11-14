import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/widgets/floating_nav.dart';

void main() {
  testWidgets('flat nav fills its width and selects by dragging', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 360,
                child: Center(
                  child: FloatingNav(
                    items: const [
                      FloatingNavItem('Home', Icons.home),
                      FloatingNavItem('Shorts', Icons.play_arrow),
                      FloatingNavItem('Subscriptions', Icons.subscriptions),
                      FloatingNavItem('You', Icons.person),
                    ],
                    currentIndex: selected,
                    onSelected: (i) => setState(() => selected = i),
                    onDragSelected: (i) => setState(() => selected = i),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final nav = tester.getRect(
      find.byKey(const ValueKey('floatingNavSurface')),
    );
    expect(nav.width, closeTo(360, 0.1));
    expect(nav.center.dx, closeTo(400, 0.1));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byTooltip('Home')),
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(110, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selected, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
  testWidgets('flat nav uses theme colors without a selection indicator', (
    tester,
  ) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: FloatingNav(
                items: const [
                  FloatingNavItem('Home', Icons.home),
                  FloatingNavItem('Shorts', Icons.play_arrow),
                ],
                currentIndex: 1,
                onSelected: (_) {},
                inverted: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final surface = tester.widget<Material>(
        find.byKey(const ValueKey('floatingNavSurface')),
      );
      expect(surface.color, theme.scaffoldBackgroundColor);
      expect(find.byKey(const ValueKey('floatingNavIndicator')), findsNothing);
      final selectedIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byTooltip('Shorts'),
          matching: find.byType(Icon),
        ),
      );
      final navContext = tester.element(find.byTooltip('Shorts'));
      expect(selectedIcon.color, Theme.of(navContext).colorScheme.onSurface);
    }
  });
}
