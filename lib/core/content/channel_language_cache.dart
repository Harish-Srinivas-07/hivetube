import 'dart:convert';
import 'dart:developer' as dev;
import '../db/app_db.dart';
import 'language_profile.dart';

abstract class ChangeNotifier {
  final List<void Function()> _listeners = [];
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}

class ChannelVoteEntry {
  ChannelVoteEntry({
    required this.votes,
    this.classifiedLanguage,
    required this.updatedAt,
  });

  final Map<String, int> votes;
  String? classifiedLanguage;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'votes': votes,
    'classified': classifiedLanguage,
    'at': updatedAt.toIso8601String(),
  };

  factory ChannelVoteEntry.fromJson(Map<String, dynamic> json) =>
      ChannelVoteEntry(
        votes: Map<String, int>.from(json['votes'] as Map? ?? {}),
        classifiedLanguage: json['classified'] as String?,
        updatedAt:
            DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      );
}

class ChannelLanguageCache extends ChangeNotifier {
  static ChannelLanguageCache? _instance;
  static ChannelLanguageCache get instance =>
      _instance ??= ChannelLanguageCache._memory();
  static set instance(ChannelLanguageCache inst) => _instance = inst;

  ChannelLanguageCache(AppDb db) : this._(db);

  ChannelLanguageCache._memory() : this._(null);

  ChannelLanguageCache._(this.db) {
    _initSeedChannels();
    _loadFromDb();
  }

  final AppDb? db;
  final Map<String, ChannelVoteEntry> _cache = {};

  void _initSeedChannels() {
    final registry = LanguageProfileRegistry.instance;
    for (final profile in registry.profiles.values) {
      for (final channel in profile.seedChannels.where(
        (e) => e.channelId.startsWith('UC') && e.verifiedAt != null,
      )) {
        _cache[channel.channelId] = ChannelVoteEntry(
          votes: {profile.code: 5},
          classifiedLanguage: profile.code,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  Future<void> _loadFromDb() async {
    final database = db;
    if (database == null) return;
    try {
      final raw = await database.getValue(
        'channel_language_cache_v$CLASSIFIER_VERSION',
      );
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final now = DateTime.now();
        for (final entry in decoded.entries) {
          final val = ChannelVoteEntry.fromJson(
            entry.value as Map<String, dynamic>,
          );
          // 30 days retention
          if (now.difference(val.updatedAt).inDays < 30) {
            _cache[entry.key] = val;
          }
        }
      }
    } catch (error, stackTrace) {
      dev.log(
        'Failed to load channel-language votes',
        name: 'ChannelLanguageCache',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveToDb() async {
    final database = db;
    if (database == null) return;
    try {
      final encoded = jsonEncode(_cache.map((k, v) => MapEntry(k, v.toJson())));
      await database.setValue(
        'channel_language_cache_v$CLASSIFIER_VERSION',
        encoded,
      );
    } catch (error, stackTrace) {
      dev.log(
        'Failed to persist channel-language votes',
        name: 'ChannelLanguageCache',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Returns the classified language if $\ge 2$ votes agree, or null.
  String? getClassifiedLanguage(String channelId, {String? channelName}) {
    final key = channelId.isNotEmpty ? channelId : channelName?.toLowerCase();
    if (key == null) return null;

    final entry =
        _cache[key] ??
        (channelName != null ? _cache[channelName.toLowerCase()] : null);
    if (entry == null) return null;

    if (entry.classifiedLanguage != null) return entry.classifiedLanguage;

    for (final vote in entry.votes.entries) {
      if (vote.value >= 2) {
        entry.classifiedLanguage = vote.key;
        return vote.key;
      }
    }
    return null;
  }

  /// Adds a vote for a language for this channel. 2 agreeing votes classify the channel permanently.
  void vote(
    String channelId,
    String language, {
    String? channelName,
    int weight = 1,
  }) {
    final key = channelId.isNotEmpty ? channelId : channelName?.toLowerCase();
    if (key == null || language.isEmpty) return;

    final entry = _cache.putIfAbsent(
      key,
      () => ChannelVoteEntry(votes: {}, updatedAt: DateTime.now()),
    );
    entry.updatedAt = DateTime.now();
    entry.votes.update(language, (val) => val + weight, ifAbsent: () => weight);

    if ((entry.votes[language] ?? 0) >= 2) {
      entry.classifiedLanguage = language;
    }

    if (channelName != null && channelName.isNotEmpty) {
      _cache[channelName.toLowerCase()] = entry;
    }

    _saveToDb();
    notifyListeners();
  }

  /// Records a probe failure for a channel. After 2 failures, channel is cached as 'not_in_shown'.
  void recordProbeFailure(String channelId, {String? channelName}) {
    final key = channelId.isNotEmpty ? channelId : channelName?.toLowerCase();
    if (key == null) return;

    final entry = _cache.putIfAbsent(
      key,
      () => ChannelVoteEntry(votes: {}, updatedAt: DateTime.now()),
    );
    entry.updatedAt = DateTime.now();
    entry.votes.update('probe_failure', (v) => v + 1, ifAbsent: () => 1);
    if ((entry.votes['probe_failure'] ?? 0) >= 2) {
      entry.classifiedLanguage = 'not_in_shown';
    }

    if (channelName != null && channelName.isNotEmpty) {
      _cache[channelName.toLowerCase()] = entry;
    }

    _saveToDb();
    notifyListeners();
  }
}
