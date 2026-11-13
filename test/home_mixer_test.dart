import 'dart:math';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/content/channel_language_cache.dart';
import 'package:hivetube/core/content/language_profile.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/parser.dart';
import 'package:hivetube/features/home/home_mixer.dart';
import 'package:hivetube/features/home/home_shorts.dart';

VideoItem video(String id, {bool short = false, String channel = ''}) =>
    VideoItem(id: id, title: id, isShort: short, channelId: channel);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LanguageProfileRegistry.instance.ensureLoaded();
    ChannelLanguageCache.instance = ChannelLanguageCache(
      AppDb(NativeDatabase.memory()),
    );
  });

  test(
    'paged mixer weights and deduplicates without non-language exclusions',
    () async {
      var secondPage = false;
      final sources = [
        HomeSource(
          weight: 2,
          fetch: (cursor) async {
            if (cursor == null) {
              return VideoPage([
                video('a'),
                video('b'),
                video('seen'),
                video('short', short: true),
              ], 'next');
            }
            secondPage = true;
            return VideoPage([video('e')], null);
          },
        ),
        HomeSource(
          weight: 1,
          fetch: (_) async => VideoPage([
            video('c'),
            video('a'),
            video('blocked', channel: 'bad'),
            video('d'),
          ], null),
        ),
        HomeSource(weight: 2, fetch: (_) async => throw StateError('offline')),
      ];
      final mixer = HomeMixer(sources);
      await mixer.start();
      expect((await mixer.next(10)).map((v) => v.id), [
        'a',
        'b',
        'c',
        'seen',
        'e',
        'blocked',
        'd',
      ]);
      expect(secondPage, isTrue);
      expect(sources.last.error, isNotNull);
      expect(mixer.hasMore, isFalse);
    },
  );
  test(
    'shelf shuffles, deduplicates, caps at 12 and uses watched only to fill',
    () {
      final items = List.generate(
        18,
        (i) =>
            ShortItem(id: '$i', thumbUrl: '', title: 'The official video $i'),
      );
      final shelf = buildShortsShelf(
        [items, items],
        {'0', '1', '2', '3', '4', '5', '6', '7'},
        random: Random(2),
      );
      expect(shelf.length, 12);
      expect(shelf.map((s) => s.id).toSet().length, 12);
      expect(shelf.take(10).every((s) => int.parse(s.id) >= 8), isTrue);
      expect(shelf.skip(10).every((s) => int.parse(s.id) < 8), isTrue);
    },
  );
  test('Shorts lockups expose title and views from overlay metadata', () {
    final result = parseShorts({
      'shortsLockupViewModel': {
        'onTap': {
          'reelWatchEndpoint': {'videoId': 'abc'},
        },
        'overlayMetadata': {
          'primaryText': {'content': 'A Short'},
          'secondaryText': {'content': '10K views'},
        },
      },
    });
    expect(result.single.title, 'A Short');
    expect(result.single.viewsText, '10K views');
  });
}
