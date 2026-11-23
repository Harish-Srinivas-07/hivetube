import 'dart:async';
import 'dart:convert';

class ChannelAvatarCache {
  ChannelAvatarCache({this.read, this.write});

  static const storageKey = 'channel_avatars_v1';
  static const maxEntries = 500;
  static ChannelAvatarCache instance = ChannelAvatarCache();
  final Future<String?> Function(String key)? read;
  final Future<void> Function(String key, String value)? write;
  final Map<String, String> _entries = {};
  Future<void> _writes = Future<void>.value();
  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    if (read == null) return;
    try {
      final decoded = jsonDecode(await read!(storageKey) ?? '{}');
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          if (entry.key is String &&
              entry.value is String &&
              (entry.value as String).isNotEmpty) {
            _entries[entry.key as String] = entry.value as String;
          }
        }
      }
      _trim();
    } catch (_) {
      _entries.clear();
    }
  }

  String? get(String channelId) {
    final value = _entries.remove(channelId);
    if (value != null) {
      _entries[channelId] = value;
      _persist();
    }
    return value;
  }

  void clearMemory() => _entries.clear();

  Future<void> put(String channelId, String avatarUrl) async {
    if (!channelId.startsWith('UC') || avatarUrl.isEmpty) return;
    await load();
    _entries.remove(channelId);
    _entries[channelId] = avatarUrl;
    _trim();
    await _persist();
  }

  Future<void> _persist() async {
    if (write == null) return;
    final writeTask = _writes.then(
      (_) => write!(storageKey, jsonEncode(_entries)),
    );
    _writes = writeTask.catchError((Object _) {});
    await writeTask;
  }

  void _trim() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}

class AvatarBackfillCoordinator {
  final Map<String, Future<String?>> _inflight = {};
  final Map<String, DateTime> _failures = {};
  final List<Completer<void>> _waiters = [];
  int _active = 0;

  Future<String?> resolve(String key, Future<String> Function() fetch) {
    final previous = _inflight[key];
    if (previous != null) return previous;
    final failedAt = _failures[key];
    if (failedAt != null &&
        DateTime.now().difference(failedAt) < const Duration(minutes: 10)) {
      return Future.value(null);
    }
    final task = _run(key, fetch);
    _inflight[key] = task;
    return task;
  }

  Future<String?> _run(String key, Future<String> Function() fetch) async {
    if (_active >= 3) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _active++;
    try {
      final result = await fetch();
      if (result.isEmpty) throw StateError('No avatar');
      return result;
    } catch (_) {
      _failures[key] = DateTime.now();
      return null;
    } finally {
      _active--;
      _inflight.remove(key);
      if (_waiters.isNotEmpty) _waiters.removeAt(0).complete();
    }
  }
}
