import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../yt/watch_info.dart';

class DownloadMetadata {
  DownloadMetadata(this.directory, {Dio? dio})
    : dio =
          dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
  final Future<Directory> Function() directory;
  final Dio dio;

  Future<File> _file(String id, String suffix) async {
    final dir = await directory();
    final name = base64Url.encode(utf8.encode(id)).replaceAll('=', '');
    return File('${dir.path}/metadata_$name.$suffix');
  }

  Future<void> save(WatchInfo info, {String? thumbnailFallback}) async {
    final thumbnail = info.thumbnail.isNotEmpty
        ? info.thumbnail
        : thumbnailFallback ?? '';
    final data = <String, dynamic>{
      'avatar': info.avatar,
      'thumbnail': thumbnail,
      'subscribers': info.subscribers,
      'description': info.description,
      'likes': info.likes,
      'views': info.views,
      'date': info.date,
      'handle': info.handle,
      'durationSec': info.durationSec,
      'chapters': [
        for (final chapter in info.chapters)
          [chapter.title, chapter.start.inMilliseconds],
      ],
    };
    for (final entry in {
      'avatar': info.avatar,
      'thumbnail': thumbnail,
    }.entries) {
      if (entry.value.isEmpty) continue;
      try {
        final file = await _file(info.id, entry.key);
        final response = await dio.get<List<int>>(
          entry.value,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
          ),
        );
        if (response.data?.isNotEmpty == true) {
          await file.writeAsBytes(response.data!, flush: true);
          data[entry.key] = file.uri.toString();
        }
      } catch (_) {
        // Keep the original URL when artwork cannot be saved.
      }
    }
    await (await _file(
      info.id,
      'json',
    )).writeAsString(jsonEncode(data), flush: true);
  }

  Future<Map<String, dynamic>> read(String id) async {
    try {
      return jsonDecode(await (await _file(id, 'json')).readAsString())
          as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> remove(String id) async {
    for (final suffix in ['json', 'avatar', 'thumbnail']) {
      final file = await _file(id, suffix);
      if (await file.exists()) await file.delete();
    }
  }
}
