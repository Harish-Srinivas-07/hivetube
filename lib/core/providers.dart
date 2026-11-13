import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'streams/net_family.dart';
import 'settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'db/app_db.dart';
import 'innertube/clients.dart';
import 'innertube/innertube_http.dart';
import 'innertube/visitor.dart';
import 'yt/yt_browse.dart';
import 'yt/yt_charts.dart';
import 'yt/yt_next.dart';
import 'yt/yt_reel.dart';
import 'yt/yt_rss.dart';
import 'yt/yt_search.dart';
import 'yt/yt_comments.dart';
import 'yt/channel_avatars.dart';
import 'yt/subscriptions_feed_service.dart';
import 'yt/backup_service.dart';
import 'yt/ryd.dart';
import 'content/caption_probe.dart';
import 'content/channel_language_cache.dart';
import 'content/content_filter.dart';
import 'content/discovery/discovery_store.dart';
import 'content/discovery/discovery_engine.dart';
import 'content/language_profile.dart';

class TabRefreshRequest {
  const TabRefreshRequest(this.index, this.sequence);

  final int index;
  final int sequence;
}

final tabRefreshProvider =
    NotifierProvider<TabRefreshController, TabRefreshRequest?>(
      TabRefreshController.new,
    );

class TabRefreshController extends Notifier<TabRefreshRequest?> {
  int _sequence = 0;

  @override
  TabRefreshRequest? build() => null;

  void request(int index) {
    state = TabRefreshRequest(index, ++_sequence);
  }
}

final dbProvider = Provider<AppDb>((ref) {
  final db = AppDb();
  ref.onDispose(db.close);
  return db;
});
final channelLanguageCacheProvider = Provider<ChannelLanguageCache>((ref) {
  final db = ref.watch(dbProvider);
  final cache = ChannelLanguageCache(db);
  ChannelLanguageCache.instance = cache;
  return cache;
});
final contentFilterProvider = Provider<ContentFilter>((ref) {
  final cache = ref.watch(channelLanguageCacheProvider);
  return ContentFilter(channelCache: cache);
});
final discoveryStoreProvider = Provider<DiscoveryStore>(
  (ref) => DiscoveryStore(ref.watch(dbProvider)),
);
final discoveryEngineProvider = FutureProvider<DiscoveryEngine>((ref) async {
  final api = await ref.watch(ytApiProvider.future);
  final probe = await ref.watch(captionProbeProvider.future);
  return DiscoveryEngine(
    store: ref.watch(discoveryStoreProvider),
    search: api.search,
    browse: api.browse,
    rss: api.rss,
    probe: probe,
    registry: LanguageProfileRegistry.instance,
  );
});
final captionProbeProvider = FutureProvider<CaptionProbeService>((ref) async {
  final http = await ref.watch(innertubeProvider.future);
  final cache = ref.watch(channelLanguageCacheProvider);
  return CaptionProbeService(http, cache);
});
final channelAvatarCacheProvider = Provider<ChannelAvatarCache>((ref) {
  final db = ref.watch(dbProvider);
  final cache = ChannelAvatarCache(read: db.getValue, write: db.setValue);
  ChannelAvatarCache.instance = cache;
  Future<void>(() => cache.load());
  return cache;
});
final networkFamilyProvider = FutureProvider<NetworkFamily>((ref) async {
  final db = ref.watch(dbProvider);
  final value = await db.getValue('network_prefer_ipv4');
  final network = NetworkFamily(
    preferIpv4: value != 'false',
    savePreference: (v) => db.setValue('network_prefer_ipv4', v.toString()),
  );
  ref.onDispose(network.close);
  return network;
});
final innertubeProvider = FutureProvider<InnertubeHttp>((ref) async {
  await ref.watch(channelAvatarCacheProvider).load();
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  final gl = ref.watch(contentPrefsProvider.select((s) => s.gl));
  final network = await ref.watch(networkFamilyProvider.future);
  void resetAdapter() {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => network.client,
    );
  }

  resetAdapter();
  network.onChanged = resetAdapter;
  return InnertubeHttp(
    dio,
    await InnertubeClients.load(
      dio,
      await rootBundle.loadString('assets/innertube_clients.json'),
    ),
    hl: 'en',
    gl: gl == 'AUTO' ? '' : gl,
  );
});
final visitorDataProvider = FutureProvider<String>((ref) async {
  final http = await ref.watch(innertubeProvider.future);
  final service = VisitorService(http, ref.watch(dbProvider));
  http.refreshVisitor = () async {
    http.visitorData = await service.get(force: true);
  };
  final revision = ref.watch(
    contentPrefsProvider.select((s) => s.prefsVersion),
  );
  final value = await service.get(force: revision > 0);
  http.visitorData = value;
  return value;
});

