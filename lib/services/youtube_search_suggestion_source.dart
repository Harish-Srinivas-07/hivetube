import 'dart:convert';
import 'dart:developer' as dev;

import 'package:dio/dio.dart';

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
  int? lastStatusCode;
  String? lastRawBody;
  List<String> lastParsedSuggestions = const [];

  @override
  Future<List<String>> fetch(String query) async {
    lastStatusCode = null;
    lastRawBody = null;
    lastParsedSuggestions = const [];
    Response<List<int>>? response;
    try {
      response = await _dio.get<List<int>>(
        endpoint,
        queryParameters: {
          'client': 'firefox',
          'ds': 'yt',
          'q': query,
          'hl': hl,
          'gl': gl,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      lastStatusCode = response.statusCode;
      final rawBody = _decodeBody(response.data, response.headers);
      lastRawBody = rawBody;
      final suggestions = parseSuggestionBody(rawBody);
      lastParsedSuggestions = suggestions;
      dev.log(
        'HTTP ${response.statusCode} query="$query" raw=$rawBody parsed=$suggestions',
        name: 'SearchSuggestions',
      );
      return suggestions;
    } catch (error, stackTrace) {
      final status =
          response?.statusCode ??
          (error is DioException ? error.response?.statusCode : null);
      final body = response == null && error is DioException
          ? _decodeErrorBody(error.response?.data, error.response?.headers)
          : response == null
          ? '<no response body>'
          : _decodeBody(response.data, response.headers);
      lastStatusCode = status;
      lastRawBody = body;
      dev.log(
        'HTTP $status query="$query" raw=$body request failed',
        name: 'SearchSuggestions',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static String _decodeBody(List<int>? bytes, Headers headers) {
    if (bytes == null || bytes.isEmpty) return '';
    final contentType = headers.value(Headers.contentTypeHeader) ?? '';
    final charset = RegExp(
      r'charset=([^; ]+)',
      caseSensitive: false,
    ).firstMatch(contentType)?.group(1)?.replaceAll('"', '').toLowerCase();
    if (charset == 'iso-8859-1' || charset == 'latin1') {
      return latin1.decode(bytes);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String _decodeErrorBody(Object? data, Headers? headers) {
    if (data is List<int>) return _decodeBody(data, headers ?? Headers());
    if (data is String) return data;
    return data?.toString() ?? '<no response body>';
  }

  static List<String> parseSuggestionBody(String body) {
    final normalized = body
        .replaceFirst(RegExp(r'^\uFEFF'), '')
        .replaceFirst(RegExp(r"^\)\]\}',?\s*"), '')
        .trim();
    Object? decoded;
    try {
      decoded = jsonDecode(normalized);
    } on FormatException {
      final open = normalized.indexOf('(');
      final close = normalized.lastIndexOf(')');
      if (open < 0 || close <= open) rethrow;
      decoded = jsonDecode(normalized.substring(open + 1, close));
    }
    if (decoded is! List || decoded.length < 2 || decoded[1] is! List) {
      throw const FormatException('Unexpected YouTube suggestion response');
    }
    return (decoded[1] as List)
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
