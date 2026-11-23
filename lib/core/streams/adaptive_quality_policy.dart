/// User-selected playback quality policy.
enum VideoQualityPreference {
  auto,
  always1080,
  always720,
  always480,
  always360,
  dataSaver,
}

/// Shared ABR tiers, network caps, thresholds, and timing policy.
abstract final class AdaptiveQualityPolicy {
  static const int quality240 = 240;
  static const int quality360 = 360;
  static const int quality480 = 480;
  static const int quality720 = 720;
  static const int quality1080 = 1080;
  static const int wifiCap = quality1080;
  static const int mobileCap = quality720;
  static const int fallbackCap = quality360;
  static const int dataSaverMobileCap = quality360;
  static const int maxVideoHeight = quality1080;
  static const List<int> tiers = [
    quality240,
    quality360,
    quality480,
    quality720,
    quality1080,
  ];

  static const double safetyFactor = 0.7;
  static const double ewmaAlpha = 0.3;
  static const double threshold1080Mbps = 8;
  static const double threshold720Mbps = 4;
  static const double threshold480Mbps = 2;
  static const double threshold360Mbps = 1;
  static const int probeBytes = 512 * 1024;
  static const Duration probeTimeout = Duration(milliseconds: 1500);
  static const Duration stallWindow = Duration(seconds: 20);
  static const int stallsToStepDown = 2;
  static const Duration stableBeforeStepUp = Duration(seconds: 30);
  static const Duration switchCooldown = Duration(seconds: 60);
  static const Duration adaptationCheckInterval = Duration(seconds: 5);

  static int networkCap({required bool wifi, required bool mobile}) => wifi
      ? wifiCap
      : mobile
      ? mobileCap
      : fallbackCap;

  static int capForPreference(
    VideoQualityPreference preference, {
    required bool wifi,
    required bool mobile,
  }) {
    final network = networkCap(wifi: wifi, mobile: mobile);
    return switch (preference) {
      VideoQualityPreference.auto => network,
      VideoQualityPreference.always1080 => quality1080,
      VideoQualityPreference.always720 => quality720,
      VideoQualityPreference.always480 => quality480,
      VideoQualityPreference.always360 => quality360,
      VideoQualityPreference.dataSaver => mobile ? dataSaverMobileCap : network,
    };
  }

  static int? fixedHeight(VideoQualityPreference preference) =>
      switch (preference) {
        VideoQualityPreference.always1080 => quality1080,
        VideoQualityPreference.always720 => quality720,
        VideoQualityPreference.always480 => quality480,
        VideoQualityPreference.always360 => quality360,
        _ => null,
      };
}
