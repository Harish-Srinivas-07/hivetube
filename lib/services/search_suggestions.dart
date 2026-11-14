import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import 'search_suggestion_source.dart';

export 'search_suggestion_source.dart';

class SearchSuggestionController extends ChangeNotifier {
  SearchSuggestionController({
    required this.source,
    this.debounceDuration = const Duration(milliseconds: 250),
  });

  final SearchSuggestionSource source;
  final Duration debounceDuration;

  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;
  List<String> suggestions = const [];
  bool isLoading = false;
  Object? error;

  void updateQuery(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    final query = value.trim();
    suggestions = const [];
    isLoading = query.isNotEmpty;
    error = null;
    notifyListeners();
    if (query.isEmpty) return;

    _debounce = Timer(debounceDuration, () {
      unawaited(_load(query, generation));
    });
  }

  Future<void> _load(String query, int generation) async {
    if (_disposed || generation != _generation) return;
    isLoading = true;
    notifyListeners();
    try {
      final values = await source.fetch(query);
      if (_disposed || generation != _generation) return;
      suggestions = values;
    } catch (caught, stackTrace) {
      final status = source is YoutubeSearchSuggestionSource
          ? (source as YoutubeSearchSuggestionSource).lastStatusCode
          : null;
      dev.log(
        'Suggestion request failed status=$status query="$query" error=$caught',
        name: 'SearchSuggestionController',
        error: caught,
        stackTrace: stackTrace,
      );
      if (_disposed || generation != _generation) return;
      error = caught;
    } finally {
      if (!_disposed && generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    super.dispose();
  }
}
