import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/parser.dart';
import 'package:hivetube/core/yt/yt_search.dart';
import 'package:hivetube/features/search/search_screen.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/services/search_suggestions.dart';
import 'package:hivetube/theme/app_spacing.dart';
import 'package:hivetube/widgets/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unknown search filters are unselected and apply their params', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final search = _FilterSearch();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          ytApiProvider.overrideWith((ref) async => _FilterApi(search)),
          recentSearchesStreamProvider.overrideWith(
            (ref) => Stream.value(const <String>[]),
          ),
          subscriptionsStreamProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
        child: MaterialApp(
          home: SearchScreen(
            initialQuery: 'music',
            suggestionSource: _FakeSuggestionSource(),
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    AppChip chip(String label) => tester.widget<AppChip>(
      find.byWidgetPredicate(
        (widget) => widget is AppChip && widget.label == label,
      ),
    );
    expect(chip('All').selected, isTrue);
    expect(chip('Movies').selected, isFalse);
    expect(chip('Under 3 minutes').selected, isFalse);
    await tester.tap(find.text('Movies'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(search.lastParams, 'movies-param');
    expect(chip('All').selected, isFalse);
    expect(chip('Movies').selected, isTrue);
    expect(chip('Under 3 minutes').selected, isFalse);
  });

  testWidgets('shorts shelf fits two-line titles at larger text sizes', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        ytApiProvider.overrideWith((ref) async => _ShortsApi()),
        recentSearchesStreamProvider.overrideWith(
          (ref) => Stream.value(const <String>[]),
        ),
        subscriptionsStreamProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder: (_, _) => SearchScreen(
            initialQuery: 'music',
            suggestionSource: _FakeSuggestionSource(),
          ),
        ),
        GoRoute(
          path: '/shorts',
          builder: (_, _) => const Scaffold(body: Text('shorts route')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.text('A longer title that wraps across two lines'),
      findsOneWidget,
    );
    expect(find.text('Standalone short'), findsOneWidget);
    expect(find.text('123 views'), findsOneWidget);
    expect(
      tester.widget<ShortsShelf>(find.byType(ShortsShelf)).cardWidth,
      AppSpacing.searchShortWidth,
    );
    expect(
      tester
          .widget<CachedNetworkImage>(
            find.byKey(const ValueKey('shortsShelfThumbnail:one:preferred')),
          )
          .imageUrl,
      'https://i.ytimg.com/vi/one/maxresdefault.jpg',
    );
    expect(find.byTooltip('More options'), findsNWidgets(2));
    expect(
      tester.widget<GridView>(find.byType(GridView)).scrollDirection,
      Axis.horizontal,
    );
    await tester.tap(find.text('A longer title that wraps across two lines'));
    await tester.pumpAndSettle();
    expect(find.text('shorts route'), findsOneWidget);
    expect(container.read(shortsSelectionProvider).items.single.id, 'one');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows suggestion placeholders while loading', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final source = _PendingSuggestionSource();
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
        child: MaterialApp(home: SearchScreen(suggestionSource: source)),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('searchQueryField')),
      'music',
    );
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.byType(SkeletonBox), findsNWidgets(4));
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    source.result.complete(['music videos']);
    await tester.pump();
    expect(find.byType(SkeletonBox), findsNothing);
    expect(find.text('music videos'), findsOneWidget);
  });

  testWidgets('search field keeps focus while suggestions render', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    final source = _FakeSuggestionSource();
    addTearDown(() async => db.close());

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

class _FilterApi extends Fake implements YtApi {
  _FilterApi(this.search);
  @override
  final YtSearch search;
}

class _FilterSearch extends Fake implements YtSearch {
  String? lastParams;
  @override
  Future<SearchResultPage> search(
    String query, {
    String? continuation,
    String? params,
    CancelToken? cancelToken,
  }) async {
    lastParams = params;
    final filters = parseSearchFilterChips({
      'searchFilterGroupRenderer': {
        'filters': [
          for (final filter in [
            ('Movies', 'movies-param'),
            ('Under 3 minutes', 'duration-param'),
          ])
            {
              'searchFilterRenderer': {
                'label': {'simpleText': filter.$1},
                'navigationEndpoint': {
                  'searchEndpoint': {'params': filter.$2},
                },
              },
            },
        ],
      },
    });
    return SearchResultPage(items: const [], filters: filters);
  }
}

class _ShortsApi extends Fake implements YtApi {
  @override
  YtSearch get search => _ShortsSearch();
}

class _ShortsSearch extends Fake implements YtSearch {
  @override
  Future<SearchResultPage> search(
    String query, {
    String? continuation,
    String? params,
    CancelToken? cancelToken,
  }) async => const SearchResultPage(
    items: [
      ShortsShelfSearchResult([
        ShortItem(
          id: 'one',
          thumbUrl: 'https://i.ytimg.com/vi/one/hqdefault.jpg',
          title: 'A longer title that wraps across two lines',
          viewsText: '123 views',
        ),
      ]),
      ShortSearchResult(
        ShortItem(id: 'two', thumbUrl: '', title: 'Standalone short'),
      ),
    ],
  );
}

class _PendingSuggestionSource implements SearchSuggestionSource {
  final result = Completer<List<String>>();

  @override
  Future<List<String>> fetch(String query) => result.future;

  @override
  void dispose() {}
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
