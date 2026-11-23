import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/downloads/download_notifications.dart';

class _FakeNotifications extends DownloadNotifications {
  _FakeNotifications({this.granted = false});

  bool granted;
  int areNotificationsGrantedCalls = 0;
  int requestPermissionCalls = 0;

  @override
  Future<bool> areNotificationsGranted() async {
    areNotificationsGrantedCalls++;
    return granted;
  }

  @override
  Future<bool?> requestPermission() async {
    requestPermissionCalls++;
    return granted;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification permission prompt on Home', () {
    late AppDb db;

    setUp(() {
      db = AppDb(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('skips permission prompt on desktop/non-android platforms', () async {
      final notifs = _FakeNotifications(granted: false);

      await promptNotificationPermissionIfNeeded(
        db: db,
        notifications: notifs,
        isAndroid: false,
        sdkInt: 33,
      );

      expect(notifs.requestPermissionCalls, 0);
      expect(await db.getValue('notifPermAsked'), isNull);
    });

    test('skips runtime prompt on Android versions below 13 (API < 33)', () async {
      final notifs = _FakeNotifications(granted: false);

      await promptNotificationPermissionIfNeeded(
        db: db,
        notifications: notifs,
        isAndroid: true,
        sdkInt: 32,
      );

      expect(notifs.requestPermissionCalls, 0);
      expect(await db.getValue('notifPermAsked'), isNull);
    });

    test('requests permission on Android 13+ when not granted and not already asked', () async {
      final notifs = _FakeNotifications(granted: false);

      await promptNotificationPermissionIfNeeded(
        db: db,
        notifications: notifs,
        isAndroid: true,
        sdkInt: 33,
      );

      expect(notifs.requestPermissionCalls, 1);
      expect(await db.getValue('notifPermAsked'), 'true');
    });

    test('never re-asks after user denies permission', () async {
      final notifs = _FakeNotifications(granted: false);

      // First run: asks and marks asked
      await promptNotificationPermissionIfNeeded(
        db: db,
        notifications: notifs,
        isAndroid: true,
        sdkInt: 33,
      );
      expect(notifs.requestPermissionCalls, 1);
      expect(await db.getValue('notifPermAsked'), 'true');

      // Subsequent run (e.g. next Home open): skips automatically
      await promptNotificationPermissionIfNeeded(
        db: db,
        notifications: notifs,
        isAndroid: true,
        sdkInt: 33,
      );
      expect(notifs.requestPermissionCalls, 1);
    });

    test('marks notifPermAsked without prompt if already granted beforehand', () async {
      final notifs = _FakeNotifications(granted: true);

      await promptNotificationPermissionIfNeeded(
        db: db,
        notifications: notifs,
        isAndroid: true,
        sdkInt: 34,
      );

      expect(notifs.requestPermissionCalls, 0);
      expect(await db.getValue('notifPermAsked'), 'true');
    });

    test('prompts existing users who finished onboarding if notifPermAsked is not set', () async {
      // Simulate existing user who onboarded previously
      await db.setValue('onboarded', 'true');
      final notifs = _FakeNotifications(granted: false);

      await promptNotificationPermissionIfNeeded(
        db: db,
        notifications: notifs,
        isAndroid: true,
        sdkInt: 33,
      );

      expect(notifs.requestPermissionCalls, 1);
      expect(await db.getValue('notifPermAsked'), 'true');
    });
  });

  group('Home first launch sequence (language sheet -> notification prompt)', () {
    late AppDb db;

    setUp(() {
      db = AppDb(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('runs strict sequence: Home -> language sheet -> notification prompt', () async {
      final notifs = _FakeNotifications(granted: false);
      final sequence = <String>[];
      final sheetCompleter = Completer<void>();

      final future = runHomeFirstLaunchSequence(
        db: db,
        notifications: notifs,
        showLanguageSheet: () async {
          sequence.add('language_sheet_shown');
          await sheetCompleter.future;
          sequence.add('language_sheet_closed');
        },
        isAndroid: true,
        sdkInt: 33,
      );

      // Let asynchronous db.getValue resolve up to the sheet
      await pumpEventQueue();

      // Sheet must be open, but notification permission MUST NOT be called yet
      expect(sequence, ['language_sheet_shown']);
      expect(notifs.requestPermissionCalls, 0);
      expect(await db.getValue('languageAsked'), isNull);
      expect(await db.getValue('notifPermAsked'), isNull);

      // Now close/complete language sheet
      sheetCompleter.complete();
      await future;

      // Now notification permission should have been called in strict order
      expect(sequence, ['language_sheet_shown', 'language_sheet_closed']);
      expect(notifs.requestPermissionCalls, 1);
      expect(await db.getValue('languageAsked'), 'true');
      expect(await db.getValue('notifPermAsked'), 'true');
    });

    test('skips language sheet if languageAsked is already true', () async {
      await db.setValue('languageAsked', 'true');
      final notifs = _FakeNotifications(granted: false);
      var sheetShown = false;

      await runHomeFirstLaunchSequence(
        db: db,
        notifications: notifs,
        showLanguageSheet: () async {
          sheetShown = true;
        },
        isAndroid: true,
        sdkInt: 33,
      );

      expect(sheetShown, isFalse);
      expect(notifs.requestPermissionCalls, 1);
      expect(await db.getValue('notifPermAsked'), 'true');
    });

    test('shows nothing if both languageAsked and notifPermAsked are true', () async {
      await db.setValue('languageAsked', 'true');
      await db.setValue('notifPermAsked', 'true');
      final notifs = _FakeNotifications(granted: false);
      var sheetShown = false;

      await runHomeFirstLaunchSequence(
        db: db,
        notifications: notifs,
        showLanguageSheet: () async {
          sheetShown = true;
        },
        isAndroid: true,
        sdkInt: 33,
      );

      expect(sheetShown, isFalse);
      expect(notifs.requestPermissionCalls, 0);
    });

    test('aborts sequence gracefully if Home widget is disposed mid-sequence', () async {
      final notifs = _FakeNotifications(granted: false);
      var mounted = true;
      final sheetCompleter = Completer<void>();

      final future = runHomeFirstLaunchSequence(
        db: db,
        notifications: notifs,
        showLanguageSheet: () async {
          await sheetCompleter.future;
        },
        isMounted: () => mounted,
        isAndroid: true,
        sdkInt: 33,
      );

      await pumpEventQueue();

      // Dispose mid-sequence while sheet is showing
      mounted = false;
      sheetCompleter.complete();
      await future;

      // Notification permission must NOT be requested because widget was disposed
      expect(notifs.requestPermissionCalls, 0);
    });
  });
}
