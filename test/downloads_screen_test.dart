import 'package:drift/drift.dart' show Value;
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/downloads/download_manager.dart';
import 'package:hivetube/core/downloads/download_metadata.dart';
import 'package:hivetube/core/downloads/download_export.dart';
import 'package:hivetube/core/yt/watch_info.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/features/downloads/downloads_screen.dart';
import 'package:hivetube/features/watch/watch_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _NoPlayback extends PlaybackController {
  @override
  PlaybackService? build() => null;
}

class _FakeExport extends DownloadExportService {
  String? title;
  @override
  Future<void> export(DownloadRow row, String title) async {
    this.title = title;
  }
}

class _ArtworkAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes([1, 2, 3], 200);
  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'export copies video and audio with their real extension and suffix',
    () async {
      final dir = await Directory.systemTemp.createTemp('export_test_');
      addTearDown(() => dir.delete(recursive: true));
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final video = File('${dir.path}/source.mp4');
      final audio = File('${dir.path}/source.m4a');
      await video.writeAsBytes([1, 2, 3]);
      await audio.writeAsBytes([4, 5]);
      final videoId = await db
          .into(db.downloads)
          .insert(
            DownloadsCompanion.insert(
              videoId: 'video',
              kind: 'video',
              status: const Value('completed'),
              path: Value(video.path),
              createdAt: 1,
            ),
          );
      final audioId = await db
          .into(db.downloads)
          .insert(
            DownloadsCompanion.insert(
              videoId: 'audio',
              kind: 'audio',
              status: const Value('completed'),
              path: Value(audio.path),
              createdAt: 2,
            ),
          );
      final calls = <String>[];
      Future<String?> save({
        required String path,
        required String name,
        required String extension,
        required String mime,
      }) async {
        calls.add('$name.$extension|$mime');
        expect(await File(path).exists(), isTrue);
        return 'content://saved';
      }

      final exporter = DownloadExportService(
        supported: () async => true,
        saveDownloads: save,
        saveGallery: save,
      );
      final videoRow = await (db.select(
        db.downloads,
      )..where((row) => row.id.equals(videoId))).getSingle();
      final audioRow = await (db.select(
        db.downloads,
      )..where((row) => row.id.equals(audioId))).getSingle();
      await exporter.export(videoRow, 'Video / title');
      expect(calls.length, 2);
      expect(
        calls[0],
        matches(RegExp(r'^Video title_video_\d+_HiveTibe\.mp4\|video/mp4$')),
      );
      expect(calls[1], calls[0]);
      await exporter.export(audioRow, 'Audio');
      expect(calls.length, 3);
      expect(
        calls.last,
        matches(RegExp(r'^Audio_audio_\d+_HiveTibe\.m4a\|audio/mp4$')),
      );
      expect(await video.readAsBytes(), [1, 2, 3]);
      expect(await audio.readAsBytes(), [4, 5]);
      final failingGallery = DownloadExportService(
        supported: () async => true,
        saveDownloads: save,
        saveGallery:
            ({
              required path,
              required name,
              required extension,
              required mime,
            }) async => throw StateError('offline storage'),
      );
      await expectLater(
        failingGallery.export(videoRow, 'Video'),
        throwsA(isA<GalleryExportException>()),
      );
      expect(await video.readAsBytes(), [1, 2, 3]);
    },
  );
  test('offline download retains metadata and local artwork', () async {
    final dir = await Directory.systemTemp.createTemp('offline_metadata_');
    addTearDown(() => dir.delete(recursive: true));
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final manager = DownloadManager(
      db,
      () async => throw StateError('offline'),
      directory: () async => dir,
    );
    addTearDown(manager.dispose);
    final dio = Dio()..httpClientAdapter = _ArtworkAdapter();
    addTearDown(() => dio.close(force: true));
    await DownloadMetadata(
      () async =>
          Directory('${dir.path}/downloads')..createSync(recursive: true),
      dio: dio,
    ).save(
      const WatchInfo(
        id: 'offline',
        title: 'Title',
        channelName: 'Channel',
        channelId: 'c',
        avatar: 'https://example.com/avatar',
        thumbnail: 'https://example.com/thumb',
        subscribers: '100 subscribers',
        description: 'Saved description',
        likes: '5',
        views: '42 views',
        date: 'Today',
        handle: '@channel',
        commentsToken: null,
        related: VideoPage([], null),
        chapters: [WatchChapter('Intro', Duration(seconds: 3))],
        chips: {},
        durationSec: 25,
      ),
    );
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            videoId: 'offline',
            title: 'Title',
            channelId: 'c',
            channelName: 'Channel',
            thumbUrl: '',
            updatedAt: 1,
          ),
        );
    await db
        .into(db.downloads)
        .insert(
          DownloadsCompanion.insert(
            videoId: 'offline',
            kind: 'video',
            status: const Value('completed'),
            createdAt: 1,
          ),
        );
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        downloadManagerProvider.overrideWithValue(manager),
        ytApiProvider.overrideWith((ref) async => throw StateError('offline')),
      ],
    );
    addTearDown(container.dispose);
    final info = await container.read(watchInfoProvider('offline').future);
    expect(info.description, 'Saved description');
    expect(info.views, '42 views');
    expect(info.durationSec, 25);
    expect(info.chapters.single.start, const Duration(seconds: 3));
    expect(await File.fromUri(Uri.parse(info.avatar)).readAsBytes(), [1, 2, 3]);
    expect(await File.fromUri(Uri.parse(info.thumbnail)).readAsBytes(), [
      1,
      2,
      3,
    ]);
  });
  test('offline watch details use saved download metadata', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            videoId: 'offline',
            title: 'Saved title',
            channelId: 'c',
            channelName: 'Saved channel',
            thumbUrl: '',
            updatedAt: 1,
          ),
        );
    await db
        .into(db.downloads)
        .insert(
          DownloadsCompanion.insert(
            videoId: 'offline',
            kind: 'video',
            status: const Value('completed'),
            createdAt: 1,
          ),
        );
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        ytApiProvider.overrideWith((ref) async => throw StateError('offline')),
      ],
    );
    addTearDown(container.dispose);
    final info = await container.read(watchInfoProvider('offline').future);
    expect(info.title, 'Saved title');
    expect(info.channelName, 'Saved channel');
  });

  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  testWidgets('completed video offers export to gallery and downloads', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('download_size_'),
    ))!;
    addTearDown(() => directory.delete(recursive: true));
    final savedFile = File('${directory.path}/video.mp4');
    await tester.runAsync(() => savedFile.writeAsBytes(List.filled(2048, 0)));
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            videoId: 'one',
            title: 'Saved video',
            channelId: 'c',
            channelName: 'Channel',
            thumbUrl: '',
            updatedAt: 1,
          ),
        );
    await db
        .into(db.downloads)
        .insert(
          DownloadsCompanion.insert(
            videoId: 'one',
            kind: 'video',
            status: const Value('completed'),
            height: const Value(720),
            path: Value(savedFile.path),
            createdAt: 1,
          ),
        );
    final manager = DownloadManager(
      db,
      () async => throw StateError('offline'),
    );
    final exporter = _FakeExport();
    addTearDown(manager.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_NoPlayback.new),
          downloadManagerProvider.overrideWithValue(manager),
          downloadExportProvider.overrideWithValue(exporter),
          downloadFileSizeProvider.overrideWith((ref, path) async => 2048),
        ],
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final thumbnail = tester.getRect(
      find.byKey(const ValueKey('compactThumbnail:one')),
    );
    final metadata = tester.getRect(find.text('720p · Downloaded'));
    expect(metadata.left, greaterThanOrEqualTo(thumbnail.right));
    expect(metadata.top, lessThan(thumbnail.bottom));
    expect(metadata.top, greaterThan(tester.getRect(find.text('Channel')).top));
    expect(find.text('2.0 KB'), findsOneWidget);
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to Gallery and Downloads'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(exporter.title, 'Saved video');
    expect(find.text('Saved to Gallery and Downloads'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
  testWidgets('download progress overlays its thumbnail and tracks updates', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('download_overlay_'),
    ))!;
    addTearDown(() => dir.delete(recursive: true));
    final manager = DownloadManager(
      db,
      () async => throw StateError('unused'),
      directory: () async => dir,
    );
    addTearDown(manager.dispose);
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            videoId: 'progress',
            title: 'Video',
            channelId: '',
            channelName: '',
            thumbUrl: '',
            updatedAt: 1,
          ),
        );
    final id = await db
        .into(db.downloads)
        .insert(
          DownloadsCompanion.insert(
            videoId: 'progress',
            kind: 'video',
            status: const Value('downloading'),
            total: const Value(100),
            done: const Value(25),
            videoTotal: const Value(60),
            audioTotal: const Value(40),
            createdAt: 1,
          ),
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          downloadManagerProvider.overrideWithValue(manager),
          playbackProvider.overrideWith(_NoPlayback.new),
        ],
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final thumb = tester.getRect(
      find.byKey(const ValueKey('compactThumbnail:progress')),
    );
    expect(thumb.contains(tester.getCenter(find.text('25%'))), isTrue);
    expect(find.text('25 B downloaded\n~75 B remaining'), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      .25,
    );
    await tester.runAsync(
      () => (db.update(db.downloads)..where((row) => row.id.equals(id))).write(
        const DownloadsCompanion(done: Value(75)),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('75 B downloaded\n~25 B remaining'), findsOneWidget);
    await tester.runAsync(
      () => (db.update(db.downloads)..where((row) => row.id.equals(id))).write(
        const DownloadsCompanion(status: Value('completed')),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
  testWidgets('shows failed downloads and retry actions', (tester) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.media)
        .insert(
          MediaCompanion.insert(
            videoId: 'one',
            title: 'Saved video',
            channelId: 'c',
            channelName: 'Channel',
            thumbUrl: '',
            durationSec: const Value(3862),
            updatedAt: 1,
          ),
        );
    await db
        .into(db.downloads)
        .insert(
          DownloadsCompanion.insert(
            videoId: 'one',
            kind: 'video',
            height: const Value(720),
            status: const Value('failed'),
            createdAt: 1,
          ),
        );
    final manager = DownloadManager(
      db,
      () async => throw StateError('offline'),
    );
    addTearDown(manager.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          playbackProvider.overrideWith(_NoPlayback.new),
          downloadManagerProvider.overrideWithValue(manager),
        ],
        child: const MaterialApp(home: DownloadsScreen()),
      ),
    );
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Saved video'), findsOneWidget);
    expect(find.text('1:04:22'), findsOneWidget);
    expect(find.text('720p · Failed'), findsOneWidget);
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Remove download'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
