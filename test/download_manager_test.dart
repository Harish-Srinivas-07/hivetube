import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/downloads/chunked_download.dart';
import 'package:hivetube/core/downloads/download_manager.dart';
import 'package:hivetube/core/downloads/download_muxer.dart';
import 'package:hivetube/core/downloads/download_notifications.dart';
import 'package:hivetube/core/streams/stream_cache.dart';
import 'package:hivetube/core/streams/stream_selector.dart';

class _Cache implements StreamCache {
  final videos = [
    StreamFormat({
      'itag': 137,
      'height': 1080,
      'contentLength': '4',
      'mimeType': 'video/mp4; codecs="avc1"',
    }, Uri.parse('https://example.com/video')),
    StreamFormat({
      'itag': 136,
      'height': 720,
      'contentLength': '4',
      'mimeType': 'video/mp4; codecs="avc1"',
    }, Uri.parse('https://example.com/video')),
  ];
  final audio = StreamFormat({
    'itag': 140,
    'contentLength': '4',
    'mimeType': 'audio/mp4',
  }, Uri.parse('https://example.com/audio'));
  int? lastQuality;
  @override
  Future<SelectedStreams> candidates(
    String id,
    PlaybackMode mode, {
    int maxHeight = 1080,
  }) async => SelectedStreams(videos, audio);
  @override
  Future<SelectedStreams> resolve(
    String id,
    PlaybackMode mode, {
    int? quality,
    int maxHeight = 1080,
  }) async {
    lastQuality = quality;
    return SelectedStreams(videos, audio);
  }

  @override
  void invalidate(String id) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notifications extends DownloadNotifications {
  int progressCalls = 0;
  int completedCalls = 0;

  @override
  Future<void> initialize({bool requestPermission = false}) async {}

  @override
  Future<void> progress(
    int downloadId,
    String title, {
    required int done,
    required int total,
  }) async {
    progressCalls++;
  }

  @override
  Future<void> completed(int downloadId, String title) async {
    completedCalls++;
  }
}

class _RangeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final range = options.headers[HttpHeaders.rangeHeader] as String;
    final matches = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
    final start = int.parse(matches[1]!);
    final end = int.parse(matches[2]!);
    final bytes = options.uri.path == '/video' ? [1, 2, 3, 4] : [5, 6, 7, 8];
    return ResponseBody.fromBytes(
      bytes.sublist(start, end + 1),
      206,
      headers: {
        HttpHeaders.contentRangeHeader: ['bytes $start-$end/4'],
        HttpHeaders.contentLengthHeader: ['${end - start + 1}'],
        HttpHeaders.etagHeader: ['"stable"'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<DownloadRow> _waitFor(AppDb db, String status) async => db
    .select(db.downloads)
    .watch()
    .map((rows) => rows.where((r) => r.status == status).firstOrNull)
    .firstWhere((row) => row != null)
    .then((row) => row!)
    .timeout(const Duration(seconds: 5));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDb db;
  late Directory dir;
  late Dio dio;
  late DownloadManager manager;
  late _Cache cache;
  late _Notifications notifications;
  setUp(() async {
    db = AppDb(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('hivetube_download_test_');
    dio = Dio()..httpClientAdapter = _RangeAdapter();
    cache = _Cache();
    notifications = _Notifications();
    manager = DownloadManager(
      db,
      () async => (cache, ChunkedDownload(dio, chunkSize: 2)),
      directory: () async => dir,
      notifications: notifications,
      muxer: DownloadMuxer(
        run: (args) async {
          await File(args.last).writeAsBytes([9, 8, 7]);
          return true;
        },
      ),
    );
  });
  tearDown(() async {
    manager.dispose();
    dio.close(force: true);
    await db.close();
    await dir.delete(recursive: true);
  });
  MediaCompanion media(String id) => MediaCompanion.insert(
    videoId: id,
    title: 'Title',
    channelId: 'channel',
    channelName: 'Channel',
    thumbUrl: '',
    updatedAt: 1,
  );

  test('queues, transfers, merges, stores progress and deduplicates', () async {
    await Future.wait([
      manager.enqueue(media('one')),
      manager.enqueue(media('one')),
    ]);
    final row = await _waitFor(db, 'completed');
    expect(row.done, 8);
    expect(row.total, 8);
    expect(await File(row.path!).readAsBytes(), [9, 8, 7]);
    expect((await db.select(db.downloads).get()).length, 1);
    expect(
      await File('${dir.path}/downloads/${row.id}.video.part').exists(),
      isFalse,
    );
  });

  test('recovers an interrupted queued download after restart', () async {
    await db
        .into(db.downloads)
        .insert(
          DownloadsCompanion.insert(
            videoId: 'one',
            kind: 'audio',
            status: const Value('downloading'),
            createdAt: 1,
          ),
        );
    await manager.start();
    final row = await _waitFor(db, 'completed');
    expect(row.done, 4);
    expect(await File(row.path!).readAsBytes(), [5, 6, 7, 8]);
  });

  test(
    'uses the requested quality and reports notification progress',
    () async {
      await manager.enqueue(media('quality'), height: 720);
      final row = await _waitFor(db, 'completed');
      expect(cache.lastQuality, 720);
      expect(row.vItag, 136);
      expect(row.height, 720);
      expect(notifications.progressCalls, greaterThan(0));
      expect(notifications.completedCalls, 1);
    },
  );
}
