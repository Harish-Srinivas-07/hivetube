import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
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
  test('mixer weights sources, deduplicates and filters', () {
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
      history: [
        const HistoryEntry(
          'seen',
          Duration(seconds: 90),
          Duration(seconds: 100),
        ),
      ],
      disliked: {'blocked'},
    );
    expect(result.map((v) => v.id), ['a', 'b', 'c']);
  });
  test('launch cache expires at twelve hours and ignores malformed data', () {
    final now = DateTime.utc(2026);
    final cache = HomeCache(const [], const [], now);
    expect(
      HomeCache.decode(cache.encode(), now.add(const Duration(hours: 11))),
      isNotNull,
    );
    expect(
      HomeCache.decode(cache.encode(), now.add(const Duration(hours: 12))),
      isNull,
    );
    expect(HomeCache.decode(jsonEncode({'savedAt': 'bad'}), now), isNull);
  });
}
