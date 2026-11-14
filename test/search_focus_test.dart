import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/features/search/search_screen.dart';
import 'package:hivetube/services/search_suggestions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search field keeps focus while suggestions render', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    final source = _FakeSuggestionSource();
    addTearDown(() async => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbProvider.overrideWithValue(db)],
        child: MaterialApp(home: SearchScreen(suggestionSource: source)),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('searchQueryField'));
    await tester.enterText(field, 'VJ siddhu');
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump();

    expect(find.text('VJ siddhu vlogs'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'VJ siddhu',
    );
  });
}

class _FakeSuggestionSource implements SearchSuggestionSource {
  @override
  Future<List<String>> fetch(String query) async => [
    '$query vlogs',
    '$query virundhu',
  ];

  @override
  void dispose() {}
}
