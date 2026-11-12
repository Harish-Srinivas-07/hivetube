import 'dart:convert';
import 'dart:math';

import '../../core/yt/models.dart';

const contentLanguageOptions = <String, String>{
  'en': 'English',
  'ta': 'Tamil',
  'hi': 'Hindi',
  'te': 'Telugu',
  'ml': 'Malayalam',
  'kn': 'Kannada',
  'bn': 'Bengali',
  'mr': 'Marathi',
  'gu': 'Gujarati',
  'pa': 'Punjabi',
  'ur': 'Urdu',
  'or': 'Odia',
  'other': 'Other',
};

const contentLanguageNativeNames = <String, String>{
  'ta': 'தமிழ்',
  'en': 'English',
  'hi': 'हिन्दी',
  'te': 'తెలుగు',
  'ml': 'മലയാളം',
  'kn': 'ಕನ್ನಡ',
  'bn': 'বাংলা',
  'mr': 'मराठी',
  'gu': 'ગુજરાતી',
  'pa': 'ਪੰਜਾਬੀ',
  'ur': 'اردو',
  'or': 'ଓଡ଼ିଆ',
  'other': 'Other',
};

const languageTerms = <String, List<String>>{
  'ta': ['tamil', 'kollywood', 'tamil nadu', 'chennai', 'madras', 'த\u0bcd'],
  'en': ['english'],
  'hi': ['hindi', 'bollywood', 'हिन्दी', 'हिंदी'],
  'te': ['telugu', 'tollywood'],
  'ml': ['malayalam', 'mollywood'],
  'kn': ['kannada', 'sandalwood'],
  'bn': ['bengali', 'bangla'],
  'mr': ['marathi'],
  'gu': ['gujarati'],
  'pa': ['punjabi', 'ਪੰਜਾਬੀ'],
  'ur': ['urdu'],
  'or': ['odia', 'oriya'],
  'other': [
    'spanish',
    'español',
    'french',
    'français',
    'german',
    'deutsch',
    'portuguese',
    'italian',
  ],
};

const tamilTerms = [
  'tamil',
  'kollywood',
  'tamil nadu',
  'tamilnadu',
  'chennai',
  'madras',
  'coimbatore',
  'madurai',
  'trichy',
  'salem',
  'tirunelveli',
  'மதுரை',
  'சென்னை',
  'தமிழ்',
  'கோயம்புத்தூர்',
];

