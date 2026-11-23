import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/streams/adaptive_quality_policy.dart';
import 'package:hivetube/theme/app_theme.dart';
import 'package:hivetube/theme/app_colors.dart';
import 'package:hivetube/theme/app_spacing.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hivetube/widgets/player/player_settings_menu.dart';
import 'package:hivetube/widgets/video_options_menu.dart';
import 'package:hivetube/widgets/sheets/app_sheet.dart';

class _Playback extends Fake implements PlaybackService {
  final snapshot = PlaybackSnapshot()..heights = [1080, 720];
  final listeners = <VoidCallback>[];
  VideoQualityPreference preference = VideoQualityPreference.auto;
  @override
  VideoQualityPreference get qualityPreference => preference;
  @override
  Future<void> setQualityPreference(VideoQualityPreference value) async {
    preference = value;
    for (final listener in [...listeners]) {
      listener();
    }
  }

  @override
  PlaybackSnapshot get state => snapshot;
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  @override
  void setQuality(int? quality) {
    snapshot.quality = quality;
    for (final listener in [...listeners]) {
      listener();
    }
  }

  @override
  Future<void> setRate(double value) async {
    snapshot.rate = value;
    for (final listener in [...listeners]) {
      listener();
    }
  }
}

void main() {
  testWidgets('landscape player menu does not repeat screen side insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(left: 80, right: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    final session = PlayerSettingsSession(_Playback());
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showPlayerSettingsMenu(context, session: session),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    final surface = tester.getRect(
      find.byKey(const ValueKey('appSheetSurface')),
    );
    final icon = tester.getRect(find.byIcon(LucideIcons.slidersHorizontal));
    final chevron = tester.getRect(find.byIcon(LucideIcons.chevronRight).first);
    expect(icon.left - surface.left, AppSpacing.lg);
    expect(surface.right - chevron.right, AppSpacing.lg);
  });
  testWidgets('video menu follows the light app theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showVideoOptionsMenu(context, videoId: 'video'),
              child: const Text('Open menu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    final surface = find.byKey(const ValueKey('appSheetSurface'));
    expect(
      tester.widget<Material>(surface).color,
      AppTheme.light.colorScheme.surface,
    );
    expect(
      Theme.of(tester.element(find.byType(AppSheetRow).first)).brightness,
      Brightness.light,
    );
  });
  testWidgets('player sheet navigates and applies quality and speed', (
    tester,
  ) async {
    final service = _Playback();
    final session = PlayerSettingsSession(service);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showPlayerSettingsMenu(context, session: session),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    final surface = find.byKey(const ValueKey('appSheetSurface'));
    expect(
      tester.widget<Material>(surface).color,
      AppTheme.light.colorScheme.surface,
    );
    expect(
      Theme.of(tester.element(find.byType(AppSheetRow).first)).brightness,
      Brightness.light,
    );
    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('Playback speed'), findsOneWidget);
    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(AppSheetRow).first)).brightness,
      Brightness.light,
    );
    await tester.tap(find.text('720p'));
    await tester.pumpAndSettle();
    expect(service.qualityPreference, VideoQualityPreference.always720);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playback speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();
    expect(service.state.rate, 1.5);
    expect(tester.takeException(), isNull);
  });
  testWidgets('player settings follow the dark app theme', (tester) async {
    final session = PlayerSettingsSession(_Playback());
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showPlayerSettingsMenu(context, session: session),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Material>(find.byKey(const ValueKey('appSheetSurface')))
          .color,
      AppColors.videoSheet,
    );
    expect(
      Theme.of(tester.element(find.byType(AppSheetRow).first)).brightness,
      Brightness.dark,
    );
  });
  testWidgets('video menu closes and runs only the selected action', (
    tester,
  ) async {
    var next = 0, queue = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showVideoOptionsMenu(
                context,
                videoId: 'video',
                onPlayNext: () => next++,
                onAddToQueue: () => queue++,
              ),
              child: const Text('Open menu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Copy link'), findsNothing);
    await tester.tap(find.text('Add to queue'));
    await tester.pumpAndSettle();
    expect(queue, 1);
    expect(next, 0);
    expect(find.text('Add to queue'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
