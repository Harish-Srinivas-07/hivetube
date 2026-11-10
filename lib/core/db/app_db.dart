import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_db.g.dart';

class Prefs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Prefs])
class AppDb extends _$AppDb {
  AppDb() : super(driftDatabase(name: 'hivetube'));
  @override
  int get schemaVersion => 1;

  Future<String?> getValue(String key) async => (await (select(
    prefs,
  )..where((p) => p.key.equals(key))).getSingleOrNull())?.value;
  Future<void> setValue(String key, String value) => into(
    prefs,
  ).insertOnConflictUpdate(PrefsCompanion.insert(key: key, value: value));
}

class HistoryEntry {
  const HistoryEntry(this.videoId, this.position, this.duration);
  final String videoId;
  final Duration position, duration;
}

abstract interface class HistoryRepo {
  Future<List<HistoryEntry>> recent();
  Future<Set<String>> dislikedChannels();
}

abstract interface class SubscriptionRepo {
  Future<List<String>> channelIds();
}

class EmptyHistoryRepo implements HistoryRepo {
  @override
  Future<List<HistoryEntry>> recent() async => [];
  @override
  Future<Set<String>> dislikedChannels() async => {};
}

class EmptySubscriptionRepo implements SubscriptionRepo {
  @override
  Future<List<String>> channelIds() async => [];
}
