import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/content/channel_language_cache.dart';
import 'package:hivetube/core/content/content_filter.dart';
import 'package:hivetube/core/content/home_trace.dart';
import 'package:hivetube/core/content/language_profile.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/yt/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled English profile loads its referenced asset', () async {
    final registry = LanguageProfileRegistry.instance;
    await registry.ensureLoaded();
    expect(registry.hasLatinLexicon('en'), isTrue);
    expect(registry.identifyLatin('the and with')?.code, 'en');
  });

  test(
    'optional weighted assets classify, fall back, and can be removed',
    () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final registry = LanguageProfileRegistry.fromProfiles(const [
        LanguageProfile(
          code: 'aa',
          englishName: 'A',
          nativeName: 'A',
          scriptRanges: [],
          lexiconAsset: 'assets/lexicons/aa.json',
        ),
        LanguageProfile(
          code: 'bb',
          englishName: 'B',
          nativeName: 'B',
          scriptRanges: [],
          lexiconAsset: 'assets/lexicons/bb.json',
        ),
      ]);
      await registry.loadLexicons(
        loader: (path) async => path.endsWith('/aa.json')
            ? jsonEncode({
                'code': 'aa',
                'words': {'wexa': 1.2, 'zulki': 1.1},
              })
            : null,
      );
      final cache = ChannelLanguageCache(db);
      final filter = ContentFilter(channelCache: cache, registry: registry);
      ContentFilterResult classify(
        String title, {
        String channel = '',
        String? probe,
      }) => filter.evaluate(
        id: 'item',
        title: title,
        channelId: channel,
        channelName: '',
        shownLanguages: {'aa', 'bb'},
        hiddenLanguages: {},
        probeLanguage: probe,
      );
      final matched = classify('wexa zulki');
      expect(matched.kept, isTrue);
      expect(matched.finalLanguage, 'aa');
      expect(matched.detectionSource, 'langid');
      expect(registry.hasLatinLexicon('bb'), isFalse);
      cache.vote('channel-b', 'bb', weight: 2);
      expect(classify('qzx', channel: 'channel-b').detectionSource, 'channel');
      expect(classify('qzx', probe: 'bb').detectionSource, 'probe');
      expect(classify('qzx').kept, isFalse);

      HomeTraceStore.instance.clear();
      for (var i = 0; i < 2; i++) {
        filter.filterVideos(
          const [VideoItem(id: 'item', title: 'qzx')],
          shownLanguages: {'aa', 'bb'},
          hiddenLanguages: {},
        );
      }
      expect(HomeTraceStore.instance.warnings, isEmpty);
      expect(
        HomeTraceStore.instance.dumpLog(),
        isNot(contains('WARNING: no latin lexicon for bb')),
      );

      await registry.loadLexicons(loader: (_) async => null);
      expect(classify('wexa zulki').kept, isFalse);
      await registry.loadLexicons(loader: (_) async => '{invalid');
      expect(registry.hasLatinLexicon('aa'), isFalse);
    },
  );
}
