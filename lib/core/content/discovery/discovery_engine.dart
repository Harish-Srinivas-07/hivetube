import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../language_profile.dart';
import '../../yt/yt_search.dart';
import '../../yt/yt_browse.dart';
import '../../yt/models.dart';
import '../../yt/yt_rss.dart';
import '../caption_probe.dart';
import '../../db/app_db.dart' show LearnedChannel;
import 'discovery_store.dart';

class DiscoveryPlan {
  const DiscoveryPlan({required this.queries, required this.channelIds, required this.suggestions});
  final List<String> queries, channelIds, suggestions;
}

class DiscoveryEngine {
  DiscoveryEngine({required this.store, required this.search, required this.browse, required this.rss, required this.probe, required this.registry});
  final DiscoveryStore store;
  final YtSearch search;
  final YtBrowse browse;
  final YtRss rss;
  final CaptionProbeService probe;
  final LanguageProfileRegistry registry;

  Future<DiscoveryPlan> plan({
    required String language,
    required String chip,
    required Random random,
  }) async {
    final profile = registry.get(language);
    if (profile == null) return const DiscoveryPlan(queries: [], channelIds: [], suggestions: []);
    final topic = profile.topicNames.isEmpty ? chip.toLowerCase() : profile.topicNames[random.nextInt(profile.topicNames.length)].toLowerCase();
    final letters = 'abcdefghijklmnopqrstuvwxyz'.split('')..shuffle(random);
    final seeds = <String>{
      profile.englishName.toLowerCase(),
      '${profile.englishName.toLowerCase()} $topic',
      '${profile.nativeName} $topic',
      '${profile.englishName.toLowerCase()} music artist',
      '${profile.englishName.toLowerCase()} new film trailer',
      ...letters.take(2).map((letter) => '${profile.englishName.toLowerCase()} $topic $letter'),
      ...(profile.slotValues['artist'] ?? const []).map((e) => '$e ${profile.englishName.toLowerCase()}'),
      ...(profile.slotValues['film'] ?? const []).map((e) => '$e ${profile.englishName.toLowerCase()}'),
    };
    final suggestions = <String>{};
    final suggestionPages = await Future.wait(seeds.take(7).map((seed) async {
      var values = await store.cachedSuggestions(seed);
      if (values == null) {
        try {
          values = await search.suggestions(seed);
          await store.cacheSuggestions(seed, values);
        } catch (_) {
          values = const [];
        }
      }
      return values;
    }));
    for (final page in suggestionPages) {
      for (final value in page) {
        final script = registry.detectScript(value);
        if (script == language || registry.lexiconMatches(value, language)) suggestions.add(value.trim());
      }
    }
    final generated = registry.buildQueries(
      shownLanguages: {language},
      chip: chip,
      localRatio: 1,
      random: random,
      suggestionSeeds: suggestions,
      date: DateTime.now(),
    );
    final candidates = <String>{...suggestions, ...generated}.where((e) => e.isNotEmpty).toList();
    final queries = await store.chooseQueries(candidates, count: 6, random: random);
    final seedIds = profile.seedChannels
        .where((e) => e.channelId.startsWith('UC') && e.verifiedAt != null)
        .map((e) => e.channelId);
    final verifiedCandidates = await _verifiedSeedCache(language);
    unawaited(_verifySeedCandidates(language, random));
    final learned = await store.channels(language);
    final learnedIds = learned.whereType<LearnedChannel>().where((e) => e.votes >= 3).map((e) => e.channelId);
    return DiscoveryPlan(
      queries: queries,
      channelIds: {...seedIds, ...verifiedCandidates, ...learnedIds}.toList()..shuffle(random),
      suggestions: suggestions.toList(),
    );
  }

  Future<Set<String>> _verifiedSeedCache(String language) async {
    try {
      final value = jsonDecode(await store.db.getValue('seed_channels_verified_$language') ?? '') as Map<String, dynamic>;
      final age = DateTime.now().difference(DateTime.tryParse(value['checkedAt'] as String? ?? '') ?? DateTime(2000));
      if (age < const Duration(days: 30)) return (value['channelIds'] as List? ?? const []).whereType<String>().toSet();
    } catch (_) {}
    return {};
  }

  Future<void> _verifySeedCandidates(String language, Random random) async {
    final profile = registry.get(language);
    if (profile == null || profile.seedChannelCandidates.isEmpty) return;
    final key = 'seed_channels_verified_$language';
    final now = DateTime.now();
    final cached = await store.db.getValue(key);
    final verified = <String>{};
    DateTime? checkedAt;
    try {
      final value = jsonDecode(cached ?? '') as Map<String, dynamic>;
      checkedAt = DateTime.tryParse(value['checkedAt'] as String? ?? '');
      verified.addAll((value['channelIds'] as List? ?? const []).whereType<String>());
    } catch (_) {}
    if (checkedAt != null && now.difference(checkedAt) < const Duration(days: 1)) return;

    var checked = 0;
    final candidates = [...profile.seedChannelCandidates]..shuffle(random);
    for (final candidate in candidates) {
      if (checked >= 6 || verified.length >= 40) break;
      if (candidate.name.isEmpty) continue;
      checked++;
      try {
        var page = await search.search(candidate.name);
        final channelsFilter = page.filters.where((f) => f.type == SearchFilterType.channels).firstOrNull;
        if (channelsFilter != null) page = await search.search(candidate.name, params: channelsFilter.params);
        final result = page.items.whereType<ChannelSearchResult>().firstOrNull?.channel;
        if (result == null || !result.id.startsWith('UC')) continue;
        final details = await browse.channelPage(result.id);
        if (!_sameChannel(candidate.name, '${result.title} ${details.name}')) continue;
        final uploads = await rss.uploads(result.id);
        var groundTruthItems = 0;
        for (final item in uploads.take(6)) {
          final script = registry.detectScript(item.title);
          if (script == language || registry.lexiconMatches(item.title, language)) {
            groundTruthItems++;
          } else if (script == null) {
            final asr = await probe.probeVideo(item.id, channelId: result.id, channelName: details.name, asrOnly: true);
            if (asr?.toLowerCase().split('-').first == language) groundTruthItems++;
          }
          if (groundTruthItems >= 3) break;
        }
        if (groundTruthItems >= 3) verified.add(result.id);
      } catch (_) {}
    }
    await store.db.setValue(key, jsonEncode({'checkedAt': now.toIso8601String(), 'channelIds': verified.toList()}));
  }

  bool _sameChannel(String expected, String actual) {
    String normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0B80-\u0BFF]+'), ' ').trim();
    final left = normalize(expected).split(' ').where((e) => e.length > 1).toSet();
    final right = normalize(actual).split(' ').where((e) => e.length > 1).toSet();
    return left.isNotEmpty && left.intersection(right).length / left.length >= .6;
  }
}
