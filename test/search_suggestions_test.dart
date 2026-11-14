import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/services/search_suggestions.dart';

void main() {
  test('parses text/javascript JSON and preserves non-ASCII suggestions', () {
    const body = 'google.ac.h(["VJ siddhu",["vj siddhu","விஜய் சித்து"]]);';

    expect(YoutubeSearchSuggestionSource.parseSuggestionBody(body), [
      'vj siddhu',
      'விஜய் சித்து',
    ]);
  });

  test(
    'debounces, clears old results immediately, and drops stale responses',
    () {
      fakeAsync((async) {
        final staleResponse = Completer<List<String>>();
        final currentResponse = Completer<List<String>>();
        final source = _FakeSuggestionSource((query) {
          if (query == 'second') return staleResponse.future;
          if (query == 'third') return currentResponse.future;
          return Future.value(['first result']);
        });
        final controller = SearchSuggestionController(source: source);

        controller.updateQuery('first');
        async.elapse(const Duration(milliseconds: 249));
        expect(source.queries, isEmpty);
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(source.queries, ['first']);
        expect(controller.suggestions, ['first result']);

        controller.updateQuery('second');
        expect(controller.suggestions, isEmpty);
        async.elapse(const Duration(milliseconds: 250));
        async.flushMicrotasks();
        expect(source.queries, ['first', 'second']);

        controller.updateQuery('third');
        expect(controller.suggestions, isEmpty);
        async.elapse(const Duration(milliseconds: 249));
        expect(source.queries, ['first', 'second']);
        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(source.queries, ['first', 'second', 'third']);

        currentResponse.complete(['third result']);
        async.flushMicrotasks();
        expect(controller.suggestions, ['third result']);

        staleResponse.complete(['stale result']);
        async.flushMicrotasks();
        expect(controller.suggestions, ['third result']);

        controller.dispose();
        source.dispose();
      });
    },
  );
}

class _FakeSuggestionSource implements SearchSuggestionSource {
  _FakeSuggestionSource(this.respond);

  final Future<List<String>> Function(String query) respond;
  final List<String> queries = [];

  @override
  Future<List<String>> fetch(String query) {
    queries.add(query);
    return respond(query);
  }

  @override
  void dispose() {}
}
