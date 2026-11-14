import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/features/search/search_screen.dart';
import 'package:hivetube/services/search_suggestions.dart';
import 'package:hivetube/theme/app_radius.dart';
import 'package:hivetube/theme/app_sizes.dart';
import 'package:hivetube/theme/app_spacing.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/theme/app_text_styles.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Search field layout in $brightness theme', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dbProvider.overrideWithValue(db),
            recentSearchesStreamProvider.overrideWith(
              (ref) => Stream.value(const <String>[]),
            ),
            subscriptionsStreamProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: brightness == Brightness.light
                ? ThemeMode.light
                : ThemeMode.dark,
            home: SearchScreen(suggestionSource: _EmptySuggestionSource()),
          ),
        ),
      );
      await tester.pump();

      final fieldFinder = find.byKey(const ValueKey('searchQueryField'));
      final field = tester.widget<TextField>(fieldFinder);
      final fieldRect = tester.getRect(fieldFinder);
      final barRect = tester.getRect(
        find.byKey(const ValueKey('searchTopBar')),
      );
      final backFinder = find.byTooltip('Back');
      final backRect = tester.getRect(backFinder);
      final scheme = Theme.of(tester.element(fieldFinder)).colorScheme;

      expect(fieldRect.height, 40);
      expect(fieldRect.center.dy, closeTo(barRect.center.dy, 1));
      expect(barRect.height, 56);
      expect(backRect.left, 0);
      expect(backRect.size, const Size(48, 48));
      expect(fieldRect.left - backRect.right, AppSpacing.xs);
      expect(fieldRect.right, 348);
      expect(field.focusNode?.hasFocus, isTrue);
      expect(field.decoration!.fillColor, scheme.surfaceContainerHighest);
      expect(field.decoration!.isDense, isTrue);
      expect(
        (field.decoration!.border! as OutlineInputBorder).borderRadius,
        AppRadius.pillBorder,
      );
      expect(field.cursorColor, scheme.primary);
      expect(field.textInputAction, TextInputAction.search);
      expect(field.onSubmitted, isNotNull);
      expect(field.style!.fontSize, AppTextStyles.settingsTitle.fontSize);
      expect(field.style!.height, AppTextStyles.settingsTitle.height);
      expect(
        field.decoration!.prefixIconConstraints!.minWidth,
        greaterThanOrEqualTo(AppSizes.touchMin - AppSpacing.sm),
      );
      expect(
        (field.decoration!.contentPadding! as EdgeInsets).vertical,
        AppSpacing.none,
      );

      final hintRect = tester.getRect(find.text('Search'));
      expect(hintRect.center.dy, closeTo(fieldRect.center.dy, 1));
      expect(field.decoration!.hintStyle!.fontSize, field.style!.fontSize);
      expect(field.decoration!.hintStyle!.color, scheme.onSurfaceVariant);

      final decoration = field.decoration!;
      for (final border in [
        decoration.border,
        decoration.enabledBorder,
        decoration.focusedBorder,
        decoration.errorBorder,
        decoration.disabledBorder,
      ]) {
        expect(border, isA<OutlineInputBorder>());
        expect((border! as OutlineInputBorder).borderSide, BorderSide.none);
      }
      expect(decoration.suffixIcon, isNull);
      final themeFocusedBorder =
          Theme.of(
                tester.element(fieldFinder),
              ).inputDecorationTheme.focusedBorder!
              as OutlineInputBorder;
      expect(themeFocusedBorder.borderSide, BorderSide.none);

      await tester.enterText(fieldFinder, 'typed query');
      await tester.pump();
      final typedField = tester.widget<TextField>(fieldFinder);
      final typedStyle = typedField.style!;
      expect(typedStyle.color, scheme.onSurface);
      expect(
        typedField.decoration!.suffixIconConstraints!.minWidth,
        AppSizes.touchMin - AppSpacing.sm,
      );
      final clearIcon = typedField.decoration!.suffixIcon as IconButton;
      expect((clearIcon.icon as Icon).size, AppSizes.iconSm);
      final fill = typedField.decoration!.fillColor!;
      expect(_contrast(typedStyle.color!, fill), greaterThanOrEqualTo(4.5));

      typedField.focusNode!.unfocus();
      await tester.pump();
      expect(typedField.decoration!.enabledBorder, isA<OutlineInputBorder>());
      expect(
        (typedField.decoration!.enabledBorder! as OutlineInputBorder)
            .borderSide,
        BorderSide.none,
      );
    });
  }
}

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

class _EmptySuggestionSource implements SearchSuggestionSource {
  @override
  Future<List<String>> fetch(String query) async => const [];

  @override
  void dispose() {}
}
