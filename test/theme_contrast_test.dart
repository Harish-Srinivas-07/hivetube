import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/theme/app_theme.dart';

void main() {
  testWidgets('root screen titles contrast in light and dark themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);

    const screens = <({String route, String title, bool searchField})>[
      (route: '/home', title: 'HiveTube', searchField: false),
      (route: '/subscriptions', title: 'Subscriptions', searchField: false),
      (route: '/library', title: 'You', searchField: false),
      (route: '/search', title: 'Search', searchField: true),
      (route: '/settings', title: 'Settings', searchField: false),
      (route: '/history', title: 'History', searchField: false),
    ];

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      appRouter.go('/home');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dbProvider.overrideWithValue(db)],
          child: MaterialApp.router(theme: theme, routerConfig: appRouter),
        ),
      );

      for (final screen in screens) {
        appRouter.go(screen.route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final background = _screenBackground(tester);
        final foreground = screen.searchField
            ? _searchTextColor(tester)
            : _titleTextColor(tester, screen.title);
        expect(
          _contrast(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason:
              '${screen.route} title contrast under ${theme.brightness}: '
              'foreground=$foreground background=$background',
        );
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });
}

Color _screenBackground(WidgetTester tester) {
  final scaffoldFinder = find.byType(Scaffold).last;
  final scaffold = tester.widget<Scaffold>(scaffoldFinder);
  return scaffold.backgroundColor ??
      Theme.of(tester.element(scaffoldFinder)).scaffoldBackgroundColor;
}

Color _titleTextColor(WidgetTester tester, String title) {
  final finder = find.text(title).first;
  final element = tester.element(finder);
  final widget = tester.widget<Text>(finder);
  return widget.style?.color ?? DefaultTextStyle.of(element).style.color!;
}

Color _searchTextColor(WidgetTester tester) {
  final editable = tester.widget<EditableText>(find.byType(EditableText).first);
  final element = tester.element(find.byType(EditableText).first);
  return editable.style.color ?? DefaultTextStyle.of(element).style.color!;
}

double _contrast(Color foreground, Color background) {
  final light = foreground.computeLuminance();
  final dark = background.computeLuminance();
  final high = light > dark ? light : dark;
  final low = light > dark ? dark : light;
  return (high + 0.05) / (low + 0.05);
}
