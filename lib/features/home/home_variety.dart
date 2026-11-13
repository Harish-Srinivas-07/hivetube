import 'dart:convert';
import 'dart:math';

import '../../core/content/channel_language_cache.dart';
import '../../core/content/content_filter.dart';
import '../../core/content/language_profile.dart';
import '../../core/yt/models.dart';

const homeCategoryChips = <String>[
  'Music',
  'Movies',
  'Gaming',
  'Live',
  'News',
  'Podcasts',
  'Sports',
  'Comedy',
  'Cooking',
  'Science',
  'Tech',
  'Education',
];

const homeChips = <String>['All', ...homeCategoryChips];

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

String scriptLanguage(String text) {
  final detected = LanguageProfileRegistry.instance.detectScript(text);
  if (detected != null) return detected;

  // If no script, try lexicon classification
  final lex = LanguageProfileRegistry.instance.classify(text);
  return lex ?? 'en';
}

String _metadata(VideoItem item) =>
    '${item.title} ${item.channelName}'.toLowerCase();

bool hiddenLanguage(VideoItem item, Set<String> hidden) {
  final text = _metadata(item);
  final detected = scriptLanguage(text);
  if (hidden.contains(detected)) return true;

  for (final language in hidden) {
    if (LanguageProfileRegistry.instance.lexiconMatches(text, language)) {
      return true;
    }
  }
  return false;
}

bool isLocalLanguageQuery(String query, Set<String> shownLanguages) {
  final normalized = query.toLowerCase();
  for (final lang in shownLanguages) {
    if (lang == 'en') continue;
    final profile = LanguageProfileRegistry.instance.get(lang);
    if (profile == null) continue;
    if (normalized.contains(profile.nativeName.toLowerCase()) ||
        normalized.contains(profile.englishName.toLowerCase()) ||
        normalized.contains(profile.englishName.toLowerCase())) {
      return true;
    }
  }
  return false;
}

int? publishedAgeDays(VideoItem item, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (item.publishedAt != null) {
    return current.difference(item.publishedAt!).inDays.clamp(0, 36500);
  }
  final value = item.publishedText.toLowerCase();
  final match = RegExp(
    r'(\d+)\s*(minute|hour|day|week|month|year)',
  ).firstMatch(value);
  if (match == null) return null;
  final amount = int.tryParse(match.group(1) ?? '');
  if (amount == null) return null;
  final unit = match.group(2)!;
  if (unit == 'minute' || unit == 'hour') return 0;
  if (unit == 'day') return amount;
  if (unit == 'week') return amount * 7;
  if (unit == 'month') return amount * 30;
  return amount * 365;
}

List<VideoItem> mixByPublishedAge(
  List<VideoItem> items, {
  required Random random,
}) {
  final fresh = <VideoItem>[];
  final recent = <VideoItem>[];
  final evergreen = <VideoItem>[];
  for (final item in items) {
    final age = publishedAgeDays(item);
    if (age != null && age <= 7) {
      fresh.add(item);
    } else if (age != null && age <= 60) {
      recent.add(item);
    } else {
      evergreen.add(item);
    }
  }
  fresh.shuffle(random);
  recent.shuffle(random);
  evergreen.shuffle(random);
  final output = <VideoItem>[];
  final freshTarget = (items.length * .6).floor();
  final recentTarget = (items.length * .3).floor();
  final evergreenTarget = items.length - freshTarget - recentTarget;
  output.addAll(fresh.take(freshTarget));
  output.addAll(recent.take(recentTarget));
  output.addAll(evergreen.take(evergreenTarget));
  final used = output.map((e) => e.id).toSet();
  output.addAll(
    [...recent, ...evergreen, ...fresh].where((e) => !used.contains(e.id)),
  );
  return output;
}

List<VideoItem> trendingWithSeenFallback(
  Iterable<VideoItem> items,
  SeenVideos seen, {
  int limit = 5,
  int minimumUnseen = 3,
}) {
  final unique = <String, VideoItem>{};
  for (final item in items) {
    unique.putIfAbsent(item.id, () => item);
  }
  final candidates = unique.values.toList();
  final fresh = candidates
      .where((item) => !seen.entries.containsKey(item.id))
      .take(limit)
      .toList();
  if (fresh.length >= minimumUnseen || fresh.length >= limit) {
    return fresh;
  }
  final fallback =
      candidates.where((item) => seen.entries.containsKey(item.id)).toList()
        ..sort((a, b) => seen.entries[a.id]!.compareTo(seen.entries[b.id]!));
  final ids = fresh.map((item) => item.id).toSet();
  for (final item in fallback) {
    if (fresh.length >= limit) break;
    if (ids.add(item.id)) fresh.add(item);
  }
  return fresh;
}

List<VideoItem> rankHomeItems(
  Iterable<VideoItem> items, {
  required Set<String> preferred,
  required Set<String> hidden,
  required Set<String> seen,
  required Random random,
  bool strictHome = true,
  String source = 'home',
  Map<String, String?> probeResults = const {},
  ChannelLanguageCache? channelCache,
}) {
  final filter = ContentFilter(
    channelCache: channelCache ?? ChannelLanguageCache.instance,
    registry: LanguageProfileRegistry.instance,
  );
  return filter
      .filterVideos(
        items,
        shownLanguages: preferred,
        hiddenLanguages: hidden,
        strictHome: strictHome,
        seen: seen,
        random: random,
        source: source,
        probeResults: probeResults,
      )
      .items;
}

List<String> chooseHomeQueries({
  required String chip,
  required bool hasHistory,
  required double localRatio,
  required Set<String> shownLanguages,
  required Random random,
}) {
  return LanguageProfileRegistry.instance.buildQueries(
    shownLanguages: shownLanguages,
    chip: chip,
    localRatio: localRatio,
    random: random,
  );
}

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
        if (id is String &&
            time != null &&
            now.difference(time) < const Duration(days: 7)) {
          entries[id] = time;
        }
      }
      final recent = entries.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return SeenVideos(Map.fromEntries(recent.take(400)));
    } catch (_) {
      return SeenVideos({});
    }
  }

  void mark(Iterable<String> ids, DateTime now) {
    for (final id in ids) {
      entries[id] = now;
    }
    final recent = entries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    entries
      ..clear()
      ..addEntries(recent.take(400));
  }

  String encode() => jsonEncode([
    for (final e in entries.entries)
      {'id': e.key, 'at': e.value.toIso8601String()},
  ]);
}
