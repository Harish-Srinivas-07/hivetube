import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/features/home/home_controller.dart';
import 'package:hivetube/features/home/home_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _Home extends HomeController {
  @override
  HomeData build() => HomeData(
    videos: List.generate(
      10,
      (i) => VideoItem(
        id: '$i',
        title: 'Video $i',
        channelId: 'UC$i',
        channelName: 'Channel $i',
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('avatar completion does not rebuild feed cards', (tester) async {
    final avatar = Completer<({String url, String channelId})>();
    final builds = <String, int>{};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeProvider.overrideWith(_Home.new),
          homeHistoryByIdProvider.overrideWithValue({}),
          channelAvatarProvider.overrideWith(
            (ref, key) => key.channelId == 'UC0'
                ? avatar.future
                : Future.value((url: '', channelId: key.channelId)),
          ),
        ],
        child: MaterialApp(
          home: HomeScreen(
            onCardBuilt: (id) =>
                builds.update(id, (count) => count + 1, ifAbsent: () => 1),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(builds, isNotEmpty);
    final before = Map<String, int>.of(builds);
    avatar.complete((url: '', channelId: 'UC0'));
    await tester.pump();
    expect(builds, before);
    await tester.pump(const Duration(milliseconds: 300));
  });
}
