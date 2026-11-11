import 'dart:async';
import 'package:dio/dio.dart';
import '../innertube/innertube_http.dart';
import '../innertube/json_find.dart';
import 'models.dart';
import 'parser.dart';

class ReelPage {
  const ReelPage(
    this.items,
    this.continuation,
    this.continuationCount, {
    this.failed = false,
  });
  final List<ShortItem> items;
  final String? continuation;
  final int continuationCount;
  final bool failed;
}

class YtReel {
  YtReel(this.http);
  final InnertubeHttp http;
  final Map<String, Future<ShortItem?>> _metadata = {};
  int _active = 0;
  final List<Completer<void>> _waiting = [];

  Future<ReelPage> fetch({
    String? continuation,
    int count = 12,
    int maxContinuations = 5,
    CancelToken? cancelToken,
  }) async {
    final items = <ShortItem>[];
    final seen = <String>{};
    final tokens = <String>{?continuation};
    var cursor = continuation;
    var calls = 0;
    var failed = false;
    do {
      try {
        final response = await http.post(
          'reel/reel_watch_sequence',
          cursor == null
              ? {'sequenceParams': 'CA8%3D'}
              : {'continuation': cursor},
          cancelToken: cancelToken,
        );
        if (cursor != null) calls++;
        final page = parseReelEntries(response);
        items.addAll(page.where((item) => seen.add(item.id)));
        final next = reelContinuation(response);
        cursor = next != null && tokens.add(next) ? next : null;
        if (page.isEmpty) cursor = null;
      } catch (_) {
        failed = true;
        break;
      }
    } while (items.length < count &&
        cursor != null &&
        calls < maxContinuations);
    return ReelPage(items, cursor, calls, failed: failed);
  }

  Future<List<ShortItem>> shorts({CancelToken? cancelToken}) async =>
      (await fetch(cancelToken: cancelToken)).items;

  Future<ShortItem?> metadata(String id) => _metadata.putIfAbsent(id, () async {
    if (_active >= 4) {
      final waiter = Completer<void>();
      _waiting.add(waiter);
      await waiter.future;
    } else {
      _active++;
    }
    try {
      final response = await http.post('next', {
        'videoId': id,
        'contentCheckOk': true,
        'racyCheckOk': true,
      });
      return parseShortMetadata(response, id);
    } catch (_) {
      return null;
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  });
}

String? reelContinuation(dynamic json) {
  // Entry prefetch data contains unrelated comment and panel continuations.
  final rootToken = safeNav(json, [
    'continuationEndpoint',
    'continuationCommand',
    'token',
  ]);
  if (rootToken is String && rootToken.isNotEmpty) return rootToken;
  if (json is Map) json = Map.of(json)..remove('entries');
  for (final key in [
    'continuation',
    'continuationCommand',
    'nextContinuationData',
    'reloadContinuationData',
  ]) {
    for (final value in findAll(json, key)) {
      final token = value is String
          ? value
          : value is Map
          ? (value['token'] ?? value['continuation'])
          : null;
      if (token is String && token.isNotEmpty) return token;
    }
  }
  return null;
}
