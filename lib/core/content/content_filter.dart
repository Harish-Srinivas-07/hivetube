import 'dart:math';
import '../yt/models.dart';
import 'channel_language_cache.dart';
import 'home_trace.dart';
import 'language_profile.dart';

enum ContentSurface { strict, library }

class FilteredFeed<T> {
  const FilteredFeed(this.items);
  final List<T> items;
}

class ContentFilterResult {
  const ContentFilterResult({
    required this.finalLanguage,
    required this.kept,
    required this.reason,
    this.scriptVerdict,
    this.lexiconVerdict,
    this.channelVoteVerdict,
    this.probeVerdict,
    this.matchedWords = const [],
    this.isAmbiguous = false,
    this.detectionSource = 'unknown',
    this.confidence = 0,
  });

  final String finalLanguage;
  final bool kept;
  final String reason;
  final String? scriptVerdict;
  final String? lexiconVerdict;
  final String? channelVoteVerdict;
  final String? probeVerdict;
  final List<String> matchedWords;
  final bool isAmbiguous;
  final String detectionSource;
  final double confidence;
}

class ContentFilter {
  ContentFilter({required this.channelCache, LanguageProfileRegistry? registry})
    : registry = registry ?? LanguageProfileRegistry.instance;

  final ChannelLanguageCache channelCache;
  final LanguageProfileRegistry registry;
  final Set<String> _votedVideos = {};

  ContentFilterResult evaluate({
    required String id,
    required String title,
    required String channelId,
    required String channelName,
    required Set<String> shownLanguages,
    required Set<String> hiddenLanguages,
    bool strictHome = true,
    ContentSurface surface = ContentSurface.strict,
    String? probeLanguage,
    bool isSubscribed = false,
  }) {
    final text = '$title $channelName';
    final script = registry.detectScript(text);
    final channel = channelCache.getClassifiedLanguage(channelId);
    String? lexicon;
    var bestScore = 0;
    var tied = false;
    for (final profile in registry.profiles.values) {
      final evidence = registry.lexiconEvidence(text, profile.code);
      final romanizedWords = evidence.words
          .where((word) => !registry.isLanguageIdWord(profile.code, word))
          .toSet();
      if (romanizedWords.length < 2 ||
          !registry.lexiconMatches(text, profile.code)) {
        continue;
      }
      final score = evidence.strong * 2 + evidence.weak;
      if (score > bestScore) {
        bestScore = score;
        lexicon = profile.code;
        tied = false;
      } else if (score == bestScore) {
        tied = true;
      }
    }
    if (tied) lexicon = null;
    final languageId = registry.identifyLatin(text);
    final probe = probeLanguage?.toLowerCase().split(RegExp('[-_]')).first;
    var language = 'unknown';
    var source = 'unknown';
    var confidence = 0.0;
    if (script != null) {
      language = script;
      source = 'script';
      confidence = 1;
    } else if (channel != null && registry.profiles.containsKey(channel)) {
      language = channel;
      source = 'channel';
      confidence = 0.8;
    } else if (lexicon != null) {
      language = lexicon;
      source = 'lex';
      confidence = 0.8;
    } else if (languageId != null && languageId.confidence >= 0.65) {
      language = languageId.code;
      source = 'langid';
      confidence = languageId.confidence;
    } else if (probe != null && registry.profiles.containsKey(probe)) {
      language = probe;
      source = 'probe';
      confidence = 0.9;
    }

    final isHidden = hiddenLanguages.contains(language);
    final isShown = shownLanguages.contains(language);
    final isChannelMatch = channel != null && shownLanguages.contains(channel);

    bool kept;
    String reason;

    if (isHidden) {
      kept = false;
      reason = 'hidden_language ($language)';
    } else if (language == 'unknown') {
      if (isChannelMatch) {
        kept = true;
        reason = 'kept_unknown (channel match: $channel)';
      } else if (isSubscribed) {
        kept = true;
        reason = 'kept_unknown (subscribed channel)';
      } else {
        kept = false;
        reason = 'dropped_unknown (no channel match)';
      }
    } else if (language == 'en' && !shownLanguages.contains('en')) {
      if (isChannelMatch) {
        kept = true;
        reason = 'kept_english (channel match: $channel)';
      } else {
        kept = false;
        reason = 'dropped_english_leak (en not in selected)';
      }
    } else if (isShown) {
      kept = true;
      reason = 'shown_match ($language)';
    } else if (surface == ContentSurface.library) {
      kept = true;
      reason = 'library_allowed ($language)';
    } else if (!strictHome) {
      kept = true;
      reason = 'non_strict_allowed ($language)';
    } else {
      final selected = shownLanguages.toList()..sort();
      kept = false;
      reason =
          'not_in_shown_languages ($language; selected=${selected.join(',')})';
    }

    return ContentFilterResult(
      finalLanguage: language,
      kept: kept,
      reason: reason,
      scriptVerdict: script,
      lexiconVerdict: lexicon == null ? null : '$lexicon (score=$bestScore)',
      channelVoteVerdict: channel,
      probeVerdict: probeLanguage,
      matchedWords: lexicon == null
          ? const []
          : registry.getMatchedLexiconWords(text, lexicon),
      isAmbiguous: source == 'unknown',
      detectionSource: source,
      confidence: confidence,
    );
  }

