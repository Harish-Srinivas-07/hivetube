import 'package:fake_async/fake_async.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/streams/adaptive_quality_controller.dart';
import 'package:hivetube/core/streams/adaptive_quality_policy.dart';
import 'package:hivetube/core/streams/bandwidth_estimator.dart';
import 'package:hivetube/core/streams/stream_selector.dart';

void main() {
  test('bandwidth samples update the EWMA with the configured alpha', () {
    final estimator = BandwidthEstimator(Dio());
    expect(estimator.addSample(1000000, const Duration(seconds: 1)), 8);
    expect(estimator.addSample(2000000, const Duration(seconds: 1)), 10.4);
    estimator.dispose();
  });

  group('pickHeight', () {
    test('applies the safety factor before selecting the tier', () {
      expect(
        pickHeight(12, AdaptiveQualityPolicy.quality1080),
        AdaptiveQualityPolicy.quality1080,
      );
      expect(
        pickHeight(7, AdaptiveQualityPolicy.quality1080),
        AdaptiveQualityPolicy.quality720,
      );
      expect(
        pickHeight(3, AdaptiveQualityPolicy.quality1080),
        AdaptiveQualityPolicy.quality480,
      );
      expect(
        pickHeight(1.5, AdaptiveQualityPolicy.quality1080),
        AdaptiveQualityPolicy.quality360,
      );
      expect(
        pickHeight(0.5, AdaptiveQualityPolicy.quality1080),
        AdaptiveQualityPolicy.quality240,
      );
    });

    test('does not exceed the network cap', () {
      expect(pickHeight(100, AdaptiveQualityPolicy.quality480), 480);
    });
  });

  test('network type applies default and data-saver caps', () {
    expect(
      AdaptiveQualityPolicy.capForPreference(
        VideoQualityPreference.auto,
        wifi: true,
        mobile: false,
      ),
      AdaptiveQualityPolicy.quality1080,
    );
    expect(
      AdaptiveQualityPolicy.capForPreference(
        VideoQualityPreference.auto,
        wifi: false,
        mobile: true,
      ),
      AdaptiveQualityPolicy.quality720,
    );
    expect(
      AdaptiveQualityPolicy.capForPreference(
        VideoQualityPreference.auto,
        wifi: false,
        mobile: false,
      ),
      AdaptiveQualityPolicy.quality360,
    );
    expect(
      AdaptiveQualityPolicy.capForPreference(
        VideoQualityPreference.dataSaver,
        wifi: false,
        mobile: true,
      ),
      AdaptiveQualityPolicy.quality360,
    );
  });

  test('steps down after two stalls in twenty seconds', () {
    fakeAsync((async) {
      final start = DateTime(2026);
      final controller = AdaptiveQualityController()..reset(720, start);

      expect(
        controller.recordStall(
          now: start,
          currentHeight: 720,
          cap: AdaptiveQualityPolicy.quality1080,
        ),
        isNull,
      );
      async.elapse(const Duration(seconds: 19));
      expect(
        controller.recordStall(
          now: start.add(async.elapsed),
          currentHeight: 720,
          cap: AdaptiveQualityPolicy.quality1080,
        ),
        AdaptiveQualityPolicy.quality480,
      );
    });
  });

  test('does not step down when stalls are outside the window', () {
    fakeAsync((async) {
      final start = DateTime(2026);
      final controller = AdaptiveQualityController()..reset(720, start);
      controller.recordStall(
        now: start,
        currentHeight: 720,
        cap: AdaptiveQualityPolicy.quality1080,
      );
      async.elapse(
        AdaptiveQualityPolicy.stallWindow + const Duration(seconds: 1),
      );
      expect(
        controller.recordStall(
          now: start.add(async.elapsed),
          currentHeight: 720,
          cap: AdaptiveQualityPolicy.quality1080,
        ),
        isNull,
      );
    });
  });

  test('steps up after stable time when throughput supports a tier', () {
    fakeAsync((async) {
      final start = DateTime(2026);
      final controller = AdaptiveQualityController()..reset(480, start);
      async.elapse(AdaptiveQualityPolicy.stableBeforeStepUp);

      expect(
        controller.stepUpIfSupported(
          now: start.add(async.elapsed),
          estimateMbps: 12,
          currentHeight: 480,
          cap: AdaptiveQualityPolicy.quality1080,
        ),
        AdaptiveQualityPolicy.quality720,
      );
      async.elapse(AdaptiveQualityPolicy.switchCooldown);
      expect(
        controller.stepUpIfSupported(
          now: start.add(async.elapsed),
          estimateMbps: 20,
          currentHeight: 720,
          cap: AdaptiveQualityPolicy.quality1080,
        ),
        AdaptiveQualityPolicy.quality1080,
      );
    });
  });
}
