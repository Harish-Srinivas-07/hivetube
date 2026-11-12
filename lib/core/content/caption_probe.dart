import 'dart:async';
import '../innertube/innertube_http.dart';
import 'channel_language_cache.dart';

class CaptionProbeService {
  CaptionProbeService(this.http, this.channelCache);

  final InnertubeHttp http;
  final ChannelLanguageCache channelCache;
  final Map<String, String?> _videoLangCache = {};
  final Map<String, String?> _asrVideoLangCache = {};

  /// Probes the spoken language from the ASR caption track.
  Future<String?> probeVideo(String videoId, {String? channelId, String? channelName, bool asrOnly = false}) async {
    final cache = asrOnly ? _asrVideoLangCache : _videoLangCache;
    if (cache.containsKey(videoId)) {
      return cache[videoId];
    }

    // Check if channel is already classified
    if (!asrOnly && channelId != null) {
      final classified = channelCache.getClassifiedLanguage(channelId, channelName: channelName);
      if (classified != null) {
        cache[videoId] = classified;
        return classified;
      }
    }

    try {
      final res = await http.post('player', {
        'videoId': videoId,
      }, clientName: 'ANDROID').timeout(
        const Duration(milliseconds: 1500),
      );

      final captions = res['captions']?['playerCaptionsTracklistRenderer']?['captionTracks'];
      if (captions is List) {
        // Look for asr caption first, then any caption track
        String? asrLang;
        String? anyLang;
        for (final track in captions) {
          if (track is Map) {
            final code = track['languageCode'] as String?;
            final kind = track['kind'] as String?;
            if (code != null && code.isNotEmpty) {
            if (kind == 'asr') {
                asrLang = code;
                break;
              }
            if (!asrOnly) anyLang ??= code;
            }
          }
        }

        final lang = asrLang ?? anyLang;
        if (lang != null) {
          cache[videoId] = lang;
          if (channelId != null) {
            channelCache.vote(channelId, lang, channelName: channelName, weight: 2);
          }
          return lang;
        }
      }
    } catch (_) {
      // Timeout or error
    }

    if (channelId != null) {
      channelCache.recordProbeFailure(channelId, channelName: channelName);
    }
    cache[videoId] = null;
    return null;
  }

  /// Batch prefetch probe with max 20 items, concurrency 3, and 1.5s timeout.
  Future<Map<String, String?>> probeBatch(
    List<({String videoId, String? channelId, String? channelName})> items, {
    bool asrOnly = false,
  }) async {
    final targets = items.take(20).toList();
    final results = <String, String?>{};
    if (targets.isEmpty) return results;

    var cursor = 0;
    Future<void> worker() async {
      while (cursor < targets.length) {
        final current = targets[cursor++];
        final lang = await probeVideo(
          current.videoId,
          channelId: current.channelId,
          channelName: current.channelName,
          asrOnly: asrOnly,
        );
        results[current.videoId] = lang;
      }
    }

    await Future.wait(
      List.generate(targets.length < 3 ? targets.length : 3, (_) => worker()),
    );

    return results;
  }
}

