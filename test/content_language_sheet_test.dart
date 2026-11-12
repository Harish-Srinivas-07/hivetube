import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/settings/app_settings.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/widgets/app_top_bar.dart';
import 'package:hivetube/widgets/content_language_button.dart';
import 'package:hivetube/widgets/home_top_bar.dart';

ProviderContainer _container(AppDb db, [AppSettings? settings]) =>
    ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        initialAppSettingsProvider.overrideWithValue(
          settings ?? AppSettings.defaults(const Locale('en', 'IN')),
        ),
      ],
    );

Future<void> _showBar(
  WidgetTester tester,
  ProviderContainer container,
  Widget bar, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(body: bar),
      ),
    ),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('language button appears on Home and AppTopBar', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    final container = _container(db);
    addTearDown(container.dispose);
    addTearDown(db.close);

    await _showBar(tester, container, const HomeTopBar());
    expect(find.byType(ContentLanguageButton), findsOneWidget);
    expect(
      find.byKey(const ValueKey('contentLanguageChangedDot')),
      findsNothing,
    );

    await _showBar(tester, container, const AppTopBar());
    expect(find.byType(ContentLanguageButton), findsOneWidget);
  });

  testWidgets('opens the draggable language sheet with its title', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    final container = _container(db);
    addTearDown(container.dispose);
    addTearDown(db.close);
    await _showBar(tester, container, const HomeTopBar());

    await tester.tap(find.byKey(const ValueKey('contentLanguageButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('contentLanguageSheetTitle')),
      findsOneWidget,
    );
    expect(
      find.text('Choose what Home, Shorts and suggestions show.'),
      findsOneWidget,
    );
    await _scrollTo(tester, find.text('Region'));
    expect(find.text('Region'), findsOneWidget);
    await _scrollTo(tester, find.text('Mix'));
    expect(find.text('Mix'), findsOneWidget);
  });

  testWidgets('last shown language stays selected and shows a hint', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    final container = _container(
      db,
      const AppSettings(
        hl: 'ta',
        gl: 'IN',
        contentLanguages: {'ta'},
        hiddenLanguages: {'hi'},
      ),
    );
    addTearDown(container.dispose);
    addTearDown(db.close);
    await _showBar(tester, container, const HomeTopBar());
    await tester.tap(find.byKey(const ValueKey('contentLanguageButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('showLanguage_ta')));
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('showLanguage_ta')))
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('showLanguage_en')))
          .value,
      isTrue,
    );
    await _scrollTo(tester, find.byKey(const ValueKey('contentLanguageHint')));
    expect(find.byKey(const ValueKey('contentLanguageHint')), findsOneWidget);
  });

  testWidgets('hide and show are exclusive; Done applies preferences once', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    final container = _container(db);
    addTearDown(container.dispose);
    addTearDown(db.close);
    await _showBar(tester, container, const HomeTopBar());
    await tester.tap(find.byKey(const ValueKey('contentLanguageButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('hideLanguage_ta')));
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(find.byKey(const ValueKey('showLanguage_ta')))
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('contentPrefsDone')));
    await tester.pumpAndSettle();

    final prefs = container.read(contentPrefsProvider);
    expect(prefs.contentLanguages, {'en'});
    expect(prefs.hiddenLanguages, {'hi', 'ta'});
    expect(prefs.contentLanguages.intersection(prefs.hiddenLanguages), isEmpty);
    expect(prefs.prefsVersion, 1);
    expect(await db.getValue('settings_prefs_version'), '1');
  });

  testWidgets('Reset restores defaults and removes the changed dot', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    final container = _container(
      db,
      const AppSettings(
        hl: 'te',
        gl: 'US',
        contentLanguages: {'te'},
        hiddenLanguages: {'hi'},
        localRatio: .8,
      ),
    );
    addTearDown(container.dispose);
    addTearDown(db.close);
    await _showBar(tester, container, const AppTopBar());
    expect(
      find.byKey(const ValueKey('contentLanguageChangedDot')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('contentLanguageButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contentPrefsReset')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('contentPrefsDone')));
    await tester.pumpAndSettle();

    final prefs = container.read(contentPrefsProvider);
    expect(prefs.contentLanguages, {'ta', 'en'});
    expect(prefs.hiddenLanguages, {'hi'});
    expect(prefs.gl, 'IN');
    expect(prefs.hl, 'en');
    expect(prefs.localRatio, .6);
    expect(
      find.byKey(const ValueKey('contentLanguageChangedDot')),
      findsNothing,
    );
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('sheet renders under ${theme.brightness.name} theme', (
      tester,
    ) async {
      final db = AppDb(NativeDatabase.memory());
      final container = _container(db);
      addTearDown(container.dispose);
      addTearDown(db.close);
      await _showBar(tester, container, const HomeTopBar(), theme: theme);
      await tester.tap(find.byKey(const ValueKey('contentLanguageButton')));
      await tester.pumpAndSettle();
      expect(find.text('Languages'), findsOneWidget);
      await _scrollTo(tester, find.text('More local'));
      expect(find.text('More local'), findsOneWidget);
      expect(find.byKey(const ValueKey('contentPrefsDone')), findsOneWidget);
    });
  }
}
