import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'history_entry.dart';
export 'history_entry.dart';

part 'app_db.g.dart';

class Prefs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Prefs])
class AppDb extends _$AppDb {
  AppDb([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'hivetube'));
  @override
  int get schemaVersion => 1;

  Future<String?> getValue(String key) async => (await (select(
    prefs,
  )..where((p) => p.key.equals(key))).getSingleOrNull())?.value;
  Future<int> deleteValue(String key) =>
      (delete(prefs)..where((p) => p.key.equals(key))).go();
  Future<int> clearAppData() => delete(prefs).go();
  Future<void> setValue(String key, String value) => into(
    prefs,
  ).insertOnConflictUpdate(PrefsCompanion.insert(key: key, value: value));
}

abstract interface class HistoryRepo {
  Future<List<HistoryEntry>> recent();
  Future<Set<String>> dislikedChannels();
  Future<void> save(HistoryEntry entry);
}

abstract interface class SubscriptionRepo {
  Future<List<String>> channelIds();
  Future<void> setSubscribed(String channelId, bool subscribed);
}

class EmptyHistoryRepo implements HistoryRepo {
  final Map<String, HistoryEntry> _entries = {};
  @override
  Future<List<HistoryEntry>> recent() async =>
      _entries.values.toList().reversed.toList();
  @override
  Future<Set<String>> dislikedChannels() async => {};
  @override
  Future<void> save(HistoryEntry entry) async {
    _entries.remove(entry.videoId);
    _entries[entry.videoId] = entry;
  }
}

class StoredHistoryRepo implements HistoryRepo {
  StoredHistoryRepo(this.db);
  final AppDb db;
  Future<void> _writes = Future.value();
  static const _key = 'watch_history_v1';

  Future<List<HistoryEntry>> _load() async {
    try {
      final data = jsonDecode(await db.getValue(_key) ?? '[]');
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map(
            (entry) => HistoryEntry(
              entry['id'] as String,
              Duration(milliseconds: entry['position'] as int),
              Duration(milliseconds: entry['duration'] as int),
              isShort: entry['isShort'] as bool? ?? false,
              channelName: entry['channelName'] as String? ?? '',
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<HistoryEntry>> recent() async {
    await _writes;
    return _load();
  }

  @override
  Future<Set<String>> dislikedChannels() async {
    try {
      final value = jsonDecode(
        await db.getValue('disliked_channels_v1') ?? '[]',
      );
      return value is List ? value.whereType<String>().toSet() : {};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> save(HistoryEntry entry) {
    final write = _writes.then((_) async {
      final entries = await _load();
      final previous = entries
          .where((e) => e.videoId == entry.videoId)
          .firstOrNull;
      entries.removeWhere((e) => e.videoId == entry.videoId);
      entries.insert(
        0,
        HistoryEntry(
          entry.videoId,
          entry.position,
          entry.duration,
          isShort: entry.isShort || (previous?.isShort ?? false),
          channelName: entry.channelName.isNotEmpty
              ? entry.channelName
              : previous?.channelName ?? '',
        ),
      );

      await db.setValue(
        _key,
        jsonEncode(
          entries
              .take(500)
              .map(
                (e) => {
                  'id': e.videoId,
                  'position': e.position.inMilliseconds,
                  'duration': e.duration.inMilliseconds,
                  'isShort': e.isShort,
                  'channelName': e.channelName,
                },
              )
              .toList(),
        ),
      );
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}

class StoredSubscriptionRepo implements SubscriptionRepo {
  StoredSubscriptionRepo(this.db);
  final AppDb db;
  @override
  Future<void> setSubscribed(String channelId, bool subscribed) =>
      updateSubscription(channelId, subscribed);
  @override
  Future<List<String>> channelIds() async {
    try {
      final value = jsonDecode(await db.getValue('subscriptions_v1') ?? '[]');
      if (value is! List) return [];
      return value
          .map(
            (e) => e is String
                ? e
                : e is Map
                ? e['channelId']
                : null,
          )
          .whereType<String>()
          .where((id) => id.startsWith('UC'))
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }
}

extension SubscriptionChanges on StoredSubscriptionRepo {
  Future<void> updateSubscription(String channelId, bool subscribed) async {
    final ids = await channelIds();
    ids.remove(channelId);
    if (subscribed) ids.add(channelId);
    await db.setValue('subscriptions_v1', jsonEncode(ids));
  }
}

class EmptySubscriptionRepo implements SubscriptionRepo {
  @override
  Future<void> setSubscribed(String channelId, bool subscribed) async {}
  @override
  Future<List<String>> channelIds() async => [];
}
