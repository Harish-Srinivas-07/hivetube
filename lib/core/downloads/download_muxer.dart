import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';

typedef MuxCommand = Future<bool> Function(List<String> arguments);

class DownloadMuxer {
  const DownloadMuxer({this.run = _runFfmpeg});
  final MuxCommand run;

  static Future<bool> _runFfmpeg(List<String> arguments) async {
    final session = await FFmpegKit.executeWithArguments(arguments);
    return ReturnCode.isSuccess(await session.getReturnCode());
  }

  Future<void> merge({
    required File video,
    required File audio,
    required File output,
  }) async {
    try {
      final ok = await run([
        '-y',
        '-i',
        video.path,
        '-i',
        audio.path,
        '-map',
        '0:v:0',
        '-map',
        '1:a:0',
        '-c',
        'copy',
        '-f',
        'mp4',
        output.path,
      ]);
      if (!ok || !await output.exists() || await output.length() == 0) {
        throw const FileSystemException('Video merge failed');
      }
    } catch (_) {
      if (await output.exists()) await output.delete();
      if (await video.exists()) await video.delete();
      if (await audio.exists()) await audio.delete();
      rethrow;
    }
  }
}