  bool isAmbiguous({
    required String title,
    required String channelId,
    required String channelName,
  }) =>
      evaluate(
        id: '',
        title: title,
        channelId: channelId,
        channelName: channelName,
        shownLanguages: const {},
        hiddenLanguages: const {},
      ).finalLanguage ==
      'unknown';

  /// Filters a list of VideoItems according to the surface policy.
  FilteredFeed<VideoItem> filterVideos(
    Iterable<VideoItem> items, {
    required Set<String> shownLanguages,
    required Set<String> hiddenLanguages,
    bool strictHome = true,
    ContentSurface surface = ContentSurface.strict,
    String source = 'home',
    Set<String> seen = const {},
    Map<String, String?> probeResults = const {},
    Random? random,
    bool recordTrace = true,
    Set<String>? subscribedChannelIds,
  }) {
    final rng = random ?? Random();
    final ranked =
        <
          ({
            VideoItem item,
            bool seen,
            DateTime? publishedAt,
            int tie,
            int order,
          })
        >[];
    var order = 0;
    var keptCount = 0;
    var unknownKeptCount = 0;

    final processedIds = <String>{};
    for (final item in items) {
      if (!processedIds.add(item.id)) continue;
      final probe = probeResults[item.id];
      final isSubscribed =
          subscribedChannelIds != null &&
          subscribedChannelIds.contains(item.channelId);
      final res = evaluate(
        id: item.id,
        title: item.title,
        channelId: item.channelId,
        channelName: item.channelName,
        shownLanguages: shownLanguages,
        hiddenLanguages: hiddenLanguages,
        strictHome: strictHome,
        surface: surface,
        probeLanguage: probe,
        isSubscribed: isSubscribed,
      );

      var effectiveKept = res.kept;
      var effectiveReason = res.reason;

      // Cap unknown items to <= 15% of the kept feed
      if (effectiveKept && res.finalLanguage == 'unknown') {
        if (keptCount >= 4 &&
            (unknownKeptCount + 1) / (keptCount + 1) > 0.15) {
          effectiveKept = false;
          effectiveReason = 'dropped_unknown_cap_exceeded (>15%)';
        }
      }

      if (item.channelId.isNotEmpty &&
          res.confidence >= 0.8 &&
          (res.detectionSource == 'script' ||
              res.detectionSource == 'lex' ||
              res.detectionSource == 'langid') &&
          _votedVideos.add('${item.channelId}:${item.id}')) {
        channelCache.vote(item.channelId, res.finalLanguage, weight: 1);
      }

      if (recordTrace) {
        HomeTraceStore.instance.record(
          HomeTraceItem(
            id: item.id,
            title: item.title,
            channelName: item.channelName,
            source: source,
            scriptVerdict: res.scriptVerdict,
            lexiconVerdict: res.lexiconVerdict,
            channelVoteVerdict: res.channelVoteVerdict,
            probeVerdict: res.probeVerdict,
            finalLanguage: res.finalLanguage,
            kept: effectiveKept,
            reason: effectiveReason,
            matchedWords: res.matchedWords,
            isAmbiguous: res.isAmbiguous,
            detectionSource: res.detectionSource,
            confidence: res.confidence,
          ),
        );
      }

      if (effectiveKept) {
        keptCount++;
        if (res.finalLanguage == 'unknown') unknownKeptCount++;
        ranked.add((
          item: item,
          seen: seen.contains(item.id),
          publishedAt: item.publishedAt,
          tie: rng.nextInt(1 << 31),
          order: order++,
        ));
      }
    }

    ranked.sort((a, b) {
      if (a.seen != b.seen) return a.seen ? 1 : -1;
      final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final freshness = bDate.compareTo(aDate);
      if (freshness != 0) return freshness;
      final tie = a.tie.compareTo(b.tie);
      return tie != 0 ? tie : a.order.compareTo(b.order);
    });

    return FilteredFeed(ranked.map((e) => e.item).toList());
  }

  /// Filters a list of ShortItems.
  FilteredFeed<ShortItem> filterShorts(
    Iterable<ShortItem> items, {
    required Set<String> shownLanguages,
    required Set<String> hiddenLanguages,
    bool strictHome = true,
    String source = 'shorts',
    Set<String> seen = const {},
    Random? random,
  }) {
    final videoItems = [
      for (final s in items)
        VideoItem(
          id: s.id,
          title: s.title ?? '',
          channelId: s.channelId ?? '',
          channelName: s.channelName ?? '',
          channelAvatarUrl: s.channelAvatarUrl ?? '',
          thumbUrl: s.thumbUrl,
          isShort: true,
        ),
    ];

    final filtered = filterVideos(
      videoItems,
      shownLanguages: shownLanguages,
      hiddenLanguages: hiddenLanguages,
      strictHome: strictHome,
      surface: ContentSurface.strict,
      source: source,
      seen: seen,
      random: random,
    );

    final byId = {for (final s in items) s.id: s};
    final result = [
      for (final v in filtered.items)
        if (byId.containsKey(v.id)) byId[v.id]!,
    ];

    return FilteredFeed(result);
  }
}
