import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/playback/playback_service.dart';
import 'package:hivetube/core/providers.dart';
import 'package:hivetube/core/settings/app_settings.dart';
import 'package:hivetube/core/streams/stream_selector.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/watch_info.dart';
import 'package:hivetube/features/watch/watch_screen.dart';

class _Playback extends Fake implements PlaybackService {
  final snapshot = PlaybackSnapshot()
    ..videoId = 'video'
    ..mode = PlaybackMode.video
    ..position = const Duration(seconds: 42)
    ..playing = true
    ..status = PlayerStatus.playing;
  final listeners = <VoidCallback>[];

  @override
  PlaybackSnapshot get state => snapshot;
  @override
  PlayRequest get request =>
      PlayRequest(videoId: 'video', mode: snapshot.mode!);
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  @override
  Future<void> setAudioOnly(bool enabled) async {
    snapshot.mode = enabled ? PlaybackMode.audio : PlaybackMode.video;
    for (final listener in List<VoidCallback>.of(listeners)) {
      listener();
    }
  }
}

class _PlaybackController extends PlaybackController {
  _PlaybackController(this.service);
  final PlaybackService service;
  @override
  PlaybackService build() => service;
}

void main() {
  testWidgets('background setting controls audio-only and restores video', (
    tester,
  ) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final service = _Playback();
    final container = ProviderContainer(
      overrides: [
        dbProvider.overrideWithValue(db),
        initialAppSettingsProvider.overrideWithValue(
          const AppSettings(gl: 'AUTO', backgroundPlay: false),
        ),
        playbackProvider.overrideWith(() => _PlaybackController(service)),
        isOfflineProvider.overrideWithValue(false),
        watchInfoProvider('video').overrideWith(
          (ref) async => const WatchInfo(
            id: 'video',
            title: 'Video',
            channelName: '',
            channelId: '',
            avatar: '',
            subscribers: '',
            description: '',
            likes: '',
            views: '',
            date: '',
            handle: '',
            commentsToken: null,
            related: VideoPage([], null),
            chapters: [],
            chips: {},
          ),
        ),
        dislikeCountProvider('video').overrideWith((ref) async => 0),
      ],
    );
    var disposed = false;
    addTearDown(() {
      if (!disposed) container.dispose();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: WatchScreen(
            id: 'video',
            embedded: true,
            placeholderVideo: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Audio only'), findsNothing);

    await container.read(appSettingsProvider.notifier).setBackgroundPlay(true);
    await tester.pump();
    expect(find.text('Audio only'), findsOneWidget);
    await tester.tap(find.text('Audio only'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(appSettingsProvider).audioOnly, isTrue);
    expect(service.state.mode, PlaybackMode.audio);

    await container.read(appSettingsProvider.notifier).setBackgroundPlay(false);
    await tester.pump();
    expect(find.text('Audio only'), findsNothing);
    expect(find.text('Audio only on'), findsNothing);
    expect(container.read(appSettingsProvider).audioOnly, isFalse);
    expect(await db.getValue('settings_audio_only'), 'false');
    expect(service.state.mode, PlaybackMode.video);
    expect(service.state.position, const Duration(seconds: 42));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    disposed = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });
}
