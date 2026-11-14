import 'dart:async';

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

  test('debounces for 250ms and drops stale responses', () async {
    final oldResponse = Completer<List<String>>();
    final newResponse = Completer<List<String>>();
    final source = _FakeSuggestionSource((query) {
      if (query == 'VJ') return oldResponse.future;
      return newResponse.future;
    });
    final controller = SearchSuggestionController(source: source);
    addTearDown(controller.dispose);

    controller.updateQuery('VJ');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(source.queries, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(source.queries, ['VJ']);

    controller.updateQuery('VJ siddhu');
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(source.queries, ['VJ', 'VJ siddhu']);

    newResponse.complete(['VJ siddhu vlogs', 'VJ siddhu virundhu']);
    await Future<void>.delayed(Duration.zero);
    expect(controller.suggestions, ['VJ siddhu vlogs', 'VJ siddhu virundhu']);

    oldResponse.complete(['stale suggestion']);
    await Future<void>.delayed(Duration.zero);
    expect(controller.suggestions, ['VJ siddhu vlogs', 'VJ siddhu virundhu']);
  });
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
