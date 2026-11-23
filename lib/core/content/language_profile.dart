import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';
import 'asset_loader_vm.dart' if (dart.library.ui) 'asset_loader_flutter.dart';

// ignore: constant_identifier_names
const int CLASSIFIER_VERSION = 3;

class LanguageProfile {
  const LanguageProfile({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.scriptRanges,
    this.topicQueries = const {},
    this.topicNames = const [],
    this.topicTemplates = const {},
    this.freshnessWords = const [],
    this.seasonalTerms = const [],
    this.slotValues = const {},
    this.lexicon = const {},
    this.lexiconStrong = const {},
    this.lexiconWeak = const {},
    this.languageIdWords = const {},
    this.lexiconAsset,
    this.scriptWords = const {},
    this.negativeCollisions = const {},
    this.negativeCollisionsByLanguage = const {},
    this.seedChannels = const [],
    this.seedChannelCandidates = const [],
    this.boostTerms = const [],
  });

  final String code;
  final String englishName;
  final String nativeName;
  final List<List<int>> scriptRanges;
  final Map<String, List<String>> topicQueries;
  final List<String> topicNames;
  final Map<String, List<String>> topicTemplates;
  final List<String> freshnessWords;
  final List<SeasonalTerm> seasonalTerms;
  final Map<String, List<String>> slotValues;
  final Set<String> lexicon, lexiconStrong, lexiconWeak;
  final Set<String> languageIdWords;
  final String? lexiconAsset;
  final Set<String> scriptWords;
  final Set<String> negativeCollisions;
  final Map<String, Set<String>> negativeCollisionsByLanguage;
  final List<SeedChannel> seedChannels;
  final List<SeedChannel> seedChannelCandidates;
  final List<String> boostTerms;

