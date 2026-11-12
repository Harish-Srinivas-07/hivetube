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
  test('context always forces English hl with selected country and visitor', () {
    final context = buildClientContext(
      {'clientName': 'WEB', 'clientVersion': '1'},
      hl: 'ta',
      gl: 'IN',
      visitorData: 'v',
    );
    expect(context['client'], containsPair('hl', 'en'));
    expect(context['client'], containsPair('gl', 'IN'));
    expect(context['client'], containsPair('visitorData', 'v'));
  });
  test('visitor and Home keys distinguish regions and content languages without hl', () {
    expect(visitorCacheKey('US'), isNot(visitorCacheKey('IN')));
    expect(
      homeCacheKey(const AppSettings(gl: 'US')),
      isNot(homeCacheKey(const AppSettings(gl: 'IN'))),
    );
    expect(homeCacheKey(const AppSettings(gl: 'IN')).contains('en_IN'), isFalse);
    expect(AppSettings.defaults().cacheKey.contains('en_'), isFalse);
    expect(AppSettings.defaults().contentLanguages, {
      'ta',
      'en',
    });
    expect(AppSettings.defaults().hiddenLanguages, {
      'hi',
    });
  });
  test('regional queries include plain search and respect the region setting', () {
    expect(regionalQueries('music', const AppSettings(gl: 'IN')), [
      'indian music',
      'music',
    ]);
    expect(
      regionalQueries('news today', const AppSettings(gl: 'IN')),
      ['indian news today', 'news today'],
    );
    expect(regionalQueries('music', const AppSettings(gl: 'US')), [
      'music',
    ]);
    expect(
      regionalQueries(
        'music',
        const AppSettings(gl: 'IN', localContent: false),
      ),
      ['music'],
    );
  });
  test('visitor cache reads only the selected region', () async {
    final db = AppDb(NativeDatabase.memory());
    final expiry = DateTime.now()
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;
    await db.setValue(
      visitorCacheKey('IN'),
      jsonEncode({'value': 'india_visitor', 'expires': expiry}),
    );
    await db.setValue(
      visitorCacheKey('US'),
      jsonEncode({'value': 'us_visitor', 'expires': expiry}),
    );
    final dio = Dio();
    final clients = InnertubeClients({});
    expect(
      await VisitorService(
        InnertubeHttp(dio, clients, gl: 'IN'),
        db,
      ).get(),
      'india_visitor',
    );
    expect(
      await VisitorService(
        InnertubeHttp(dio, clients, gl: 'US'),
        db,
      ).get(),
      'us_visitor',
    );
    dio.close();
    await db.close();
  });
  test('changing settings clears old and new launch cache entries', () async {
    final db = AppDb(NativeDatabase.memory());
    final old = const AppSettings(gl: 'IN');
    final next = const AppSettings(gl: 'US');
    await db.setValue(homeCacheKey(old), 'old');
    await db.setValue(homeCacheKey(next), 'new');
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        initialAppSettingsProvider.overrideWithValue(old),
      ],
    );
    await container.read(appSettingsProvider.notifier).update(gl: 'US');
    expect(await db.getValue(homeCacheKey(old)), isNull);
    expect(await db.getValue(homeCacheKey(next)), isNull);
    expect(container.read(appSettingsProvider).hl, 'en');
    expect(await db.getValue('settings_hl'), isNull);
    container.dispose();
    await db.close();
  });
}
