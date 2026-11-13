import 'dart:async';
import 'dart:io';
import 'player_client.dart';
import 'stream_selector.dart';

class _Entry {
  _Entry(this.data, this.created);
  final Map<String, dynamic> data;
  final DateTime created;
  final Set<String> probed = {};
}

class _Verdict {
  _Verdict(this.error, this.at);
  final StreamException error;
  final DateTime at;
}

class StreamCache {
  StreamCache(this.player, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final PlayerClient player;
  final DateTime Function() _clock;
  final Map<String, _Entry> _cache = {};
  final Map<String, Future<_Entry>> _inFlight = {};
  final Map<String, _Verdict> _verdicts = {};
  void clearCache() {
    _cache.clear();
  }

  void invalidate(String id) {
    _cache.remove(id);
  }

  List<Map<String, dynamic>> captionTracks(String id) {
    final captions = _cache[id]?.data['captions'];
    final renderer = captions is Map
        ? captions['playerCaptionsTracklistRenderer']
        : null;
    final tracks = renderer is Map ? renderer['captionTracks'] : null;
    return tracks is List
        ? tracks
              .whereType<Map>()
              .map((v) => Map<String, dynamic>.from(v))
              .toList()
        : [];
  }

  int? durationSeconds(String id) {
    final details = _cache[id]?.data['videoDetails'];
    if (details is Map) {
      final len = details['lengthSeconds'];
      if (len != null) return int.tryParse(len.toString());
    }
    return null;
  }

  void clearVerdicts() => _verdicts.clear();
  Future<_Entry> _get(String id) async {
    final verdict = _verdicts[id];
    if (verdict != null &&
        _clock().difference(verdict.at) < const Duration(minutes: 10)) {
      throw verdict.error;
    }
    _verdicts.remove(id);
    final current = _cache[id];
    if (current != null &&
        _clock().difference(current.created) < const Duration(minutes: 20)) {
      return current;
    }
    _cache.remove(id);
    return _inFlight
        .putIfAbsent(id, () async {
          try {
            return _Entry(await player.resolve(id), _clock());
          } on StreamException catch (error) {
            if ([
              StreamError.ageRestricted,
              StreamError.geoRestricted,
              StreamError.unavailable,
              StreamError.noStreams,
            ].contains(error.code)) {
              _verdicts[id] = _Verdict(error, _clock());
            }
            rethrow;
          }
        })
        .whenComplete(() => _inFlight.remove(id));
  }

  Future<void> prepare(String id) async {
    await _get(id);
  }

  Future<SelectedStreams> resolve(
    String id,
    PlaybackMode mode, {
    int? quality,
  }) async {
    final entry = await _get(id);
    final allSelected = selectStreams(entry.data, mode);
    final selected = mode == PlaybackMode.short
        ? SelectedStreams(
            allSelected.videos.where((format) {
              final resolution =
                  format.width > 0 && format.width < format.height
                  ? format.width
                  : format.height;
              return resolution <= 720 && format.mimeType.contains('avc1');
            }).toList(),
            allSelected.audio,
          )
        : allSelected;
    if (selected.audio == null) {
      const error = StreamException(StreamError.noStreams);
      _verdicts[id] = _Verdict(error, _clock());
      throw error;
    }
    if (mode != PlaybackMode.audio && selected.videos.isEmpty) {
      throw const StreamException(StreamError.noVideo);
    }
    final video = quality == null
        ? selected.videos.firstOrNull
        : selected.videos.where((f) => f.height == quality).firstOrNull ??
              selected.videos.firstOrNull;
    final needed = [
      selected.audio!,
      if (mode != PlaybackMode.audio && video != null) video,
    ];
    for (final format in needed) {
      if (format.expires != null &&
          _clock().isAfter(
            format.expires!.subtract(const Duration(minutes: 5)),
          )) {
        if (identical(_cache[id], entry)) {
          _cache.remove(id);
          return resolve(id, mode, quality: quality);
        }
        throw const StreamException(StreamError.extractionFailed);
      }
      if (!entry.probed.contains(format.url.toString())) {
        final ok = await probe(format);
        if (!ok) {
          _cache.remove(id);
          throw const StreamException(StreamError.extractionFailed);
        }
        entry.probed.add(format.url.toString());
      }
    }
    _cache.remove(id);
    _cache[id] = entry;
    if (_cache.length > 32) _cache.remove(_cache.keys.first);
    return selected;
  }

  Future<bool> probe(StreamFormat format) async {
    try {
      final start = format.length > 1024 * 1024 + 16384 ? 1024 * 1024 + 1 : 0;
      final end = format.length > 0
          ? (start + 1024 * 1024 - 1).clamp(start, format.length - 1)
          : start + 1024 * 1024 - 1;
      return await (() async {
        final request = await player.network.client.getUrl(format.url);
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
        request.headers.set(
          HttpHeaders.userAgentHeader,
          format.userAgent ?? player.clients['VISIONOS']['ua'],
        );
        final response = await request.close();
        if (response.statusCode != 206) {
          await response.drain<void>();
          return false;
        }
        var length = 0;
        await for (final data in response) {
          length += data.length;
        }
        return length >= 16384;
      })().timeout(const Duration(seconds: 6));
    } catch (_) {
      return false;
    }
  }
}
