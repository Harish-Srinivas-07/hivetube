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
}

class ContentFilter {
  ContentFilter({required this.channelCache, LanguageProfileRegistry? registry})
    : registry = registry ?? LanguageProfileRegistry.instance;

  final ChannelLanguageCache channelCache;
  final LanguageProfileRegistry registry;

  bool _looksHindiChannelName(String channelName) {
    if (registry.detectScript(channelName) == 'hi') return true;
    const markers = {
      'hindi',
      'hindustani',
      'hindustan',
      'bollywood',
      'bhojpuri',
      'haryanvi',
      'desi',
      'हिंदी',
      'हिन्दी',
      'भोजपुरी',
      'हरियाणवी',
    };
    final tokens = channelName.toLowerCase().split(
      RegExp(r'[^a-z0-9\u0900-\u097f]+'),
    );
    return tokens.any(markers.contains);
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
  }) {
    final text = '$title $channelName';

    // 1. Script detection (Unicode ground truth)
    final scriptLang = registry.detectScript(text);

    // 2. Channel votes
    final channelLang = channelCache.getClassifiedLanguage(
      channelId,
      channelName: channelName,
    );

    // 3. Lexicon scoring
    String? lexiconLang;
    int maxLexiconScore = 0;
    for (final profile in registry.profiles.values) {
      if (profile.code == 'en') continue;
      final evidence = registry.lexiconEvidence(text, profile.code);
      final matches =
          registry.lexiconMatches(text, profile.code) ||
          (profile.code == 'hi' &&
              registry.lexiconEvidence(text, 'hi').strong >= 1 &&
              _looksHindiChannelName(channelName));
      final s = matches ? evidence.strong * 2 + evidence.weak : 0;
      if (s > maxLexiconScore) {
        maxLexiconScore = s;
        lexiconLang = profile.code;
      }
    }
    if (maxLexiconScore < 2) {
      lexiconLang = null;
    }

    // Script, lexicon, channel vote, then caption probe.
    String finalLang = 'unknown';
    final normalizedProbe = probeLanguage?.toLowerCase().split('-').first;
    if (scriptLang != null) {
      finalLang = scriptLang;
    } else if (lexiconLang != null) {
      finalLang = lexiconLang;
    } else if (registry.englishWordRatio(text) >= 0.2) {
      finalLang = 'en';
    } else if (channelLang != null) {
      finalLang = channelLang;
    } else if (normalizedProbe != null &&
        registry.profiles.containsKey(normalizedProbe)) {
      finalLang = normalizedProbe;
    }

    // 5. Allow-list Decision
    final isHidden = hiddenLanguages.contains(finalLang);
    final isShown = shownLanguages.contains(finalLang);

    bool kept = false;
    String reason = '';

    if (isHidden) {
      kept = false;
      reason = 'hidden_language ($finalLang)';
    } else if (surface == ContentSurface.library || !strictHome) {
      // Hidden-only policy
      kept = true;
      reason = isShown
          ? 'shown_match ($finalLang)'
          : 'library_allowed ($finalLang)';
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

    final isAmbiguous =
        scriptLang == null && channelLang == null && maxLexiconScore < 2;
    final matchedWords = lexiconLang != null
        ? registry.getMatchedLexiconWords(text, lexiconLang)
        : const <String>[];

    return ContentFilterResult(
      finalLanguage: finalLang,
      kept: kept,
      reason: reason,
      scriptVerdict: scriptLang,
      lexiconVerdict: lexiconLang != null
          ? '$lexiconLang (score=$maxLexiconScore)'
          : null,
      channelVoteVerdict: channelLang,
      probeVerdict: probeLanguage,
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
    if (registry.englishWordRatio(text) >= 0.2) return false;
    if (channelCache.getClassifiedLanguage(
          channelId,
          channelName: channelName,
        ) !=
        null) {
      return false;
    }
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
    final unknowns =
        <
          ({
            VideoItem item,
            double score,
            bool seen,
            DateTime? publishedAt,
            int tie,
            int order,
          })
        >[];
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

      if (res.kept) {
        ranked.add((
          item: item,
          seen: seen.contains(item.id),
          publishedAt: item.publishedAt,
          tie: rng.nextInt(1 << 31),
          order: order++,
        ));
      } else if (!hiddenLanguages.contains(res.finalLanguage) &&
          (res.finalLanguage == 'unknown' || res.reason.contains('unknown'))) {
        final text = '${item.title} ${item.channelName}';
        var score = 0.0;
        if (shownLanguages.contains('en')) {
          score += registry.englishWordRatio(text);
        }
        for (final lang in shownLanguages) {
          if (lang == 'en') continue;
          score += registry.scoreLexicon(text, lang) * 0.1;
          final profile = registry.get(lang);
          if (profile != null) {
            final lower = item.channelName.toLowerCase();
            if (lower.contains(profile.englishName.toLowerCase()) ||
                lower.contains(profile.nativeName.toLowerCase())) {
              score += 0.5;
            }
          }
        }
        unknowns.add((
          item: item,
          score: score,
          seen: seen.contains(item.id),
          publishedAt: item.publishedAt,
          tie: rng.nextInt(1 << 31),
          order: order++,
        ));
      }
    }

    const minKept = 20;
    if (strictHome && ranked.length < minKept && unknowns.isNotEmpty) {
      unknowns.sort((a, b) {
        if (a.seen != b.seen) return a.seen ? 1 : -1;
        final scoreCmp = b.score.compareTo(a.score);
        if (scoreCmp != 0) return scoreCmp;
        final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateCmp = bDate.compareTo(aDate);
        if (dateCmp != 0) return dateCmp;
        final tieCmp = a.tie.compareTo(b.tie);
        return tieCmp != 0 ? tieCmp : a.order.compareTo(b.order);
      });

      final candidates = ranked.isEmpty
          ? unknowns
          : unknowns.where((u) => u.score > 0).toList();
      final needed = minKept - ranked.length;
      for (final u in candidates.take(needed)) {
        HomeTraceStore.instance.record(
          HomeTraceItem(
            id: u.item.id,
            title: u.item.title,
            channelName: u.item.channelName,
            source: source,
            scriptVerdict: null,
            lexiconVerdict: null,
            channelVoteVerdict: null,
            probeVerdict: null,
            finalLanguage: 'unknown',
            kept: true,
            reason: 'fallback_unknown (score=${u.score.toStringAsFixed(2)})',
            matchedWords: const [],
            isAmbiguous: true,
          ),
        );
        ranked.add((
          item: u.item,
          seen: u.seen,
          publishedAt: u.publishedAt,
          tie: u.tie,
          order: u.order,
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
