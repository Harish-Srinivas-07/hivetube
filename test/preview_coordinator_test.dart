import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/playback/preview_coordinator.dart';
import 'package:hivetube/theme/app_motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('elects one eligible preview after debounce, preferring visibility', () {
    fakeAsync((async) {
      final container = ProviderContainer(
        overrides: [previewPlaybackAllowedProvider.overrideWithValue(true)],
      );
      addTearDown(container.dispose);
      final coordinator = container.read(previewCoordinatorProvider.notifier);

      coordinator.reportCandidate(
        id: 'below-threshold',
        visibleFraction: PreviewCoordinator.minVisibleFraction - 0.01,
        centerDistance: 0,
      );
      coordinator.reportCandidate(
        id: 'less-visible',
        visibleFraction: 0.7,
        centerDistance: 0,
      );
      coordinator.reportCandidate(
        id: 'winner',
        visibleFraction: 0.8,
        centerDistance: 200,
      );
      coordinator.reportCandidate(
        id: 'tie-closer-to-center',
        visibleFraction: 0.8,
        centerDistance: 20,
      );

      expect(container.read(previewCoordinatorProvider), isNull);
      async.elapse(AppMotion.previewElectionDebounce);
      expect(
        container.read(previewCoordinatorProvider),
        'tie-closer-to-center',
      );

      coordinator.scrollStarted();
      expect(container.read(previewCoordinatorProvider), isNull);
      coordinator.scrollEnded();
      async.elapse(AppMotion.previewElectionDebounce);
      expect(
        container.read(previewCoordinatorProvider),
        'tie-closer-to-center',
      );
    });
  });
}
