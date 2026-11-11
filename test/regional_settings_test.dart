import 'dart:ui';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hivetube/core/innertube/clients.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/innertube/visitor.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/settings/app_settings.dart';

void main() {
  test('context carries selected language, country and visitor', () {
    final context = buildClientContext(
      {'clientName': 'WEB', 'clientVersion': '1'},
      hl: 'ta',
      gl: 'IN',
      visitorData: 'v',
    );
    expect(context['client'], containsPair('hl', 'ta'));
    expect(context['client'], containsPair('gl', 'IN'));
    expect(context['client'], containsPair('visitorData', 'v'));
  });
  test('visitor and Home keys distinguish locale pairs', () {
    expect(visitorCacheKey('ta', 'IN'), isNot(visitorCacheKey('hi', 'IN')));
    expect(
      homeCacheKey(const AppSettings(hl: 'en', gl: 'US')),
      isNot(homeCacheKey(const AppSettings(hl: 'en', gl: 'IN'))),
    );
    expect(AppSettings.defaults(const Locale('ta', 'IN')).cacheKey, 'ta_IN');
  });
  test('regional queries include plain search and respect the setting', () {
    expect(regionalQueries('music', const AppSettings(hl: 'ta', gl: 'IN')), [
      'tamil music',
      'music',
    ]);
    expect(
      regionalQueries('news today', const AppSettings(hl: 'hi', gl: 'IN')),
      ['hindi news today', 'news today'],
    );
    expect(regionalQueries('music', const AppSettings(hl: 'en', gl: 'US')), [
      'music',
    ]);
    expect(
      regionalQueries(
        'music',
        const AppSettings(hl: 'ta', gl: 'IN', localContent: false),
      ),
      ['music'],
    );
  });
  test('visitor cache reads only the selected language and region', () async {
    final db = AppDb(NativeDatabase.memory());
    final expiry = DateTime.now()
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;
    await db.setValue(
      visitorCacheKey('ta', 'IN'),
      jsonEncode({'value': 'tamil', 'expires': expiry}),
    );
    await db.setValue(
      visitorCacheKey('hi', 'IN'),
      jsonEncode({'value': 'hindi', 'expires': expiry}),
    );
    final dio = Dio();
    final clients = InnertubeClients({});
    expect(
      await VisitorService(
        InnertubeHttp(dio, clients, hl: 'ta', gl: 'IN'),
        db,
      ).get(),
      'tamil',
    );
    expect(
      await VisitorService(
        InnertubeHttp(dio, clients, hl: 'hi', gl: 'IN'),
        db,
      ).get(),
      'hindi',
    );
    dio.close();
    await db.close();
  });
  test('changing settings clears old and new launch cache entries', () async {
    final db = AppDb(NativeDatabase.memory());
    final old = const AppSettings(hl: 'ta', gl: 'IN');
    final next = const AppSettings(hl: 'hi', gl: 'IN');
    await db.setValue(homeCacheKey(old), 'old');
    await db.setValue(homeCacheKey(next), 'new');
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        initialAppSettingsProvider.overrideWithValue(old),
      ],
    );
    await container.read(appSettingsProvider.notifier).update(hl: 'hi');
    expect(await db.getValue(homeCacheKey(old)), isNull);
    expect(await db.getValue(homeCacheKey(next)), isNull);
    expect(container.read(appSettingsProvider).hl, 'hi');
    expect(await db.getValue('settings_hl'), 'hi');
    container.dispose();
    await db.close();
  });
}
