import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import '../../db/app_db.dart';

class DiscoveryStore {
  DiscoveryStore(this.db);
  final AppDb db;

  Future<Set<String>> recentlyUsedQueries({Duration window = const Duration(hours: 24)}) async {
    final cutoff = DateTime.now().subtract(window).millisecondsSinceEpoch;
    final rows = await (db.select(db.discoveryQueries)..where((q) => q.lastUsed.isBiggerOrEqualValue(cutoff))).get();
    return rows.map((row) => row.query).toSet();
  }

  Future<void> recordQuery(String query, {int newItems = 0, double? precision, int dwellMs = 0}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final old = await (db.select(db.discoveryQueries)..where((q) => q.query.equals(query))).getSingleOrNull();
    await db.into(db.discoveryQueries).insertOnConflictUpdate(DiscoveryQueriesCompanion.insert(
      query: query,
      lastUsed: now,
      yieldNew: Value(old == null ? newItems : old.yieldNew + newItems),
      precision: Value(precision ?? old?.precision),
      dwellMs: Value(old == null ? dwellMs : old.dwellMs + dwellMs),
    ));
    final rows = await (db.select(db.discoveryQueries)..orderBy([(q) => OrderingTerm.desc(q.lastUsed)])).get();
    if (rows.length > 300) {
      await (db.delete(db.discoveryQueries)..where((q) => q.query.isIn(rows.skip(300).map((e) => e.query)))).go();
    }
  }

  Future<List<String>> chooseQueries(List<String> candidates, {int count = 4, Random? random}) async {
    if (candidates.isEmpty) return const [];
    final rng = random ?? Random();
    final recent = await recentlyUsedQueries();
    final available = candidates.where((q) => !recent.contains(q)).toList();
    if (available.isEmpty) return const [];
    final rows = await (db.select(db.discoveryQueries)..where((q) => q.query.isIn(available))).get();
    final learned = {for (final row in rows) row.query: row};
    available.sort((a, b) {
      final ar = learned[a], br = learned[b];
      double score(String query, dynamic row) {
        if (row == null) return 3 + rng.nextDouble();
        final precision = (row.precision as double?) ?? 0.5;
        final cost = 1 + ((row.dwellMs as int) / 1000);
        final ageHours = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(row.lastUsed as int)).inHours;
        return (row.yieldNew as int) / cost + precision * 5 + min(ageHours, 48) / 24 + rng.nextDouble() * 0.3;
      }
      return score(b, br).compareTo(score(a, ar));
    });
    final selected = available.take(count).toList();
    for (final query in selected) {
      await recordQuery(query);
    }
    return selected;
  }

  Future<List<String>?> cachedSuggestions(String seed, {Duration ttl = const Duration(hours: 6)}) async {
    final row = await (db.select(db.suggestionCache)..where((s) => s.seed.equals(seed))).getSingleOrNull();
    if (row == null || DateTime.now().millisecondsSinceEpoch - row.fetchedAt > ttl.inMilliseconds) return null;
    try { return (jsonDecode(row.suggestionsJson) as List).cast<String>(); } catch (_) { return null; }
  }

  Future<void> cacheSuggestions(String seed, List<String> suggestions) async {
    await db.into(db.suggestionCache).insertOnConflictUpdate(SuggestionCacheCompanion.insert(
      seed: seed,
      suggestionsJson: jsonEncode(suggestions),
      fetchedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<List<LearnedChannel>> channels(String language) => (db.select(db.learnedChannels)
    ..where((c) => c.language.equals(language))
    ..orderBy([(c) => OrderingTerm.desc(c.votes)])).get();

  Future<void> observeChannel({required String channelId, required String videoId, required String language, required bool groundTruthMatch, Iterable<String> topics = const []}) async {
    if (!channelId.startsWith('UC') || videoId.isEmpty) return;
    final previousEvidence = await (db.select(db.channelEvidence)
      ..where((e) => e.channelId.equals(channelId) & e.videoId.equals(videoId))).getSingleOrNull();
    if (previousEvidence?.language == language && previousEvidence?.matched == groundTruthMatch) return;
    final channelEvidence = await (db.select(db.channelEvidence)..where((e) => e.channelId.equals(channelId))).get();
    final lastSeen = channelEvidence.fold<int>(0, (latest, item) => max(latest, item.lastSeen));
    final observedAt = max(DateTime.now().millisecondsSinceEpoch, lastSeen + 1);
    await db.into(db.channelEvidence).insertOnConflictUpdate(ChannelEvidenceCompanion.insert(
      channelId: channelId,
      videoId: videoId,
      language: language,
      matched: groundTruthMatch,
      lastSeen: observedAt,
    ));
    final evidence = await (db.select(db.channelEvidence)
      ..where((e) => e.channelId.equals(channelId) & e.language.equals(language))).get();
    final votes = evidence.where((e) => e.matched).length;
    final latest = evidence.toList()..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    final failedStreak = latest.takeWhile((e) => !e.matched).length;
    if (votes < 3 || failedStreak >= 2) {
      await (db.delete(db.learnedChannels)..where((c) => c.channelId.equals(channelId))).go();
      return;
    }
    final old = await (db.select(db.learnedChannels)..where((c) => c.channelId.equals(channelId))).getSingleOrNull();
    await db.into(db.learnedChannels).insertOnConflictUpdate(LearnedChannelsCompanion.insert(
      channelId: channelId,
      language: language,
      votes: Value(votes),
      lastSeen: DateTime.now().millisecondsSinceEpoch,
      topics: Value((topics.isEmpty ? (old?.topics.split(',') ?? const <String>[]) : topics).where((e) => e.isNotEmpty).toSet().join(',')),
    ));
  }

  Future<void> mineTerms({required String language, required String title, required Iterable<String> verifiedNonLanguageTerms}) async {
    final excluded = verifiedNonLanguageTerms.map((e) => e.toLowerCase()).toSet();
    final tokens = RegExp(r"[a-zA-Z][a-zA-Z']{2,}").allMatches(title.toLowerCase()).map((m) => m.group(0)!).toSet().difference(excluded);
    for (final term in tokens) {
      final old = await (db.select(db.learnedTerms)..where((t) => t.term.equals(term) & t.language.equals(language))).getSingleOrNull();
      await db.into(db.learnedTerms).insertOnConflictUpdate(LearnedTermsCompanion.insert(
        term: term,
        language: language,
        strength: Value((old?.seenCount ?? 0) + 1 >= 2 ? 1 : 0),
        seenCount: Value((old?.seenCount ?? 0) + 1),
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  Future<List<LearnedTerm>> topTerms(String language, {int limit = 30}) => (db.select(db.learnedTerms)
    ..where((t) => t.language.equals(language))
    ..orderBy([(t) => OrderingTerm.desc(t.seenCount)])
    ..limit(limit)).get();
}
