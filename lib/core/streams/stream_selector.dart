import 'dart:convert';

enum PlaybackMode { video, audio, short }

class StreamFormat {
  StreamFormat(this.json, this.url);
  final Map<String, dynamic> json;
  final Uri url;
  int get itag => json['itag'] as int? ?? 0;
  int get height => json['height'] as int? ?? 0;
  int get bitrate => json['bitrate'] as int? ?? 0;
  int get length =>
      int.tryParse(
        '${json['contentLength'] ?? url.queryParameters['clen'] ?? 0}',
      ) ??
      0;
  String get mimeType => json['mimeType'] as String? ?? '';
  String? get userAgent => json['_userAgent'] as String?;
  DateTime? get expires {
    final n = int.tryParse(url.queryParameters['expire'] ?? '');
    return n == null ? null : DateTime.fromMillisecondsSinceEpoch(n * 1000);
  }
}

class SelectedStreams {
  SelectedStreams(this.videos, this.audio);
  final List<StreamFormat> videos;
  final StreamFormat? audio;
}

// xtags holds repeated protobuf key/value records; reject non-original tracks.
String? _trackType(String? xtags) {
  if (xtags == null || xtags.isEmpty) return null;
  try {
    final bytes = base64Url.decode(base64Url.normalize(xtags));
    int offset = 0;
    int varint() {
      var v = 0;
      var shift = 0;
      while (offset < bytes.length) {
        final b = bytes[offset++];
        v |= (b & 127) << shift;
        if (b < 128) return v;
        shift += 7;
        if (shift > 63) throw const FormatException();
      }
      throw const FormatException();
    }

    List<int> field() {
      final n = varint();
      if (offset + n > bytes.length) throw const FormatException();
      final value = bytes.sublist(offset, offset + n);
      offset += n;
      return value;
    }

    while (offset < bytes.length) {
      final tag = varint();
      if (tag != 10) break;
      final entry = field();
      var pos = 0;
      String? key, value;
      while (pos < entry.length) {
        final keyTag = entry[pos++];
        if (pos >= entry.length || (keyTag != 10 && keyTag != 18)) break;
        var length = 0, shift = 0, b = 0;
        do {
          if (pos >= entry.length) throw const FormatException();
          b = entry[pos++];
          length |= (b & 127) << shift;
          shift += 7;
        } while (b >= 128);
        if (pos + length > entry.length) throw const FormatException();
        final text = utf8.decode(entry.sublist(pos, pos + length));
        pos += length;
        if (keyTag == 10) {
          key = text;
        } else {
          value = text;
        }
      }
      if (key == 'acont') return value;
    }
  } catch (_) {
    return null;
  }
  return null;
}

SelectedStreams selectStreams(dynamic response, PlaybackMode mode) {
  final raw = response is Map ? response['streamingData'] : null;
  final formats = raw is Map && raw['adaptiveFormats'] is List
      ? raw['adaptiveFormats'] as List
      : [];
  final all = <StreamFormat>[];
  for (final value in formats) {
    if (value is! Map || value['url'] is! String) continue;
    final uri = Uri.tryParse(value['url'] as String);
    if (uri == null || !uri.hasScheme) continue;
    all.add(StreamFormat(Map<String, dynamic>.from(value), uri));
  }
  final cap = mode == PlaybackMode.short ? 720 : 1080;
  final avc = all
      .where(
        (f) =>
            f.height >= 360 && f.height <= cap && f.mimeType.contains('avc1'),
      )
      .toList();
  final hasAvc = all.any((f) => f.height > 0 && f.mimeType.contains('avc1'));
  final candidates = hasAvc
      ? avc
      : all
            .where(
              (f) =>
                  f.height >= 360 &&
                  f.height <= cap &&
                  (f.mimeType.contains('vp9') || f.mimeType.contains('vp09')),
            )
            .toList();
  final byHeight = <int, StreamFormat>{};
  for (final f in candidates) {
    if (byHeight[f.height] == null || f.bitrate > byHeight[f.height]!.bitrate) {
      byHeight[f.height] = f;
    }
  }
  final video = byHeight.values.toList()
    ..sort((a, b) => b.height.compareTo(a.height));
  final itags = mode == PlaybackMode.audio ? [251, 250, 249] : [140];
  final audio =
      all.where((f) {
        final track = f.json['audioTrack'];
        final type = _trackType(f.json['xtags'] as String?);
        return itags.contains(f.itag) &&
            f.json['isDrc'] != true &&
            (type == null || type.toLowerCase() == 'original') &&
            (track is! Map || track['audioIsDefault'] == true);
      }).toList()..sort(
        (a, b) => itags.indexOf(a.itag).compareTo(itags.indexOf(b.itag)),
      );
  return SelectedStreams(video, audio.firstOrNull);
}
