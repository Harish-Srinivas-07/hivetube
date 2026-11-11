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

final dbProvider = Provider<AppDb>((ref) {
  final db = AppDb();
  ref.onDispose(db.close);
  return db;
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
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  final settings = ref.watch(appSettingsProvider);
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
    hl: settings.hl,
    gl: settings.gl,
  );
});
final visitorDataProvider = FutureProvider<String>((ref) async {
  final http = await ref.watch(innertubeProvider.future);
  final service = VisitorService(http, ref.watch(dbProvider));
  http.refreshVisitor = () async {
    http.visitorData = await service.get(force: true);
  };
  final settings = ref.watch(appSettingsProvider);
  final value = await service.get(force: settings.revision > 0);
  http.visitorData = value;
  return value;
});

class YtApi {
  YtApi(InnertubeHttp http)
    : browse = YtBrowse(http),
      charts = YtCharts(http),
      search = YtSearch(http),
      next = YtNext(http),
      reel = YtReel(http),
      rss = YtRss(http.dio);
  final YtBrowse browse;
  final YtCharts charts;
  final YtSearch search;
  final YtNext next;
  final YtReel reel;
  final YtRss rss;
}

final ytApiProvider = FutureProvider<YtApi>((ref) async {
  await ref.watch(visitorDataProvider.future);
  return YtApi(await ref.watch(innertubeProvider.future));
});

final historyRepoProvider = Provider<HistoryRepo>((ref) => EmptyHistoryRepo());
final subscriptionRepoProvider = Provider<SubscriptionRepo>(
  (ref) => EmptySubscriptionRepo(),
);
