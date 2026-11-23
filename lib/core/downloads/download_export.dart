import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_db.dart';

typedef ExportWriter =
    Future<String?> Function({
      required String path,
      required String name,
      required String extension,
      required String mime,
    });

final downloadExportProvider = Provider<DownloadExportService>(
  (ref) => DownloadExportService(),
);

class DownloadExportService {
  DownloadExportService({
    Future<bool> Function()? supported,
    ExportWriter? saveDownloads,
    ExportWriter? saveGallery,
  }) : _supported = supported ?? _isSupported,
       _saveDownloads = saveDownloads ?? _downloads,
       _saveGallery = saveGallery ?? _gallery;

  final Future<bool> Function() _supported;
  final ExportWriter _saveDownloads;
  final ExportWriter _saveGallery;
  final Set<int> _active = {};

  static Future<bool> _isSupported() async =>
      Platform.isAndroid &&
      (await DeviceInfoPlugin().androidInfo).version.sdkInt >= 29;

  static Future<String?> _downloads({
    required String path,
    required String name,
    required String extension,
    required String mime,
  }) => FileSaver.instance.saveToDownloads(
    name: name,
    filePath: path,
    fileExtension: extension,
    mimeType: MimeType.custom,
    customMimeType: mime,
  );

  static Future<String?> _gallery({
    required String path,
    required String name,
    required String extension,
    required String mime,
  }) => FileSaver.instance.saveToGallery(
    name: name,
    filePath: path,
    fileExtension: extension,
    mimeType: MimeType.custom,
    customMimeType: mime,
    album: 'HiveTube',
  );

  Future<void> export(DownloadRow row, String title) async {
    if (!_active.add(row.id)) throw StateError('Export already in progress');
    try {
      if (!await _supported()) {
        throw UnsupportedError('Saving requires Android 10 or later');
      }
      final path = row.path;
      if (row.status != 'completed' ||
          path == null ||
          !await File(path).exists()) {
        throw StateError('Downloaded file is unavailable');
      }
      final filename = Uri.file(path).pathSegments.last;
      final extension = filename.contains('.')
          ? filename.split('.').last.toLowerCase()
          : '';
      final mime = switch ((row.kind, extension)) {
        ('video', 'mp4') => 'video/mp4',
        ('video', 'webm') => 'video/webm',
        ('audio', 'mp3') => 'audio/mpeg',
        ('audio', 'm4a') => 'audio/mp4',
        ('audio', 'webm') => 'audio/webm',
        _ => throw UnsupportedError('Unsupported download format'),
      };
      final cleaned = title
          .replaceAll(RegExp(r'[\x00-\x1f<>:"/\\|?*]'), ' ')
          .trim()
          .replaceAll(RegExp(r'\s+'), ' ');
      final base = cleaned.isEmpty
          ? 'Video'
          : String.fromCharCodes(cleaned.runes.take(80));
      final safeId = row.videoId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
      final name =
          '${base}_${safeId}_${DateTime.now().microsecondsSinceEpoch}_HiveTibe';
      final downloadUri = await _saveDownloads(
        path: path,
        name: name,
        extension: extension,
        mime: mime,
      );
      if (downloadUri == null || downloadUri.isEmpty) {
        throw StateError('Could not save to Downloads');
      }
      if (row.kind == 'video') {
        try {
          final galleryUri = await _saveGallery(
            path: path,
            name: name,
            extension: extension,
            mime: mime,
          );
          if (galleryUri == null || galleryUri.isEmpty) {
            throw StateError('Gallery save failed');
          }
        } catch (_) {
          throw const GalleryExportException();
        }
      }
    } finally {
      _active.remove(row.id);
    }
  }
}

class GalleryExportException implements Exception {
  const GalleryExportException();
}
