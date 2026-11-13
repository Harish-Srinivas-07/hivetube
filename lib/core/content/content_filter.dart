import 'dart:math';
import '../yt/models.dart';
import 'channel_language_cache.dart';
import 'home_trace.dart';
import 'language_profile.dart';

enum ContentSurface {
  strict,
  library,
}

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
    this.score = 0,
    this.matchedWords = const [],
    this.isAmbiguous = false,
  });

  final String finalLanguage;
  final bool kept;
  final String reason;
  final String? scriptVerdict;
  final String? lexiconVerdict;
  final String? channelVoteVerdict;
  final String? probeVerdict;
  final int score;
  final List<String> matchedWords;
  final bool isAmbiguous;
}

class ContentFilter {
  ContentFilter({
    required this.channelCache,
    LanguageProfileRegistry? registry,
  }) : registry = registry ?? LanguageProfileRegistry.instance;

  final ChannelLanguageCache channelCache;
  final LanguageProfileRegistry registry;

  bool _looksHindiChannelName(String channelName) {
    if (registry.detectScript(channelName) == 'hi') return true;
    const markers = {
      'hindi', 'hindustani', 'hindustan', 'bollywood', 'bhojpuri', 'haryanvi',
      'desi', 'हिंदी', 'हिन्दी', 'भोजपुरी', 'हरियाणवी',
    };
    final tokens = channelName.toLowerCase().split(RegExp(r'[^a-z0-9\u0900-\u097f]+'));
    return tokens.any(markers.contains);
  }

  bool _isHindiDevotional(String text) {
    final terms = registry.get('hi')?.devotionalBlocklist ?? const <String>[];
    final lower = text.toLowerCase();
    return terms.any((term) {
      final escaped = RegExp.escape(term).replaceAll(r'\ ', r'\s+');
      return RegExp(
        '(?:^|[^a-z0-9\\u0900-\\u097f])$escaped(?:\$|[^a-z0-9\\u0900-\\u097f])',
      ).hasMatch(lower);
    });
  }

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
    bool filterHindiDevotional = false,
  }) {
    final text = '$title $channelName';
    final lower = text.toLowerCase();

    // 1. Script detection (Unicode ground truth)
    final scriptLang = registry.detectScript(text);

    // 2. Channel votes
    final channelLang = channelCache.getClassifiedLanguage(channelId, channelName: channelName);

    // 3. Lexicon scoring
    String? lexiconLang;
    int maxLexiconScore = 0;
    for (final profile in registry.profiles.values) {
      if (profile.code == 'en') continue;
      final evidence = registry.lexiconEvidence(text, profile.code);
      final matches = registry.lexiconMatches(text, profile.code) ||
          (profile.code == 'hi' &&
              registry.lexiconEvidence(text, 'hi').strong >= 1 &&
              _looksHindiChannelName(channelName));
      final s = matches
          ? evidence.strong * 2 + evidence.weak
          : 0;
      if (s > maxLexiconScore) {
        maxLexiconScore = s;
        lexiconLang = profile.code;
      }
    }
    if (maxLexiconScore < 2) {
      lexiconLang = null;
    }

    // 4. Resolve final language
    // ASR is ground truth for spoken language; script and then learned signals follow.
    String finalLang = 'en';
    final normalizedProbe = probeLanguage?.toLowerCase().split('-').first;
    if (normalizedProbe != null && registry.profiles.containsKey(normalizedProbe)) {
      finalLang = normalizedProbe;
    } else if (channelLang == 'not_in_shown') {
      finalLang = 'not_in_shown';
    } else if (scriptLang != null) {
      finalLang = scriptLang;
    } else if (channelLang != null) {
      finalLang = channelLang;
    } else if (lexiconLang != null) {
      finalLang = lexiconLang;
    } else {
      // Check if text matches 'other' language markers
      final otherProfile = registry.get('other');
      if (otherProfile != null && otherProfile.boostTerms.any(lower.contains)) {
        finalLang = 'other';
      }
    }

    // 5. Allow-list Decision
    final isHidden = hiddenLanguages.contains(finalLang);
    final isShown = shownLanguages.contains(finalLang);

    bool kept = false;
    String reason = '';

    if (filterHindiDevotional &&
        hiddenLanguages.contains('hi') &&
        _isHindiDevotional(text)) {
      kept = false;
      reason = 'devotional_blocklist (hi hidden)';
    } else if (isHidden) {
      kept = false;
      reason = 'hidden_language ($finalLang)';
    } else if (surface == ContentSurface.library || !strictHome) {
      // Hidden-only policy
      kept = true;
      reason = isShown ? 'shown_match ($finalLang)' : 'library_allowed ($finalLang)';
    } else {
      // Strict Home allow-list policy:
      // KEEP ONLY items classified into a shown language.
      if (isShown) {
        kept = true;
        reason = 'shown_match ($finalLang)';
      } else if (finalLang == 'en' && shownLanguages.contains('en')) {
        kept = true;
        reason = 'english_shown_match';
      } else {
        kept = false;
        reason = 'not_in_shown_languages ($finalLang)';
      }
    }

    // Compute ranking score
    int score = 0;
    if (isShown) {
      score += 5;
      if (finalLang != 'en') score += 3;
    }
    if (maxLexiconScore > 0) score += min(maxLexiconScore, 5);

    final isAmbiguous = scriptLang == null && channelLang == null && maxLexiconScore < 2;
    final matchedWords = lexiconLang != null
        ? registry.getMatchedLexiconWords(text, lexiconLang)
        : const <String>[];

    return ContentFilterResult(
      finalLanguage: finalLang,
      kept: kept,
      reason: reason,
      scriptVerdict: scriptLang,
      lexiconVerdict: lexiconLang != null ? '$lexiconLang (score=$maxLexiconScore)' : null,
      channelVoteVerdict: channelLang,
      probeVerdict: probeLanguage,
      score: score,
      matchedWords: matchedWords,
      isAmbiguous: isAmbiguous,
    );
  }

  /// Checks if an item's language is ambiguous (Latin metadata, no channel classification, < 2 lexicon hits).
  bool isAmbiguous({
    required String title,
    required String channelId,
    required String channelName,
  }) {
    final text = '$title $channelName';
    if (registry.detectScript(text) != null) return false;
    if (channelCache.getClassifiedLanguage(channelId, channelName: channelName) != null) return false;
    for (final profile in registry.profiles.values) {
      if (profile.code == 'en') continue;
      if (registry.lexiconMatches(text, profile.code)) return false;
    }
    return true;
  }

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
    bool filterHindiDevotional = false,
  }) {
    final rng = random ?? Random();
    final ranked = <({VideoItem item, int score, bool seen, int tie, int order})>[];
    var order = 0;

    for (final item in items) {
      final probe = probeResults[item.id];
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
        filterHindiDevotional: filterHindiDevotional,
      );

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
          kept: res.kept,
          reason: res.reason,
          matchedWords: res.matchedWords,
          isAmbiguous: res.isAmbiguous,
        ),
      );

      if (!res.kept) continue;

      ranked.add((
        item: item,
        score: res.score,
        seen: seen.contains(item.id),
        tie: rng.nextInt(1 << 31),
        order: order++,
      ));
    }

    ranked.sort((a, b) {
      if (a.seen != b.seen) return a.seen ? 1 : -1;
      final scoreDiff = b.score.compareTo(a.score);
      if (scoreDiff != 0) return scoreDiff;
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

