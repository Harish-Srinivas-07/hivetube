import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/content/channel_language_cache.dart';
import 'package:hivetube/core/content/content_filter.dart';
import 'package:hivetube/core/content/language_profile.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/settings/app_settings.dart';
import 'package:hivetube/core/yt/models.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LanguageProfileRegistry.instance.ensureLoaded();
  });

  group('ContentFilter allow-list policy', () {
    late ChannelLanguageCache cache;
    late ContentFilter filter;

    setUp(() {
      cache = ChannelLanguageCache(AppDb(NativeDatabase.memory()));
      filter = ContentFilter(channelCache: cache);
    });

    test('Strict Home allows only shown languages', () {
      final res = filter.evaluate(
        id: 'v1',
        title: 'తెలుగు సినిమా పాటలు',
        channelId: 'ch1',
        channelName: 'Aditya Music Telugu',
        shownLanguages: {'te'},
        hiddenLanguages: {'hi'},
        strictHome: true,
      );
      expect(res.kept, isTrue);
      expect(res.finalLanguage, 'te');
    });

    test('Strict Home drops non-shown languages even if not in hidden', () {
      // Kannada item when shown is only Telugu and hidden is only Hindi
      final res = filter.evaluate(
        id: 'v2',
        title: 'ಕನ್ನಡ ಹೊಸ ಹಾಡುಗಳು',
        channelId: 'ch2',
        channelName: 'Anand Audio Kannada',
        shownLanguages: {'te'},
        hiddenLanguages: {'hi'},
        strictHome: true,
      );
      expect(res.kept, isFalse);
      expect(res.finalLanguage, 'kn');
    });

    test('Strict Home drops hidden languages unconditionally', () {
      final res = filter.evaluate(
        id: 'v3',
        title: 'हिंदी नया गाना',
        channelId: 'ch3',
        channelName: 'T-Series Hindi',
        shownLanguages: {'hi', 'te'},
        hiddenLanguages: {'hi'},
        strictHome: true,
      );
      expect(res.kept, isFalse);
      expect(res.finalLanguage, 'hi');
    });

    test('Unknown-Latin drops when no selected language evidence exists', () {
      final res = filter.evaluate(
        id: 'v4',
        title: 'Amazing Super Action Movie Review 2024',
        channelId: 'ch4',
        channelName: 'Action Mania',
        shownLanguages: {'te'},
        hiddenLanguages: {'hi'},
        strictHome: true,
      );
      expect(res.kept, isFalse);
      expect(res.finalLanguage, 'unknown');
    });

    test(
      'Unknown-Latin drops even when English is shown without English evidence',
      () {
        final res = filter.evaluate(
          id: 'v5',
          title: 'Amazing Super Action Movie Review 2024',
          channelId: 'ch5',
          channelName: 'Action Mania',
          shownLanguages: {'en'},
          hiddenLanguages: {'hi'},
          strictHome: true,
        );
        expect(res.kept, isFalse);
        expect(res.finalLanguage, 'unknown');
      },
    );

    test('English lexical signal is kept for Tamil and English selection', () {
      final res = filter.evaluate(
        id: 'english',
        title: 'The official video trailer review',
        channelId: 'en-channel',
        channelName: 'Film Reviews',
        shownLanguages: {'ta', 'en'},
        hiddenLanguages: {'hi'},
      );
      expect(res.finalLanguage, 'en');
      expect(res.kept, isTrue);
    });

    test(
      'Tamil and English selected keeps Tamil, drops Hindi and unsupported Latin',
      () {
        ContentFilterResult evaluate(String title) => filter.evaluate(
          id: title,
          title: title,
          channelId: title,
          channelName: 'Channel',
          shownLanguages: {'ta', 'en'},
          hiddenLanguages: {'hi'},
        );

        expect(evaluate('தமிழ் புதிய படம்').finalLanguage, 'ta');
        expect(evaluate('தமிழ் புதிய படம்').kept, isTrue);
        expect(evaluate('हिंदी नया गाना').finalLanguage, 'hi');
        expect(evaluate('हिंदी नया गाना').kept, isFalse);
        expect(evaluate('hai kya nahi').finalLanguage, 'hi');
        expect(evaluate('hai kya nahi').kept, isFalse);
        expect(evaluate('paadal isai').finalLanguage, 'ta');
        expect(evaluate('paadal isai').kept, isTrue);
        expect(
          evaluate('Amazing Super Action Movie Review 2024').kept,
          isFalse,
        );
      },
    );

    test('Explicit English channel vote is a valid English signal', () {
      cache.vote('english-channel', 'en', weight: 2);
      final res = filter.evaluate(
        id: 'channel-en',
        title: 'A Latin title without known English words',
        channelId: 'english-channel',
        channelName: 'Channel',
        shownLanguages: {'ta', 'en'},
        hiddenLanguages: {'hi'},
      );
      expect(res.finalLanguage, 'en');
      expect(res.kept, isTrue);
    });

    test(
      'Script and lexicon evidence outrank channel votes and probe results',
      () {
        cache.vote('conflict-script', 'hi', weight: 2);
        cache.vote('conflict-lexicon', 'hi', weight: 2);
        final script = filter.evaluate(
          id: 'script',
          title: 'தமிழ் புதிய படம்',
          channelId: 'conflict-script',
          channelName: 'Channel',
          shownLanguages: {'ta', 'en'},
          hiddenLanguages: {'hi'},
          probeLanguage: 'hi',
        );
        final lexicon = filter.evaluate(
          id: 'lexicon',
          title: 'paadal isai',
          channelId: 'conflict-lexicon',
          channelName: 'Channel',
          shownLanguages: {'ta', 'en'},
          hiddenLanguages: {'hi'},
          probeLanguage: 'hi',
        );
        expect(script.finalLanguage, 'ta');
        expect(lexicon.finalLanguage, 'ta');
      },
    );
  });

  group('Romanized Lexicon & Marathi vs Hindi Disambiguation', () {
    late ChannelLanguageCache cache;
    late ContentFilter filter;

    setUp(() {
      cache = ChannelLanguageCache(AppDb(NativeDatabase.memory()));
      filter = ContentFilter(channelCache: cache);
    });

    test('Detects romanized Hindi comedy markers', () {
      final res = filter.evaluate(
        id: 'v6',
        title: 'Bhabi ji ghar par hai majedaar zindagi pyaar comedy episode',
        channelId: 'ch6',
        channelName: 'FULL2MASTI comedy',
        shownLanguages: {'en', 'ta'},
        hiddenLanguages: {'hi'},
        strictHome: true,
      );
      expect(res.finalLanguage, 'hi');
      expect(res.kept, isFalse); // Hindi is hidden
    });

    test('Disambiguates Devanagari Hindi vs Marathi', () {
      final hindiText = 'आज का ताजा समाचार और खबरें देश विदेश की';
      final marathiText = 'पुणे मुंबई ताजा बातम्या आजचा नवीन व्हिडीओ कसा आहे';

      final hiRes = filter.evaluate(
        id: 'v7',
        title: hindiText,
        channelId: 'ch7',
        channelName: 'News Hindi',
        shownLanguages: {'hi'},
        hiddenLanguages: {},
        strictHome: true,
      );
      expect(hiRes.finalLanguage, 'hi');

      final mrRes = filter.evaluate(
        id: 'v8',
        title: marathiText,
        channelId: 'ch8',
        channelName: 'News Marathi',
        shownLanguages: {'mr'},
        hiddenLanguages: {},
        strictHome: true,
      );
      expect(mrRes.finalLanguage, 'mr');
    });
  });

  group('Seed Filtering', () {
    late ChannelLanguageCache cache;
    late ContentFilter filter;

    setUp(() {
      cache = ChannelLanguageCache(AppDb(NativeDatabase.memory()));
      filter = ContentFilter(channelCache: cache);
    });

    test('Only picks history seeds classified into shown languages', () {
      final history = [
        const HistoryEntry(
          'h1',
          Duration.zero,
          Duration.zero,
          channelName: 'Aditya Telugu Songs (తెలుగు పాటలు)',
        ),
        const HistoryEntry(
          'h2',
          Duration.zero,
          Duration.zero,
          channelName: 'Hindi Comedy (हिंदी कॉमेडी)',
        ),
        const HistoryEntry(
          'h3',
          Duration.zero,
          Duration.zero,
          channelName: 'BBC News English',
        ),
      ];

      final validSeeds = history.where((h) {
        final eval = filter.evaluate(
          id: h.videoId,
          title: '',
          channelId: '',
          channelName: h.channelName,
          shownLanguages: {'te'},
          hiddenLanguages: {'hi'},
          strictHome: true,
        );
        return eval.kept;
      }).toList();

      expect(validSeeds.length, 1);
      expect(validSeeds.first.videoId, 'h1');
    });
  });

  group('Cache Keys & Prefs', () {
    test(
      'Cache key includes hl, gl, sorted shown, sorted hidden, mix, strictHome',
      () {
        final s1 = const AppSettings(
          hl: 'en',
          gl: 'IN',
          contentLanguages: {'te', 'en'},
          hiddenLanguages: {'hi'},
          localRatio: 0.7,
          strictHome: true,
        );
        final s2 = const AppSettings(
          hl: 'en',
          gl: 'IN',
          contentLanguages: {'en', 'te'},
          hiddenLanguages: {'hi'},
          localRatio: 0.7,
          strictHome: true,
        );
        expect(s1.cacheKey, equals(s2.cacheKey));
        expect(s1.cacheKey, contains('en-te'));
        expect(s1.cacheKey, contains('hi'));
        expect(s1.cacheKey, contains('70'));
        expect(s1.cacheKey, contains('strict'));

        final s3 = s1.copyWith(strictHome: false);
        expect(s1.cacheKey, isNot(equals(s3.cacheKey)));
        expect(s3.cacheKey, contains('lenient'));
      },
    );
  });

  group('Probe Cap & Failure Handling', () {
    test('Channel cache registers not_in_shown after 2 probe failures', () {
      final cache = ChannelLanguageCache(AppDb(NativeDatabase.memory()));
      expect(cache.getClassifiedLanguage('failed_ch'), isNull);

      cache.recordProbeFailure('failed_ch');
      expect(cache.getClassifiedLanguage('failed_ch'), isNull);

      cache.recordProbeFailure('failed_ch');
      expect(cache.getClassifiedLanguage('failed_ch'), 'not_in_shown');

      final filter = ContentFilter(channelCache: cache);
      final res = filter.evaluate(
        id: 'v_failed',
        title: 'Ambiguous Latin Title',
        channelId: 'failed_ch',
        channelName: 'Failed Channel',
        shownLanguages: {'te'},
        hiddenLanguages: {},
      );
      expect(res.kept, isFalse);
      expect(res.finalLanguage, 'not_in_shown');
    });
  });

  group('Guard Test: Raw Unfiltered Feeds Never Reach Home', () {
    test('Strict Home does not fill its quota with unknown languages', () {
      final filter = ContentFilter(
        channelCache: ChannelLanguageCache(AppDb(NativeDatabase.memory())),
      );
      const unknown = VideoItem(id: 'unknown', title: 'Qzv blarn');

      expect(
        filter
            .filterVideos(
              [unknown],
              shownLanguages: {'ta', 'en'},
              hiddenLanguages: {'hi'},
              strictHome: true,
            )
            .items,
        isEmpty,
      );
      expect(
        filter
            .filterVideos(
              [unknown],
              shownLanguages: {'ta', 'en'},
              hiddenLanguages: {'hi'},
              strictHome: true,
              probeResults: const {'unknown': 'ta'},
            )
            .items,
        [unknown],
      );
    });

    test('FilterVideos removes all non-shown items strictly', () {
      final cache = ChannelLanguageCache(AppDb(NativeDatabase.memory()));
      final filter = ContentFilter(channelCache: cache);

      final mixed = [
        VideoItem(
          id: '1',
          title: 'తెలుగు సినిమా పాటలు',
          channelId: 'c1',
          channelName: 'Aditya Telugu',
        ),
        VideoItem(
          id: '2',
          title: 'हिंदी कॉमेडी शो',
          channelId: 'c2',
          channelName: 'Hindi TV',
        ),
        VideoItem(
          id: '3',
          title: 'ಕನ್ನಡ ಜನಪ್ರಿಯ ಗೀತೆಗಳು',
          channelId: 'c3',
          channelName: 'Anand Kannada',
        ),
        VideoItem(
          id: '4',
          title: 'English Technology News Review',
          channelId: 'c4',
          channelName: 'Tech Today',
        ),
      ];

      final filtered = filter.filterVideos(
        mixed,
        shownLanguages: {'te'},
        hiddenLanguages: {'hi'},
        strictHome: true,
      );

      expect(filtered.items.length, 1);
      expect(filtered.items.first.id, '1');
    });
  });
}
