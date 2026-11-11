import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/streams/stream_selector.dart';

Map<String, dynamic> format(
  int id,
  String mime, {
  int? height,
  int bitrate = 1,
  bool drc = false,
  Map<String, dynamic>? track,
}) => {
  'itag': id,
  'url': 'https://example.com/media?expire=2000000000',
  'mimeType': mime,
  'bitrate': bitrate,
  'height': ?height,
  if (drc) 'isDrc': true,
  'audioTrack': ?track,
};
void main() {
  final data = {
    'streamingData': {
      'adaptiveFormats': [
        format(1, 'video/mp4; codecs="avc1"', height: 1080),
        format(2, 'video/mp4; codecs="avc1"', height: 720, bitrate: 2),
        format(3, 'video/mp4; codecs="avc1"', height: 720, bitrate: 5),
        format(4, 'video/mp4; codecs="avc1"', height: 240),
        format(5, 'video/webm; codecs="vp9"', height: 1080),
        format(140, 'audio/mp4', drc: true),
        format(140, 'audio/mp4'),
        format(251, 'audio/webm', drc: true),
        format(250, 'audio/webm'),
        format(249, 'audio/webm'),
      ],
    },
  };
  test('avc wins, best bitrate per height, low resolutions dropped', () {
    final result = selectStreams(data, PlaybackMode.video);
    expect(result.videos.map((e) => e.itag), [1, 3]);
    expect(result.audio?.itag, 140);
    expect(result.audio?.json['isDrc'], isNull);
    expect(
      result.videos.first.expires,
      DateTime.fromMillisecondsSinceEpoch(2000000000 * 1000),
    );
  });
  test('shorts capped at 720 and audio mode skips DRC', () {
    expect(selectStreams(data, PlaybackMode.short).videos.map((v) => v.itag), [
      3,
    ]);
    expect(selectStreams(data, PlaybackMode.audio).audio?.itag, 250);
  });
  test('VP9 fallback only with no eligible avc', () {
    final input = {
      'streamingData': {
        'adaptiveFormats': [format(5, 'video/webm; codecs="vp9"', height: 720)],
      },
    };
    expect(selectStreams(input, PlaybackMode.video).videos.single.itag, 5);
  });
}