String scriptLanguage(String text) {
  final counts = <String, int>{};
  for (final rune in text.runes) {
    final language = switch (rune) {
      >= 0x0B80 && <= 0x0BFF => 'ta',
      >= 0x0900 && <= 0x097F => 'hi',
      >= 0x0980 && <= 0x09FF => 'bn',
      >= 0x0A00 && <= 0x0A7F => 'pa',
      >= 0x0A80 && <= 0x0AFF => 'gu',
      >= 0x0B00 && <= 0x0B7F => 'or',
      >= 0x0C00 && <= 0x0C7F => 'te',
      >= 0x0D00 && <= 0x0D7F => 'ml',
      >= 0x0C80 && <= 0x0CFF => 'kn',
      >= 0x0600 && <= 0x06FF => 'ur',
      _ => null,
    };
    if (language != null) {
      counts.update(language, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  if (counts.isEmpty) return 'en';
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

String _metadata(VideoItem item) =>
    '${item.title} ${item.channelName}'.toLowerCase();

bool hiddenLanguage(VideoItem item, Set<String> hidden) {
  final text = _metadata(item);
  if (hidden.contains(scriptLanguage(text))) return true;
  for (final language in hidden) {
    for (final term in languageTerms[language] ?? const <String>[]) {
      if (text.contains(term.toLowerCase())) return true;
    }
  }
  return false;
}

int homeLanguageScore(VideoItem item, Set<String> preferred) {
  final text = _metadata(item);
  final script = scriptLanguage(text);
  // Latin is neutral: it covers English and unknown-language metadata.
  var score = script != 'en' && preferred.contains(script) ? 3 : 0;
  if (preferred.contains('other') &&
      (languageTerms['other'] ?? const []).any(text.contains)) {
    score += 3;
  }
  if (tamilTerms.any(text.contains)) score += 2;
  return score;
}

bool isLocalLanguageQuery(String query, Set<String> shownLanguages) {
  final normalized = query.toLowerCase();
  return shownLanguages
      .where((language) => language != 'en')
      .any(
        (language) => (languageTerms[language] ?? const <String>[]).any(
          normalized.contains,
        ),
      );
}

List<VideoItem> rankHomeItems(
  Iterable<VideoItem> items, {
  required Set<String> preferred,
  required Set<String> hidden,
  required Set<String> seen,
  required Random random,
}) {
  final ranked =
      <({VideoItem item, int score, bool seen, int tie, int order})>[];
  var order = 0;
  for (final item in items) {
    if (hiddenLanguage(item, hidden)) continue;
    ranked.add((
      item: item,
      score: homeLanguageScore(item, preferred),
      seen: seen.contains(item.id),
      tie: random.nextInt(1 << 31),
      order: order++,
    ));
  }
  ranked.sort((a, b) {
    if (a.seen != b.seen) return a.seen ? 1 : -1;
    final score = b.score.compareTo(a.score);
    if (score != 0) return score;
    final tie = a.tie.compareTo(b.tie);
    return tie != 0 ? tie : a.order.compareTo(b.order);
  });
  return ranked.map((entry) => entry.item).toList();
}

const tamilQueryPools = <String, List<String>>{
  'Music': [
    'tamil songs',
    'tamil new songs',
    'tamil melody',
    'tamil hits',
    'tamil bgm',
  ],
  'Movies': [
    'tamil movie trailer',
    'kollywood',
    'tamil cinema news',
    'tamil movie scenes',
  ],
  'Comedy': ['tamil comedy', 'tamil memes', 'tamil stand up'],
  'News': ['tamil news live', 'tamil nadu news today', 'chennai news'],
  'Cooking': ['tamil samayal', 'tamil nadu recipes', 'chennai street food'],
  'Gaming': ['tamil gaming', 'tamil gamer live'],
  'Tech': ['tamil tech review', 'tamil mobile review'],
  'Sports': ['ipl highlights', 'csk', 'tamil cricket commentary'],
  'Science': ['tamil science', 'tamil education'],
  'Education': ['tamil science', 'tamil education'],
  'Live': ['tamil live stream', 'tamil nadu live'],
  'Podcasts': ['tamil podcast', 'tamil interviews'],
};

const englishQueryPools = <String, List<String>>{
  'Music': ['music', 'new music', 'live music'],
  'Movies': ['movie trailer', 'cinema news'],
  'Comedy': ['stand up comedy', 'comedy clips'],
  'News': ['world news live', 'technology news'],
  'Cooking': ['easy recipes', 'street food'],
  'Gaming': ['gaming', 'gaming live'],
  'Tech': ['tech review', 'mobile review'],
  'Sports': ['sports highlights', 'cricket highlights'],
  'Science': ['science', 'science education'],
  'Education': ['science education', 'learning'],
  'Live': ['live stream'],
  'Podcasts': ['podcast interviews'],
};

const _localQueryWords = <String, String>{
  'ta': 'tamil',
  'hi': 'hindi',
  'te': 'telugu',
  'ml': 'malayalam',
  'kn': 'kannada',
  'bn': 'bengali',
  'mr': 'marathi',
  'gu': 'gujarati',
  'pa': 'punjabi',
  'ur': 'urdu',
  'or': 'odia',
};

const _otherQueryPools = <String, List<String>>{
  'Music': ['spanish songs', 'french music'],
  'Movies': ['spanish movie trailer', 'french cinema'],
  'Comedy': ['spanish comedy', 'french stand up'],
  'News': ['spanish news live', 'french news'],
  'Cooking': ['spanish recipes', 'french cooking'],
  'Gaming': ['spanish gaming', 'french gaming'],
  'Tech': ['spanish tech review', 'french tech review'],
  'Sports': ['spanish sports highlights', 'french sports'],
  'Science': ['spanish science', 'french science'],
  'Education': ['spanish education', 'french education'],
  'Live': ['spanish live stream', 'french live stream'],
  'Podcasts': ['spanish podcast', 'french podcast'],
};

List<String> _languageQueryPool(String language, String topic) {
  if (language == 'ta') return tamilQueryPools[topic] ?? ['tamil $topic'];
  if (language == 'en') {
    return englishQueryPools[topic] ?? [topic.toLowerCase()];
  }
  if (language == 'other') return _otherQueryPools[topic] ?? ['spanish $topic'];
  final word = _localQueryWords[language] ?? 'english';
  return ['$word ${topic.toLowerCase()}', '$word ${topic.toLowerCase()} live'];
}

List<String> chooseHomeQueries({
  required String chip,
  required bool hasHistory,
  required double localRatio,
  required Set<String> shownLanguages,
  required Random random,
}) {
  final topicChip = englishQueryPools.containsKey(chip) ? chip : 'All';
  final topics = topicChip == 'All'
      ? englishQueryPools.keys.toList()
      : [topicChip];
  if (topics.isEmpty) return const [];
  topics.shuffle(random);
  final count = topicChip == 'All'
      ? (hasHistory ? (random.nextBool() ? 1 : 2) : 4)
      : 1;
  final selected = topics.take(count).toList();
  final localLanguages = shownLanguages
      .where((language) => language != 'en')
      .toList();
  final queries = <String>[
    for (final topic in selected)
      _randomVariant(
        localLanguages.isNotEmpty && random.nextDouble() < localRatio
            ? _languageQueryPool(
                localLanguages[random.nextInt(localLanguages.length)],
                topic,
              )
            : _languageQueryPool('en', topic),
        random,
      ),
  ]..shuffle(random);
  return queries;
}

String _randomVariant(List<String> variants, Random random) =>
    variants[random.nextInt(variants.length)];

class SeenVideos {
  SeenVideos(this.entries);
  final Map<String, DateTime> entries;
  Set<String> get ids => entries.keys.toSet();

  static SeenVideos decode(String? raw, DateTime now) {
    try {
      final decoded = jsonDecode(raw ?? '[]');
      if (decoded is! List) return SeenVideos({});
      final entries = <String, DateTime>{};
      for (final item in decoded.whereType<Map>()) {
        final id = item['id'];
        final time = DateTime.tryParse(item['at'] as String? ?? '');
        if (id is String && time != null && now.difference(time).inDays < 7) {
          entries[id] = time;
        }
      }
      return SeenVideos(entries);
    } catch (_) {
      return SeenVideos({});
    }
  }

  void mark(Iterable<String> ids, DateTime now) {
    for (final id in ids) {
      if (id.isNotEmpty) entries.remove(id);
      if (id.isNotEmpty) entries[id] = now;
    }
    final oldest = entries.keys.length > 400 ? entries.length - 400 : 0;
    for (final id in entries.keys.take(oldest).toList()) {
      entries.remove(id);
    }
  }

  String encode() => jsonEncode([
    for (final entry in entries.entries)
      {'id': entry.key, 'at': entry.value.toIso8601String()},
  ]);
}
