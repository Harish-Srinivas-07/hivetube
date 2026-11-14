import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

abstract interface class SearchSuggestionSource {
  Future<List<String>> fetch(String query);

  void dispose();
}

/// YouTube's type-ahead endpoint, usable with an app-owned Dio client.
class YoutubeSearchSuggestionSource implements SearchSuggestionSource {
  YoutubeSearchSuggestionSource({
    Dio? dio,
    this.endpoint = 'https://suggestqueries.google.com/complete/search',
    this.hl = 'en',
    this.gl = 'IN',
  }) : _ownsDio = dio == null,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 8),
             ),
           );

  final Dio _dio;
  final bool _ownsDio;
  final String endpoint;
  final String hl;
  final String gl;

  @override
  Future<List<String>> fetch(String query) async {
    final response = await _dio.get<dynamic>(
      endpoint,
      queryParameters: {
        'client': 'firefox',
        'ds': 'yt',
        'q': query,
        'hl': hl,
        'gl': gl,
      },
    );
    final data = response.data;
    if (data is! List || data.length < 2 || data[1] is! List) {
      return const [];
    }
    return (data[1] as List)
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    if (_ownsDio) _dio.close();
  }
}

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

  void updateQuery(String value) {
    _debounce?.cancel();
    final generation = ++_generation;
    final query = value.trim();
    suggestions = const [];
    isLoading = query.isNotEmpty;
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
    } catch (_) {
      if (_disposed || generation != _generation) return;
      suggestions = const [];
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