class YtApi {
  YtApi(InnertubeHttp http)
    : browse = YtBrowse(http),
      charts = YtCharts(http),
      search = YtSearch(http),
      next = YtNext(http),
      comments = YtComments(http),
      reel = YtReel(http),
      rss = YtRss(http.dio);
  final YtBrowse browse;
  final YtCharts charts;
  final YtSearch search;
  final YtNext next;
  final YtComments comments;
  final YtReel reel;
  final YtRss rss;
}

final ytApiProvider = FutureProvider<YtApi>((ref) async {
  await ref.watch(visitorDataProvider.future);
  return YtApi(await ref.watch(innertubeProvider.future));
});

final historyRepoProvider = Provider<HistoryRepo>(
  (ref) => StoredHistoryRepo(ref.watch(dbProvider)),
);
final subscriptionRepoProvider = Provider<SubscriptionRepo>(
  (ref) => StoredSubscriptionRepo(ref.watch(dbProvider)),
);

final subscriptionsStreamProvider = StreamProvider<List<SubscriptionRow>>((
  ref,
) {
  final db = ref.watch(dbProvider);
  return db.subscriptionsDao.watchSubscriptions();
});

final feedItemsStreamProvider = StreamProvider<List<FeedItemRow>>((ref) {
  final db = ref.watch(dbProvider);
  return db.feedItemsDao.watchFeedItems();
});

final historyStreamProvider = StreamProvider<List<HistoryItemWithMedia>>((ref) {
  final db = ref.watch(dbProvider);
  return db.historyDao.watchHistory();
});

final playlistsStreamProvider = StreamProvider<List<PlaylistRow>>((ref) {
  final db = ref.watch(dbProvider);
  return db.playlistsDao.watchPlaylists();
});

final playlistItemsStreamProvider =
    StreamProvider.family<List<PlaylistItemWithMedia>, int>((ref, playlistId) {
      final db = ref.watch(dbProvider);
      return db.playlistsDao.watchPlaylistItems(playlistId);
    });

final likedVideosStreamProvider = StreamProvider<List<MediaRow>>((ref) {
  final db = ref.watch(dbProvider);
  return db.reactionsDao.watchLikedVideos();
});

final savedRemoteStreamProvider = StreamProvider<List<SavedRemoteRow>>((ref) {
  final db = ref.watch(dbProvider);
  return db.savedRemoteDao.watchSavedRemote();
});

final recentSearchesStreamProvider = StreamProvider<List<String>>((ref) {
  final db = ref.watch(dbProvider);
  return db.searchHistoryDao.watchRecentSearches();
});

final profileStreamProvider = StreamProvider<ProfileRow?>((ref) {
  final db = ref.watch(dbProvider);
  return db.profileDao.watchProfile();
});

final subscriptionsFeedServiceProvider = Provider<SubscriptionsFeedService>((
  ref,
) {
  final db = ref.watch(dbProvider);
  final api = ref.watch(ytApiProvider).value;
  final dio = ref.watch(innertubeProvider).value?.dio ?? Dio();
  return SubscriptionsFeedService(
    db: db,
    rss: api?.rss ?? YtRss(dio),
    browse:
        api?.browse ?? YtBrowse(InnertubeHttp(dio, InnertubeClients(const {}))),
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(dbProvider));
});

final rydServiceProvider = Provider<RydService>((ref) {
  final db = ref.watch(dbProvider);
  final dio = ref.watch(innertubeProvider).value?.dio ?? Dio();
  return RydService(dio, db);
});

final hasUnreadUploadsProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(subscriptionsFeedServiceProvider);
  return service.hasUnreadUploads();
});
