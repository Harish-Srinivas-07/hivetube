import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/content/channel_language_cache.dart';
import 'package:hivetube/core/content/language_profile.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/features/home/home_mixer.dart';
import 'package:hivetube/features/home/home_variety.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LanguageProfileRegistry.instance.ensureLoaded();
    ChannelLanguageCache.instance = ChannelLanguageCache(AppDb(NativeDatabase.memory()));
  });
  test('detects the supported Unicode scripts', () {
    expect(scriptLanguage('தமிழ்'), 'ta');
    expect(scriptLanguage('हिन्दी'), 'hi');
    expect(scriptLanguage('తెలుగు'), 'te');
    expect(scriptLanguage('മലയാളം'), 'ml');
    expect(scriptLanguage('ಕನ್ನಡ'), 'kn');
    expect(scriptLanguage('বাংলা'), 'bn');
    expect(scriptLanguage('ગુજરાતી'), 'gu');
    expect(scriptLanguage('ਪੰਜਾਬੀ'), 'pa');
    expect(scriptLanguage('ଓଡ଼ିଆ'), 'or');
    expect(scriptLanguage('اردو'), 'ur');
    expect(scriptLanguage('English title'), 'en');
  });

  test(
    'filters hidden language and scores preferred script and Tamil terms',
    () {
      const tamil = VideoItem(id: 'ta', title: 'தமிழ் பாடல்');
      const keyword = VideoItem(id: 'kw', title: 'Chennai food guide');
      const latin = VideoItem(id: 'en', title: 'A music guide');
      const hindi = VideoItem(id: 'hi', title: 'हिन्दी गाना');
      expect(hiddenLanguage(hindi, {'hi'}), isTrue);
      expect(
        hiddenLanguage(
          const VideoItem(id: 'word', title: 'Hindi zindagi pyaar'),
          {'hi'},
        ),
        isTrue,
      );
      expect(homeLanguageScore(tamil, {'ta', 'en'}), 5);
      expect(homeLanguageScore(keyword, {'ta', 'en'}), 2);
      expect(homeLanguageScore(latin, {'ta', 'en'}), 2);
    },
  );

  test('sorts preferred/Tamil items first and demotes seen ids', () {
    const tamil = VideoItem(id: 'ta', title: 'தமிழ் இசை');
    const neutral = VideoItem(id: 'en', title: 'Music');
    const seenTamil = VideoItem(id: 'old', title: 'தமிழ் பாடல்');
    final ids = rankHomeItems(
      [neutral, seenTamil, tamil],
      preferred: {'ta', 'en'},
      hidden: {'hi'},
      seen: {'old'},
      random: Random(7),
    ).map((item) => item.id);
    expect(ids.toList(), ['ta', 'en', 'old']);
  });

  test('query choice rotates with its random seed', () {
    final first = chooseHomeQueries(
      chip: 'All',
      hasHistory: false,
      localRatio: 0.6,
      shownLanguages: {'ta', 'en'},
      random: Random(1),
    );
    final second = chooseHomeQueries(
      chip: 'All',
      hasHistory: false,
      localRatio: 0.6,
      shownLanguages: {'ta', 'en'},
      random: Random(2),
    );
    expect(first, isNotEmpty);
    expect(second, isNotEmpty);
    expect(first.toSet(), isNot(second.toSet()));
  });

  test('selected query pools follow Telugu or English-only preferences', () {
    final telugu = chooseHomeQueries(
      chip: 'All',
      hasHistory: false,
      localRatio: 1,
      shownLanguages: {'te'},
      random: Random(6),
    );
    expect(
      telugu,
      everyElement(
        anyOf(
          predicate<String>((query) => query.toLowerCase().contains('telugu')),
          contains('తెలుగు'),
        ),
      ),
    );
    final english = chooseHomeQueries(
      chip: 'All',
      hasHistory: false,
      localRatio: 1,
      shownLanguages: {'en'},
      random: Random(6),
    );
    expect(english, isNotEmpty);
    expect(english, everyElement(isNot(contains('telugu'))));
  });

  test(
    'filtered sources fetch extra pages to fill the twenty item buffer',
    () async {
      var page = 0;
      final source = HomeSource(
        weight: 1,
        transform: (items) => rankHomeItems(
          items,
          preferred: {'ta', 'en'},
          hidden: {'hi'},
          seen: const {},
          random: Random(3),
        ),
        fetch: (_) async {
          page++;
          if (page == 1) {
            return VideoPage([
              const VideoItem(id: 'h1', title: 'हिन्दी'),
              const VideoItem(id: 'h2', title: 'हिन्दी'),
              const VideoItem(id: 'first', title: 'Tamil song'),
            ], 'next');
          }
          return VideoPage([
            for (var i = 0; i < 19; i++)
              VideoItem(id: 'p$i', title: 'English item $i'),
          ], null);
        },
      );
      await source.ensure();
      expect(page, 2);
      expect(source.done, isTrue);
      expect((await HomeMixer([source]).next(20)), hasLength(20));
    },
  );
}
