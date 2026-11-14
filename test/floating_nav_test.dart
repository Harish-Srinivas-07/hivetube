import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/theme/app_colors.dart';
import 'package:hivetube/widgets/floating_nav.dart';

void main() {
  testWidgets('centers the pill and selects a tab by dragging', (tester) async {
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
    final pill = tester.getRect(
      find.byKey(const ValueKey('floatingNavSurface')),
    );
    expect(pill.width, lessThan(360));
    expect(pill.center.dx, closeTo(400, 0.1));
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
  testWidgets(
    'Shorts keeps the red indicator and translucent glass in both themes',
    (tester) async {
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
        final surface = tester.widget<Container>(
          find.byKey(const ValueKey('floatingNavSurface')),
        );
        final indicator = tester.widget<Container>(
          find.byKey(const ValueKey('floatingNavIndicator')),
        );
        expect(
          (surface.decoration! as BoxDecoration).color,
          AppColors.shortsNavGlassFill,
        );
        expect(
          (indicator.decoration! as BoxDecoration).color,
          AppColors.primary,
        );
      }
    },
  );
}
