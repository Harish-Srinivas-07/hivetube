import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../db/app_db.dart';
import '../providers.dart';
import '../streams/player_client.dart';
import '../streams/stream_cache.dart';
import '../streams/stream_selector.dart';
import '../yt/watch_info.dart';
import 'chunked_download.dart';
import 'download_metadata.dart';
import 'download_muxer.dart';
import 'download_notifications.dart';

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final manager = DownloadManager(
    ref.read(dbProvider),
    () async {
      final http = await ref.read(innertubeProvider.future);
      await ref.read(visitorDataProvider.future);
      final network = await ref.read(networkFamilyProvider.future);
      final client = PlayerClient(
        network,
        http.clients,
        () => http.visitorData,
        () async => http.refreshVisitor?.call(),
        gl: http.gl,
      );
      final dio = Dio();
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => network.client,
      );
      return (StreamCache(client), ChunkedDownload(dio));
    },
    notifications: ref.read(downloadNotificationsProvider),
  );
  unawaited(manager.start());
  ref.onDispose(manager.dispose);
  return manager;
});

typedef DownloadServices = Future<(StreamCache, ChunkedDownload)> Function();

class DownloadManager {
  DownloadManager(
    this.db,
    this.services, {
    this.directory,
    this.muxer = const DownloadMuxer(),
    DownloadNotifications? notifications,
  }) : notifications = notifications ?? DownloadNotifications();
  final AppDb db;
  final DownloadServices services;
  final Future<Directory> Function()? directory;
  final DownloadMuxer muxer;
  final DownloadNotifications notifications;
  Future<void>? _startup;
  bool _running = false;
  int _wakeGeneration = 0;
  bool _disposed = false;
  int? _activeId;
  CancelToken? _cancel;
  Future<void> _writes = Future.value();

  Future<void> start() => _startup ??= _recover();

  Future<void> _recover() async {
    await (db.update(db.downloads)
          ..where((t) => t.status.equals('downloading')))
        .write(const DownloadsCompanion(status: Value('queued')));
    _drain();
  }

