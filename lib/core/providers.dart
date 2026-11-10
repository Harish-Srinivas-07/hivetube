import 'package:dio/dio.dart';
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
final innertubeProvider = FutureProvider<InnertubeHttp>((ref) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return InnertubeHttp(
    dio,
    await InnertubeClients.load(
      dio,
      await rootBundle.loadString('assets/innertube_clients.json'),
    ),
  );
});
final visitorDataProvider = FutureProvider<String>((ref) async {
  final http = await ref.watch(innertubeProvider.future);
  final service = VisitorService(http, ref.watch(dbProvider));
  http.refreshVisitor = () async {
    http.visitorData = await service.get(force: true);
  };
  final value = await service.get();
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
