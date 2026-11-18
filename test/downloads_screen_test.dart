import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/downloads/download_manager.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/features/downloads/downloads_screen.dart';
import 'package:hivetube/features/watch/watch_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _NoPlayback extends PlaybackController {
  @override
  PlaybackService? build() => null;
}

void main() {
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
    expect(find.text('720p · Failed'), findsOneWidget);
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Remove download'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
