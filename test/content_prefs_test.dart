import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/settings/app_settings.dart';

void main() {
  test(
    'persists preferences and increments prefsVersion once per change',
    () async {
      final db = AppDb(NativeDatabase.memory());
      final initial = AppSettings.defaults(const Locale('en', 'IN'));
      final container = ProviderContainer(
        overrides: [
          dbProvider.overrideWithValue(db),
          initialAppSettingsProvider.overrideWithValue(initial),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);
      final oldKey = homeCacheKey(initial);
      await db.setValue(oldKey, 'initial-cache');

      await container
          .read(contentPrefsProvider.notifier)
          .update(
            contentLanguages: {'ta', 'en'},
            hiddenLanguages: {'hi'},
            gl: 'AUTO',
            localRatio: .6,
          );
      expect(container.read(contentPrefsProvider).prefsVersion, 0);
      expect(await db.getValue(oldKey), 'initial-cache');

      const next = AppSettings(
        gl: 'US',
        contentLanguages: {'te'},
        hiddenLanguages: {'hi'},
        localRatio: .8,
        revision: 1,
      );
      final nextKey = homeCacheKey(next);
      await db.setValue(nextKey, 'next-cache');
      await container
          .read(contentPrefsProvider.notifier)
          .update(
            contentLanguages: {'te'},
            hiddenLanguages: {'hi'},
            gl: 'US',
            localRatio: .8,
          );

      final prefs = container.read(contentPrefsProvider);
      expect(prefs.prefsVersion, 1);
      expect(prefs.hl, 'en');
      expect(prefs.gl, 'US');
      expect(prefs.contentLanguages, {'te'});
      expect(prefs.hiddenLanguages, {'hi'});
      expect(prefs.localRatio, .8);
      expect(await db.getValue('settings_content_languages'), 'te');
      expect(await db.getValue('settings_hidden_languages'), 'hi');
      expect(await db.getValue('settings_gl'), 'US');
      expect(await db.getValue('settings_local_ratio'), '0.8');
      expect(await db.getValue('settings_prefs_version'), '1');
      expect(await db.getValue(oldKey), isNull);
      expect(await db.getValue(nextKey), isNull);
    },
  );

  test('home cache keys vary with shown, hidden and region preferences', () {
    const base = AppSettings(hl: 'en', gl: 'IN');
    expect(
      homeCacheKey(base),
      isNot(
        homeCacheKey(
          const AppSettings(hl: 'en', gl: 'IN', contentLanguages: {'te'}),
        ),
      ),
    );
    expect(
      homeCacheKey(base),
      isNot(
        homeCacheKey(
          const AppSettings(hl: 'en', gl: 'IN', hiddenLanguages: {'ta'}),
        ),
      ),
    );
    expect(
      homeCacheKey(base),
      isNot(homeCacheKey(const AppSettings(hl: 'en', gl: 'US'))),
    );
  });
}
