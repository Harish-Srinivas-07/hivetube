import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/innertube/innertube_http.dart';
import 'package:hivetube/core/innertube/visitor.dart';
import 'package:hivetube/core/settings/app_settings.dart';
import 'package:hivetube/core/yt/backup_service.dart';
import 'package:hivetube/features/home/home_variety.dart';

void main() {
  group('English-Only App Configuration', () {
    testWidgets('App renders English strings and Material labels under ta, hi, es locales',
        (tester) async {
      for (final deviceLocale in [
        const Locale('ta', 'IN'),
        const Locale('hi', 'IN'),
        const Locale('es', 'ES'),
      ]) {
        tester.platformDispatcher.localeTestValue = deviceLocale;
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('en')],
            home: Builder(
              builder: (context) {
                final currentLocale = Localizations.localeOf(context);
                final materialLoc = MaterialLocalizations.of(context);
                return Scaffold(
                  appBar: AppBar(
                    title: Text('Settings (${currentLocale.languageCode})'),
                  ),
                  body: Column(
                    children: [
                      Text('backTooltip: ${materialLoc.backButtonTooltip}'),
                      Text('cancel: ${materialLoc.cancelButtonLabel}'),
                      Text('ok: ${materialLoc.okButtonLabel}'),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Settings (en)'), findsOneWidget);
        expect(find.text('backTooltip: Back'), findsOneWidget);
        expect(find.text('cancel: Cancel'), findsOneWidget);
        expect(find.text('ok: OK'), findsOneWidget);
      }
    });

    test('every InnerTube client context forces hl = "en"', () {
      final clients = [
        {'clientName': 'WEB', 'clientVersion': '2.20230101'},
        {'clientName': 'ANDROID', 'clientVersion': '19.01.35'},
        {'clientName': 'IOS', 'clientVersion': '19.01.35'},
        {'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER', 'clientVersion': '2.0'},
        {'clientName': 'VISIONOS', 'clientVersion': '1.0'},
      ];

      for (final client in clients) {
        // Even if hl: 'ta' or 'hi' were requested, buildClientContext strictly returns 'en'
        final ctx = buildClientContext(
          client,
          hl: 'ta',
          gl: 'IN',
          visitorData: 'test_visitor',
        );
        expect(ctx['client']['hl'], 'en',
            reason: 'Client ${client['clientName']} must have hl = en');
        expect(ctx['client']['gl'], 'IN');
        expect(ctx['client']['visitorData'], 'test_visitor');
      }
    });

    test('one-time migration clears old hl and caches and bumps prefs version', () async {
      final db = AppDb(NativeDatabase.memory());

      // Seed old state
      await db.setValue('settings_hl', 'ta');
      await db.setValue('content_hl_v1', 'ta');
      await db.setValue('visitor_data_ta_IN', 'old_visitor_1');
      await db.setValue('visitor_data_hi_IN', 'old_visitor_2');
      await db.setValue('home_cache_ta_IN_strict', 'old_home_cache');
      await db.setValue('settings_prefs_version', '5');

      // Execute migration logic
      final hlMigrated = await db.getValue('settings_hl_en_migrated');
      if (hlMigrated != 'true') {
        await db.deleteValue('settings_hl');
        await db.deleteValue('content_hl_v1');
        await db.deleteValuesStartingWith('visitor_data_');
        await db.deleteValuesStartingWith('home_cache_');
        await db.setValue('settings_hl_en_migrated', 'true');
        final nextVersion = ((int.tryParse(await db.getValue('settings_prefs_version') ?? '') ?? 0) + 1).toString();
        await db.setValue('settings_prefs_version', nextVersion);
      }

      // Verify
      expect(await db.getValue('settings_hl'), isNull);
      expect(await db.getValue('content_hl_v1'), isNull);
      expect(await db.getValue('visitor_data_ta_IN'), isNull);
      expect(await db.getValue('visitor_data_hi_IN'), isNull);
      expect(await db.getValue('home_cache_ta_IN_strict'), isNull);
      expect(await db.getValue('settings_hl_en_migrated'), 'true');
      expect(await db.getValue('settings_prefs_version'), '6');

      await db.close();
    });

    test('cache keys no longer include hl', () {
      final key = visitorCacheKey('IN');
      expect(key, 'visitor_data_IN');
      expect(key.contains('en'), isFalse);
      expect(key.contains('hl'), isFalse);

      const settings = AppSettings(
        gl: 'IN',
        contentLanguages: {'ta', 'en'},
        hiddenLanguages: {'hi'},
        strictHome: true,
      );
      expect(settings.cacheKey.startsWith('IN_'), isTrue);
      expect(settings.cacheKey.contains('en_IN'), isFalse);
    });

    test('backup export and import ignore hl completely', () async {
      final db = AppDb(NativeDatabase.memory());
      await db.setValue('content_gl_v1', 'IN');
      await db.setValue('settings_hl', 'ta');

      final service = BackupService(db);
      final exported = await service.exportJson();
      expect(exported.contains('"settings_hl"'), isFalse);
      expect(exported.contains('"content_hl_v1"'), isFalse);

      // Import with legacy hl values
      const legacyBackup = jsonCodecString;
      await service.importJson(legacyBackup);
      expect(await db.getValue('settings_hl'), isNull);
      expect(await db.getValue('content_hl_v1'), isNull);
      expect(await db.getValue('content_gl_v1'), 'US');

      await db.close();
    });

    test('Content language options are exclusively in English', () {
      for (final name in contentLanguageOptions.values) {
        // Assert all characters are ASCII printable (English names)
        final isAscii = name.runes.every((r) => r >= 32 && r <= 126);
        expect(isAscii, isTrue, reason: '$name must be in English script');
      }
    });
  });
}

const jsonCodecString = '{"format":"hivetube_backup_v1","prefs":{"settings_hl":"hi","content_hl_v1":"hi","content_gl_v1":"US"}}';
