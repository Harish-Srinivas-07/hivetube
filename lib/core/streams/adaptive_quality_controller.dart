import 'adaptive_quality_policy.dart';
import 'stream_selector.dart';

/// Applies stall and throughput samples to the current automatic quality tier.
class AdaptiveQualityController {
  final List<DateTime> _stalls = [];
  int? _currentHeight;
  DateTime? _stableSince;
  DateTime? _lastStall;
  DateTime? _lastSwitch;

  int? get currentHeight => _currentHeight;

  void updateCurrentHeight(int? currentHeight) {
    if (currentHeight != null) _currentHeight = currentHeight;
  }

  void reset(int? currentHeight, DateTime now) {
    _stalls.clear();
    _currentHeight = currentHeight;
    _stableSince = now;
    _lastStall = null;
    _lastSwitch = null;
  }

  int? recordStall({
    required DateTime now,
    required int currentHeight,
    required int cap,
  }) {
    _currentHeight ??= currentHeight;
    _stalls.removeWhere(
      (stall) => now.difference(stall) > AdaptiveQualityPolicy.stallWindow,
    );
    _stalls.add(now);
    _lastStall = now;
    if (_stalls.length < AdaptiveQualityPolicy.stallsToStepDown ||
        !_cooldownPassed(now)) {
      return null;
    }

    final allowed = AdaptiveQualityPolicy.tiers
        .where((height) => height <= cap)
        .toList();
    final lower = allowed
        .where((height) => height < _currentHeight!)
        .lastOrNull;
    _stalls.clear();
    if (lower == null) return null;
    _currentHeight = lower;
    _lastSwitch = now;
    _stableSince = now;
    return lower;
  }

  int? stepUpIfSupported({
    required DateTime now,
    required double? estimateMbps,
    required int currentHeight,
    required int cap,
  }) {
    _currentHeight ??= currentHeight;
    final stableFrom = _lastStall ?? _stableSince ?? now;
    if (estimateMbps == null ||
        now.difference(stableFrom) < AdaptiveQualityPolicy.stableBeforeStepUp ||
        !_cooldownPassed(now)) {
      return null;
    }

    final supportedHeight = pickHeight(estimateMbps, cap);
    final next = AdaptiveQualityPolicy.tiers
        .where(
          (height) => height > _currentHeight! && height <= supportedHeight,
        )
        .firstOrNull;
    if (next == null) return null;
    _currentHeight = next;
    _lastSwitch = now;
    _stableSince = now;
    return next;
  }

  bool _cooldownPassed(DateTime now) =>
      _lastSwitch == null ||
      now.difference(_lastSwitch!) >= AdaptiveQualityPolicy.switchCooldown;
}