  factory LanguageProfile.fromJson(Map<String, dynamic> json) {
    return LanguageProfile(
      code: json['code'] as String,
      englishName: json['englishName'] as String,
      nativeName: json['nativeName'] as String,
      scriptRanges: (json['scriptRanges'] as List)
          .map((r) => (r as List).map((n) => (n as num).toInt()).toList())
          .toList(),
      topicQueries:
          ((json['topicQueries'] as Map<String, dynamic>?) ?? const {}).map(
            (k, v) =>
                MapEntry(k, (v as List).map((e) => e.toString()).toList()),
          ),
      topicNames: (json['topicNames'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      topicTemplates:
          ((json['topicTemplates'] as Map<String, dynamic>?) ?? const {}).map(
            (k, v) =>
                MapEntry(k, (v as List).map((e) => e.toString()).toList()),
          ),
      freshnessWords: (json['freshnessWords'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      seasonalTerms: (json['seasonalTerms'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => SeasonalTerm.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      slotValues: ((json['slotValues'] as Map<String, dynamic>?) ?? const {})
          .map(
            (k, v) =>
                MapEntry(k, (v as List).map((e) => e.toString()).toList()),
          ),
      lexicon: (json['lexicon'] as List? ?? const [])
          .map((e) => e.toString().toLowerCase())
          .toSet(),
      lexiconStrong:
          (json['lexiconStrong'] as List? ??
                  json['lexicon'] as List? ??
                  const [])
              .map((e) => e.toString().toLowerCase())
              .toSet(),
      lexiconWeak: (json['lexiconWeak'] as List? ?? const [])
          .map((e) => e.toString().toLowerCase())
          .toSet(),
      languageIdWords: (json['languageIdWords'] as List? ?? const [])
          .map((e) => e.toString().toLowerCase())
          .toSet(),
      lexiconAsset: json['lexiconAsset'] as String?,
      scriptWords: (json['scriptWords'] as List? ?? const [])
          .map((e) => e.toString().toLowerCase())
          .toSet(),
      negativeCollisions: (json['negativeCollisions'] as List? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toSet(),
      negativeCollisionsByLanguage:
          ((json['negativeCollisionsByLanguage'] as Map<String, dynamic>?) ??
                  const {})
              .map(
                (k, v) => MapEntry(
                  k,
                  (v as List).map((e) => e.toString().toLowerCase()).toSet(),
                ),
              ),
      seedChannels: (json['seedChannels'] as List? ?? const []).map((e) {
        if (e is Map) return SeedChannel.fromJson(Map<String, dynamic>.from(e));
        return SeedChannel(name: e.toString(), channelId: '', topics: const []);
      }).toList(),
      seedChannelCandidates:
          (json['seedChannelCandidates'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => SeedChannel.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
      boostTerms: (json['boostTerms'] as List? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList(),
    );
  }

  bool matchesScript(int rune) {
    for (final range in scriptRanges) {
      if (rune >= range[0] && rune <= range[1]) return true;
    }
    return false;
  }
}

class SeedChannel {
  const SeedChannel({
    required this.name,
    required this.channelId,
    required this.topics,
    this.verifiedAt,
  });
  final String name, channelId;
  final List<String> topics;
  final String? verifiedAt;
  factory SeedChannel.fromJson(Map<String, dynamic> json) => SeedChannel(
    name: json['name'] as String? ?? '',
    channelId: json['channelId'] as String? ?? '',
    topics: (json['topics'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    verifiedAt: json['verifiedAt'] as String?,
  );
}

class SeasonalTerm {
  const SeasonalTerm({
    required this.name,
    required this.query,
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
  });
  final String name, query;
  final int startMonth, startDay, endMonth, endDay;
  factory SeasonalTerm.fromJson(Map<String, dynamic> json) => SeasonalTerm(
    name: json['name'] as String? ?? '',
    query: json['query'] as String? ?? json['name'] as String? ?? '',
    startMonth: json['startMonth'] as int? ?? 1,
    startDay: json['startDay'] as int? ?? 1,
    endMonth: json['endMonth'] as int? ?? 12,
    endDay: json['endDay'] as int? ?? 31,
  );
  bool contains(DateTime date) {
    final day = date.month * 100 + date.day;
    final start = startMonth * 100 + startDay, end = endMonth * 100 + endDay;
    return start <= end
        ? day >= start && day <= end
        : day >= start || day <= end;
  }
}

class LanguageProfileRegistry {
  static final LanguageProfileRegistry instance = LanguageProfileRegistry._();
  LanguageProfileRegistry._();
  LanguageProfileRegistry.fromProfiles(Iterable<LanguageProfile> profiles) {
    for (final profile in profiles) {
      _profiles[profile.code] = profile;
    }
    _loaded = true;
  }

  final Map<String, LanguageProfile> _profiles = {};
  final Map<String, Map<String, double>> _latinLexicons = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Map<String, LanguageProfile> get profiles => Map.unmodifiable(_profiles);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final assets = await loadLanguageAssets();
      if (assets.isNotEmpty) {
        for (final content in assets.values) {
          final profile = LanguageProfile.fromJson(
            jsonDecode(content) as Map<String, dynamic>,
          );
          _profiles[profile.code] = profile;
        }
      } else {
        _loadFromFilesystem();
      }
    } catch (error, stackTrace) {
      dev.log(
        'Failed to load language profiles from Flutter assets; trying filesystem fallback',
        name: 'LanguageProfileRegistry',
        error: error,
        stackTrace: stackTrace,
      );
      _loadFromFilesystem();
    }
    await loadLexicons();
    _loaded = _profiles.isNotEmpty;
    if (!_loaded) {
      throw StateError('No language profiles could be loaded');
    }
  }

  void _loadFromFilesystem() {
    final dir = Directory('assets/languages');
    if (dir.existsSync()) {
      for (final file in dir.listSync().whereType<File>()) {
        if (file.path.endsWith('.json')) {
          try {
            final content = file.readAsStringSync();
            final profile = LanguageProfile.fromJson(
              jsonDecode(content) as Map<String, dynamic>,
            );
            _profiles[profile.code] = profile;
          } catch (error, stackTrace) {
            dev.log(
              'Failed to parse language profile ${file.path}',
              name: 'LanguageProfileRegistry',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
      }
    }
  }

  LanguageProfile? get(String code) => _profiles[code];

  /// Loads optional per-profile JSON word lists. Invalid or missing assets are
  /// ignored, leaving the other classification signals available.
  Future<void> loadLexicons({Future<String?> Function(String)? loader}) async {
    final read = loader ?? loadLexiconAsset;
    _latinLexicons.clear();
    for (final profile in _profiles.values) {
      final path =
          profile.lexiconAsset ?? 'assets/lexicons/${profile.code}.json';
      try {
        final content = await read(path);
        if (content == null) continue;
        final json = jsonDecode(content);
        if (json is! Map || json['code'] != profile.code) continue;
        final raw = json['words'];
        final words = <String, double>{};
        if (raw is List) {
          for (final word in raw.whereType<String>()) {
            if (word.trim().isNotEmpty) words[word.toLowerCase().trim()] = 1;
          }
        } else if (raw is Map) {
          for (final entry in raw.entries) {
            final word = entry.key;
            final weight = entry.value;
            if (word is String &&
                word.trim().isNotEmpty &&
                weight is num &&
                weight.isFinite &&
                weight > 0) {
              words[word.toLowerCase().trim()] = weight.toDouble();
            }
          }
        }
        if (words.isNotEmpty) _latinLexicons[profile.code] = words;
      } catch (error, stackTrace) {
        dev.log(
          'Could not load lexicon for ${profile.code}',
          name: 'LanguageProfileRegistry',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  bool hasLatinLexicon(String code) =>
      (_latinLexicons[code]?.isNotEmpty ?? false) ||
      (_profiles[code]?.languageIdWords.isNotEmpty ?? false) ||
      (_profiles[code]?.lexiconStrong.isNotEmpty ?? false);

  bool isLanguageIdWord(String code, String word) =>
      (_latinLexicons[code]?.containsKey(word) ?? false) ||
      (_profiles[code]?.languageIdWords.contains(word) ?? false);

  /// Detects script language from raw Unicode codepoints.
  /// Shared script ranges require distinguishing profile evidence.
  String? detectScript(String text) {
    if (!_loaded) _loadFromFilesystem();
    final counts = <String, int>{};
    for (final rune in text.runes) {
      if (rune < 128 ||
          (rune >= 0x00c0 && rune <= 0x024f) ||
          (rune >= 0x1e00 && rune <= 0x1eff)) {
        continue;
      }
      for (final profile in _profiles.values) {
        if (profile.matchesScript(rune)) {
          counts.update(profile.code, (c) => c + 1, ifAbsent: () => 1);
        }
      }
    }
    if (counts.isEmpty) return null;
    final maxCount = counts.values.reduce(max);
    final candidates = counts.entries
        .where((entry) => entry.value == maxCount)
        .toList();
    if (candidates.length == 1) return candidates.single.key;
    int evidence(String code) =>
        _profiles[code]!.scriptWords
            .where((word) => text.toLowerCase().contains(word))
            .length +
        scoreLexicon(text, code);
    candidates.sort((a, b) => evidence(b.key).compareTo(evidence(a.key)));
    final first = evidence(candidates.first.key);
    final second = evidence(candidates[1].key);
    return first > second ? candidates.first.key : null;
  }

  ({String code, double confidence})? identifyLatin(String text) {
    if (!_loaded) _loadFromFilesystem();
    final tokens = text
        .toLowerCase()
        .split(RegExp(r'[^a-z\u00c0-\u024f\u1e00-\u1eff]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;
    final scores = <String, ({double weight, int hits})>{};
    for (final profile in _profiles.values) {
      final matches = tokens
          .where((word) => isLanguageIdWord(profile.code, word))
          .toSet();
      if (matches.isNotEmpty) {
        scores[profile.code] = (
          weight: matches.fold<double>(
            0,
            (sum, word) => sum + (_latinLexicons[profile.code]?[word] ?? 1),
          ),
          hits: matches.length,
        );
      }
    }
    if (scores.isEmpty) return null;
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.weight.compareTo(a.value.weight));
    final best = sorted.first;
    if (best.value.hits < 2 ||
        (sorted.length > 1 && sorted[1].value.weight == best.value.weight)) {
      return null;
    }
    final confidence = min(1.0, best.value.weight / 3);
    return (code: best.key, confidence: confidence);
  }

  /// Scores text against the romanized lexicon of a given language.
  int scoreLexicon(String text, String langCode) {
    if (!_loaded) _loadFromFilesystem();
    final profile = _profiles[langCode];
    if (profile == null) return 0;

    final evidence = lexiconEvidence(text, langCode);
    int hits = evidence.strong * 2 + evidence.weak;
    final lower = text.toLowerCase();

    // Also check boost phrases
    for (final phrase in profile.boostTerms) {
      if (lower.contains(phrase)) {
        hits += 2;
      }
    }

    return hits;
  }

  LexiconEvidence lexiconEvidence(String text, String langCode) {
    if (!_loaded) _loadFromFilesystem();
    final profile = _profiles[langCode];
    if (profile == null) return const LexiconEvidence(0, 0, []);
    final lower = text.toLowerCase();
    final tokens = lower
        .split(RegExp(r'[^a-z0-9\u00c0-\u024f\u1e00-\u1eff]+'))
        .where((t) => t.isNotEmpty)
        .toSet();
    final blocked = <String>{
      ...profile.negativeCollisions,
      ...profile.negativeCollisionsByLanguage.values.expand((words) => words),
    };
    final strongWords = profile.lexiconStrong.difference(blocked);
    final weakWords = profile.lexiconWeak.difference(blocked);
    final strong = tokens.intersection(strongWords);
    final weak = tokens.intersection(weakWords).difference(strong);
    return LexiconEvidence(strong.length, weak.length, [...strong, ...weak]);
  }

  bool lexiconMatches(String text, String langCode) {
    final evidence = lexiconEvidence(text, langCode);
    return evidence.strong >= 2 || (evidence.strong >= 1 && evidence.weak >= 2);
  }

  /// Returns the matched lexicon words and phrases for diagnostic inspection.
  List<String> getMatchedLexiconWords(String text, String langCode) {
    if (!_loaded) _loadFromFilesystem();
    final profile = _profiles[langCode];
    if (profile == null) return const [];

    final matched = lexiconEvidence(text, langCode).words.toList();
    final lower = text.toLowerCase();
    for (final phrase in profile.boostTerms) {
      if (lower.contains(phrase)) {
        matched.add('phrase:"$phrase"');
      }
    }
    return matched;
  }

  /// Classifies text into a language code, returning `unknown` when unresolved.
  String? classify(String text, {Set<String>? preferredLanguages}) {
    if (!_loaded) _loadFromFilesystem();

    // 1. Script detection (native script is ground truth)
    final scriptLang = detectScript(text);
    if (scriptLang != null) return scriptLang;

    // 2. Lexicon scoring across all profiles
    final scores = <String, int>{};
    for (final code in _profiles.keys) {
      final score = scoreLexicon(text, code);
      if (score > 0 && lexiconMatches(text, code)) {
        scores[code] = score;
      }
    }

    if (scores.isNotEmpty) {
      final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
      if (lexiconMatches(text, best.key)) return best.key;
    }

    final languageId = identifyLatin(text);
    if (languageId != null && languageId.confidence >= 0.65) {
      return languageId.code;
    }

    return 'unknown';
  }

  /// Generates profile-driven topic queries for the given shown languages and chip.
  List<String> buildQueries({
    required Set<String> shownLanguages,
    required String chip,
    required double localRatio,
    required Random random,
    DateTime? date,
    Iterable<String> suggestionSeeds = const [],
    Set<String> excluded = const {},
  }) {
    if (!_loaded) _loadFromFilesystem();

    final languages = shownLanguages.toList()..sort();
    final perLanguage = <String, List<String>>{};
    for (final lang in languages) {
      final profile = _profiles[lang];
      if (profile != null) {
        final languageQueries = <String>[];
        final templateList =
            profile.topicTemplates[chip] ??
            profile.topicTemplates.values.expand((e) => e).toList();
        if (templateList.isNotEmpty) {
          final shuffled = List<String>.of(templateList)..shuffle(random);
          final freshness = profile.freshnessWords.isEmpty
              ? ['latest', 'new']
              : profile.freshnessWords;
          final topics =
              chip != 'All' && profile.topicTemplates.containsKey(chip)
              ? [chip]
              : profile.topicTemplates.keys.where((e) => e != 'All').toList();
          final currentSeason = profile.seasonalTerms
              .where((e) => e.contains(date ?? DateTime.now()))
              .toList();
          final slots = <String, List<String>>{
            'language': [profile.englishName, profile.nativeName],
            'topic': topics.isEmpty ? [chip] : topics,
            'freshness': freshness,
            'artist': [
              ...(profile.slotValues['artist'] ?? const []),
              ...suggestionSeeds,
            ],
            'film': [
              ...(profile.slotValues['film'] ?? const []),
              ...suggestionSeeds,
            ],
            'festival': currentSeason.map((e) => e.query).toList(),
          };
          for (final template in shuffled) {
            var expanded = template;
            for (final slot in [
              'language',
              'topic',
              'freshness',
              'artist',
              'film',
              'festival',
            ]) {
              final marker = '{$slot}';
              if (!expanded.contains(marker)) continue;
              final values = slots[slot] ?? const <String>[];
              if (values.isEmpty) {
                expanded = '';
                break;
              }
              expanded = expanded.replaceAll(
                marker,
                values[random.nextInt(values.length)],
              );
            }
            final trimmed = expanded.replaceAll(RegExp(r'\s+'), ' ').trim();
            if (trimmed.isNotEmpty && !excluded.contains(trimmed)) {
              languageQueries.add(trimmed);
            }
          }
        } else if (profile.topicQueries.isNotEmpty) {
          final topicList =
              profile.topicQueries[chip] ??
              profile.topicQueries.values.expand((e) => e).toList();
          final shuffled = List<String>.of(topicList)..shuffle(random);
          languageQueries.addAll(shuffled.take(3));
        } else {
          languageQueries.add('${profile.nativeName} $chip');
          languageQueries.add('${profile.englishName} $chip');
        }
        perLanguage[lang] = languageQueries.toSet().toList();
      }
    }
    if (perLanguage.isEmpty) return const [];
    final count = perLanguage.values.map((items) => items.length).reduce(min);
    final queries = <String>[];
    for (final lang in languages) {
      queries.addAll(perLanguage[lang]!.take(count));
    }
    queries.shuffle(random);
    return queries;
  }
}

class LexiconEvidence {
  const LexiconEvidence(this.strong, this.weak, this.words);
  final int strong, weak;
  final List<String> words;
}
