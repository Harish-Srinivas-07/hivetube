@Tags(['full-audit'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/app/router.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/subscriptions_feed_service.dart';
import 'package:hivetube/core/yt/yt_browse.dart';
import 'package:hivetube/core/yt/yt_charts.dart';
import 'package:hivetube/core/yt/yt_comments.dart';
import 'package:hivetube/core/yt/yt_next.dart';
import 'package:hivetube/core/yt/yt_reel.dart';
import 'package:hivetube/core/yt/yt_rss.dart';
import 'package:hivetube/core/yt/yt_search.dart';
import 'package:hivetube/features/home/home_cache.dart';
import 'package:hivetube/features/home/home_controller.dart';
import 'package:hivetube/features/shorts/shorts_screen.dart';
import 'package:hivetube/main.dart';

class _NoPlayback extends PlaybackController {
  @override
  PlaybackService? build() => null;
}

class _SelectedShorts extends ShortsSelectionController {
  _SelectedShorts(this.initial);
  final ShortsSelection initial;
  @override
  ShortsSelection build() => initial;
}

class _History implements HistoryRepo {
  _History(this.entries);
  final List<HistoryEntry> entries;
  @override
  Future<List<HistoryEntry>> recent() async => entries;
  @override
  Future<Set<String>> dislikedChannels() async => {};
  @override
  Future<void> save(HistoryEntry entry) async {}
}

class _StaticHome extends HomeController {
  @override
  Future<HomeData> build() async => const HomeData(
    videos: [
      VideoItem(
        id: 'audit_home_1',
        title: 'Audit Video 1',
        channelName: 'Audit Channel',
        thumbUrl: '',
      ),
    ],
    shorts: [
      ShortItem(id: 'audit_short_1', thumbUrl: '', title: 'Audit Short 1'),
    ],
  );
}

class _FakeSubscriptionsFeedService extends Fake
    implements SubscriptionsFeedService {
  @override
  Future<void> markTabOpened() async {}
  @override
  Future<void> backfillSubscriptionDetails() async {}
  @override
  Future<void> refreshFeed({bool force = false}) async {}
}

class _FakeBrowse extends Fake implements YtBrowse {}

class _FakeSearch extends Fake implements YtSearch {
  @override
  Future<ShortPage> shortsPage(
    String query, {
    String? continuation,
    CancelToken? cancelToken,
  }) async => const ShortPage([], null);
}

class _FakeReel extends Fake implements YtReel {
  @override
  Future<ReelPage> fetch({
    String? continuation,
    int count = 12,
    int maxContinuations = 5,
    CancelToken? cancelToken,
  }) async => const ReelPage([], null, 0);

  @override
  Future<ShortItem?> metadata(String id) async => null;
}

class _FakeRss extends Fake implements YtRss {}

class _FakeNext extends Fake implements YtNext {}

class _FakeComments extends Fake implements YtComments {}

class _FakeCharts extends Fake implements YtCharts {}

class _FakeYtApi extends Fake implements YtApi {
  @override
  final YtBrowse browse = _FakeBrowse();
  @override
  final YtSearch search = _FakeSearch();
  @override
  final YtReel reel = _FakeReel();
  @override
  final YtRss rss = _FakeRss();
  @override
  final YtNext next = _FakeNext();
  @override
  final YtComments comments = _FakeComments();
  @override
  final YtCharts charts = _FakeCharts();
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => Directory.systemTemp.path,
        );
  });

  final outDir = Directory('docs/ui_audit/after');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  final devices = [
    (name: 'phone_360x800', size: const Size(360, 800)),
    (name: 'tablet_834x1194', size: const Size(834, 1194)),
    (name: 'desktop_1280x800', size: const Size(1280, 800)),
  ];

  final themes = [(name: 'dark', brightness: Brightness.dark)];

  final textScales = [1.0];

  final routes = [
    (name: 'home', path: '/home'),
    (name: 'shorts', path: '/shorts'),
    (name: 'settings', path: '/settings'),
  ];

  group('UI Multi-device Golden & Overflow Verification', () {
    for (final dev in devices) {
      for (final th in themes) {
        for (final scale in textScales) {
          for (final r in routes) {
            testWidgets(
              '${dev.name} ${th.name} scale_$scale ${r.name} screen audit',
              tags: 'full-audit',
              timeout: const Timeout(Duration(seconds: 60)),
              (tester) async {
                tester.view.physicalSize = dev.size;
                tester.view.devicePixelRatio = 1.0;
                tester.platformDispatcher.platformBrightnessTestValue =
                    th.brightness;
                addTearDown(tester.view.resetPhysicalSize);
                addTearDown(tester.view.resetDevicePixelRatio);
                addTearDown(
                  tester.platformDispatcher.clearPlatformBrightnessTestValue,
                );

                final db = AppDb(NativeDatabase.memory());
                addTearDown(db.close);

                int overflowErrors = 0;
                final prevOnError = FlutterError.onError;
                addTearDown(() => FlutterError.onError = prevOnError);
                FlutterError.onError = (details) {
                  if (details.exceptionAsString().contains('overflowed') ||
                      details.exceptionAsString().contains('RenderFlex')) {
                    overflowErrors++;
                  }
                  prevOnError?.call(details);
                };

                final repaintKey = GlobalKey();
                const selection = ShortsSelection(
                  items: [
                    ShortItem(
                      id: 'audit_short_1',
                      thumbUrl: '',
                      title: 'Audit Short 1',
                    ),
                    ShortItem(
                      id: 'audit_short_2',
                      thumbUrl: '',
                      title: 'Audit Short 2',
                    ),
                  ],
                  index: 0,
                );
                final cache = HomeCache(
                  const [
                    VideoItem(
                      id: 'audit_home_1',
                      title: 'Audit Video 1',
                      channelName: 'Audit Channel',
                      thumbUrl: '',
                    ),
                  ],
                  const [],
                  DateTime.now(),
                );

                Widget buildAuditApp() => ProviderScope(
                  overrides: [
                    dbProvider.overrideWithValue(db),
                    ytApiProvider.overrideWith((ref) async => _FakeYtApi()),
                    shortsSelectionProvider.overrideWith(
                      () => _SelectedShorts(selection),
                    ),
                    playbackProvider.overrideWith(_NoPlayback.new),
                    homeProvider.overrideWith(_StaticHome.new),
                    subscriptionsFeedServiceProvider.overrideWithValue(
                      _FakeSubscriptionsFeedService(),
                    ),
                    initialHomeCacheProvider.overrideWithValue(cache),
                    historyRepoProvider.overrideWithValue(_History(const [])),
                  ],
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: dev.size,
                      textScaler: TextScaler.linear(scale),
                      platformBrightness: th.brightness,
                    ),
                    child: RepaintBoundary(
                      key: repaintKey,
                      child: const HiveTubeApp(),
                    ),
                  ),
                );

                appRouter.go(r.path);
                await tester.pumpWidget(buildAuditApp());
                await tester.pump(const Duration(milliseconds: 100));

                // Capture image for screenshot documentation
                try {
                  final ro = repaintKey.currentContext?.findRenderObject();
                  if (ro is RenderRepaintBoundary) {
                    final image = await ro.toImage(pixelRatio: 1.0);
                    final byteData = await image.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    if (byteData != null) {
                      final filename =
                          '${dev.name}_${th.name}_scale${scale}_${r.name}.png';
                      File(
                        '${outDir.path}/$filename',
                      ).writeAsBytesSync(byteData.buffer.asUint8List());
                    }
                  }
                } catch (_) {}

                expect(
                  overflowErrors,
                  0,
                  reason:
                      'RenderFlex overflow detected on ${dev.name} ${th.name} scale $scale',
                );
              },
            );
          }
        }
      }
    }
  });
}
