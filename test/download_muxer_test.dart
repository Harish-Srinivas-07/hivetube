import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/downloads/download_muxer.dart';

void main() {
  test('merge failure removes partial output and both inputs', () async {
    final dir = await Directory.systemTemp.createTemp('mux_test_');
    addTearDown(() => dir.delete(recursive: true));
    final video = File('${dir.path}/video.part');
    final audio = File('${dir.path}/audio.part');
    final output = File('${dir.path}/output.mp4');
    await video.writeAsBytes([1]);
    await audio.writeAsBytes([2]);
    final muxer = DownloadMuxer(
      run: (args) async {
        expect(args, containsAllInOrder(['-c', 'copy']));
        await output.writeAsBytes([3]);
        return false;
      },
    );
    await expectLater(
      muxer.merge(video: video, audio: audio, output: output),
      throwsA(isA<FileSystemException>()),
    );
    expect(await video.exists(), isFalse);
    expect(await audio.exists(), isFalse);
    expect(await output.exists(), isFalse);
  });
}