  Future<void> enqueue(
    MediaCompanion media, {
    bool audioOnly = false,
    int? height,
    WatchInfo? info,
    void Function()? onQueued,
  }) async {
    await start();
    final id = media.videoId.value;
    int? existingId;
    String? existingStatus;
    await db.transaction(() async {
      final existing =
          await (db.select(db.downloads)..where(
                (t) =>
                    t.videoId.equals(id) &
                    t.kind.equals(audioOnly ? 'audio' : 'video'),
              ))
              .get();
      final saved = await (db.select(
        db.media,
      )..where((t) => t.videoId.equals(id))).getSingleOrNull();
      if (saved == null) {
        await db.into(db.media).insert(media);
      } else {
        await (db.update(
          db.media,
        )..where((t) => t.videoId.equals(id))).write(media);
      }
      if (existing.isNotEmpty) {
        existingId = existing.last.id;
        existingStatus = existing.last.status;
        return;
      }
      await db
          .into(db.downloads)
          .insert(
            DownloadsCompanion.insert(
              videoId: id,
              kind: audioOnly ? 'audio' : 'video',
              height: Value(height),
              status: const Value('queued'),
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    });
    if (existingId == null) onQueued?.call();
    if (info != null) {
      try {
        await metadata.save(info, thumbnailFallback: media.thumbUrl.value);
      } catch (_) {}
    }
    if (existingId != null) {
      if (existingStatus == 'failed' || existingStatus == 'paused') {
        await retry(existingId!);
      }
      return;
    }
    try {
      await notifications.initialize(requestPermission: true);
    } catch (_) {}
    _drain();
  }

  Future<List<int>> availableVideoHeights(String videoId) async {
    final (cache, _) = await services();
    final streams = await cache.candidates(videoId, PlaybackMode.video);
    final heights =
        streams.videos
            .map((format) => resolutionOf(format, PlaybackMode.video))
            .where((height) => height > 0)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return heights;
  }

  Future<void> retry(int id) async {
    await start();
    await (db.update(db.downloads)..where((t) => t.id.equals(id))).write(
      const DownloadsCompanion(status: Value('queued'), error: Value(null)),
    );
    _drain();
  }

  Future<void> pause(int id) async {
    await start();
    await (db.update(db.downloads)..where((t) => t.id.equals(id))).write(
      const DownloadsCompanion(status: Value('paused')),
    );
    if (_activeId == id) _cancel?.cancel('Paused');
    final title = await _titleFor(id);
    await notifications.paused(id, title);
  }

  Future<void> remove(DownloadRow row) async {
    await pause(row.id);
    while (_activeId == row.id) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final dir = await _directory();
    for (final suffix in ['video.part', 'audio.part', 'mp4', 'm4a', 'webm']) {
      final file = File('${dir.path}/${row.id}.$suffix');
      if (await file.exists()) await file.delete();
    }
    await (db.delete(db.downloads)..where((t) => t.id.equals(row.id))).go();
    final remaining = await (db.select(
      db.downloads,
    )..where((t) => t.videoId.equals(row.videoId))).get();
    if (remaining.isEmpty) await metadata.remove(row.videoId);
    await notifications.cancel(row.id);
  }

  Future<Directory> _directory() async {
    final root =
        await (directory?.call() ?? getApplicationDocumentsDirectory());
    return Directory('${root.path}/downloads')..createSync(recursive: true);
  }

  DownloadMetadata get metadata => DownloadMetadata(_directory);

  void _drain() {
    _wakeGeneration++;
    if (_running || _disposed) return;
    _running = true;
    unawaited(_runQueue());
  }

  Future<void> _runQueue() async {
    try {
      while (!_disposed) {
        final generation = _wakeGeneration;
        final rows =
            await (db.select(db.downloads)
                  ..where((t) => t.status.equals('queued'))
                  ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
                .get();
        if (rows.isEmpty) {
          if (generation != _wakeGeneration) continue;
          break;
        }
        final row = rows.first;
        _activeId = row.id;
        _cancel = CancelToken();
        await _run(row, _cancel!);
        _activeId = null;
        _cancel = null;
      }
    } finally {
      _activeId = null;
      _running = false;
    }
  }

  Future<void> _run(DownloadRow row, CancelToken cancel) async {
    var title = row.videoId;
    Future<void> update(DownloadsCompanion data) => (db.update(
      db.downloads,
    )..where((t) => t.id.equals(row.id))).write(data).then((_) {});
    try {
      title = await _titleFor(row.id, videoId: row.videoId);
      final claimed =
          await (db.update(db.downloads)
                ..where((t) => t.id.equals(row.id) & t.status.equals('queued')))
              .write(
                const DownloadsCompanion(
                  status: Value('downloading'),
                  error: Value(null),
                ),
              );
      if (claimed == 0) return;
      await notifications.progress(row.id, title, done: 0, total: 0);
      final (cache, transfer) = await services();
      final mode = row.kind == 'audio'
          ? PlaybackMode.audio
          : PlaybackMode.video;
      final selected = await cache.resolve(
        row.videoId,
        mode,
        quality: row.height,
      );
      final targetHeight = row.height;
      final video = row.kind == 'video'
          ? row.vItag == null
                ? selected.videos
                          .where(
                            (format) =>
                                targetHeight == null ||
                                resolutionOf(format, mode) <= targetHeight,
                          )
                          .firstOrNull ??
                      selected.videos.lastOrNull
                : selected.videos.where((f) => f.itag == row.vItag).firstOrNull
          : null;
      if (row.kind == 'video' && video == null) {
        throw const DownloadRangeException(
          'Saved rendition is no longer available',
        );
      }
      final audio = selected.audio!;
      if (video != null && row.vItag != null && video.itag != row.vItag ||
          row.aItag != null && audio.itag != row.aItag) {
        throw const DownloadRangeException(
          'Saved rendition is no longer available',
        );
      }
      final dir = await _directory();
      final videoFile = File('${dir.path}/${row.id}.video.part');
      final audioFile = File('${dir.path}/${row.id}.audio.part');
      var videoDone = row.videoDone;
      var audioDone = row.audioDone;
      final videoTotal = video?.length ?? 0;
      final audioTotal = audio.length;
      await update(
        DownloadsCompanion(
          vItag: Value(video?.itag),
          aItag: Value(audio.itag),
          height: Value(video?.height),
          videoTotal: Value(videoTotal),
          audioTotal: Value(audioTotal),
          total: Value(videoTotal + audioTotal),
        ),
      );
      Future<void> fetch(
        StreamFormat format,
        File file,
        bool isVideo,
        String? etag,
      ) async {
        if (await file.exists() && etag == null) await file.delete();
        DownloadSource source(StreamFormat f) => DownloadSource(
          url: f.url,
          itag: f.itag,
          length: f.length,
          userAgent: f.userAgent,
        );
        await transfer.transfer(
          file: file,
          source: source(format),
          cancelToken: cancel,
          expectedEtag: etag,
          refresh: (itag) async {
            cache.invalidate(row.videoId);
            final refreshed = await cache.resolve(row.videoId, mode);
            final candidates = [
              ...refreshed.videos,
              if (refreshed.audio != null) refreshed.audio!,
            ];
            return source(candidates.firstWhere((f) => f.itag == itag));
          },
          onValidator: (value) => update(
            isVideo
                ? DownloadsCompanion(videoEtag: Value(value))
                : DownloadsCompanion(audioEtag: Value(value)),
          ),
          onProgress: (done, total) {
            if (isVideo) {
              videoDone = done;
            } else {
              audioDone = done;
            }
            final v = videoDone, a = audioDone;
            _writes = _writes.then((_) async {
              await update(
                DownloadsCompanion(
                  videoDone: Value(v),
                  audioDone: Value(a),
                  done: Value(v + a),
                ),
              );
              await notifications.progress(
                row.id,
                title,
                done: v + a,
                total: videoTotal + audioTotal,
              );
            });
          },
        );
        await _writes;
      }

      if (video != null) await fetch(video, videoFile, true, row.videoEtag);
      await fetch(audio, audioFile, false, row.audioEtag);
      if (cancel.isCancelled) throw cancel.cancelError!;
      final ext = video != null
          ? 'mp4'
          : audio.mimeType.contains('mp4')
          ? 'm4a'
          : 'webm';
      final output = File('${dir.path}/${row.id}.$ext');
      if (video != null) {
        await muxer.merge(video: videoFile, audio: audioFile, output: output);
        if (cancel.isCancelled) {
          if (await output.exists()) await output.delete();
          return;
        }
        if (await videoFile.exists()) await videoFile.delete();
        if (await audioFile.exists()) await audioFile.delete();
      } else {
        await audioFile.rename(output.path);
        if (cancel.isCancelled) {
          await output.rename(audioFile.path);
          return;
        }
      }
      await update(
        DownloadsCompanion(
          status: const Value('completed'),
          path: Value(output.path),
          container: Value(ext),
          done: Value(videoTotal + audioTotal),
        ),
      );
      await notifications.completed(row.id, title);
    } catch (error) {
      await _writes;
      if (!cancel.isCancelled) {
        await update(
          DownloadsCompanion(
            status: const Value('failed'),
            error: Value(error.toString()),
          ),
        );
        await notifications.failed(row.id, title);
      }
    }
  }

  Future<String> _titleFor(int downloadId, {String? videoId}) async {
    final id =
        videoId ??
        (await (db.select(
              db.downloads,
            )..where((row) => row.id.equals(downloadId))).getSingleOrNull())
            ?.videoId;
    if (id == null) return 'HiveTube download';
    final media = await (db.select(
      db.media,
    )..where((row) => row.videoId.equals(id))).getSingleOrNull();
    final title = media?.title.trim() ?? '';
    return title.isNotEmpty ? title : id;
  }

  void dispose() {
    _disposed = true;
    _cancel?.cancel('Disposed');
  }
}
