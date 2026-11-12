import 'dart:math';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/content/discovery/discovery_store.dart';
import 'package:hivetube/core/content/language_profile.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/features/home/home_cache.dart';
import 'package:hivetube/features/home/home_variety.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => LanguageProfileRegistry.instance.ensureLoaded());

  test('Tamil templates expand freshness and in-season slots', () {
    final queries = LanguageProfileRegistry.instance.buildQueries(
      shownLanguages: {'ta'},
      chip: 'All',
      localRatio: 1,
      random: Random(4),
      date: DateTime(2026, 1, 12),
    );
    expect(queries, isNotEmpty);
    expect(queries.every((q) => !q.contains('{') && !q.contains('}')), isTrue);
    expect(queries.any((q) => ['latest', 'new', 'today', 'this week', 'recent'].any(q.toLowerCase().contains)), isTrue);
    expect(queries.any((q) => q.contains('Pongal')), isTrue);
  });

  test('Tamil lexicon needs two strong or one strong plus two weak terms', () {
    final registry = LanguageProfileRegistry.instance;
    expect(registry.lexiconMatches('paadal isai', 'ta'), isTrue);
    expect(registry.lexiconMatches('kollywood anna amma', 'ta'), isTrue);
    expect(registry.lexiconMatches('anna akka amma appa', 'ta'), isFalse);
    expect(registry.lexiconMatches('police oor jeeyar', 'ta'), isFalse);
    final tamil = registry.get('ta')!;
    expect(tamil.lexiconStrong, isNot(contains('police')));
    expect(tamil.lexiconStrong, isNot(contains('oor')));
    expect(tamil.lexiconStrong, isNot(contains('jeeyar')));
    expect(tamil.negativeCollisions, isEmpty);
  });

  test('query bandit favors measured yield and enforces 24 hour reuse', () async {
    final db = AppDb(NativeDatabase.memory());
    final store = DiscoveryStore(db);
    final old = DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
    await db.into(db.discoveryQueries).insert(DiscoveryQueriesCompanion.insert(
      query: 'high yield', lastUsed: old, yieldNew: const Value(50), precision: const Value(.9), dwellMs: const Value(500),
    ));
    await db.into(db.discoveryQueries).insert(DiscoveryQueriesCompanion.insert(
      query: 'low yield', lastUsed: old, yieldNew: const Value(1), precision: const Value(.1), dwellMs: const Value(5000),
    ));
    final selected = await store.chooseQueries(
      ['high yield', 'low yield', 'untried'],
      count: 1,
      random: Random(3),
    );
    expect(selected, ['high yield']);
    expect(await store.recentlyUsedQueries(), contains('high yield'));
    expect(await store.chooseQueries(['high yield'], random: Random(4)), isEmpty);
    await db.close();
  });

  test('query history keeps newest 300 rows', () async {
    final db = AppDb(NativeDatabase.memory());
    final store = DiscoveryStore(db);
    for (var i = 0; i < 305; i++) {
      await store.recordQuery('query $i');
    }
    final rows = await (db.select(db.discoveryQueries)).get();
    expect(rows, hasLength(300));
    await db.close();
  });

  test('channel promotes after three distinct ground truth videos and demotes', () async {
    final db = AppDb(NativeDatabase.memory());
    final store = DiscoveryStore(db);
    for (var i = 1; i <= 2; i++) {
      await store.observeChannel(channelId: 'UC_test', videoId: 'v$i', language: 'ta', groundTruthMatch: true);
      expect(await store.channels('ta'), isEmpty);
    }
    await store.observeChannel(channelId: 'UC_test', videoId: 'v3', language: 'ta', groundTruthMatch: true);
    expect((await store.channels('ta')).single.votes, 3);
    await store.observeChannel(channelId: 'UC_test', videoId: 'v3', language: 'ta', groundTruthMatch: true);
    expect((await store.channels('ta')).single.votes, 3);
    await store.observeChannel(channelId: 'UC_test', videoId: 'v4', language: 'ta', groundTruthMatch: false);
    expect((await store.channels('ta')).single.votes, 3);
    await store.observeChannel(channelId: 'UC_test', videoId: 'v5', language: 'ta', groundTruthMatch: false);
    expect(await store.channels('ta'), isEmpty);
    await db.close();
  });

  test('mined title terms become weak after second verification', () async {
    final db = AppDb(NativeDatabase.memory());
    final store = DiscoveryStore(db);
    await store.mineTerms(language: 'ta', title: 'Anirudh new paadal', verifiedNonLanguageTerms: {'new'});
    expect((await store.topTerms('ta')).every((term) => term.strength == 0), isTrue);
    await store.mineTerms(language: 'ta', title: 'Anirudh paadal latest', verifiedNonLanguageTerms: {'latest'});
    final mined = await store.topTerms('ta');
    expect(mined.firstWhere((term) => term.term == 'anirudh').strength, 1);
    expect(mined.firstWhere((term) => term.term == 'paadal').strength, 1);
    await db.close();
  });

  test('Home age mix uses fresh, recent, and evergreen quotas', () {
    final now = DateTime.now();
    final items = <VideoItem>[
      for (var i = 0; i < 12; i++) VideoItem(id: 'f$i', title: 'fresh', publishedAt: now.subtract(Duration(days: i % 7))),
      for (var i = 0; i < 6; i++) VideoItem(id: 'r$i', title: 'recent', publishedAt: now.subtract(Duration(days: 10 + i))),
      for (var i = 0; i < 2; i++) VideoItem(id: 'e$i', title: 'evergreen', publishedAt: now.subtract(const Duration(days: 100))),
    ];
    final mixed = mixByPublishedAge(items, random: Random(5));
    expect(mixed.take(12).where((e) => publishedAgeDays(e)! <= 7), hasLength(12));
    expect(mixed.skip(12).take(6).where((e) => publishedAgeDays(e)! <= 60), hasLength(6));
    expect(mixed.skip(18).every((e) => publishedAgeDays(e)! > 60), isTrue);
  });

  test('Home launch cache expires at 30 minutes', () {
    final now = DateTime.now();
    final cache = HomeCache(const [], const [], now.subtract(const Duration(minutes: 29)));
    expect(HomeCache.decode(cache.encode(), now), isNotNull);
    final expired = HomeCache(const [], const [], now.subtract(const Duration(minutes: 31)));
    expect(HomeCache.decode(expired.encode(), now), isNull);
  });
}
