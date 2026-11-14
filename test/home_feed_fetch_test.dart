import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/content/caption_probe.dart';
import 'package:hivetube/core/content/channel_language_cache.dart';
import 'package:hivetube/core/content/language_profile.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/innertube/clients.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/settings/app_settings.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/yt_browse.dart';
import 'package:hivetube/core/yt/yt_charts.dart';
import 'package:hivetube/core/yt/yt_comments.dart';
import 'package:hivetube/core/yt/yt_next.dart';
import 'package:hivetube/core/yt/yt_reel.dart';
import 'package:hivetube/core/yt/yt_rss.dart';
import 'package:hivetube/core/yt/yt_search.dart';
import 'package:hivetube/features/home/home_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Home fetch displays matching videos from local search sources',
    () async {
      await LanguageProfileRegistry.instance.ensureLoaded();
      final db = AppDb(NativeDatabase.memory());
      final clients = InnertubeClients({
        'WEB': {
          'clientName': 'WEB',
          'clientVersion': 'test',
          'origin': 'https://www.youtube.com',
        },
      });
      final http = InnertubeHttp(Dio(), clients, gl: '');
      final channelCache = ChannelLanguageCache(db);
      ChannelLanguageCache.instance = channelCache;
      final api = _FakeYtApi(http);
      final probe = _FakeCaptionProbe(http, channelCache);
      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(db),
          ytApiProvider.overrideWith((ref) async => api),
          historyRepoProvider.overrideWithValue(EmptyHistoryRepo()),
          subscriptionRepoProvider.overrideWithValue(EmptySubscriptionRepo()),
          initialAppSettingsProvider.overrideWithValue(
            const AppSettings(
              gl: 'AUTO',
              contentLanguages: {'en', 'ta'},
              hiddenLanguages: {'hi'},
            ),
          ),
          captionProbeProvider.overrideWith((ref) async => probe),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final result = await container.read(homeProvider.future);

      expect(result.videos.map((item) => item.id), contains('search-video'));
      expect(probe.calls, greaterThan(0));
    },
  );

  test('caption probe uses the configured VISIONOS player client', () async {
    final db = AppDb(NativeDatabase.memory());
    final adapter = _CaptionAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final clients = InnertubeClients({
      'VISIONOS': {
        'id': '101',
        'clientName': 'VISIONOS',
        'clientVersion': '1.04',
        'clientScreen': 'WATCH',
        'platform': 'MOBILE',
        'deviceMake': 'Apple',
        'deviceModel': 'RealityDevice17,1',
        'osName': 'visionOS',
        'osVersion': '26.6.0.23O770',
        'ua': 'test-visionos',
        'origin': 'https://www.youtube.com',
      },
    });
    final probe = CaptionProbeService(
      InnertubeHttp(dio, clients, gl: ''),
      ChannelLanguageCache(db),
    );
    addTearDown(() async {
      dio.close(force: true);
      await db.close();
    });

    expect(await probe.probeVideo('test-video', asrOnly: true), 'ta');
    expect(adapter.clientContext['clientName'], 'VISIONOS');
    expect(adapter.clientContext['clientScreen'], 'WATCH');
    expect(adapter.clientContext['deviceModel'], 'RealityDevice17,1');
  });
}

class _CaptionAdapter implements HttpClientAdapter {
  Map<String, dynamic> clientContext = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data is String
        ? jsonDecode(options.data as String) as Map<String, dynamic>
        : options.data as Map<String, dynamic>;
    clientContext = Map<String, dynamic>.from(data['context']['client'] as Map);
    return ResponseBody.fromString(
      jsonEncode({
        'captions': {
          'playerCaptionsTracklistRenderer': {
            'captionTracks': [
              {'languageCode': 'ta', 'kind': 'asr'},
            ],
          },
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeYtApi extends Fake implements YtApi {
  _FakeYtApi(InnertubeHttp http)
    : browse = _FakeBrowse(http),
      charts = YtCharts(http),
      search = _FakeSearch(http),
      next = YtNext(http),
      comments = YtComments(http),
      reel = YtReel(http),
      rss = YtRss(http.dio);

  @override
  final YtBrowse browse;
  @override
  final YtCharts charts;
  @override
  final YtSearch search;
  @override
  final YtNext next;
  @override
  final YtComments comments;
  @override
  final YtReel reel;
  @override
  final YtRss rss;
}

class _FakeBrowse extends YtBrowse {
  _FakeBrowse(super.http);

  @override
  Future<VideoPage> home({
    String? continuation,
    CancelToken? cancelToken,
  }) async => const VideoPage([], null);
}

class _FakeSearch extends YtSearch {
  _FakeSearch(super.http);

  @override
  Future<VideoPage> videos(
    String query, {
    String? continuation,
    String? params,
    CancelToken? cancelToken,
  }) async => const VideoPage([
    VideoItem(id: 'search-video', title: 'Qzv blarn'),
  ], null);

  @override
  Future<ShortPage> shortsPage(
    String query, {
    String? continuation,
    CancelToken? cancelToken,
  }) async => const ShortPage([], null);
}

class _FakeCaptionProbe extends CaptionProbeService {
  _FakeCaptionProbe(super.http, super.channelCache);

  int calls = 0;

  @override
  Future<Map<String, String?>> probeBatch(
    List<({String videoId, String? channelId, String? channelName})> items, {
    bool asrOnly = false,
  }) async {
    calls++;
    return {for (final item in items) item.videoId: 'ta'};
  }
}
