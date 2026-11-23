String cleanVtt(String source) => source
    .replaceAll(RegExp(r'<\d{2}:\d{2}:\d{2}\.\d{3}>'), '')
    .replaceAll(RegExp(r'</?c(?:\.[^>]*)?>'), '');

String transcriptToVtt(dynamic json) {
  final cues = <Map>[];
  void walk(dynamic value) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key == 'transcriptCueRenderer' && entry.value is Map) {
          cues.add(entry.value as Map);
        } else {
          walk(entry.value);
        }
      }
    } else if (value is List) {
      for (final item in value) {
        walk(item);
      }
    }
  }

  String stamp(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inHours.toString().padLeft(2, '0')}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}.${d.inMilliseconds.remainder(1000).toString().padLeft(3, '0')}';
  }

  walk(json);
  final out = StringBuffer('WEBVTT\n\n');
  for (final cue in cues) {
    final start = int.tryParse('${cue['startOffsetMs']}');
    final duration = int.tryParse('${cue['durationMs']}') ?? 3000;
    final content = cue['cue'];
    final text = content is Map
        ? content['simpleText'] ??
              (content['runs'] is List
                  ? (content['runs'] as List)
                        .map((v) => v is Map ? v['text'] ?? '' : '')
                        .join()
                  : '')
        : '';
    if (start != null && '$text'.isNotEmpty) {
      out.writeln('${stamp(start)} --> ${stamp(start + duration)}\n$text\n');
    }
  }
  return cues.isEmpty ? '' : out.toString();
}
