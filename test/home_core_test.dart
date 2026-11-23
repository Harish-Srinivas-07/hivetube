import 'dart:convert';
import 'dart:io';
import 'package:hivetube/core/yt/yt_rss.dart';
import 'package:hivetube/features/home/home_guards.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/innertube/json_find.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/features/home/home_cache.dart';
import 'package:hivetube/features/home/home_mixer.dart';

void main() {
  test('findAll and safeNav handle nested and missing values', () {
    final data = {
      'x': [
        {'id': 'a'},
        {
          'nested': {'id': 'b'},
        },
      ],
    };
    expect(findAll(data, 'id'), ['a', 'b']);
    expect(safeNav(data, ['x', 1, 'nested', 'id']), 'b');
    expect(safeNav(data, ['x', 5, 'id']), isNull);
  });
  test(
    'mixer weights sources and deduplicates without watch or dislike filters',
    () {
      const a = VideoItem(id: 'a', title: 'a');
      const b = VideoItem(id: 'b', title: 'b');
      const c = VideoItem(id: 'c', title: 'c');
      const d = VideoItem(id: 'd', title: 'd', channelId: 'blocked');
      const watched = VideoItem(id: 'seen', title: 'seen');
      final result = mixHome(
        [
          [a, b, watched],
          [c, a, d],
        ],
        [2, 1],
      );
      expect(result.map((v) => v.id), ['a', 'b', 'c', 'seen', 'd']);
    },
  );
  test('launch cache expires at thirty minutes and ignores malformed data', () {
    final now = DateTime.utc(2026);
    final cache = HomeCache(
      const [VideoItem(id: 'cached', title: 'Cached')],
      const [],
      now,
    );
    expect(
      HomeCache.decode(cache.encode(), now.add(const Duration(minutes: 29))),
      isNotNull,
    );
    expect(
      HomeCache.decode(cache.encode(), now.add(const Duration(minutes: 30))),
      isNull,
    );
    expect(HomeCache.decode(jsonEncode({'savedAt': 'bad'}), now), isNull);
    expect(
      HomeCache.decode(
        jsonEncode({
          'classifierVersion': 1,
          'savedAt': now.toIso8601String(),
          'videos': [],
          'shorts': [],
        }),
        now,
      ),
      isNull,
    );
  });
  test('RSS entries participate in the weighted mixer', () {
    final uploads = parseRss(File('test/fixtures/feed.xml').readAsStringSync());
    expect(uploads.single.channelId, 'UCexample');
    expect(uploads.single.channelName, 'Channel');
    expect(uploads.single.publishedAt, DateTime.utc(2026, 11, 9));
    const topic = VideoItem(id: 'topic', title: 'Topic');
    expect(
      mixHome(
        [
          uploads,
          [topic, uploads.single],
        ],
        [2, 1],
      ).map((e) => e.id),
      ['abc', 'topic'],
    );
  });
  test('refresh applies only before interaction', () {
    final guard = HomeRefreshGuard();
    expect(guard.canApply, isTrue);
    guard.interact();
    expect(guard.canApply, isFalse);
  });
  test('pagination cannot start twice until finished', () {
    final guard = PaginationGuard();
    expect(guard.begin(), isTrue);
    expect(guard.begin(), isFalse);
    guard.end();
    expect(guard.begin(), isTrue);
  });
}
