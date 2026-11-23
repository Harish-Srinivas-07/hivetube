import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../playback/playback_service.dart';
import '../streams/adaptive_quality_policy.dart';
import '../../features/shorts/shorts_screen.dart';
import '../content/language_profile.dart';

const regions = <String, String>{
  'AUTO': 'Automatic (no region)',
  'IN': 'India',
  'US': 'United States',
  'GB': 'United Kingdom',
  'AU': 'Australia',
  'CA': 'Canada',
  'AE': 'United Arab Emirates',
  'SG': 'Singapore',
  'LK': 'Sri Lanka',
  'MY': 'Malaysia',
  'IE': 'Ireland',
  'DE': 'Germany',
  'FR': 'France',
  'ES': 'Spain',
  'BR': 'Brazil',
  'JP': 'Japan',
  'KR': 'South Korea',
};
const regionAdjectives = <String, String>{
  'IN': 'indian',
  'AE': 'emirati',
  'SG': 'singapore',
  'LK': 'sri lankan',
  'MY': 'malaysian',
  'BR': 'brazilian',
  'JP': 'japanese',
  'KR': 'korean',
  'DE': 'german',
  'FR': 'french',
  'ES': 'spanish',
};

class AppSettings {
  const AppSettings({
    String? hl,
    required this.gl,
    this.localContent = true,
    this.autoplay = false,
    this.backgroundPlay = true,
    this.pictureInPicture = true,
    this.audioOnly = false,
    this.previewsEnabled = true,
    this.previewsWifiOnly = true,
    this.revision = 0,
    this.contentLanguages = const {'ta', 'en'},
    this.hiddenLanguages = const {'hi'},
    this.localRatio = 0.6,
    this.strictHome = true,
    this.videoQualityPreference = VideoQualityPreference.auto,
  });
  String get hl => 'en';
  final String gl;
  final bool localContent;
  final bool autoplay;
  final bool backgroundPlay;
  final bool pictureInPicture;
  final bool audioOnly;
  final bool previewsEnabled;
  final bool previewsWifiOnly;
  final int revision;
  final Set<String> contentLanguages, hiddenLanguages;
  final double localRatio;
  final bool strictHome;
  final VideoQualityPreference videoQualityPreference;
  int get prefsVersion => revision;
  String get cacheKey {
    final shown = contentLanguages.toList()..sort();
    final hidden = hiddenLanguages.toList()..sort();
    return 'classifier${CLASSIFIER_VERSION}_${gl}_${shown.join("-")}_${hidden.join("-")}_${(localRatio * 100).round()}_${strictHome ? "strict" : "lenient"}';
  }

  static AppSettings defaults([Locale? _]) =>
      const AppSettings(gl: 'AUTO', strictHome: true);
  AppSettings copyWith({
    String? hl,
    String? gl,
    bool? localContent,
    bool? autoplay,
    bool? backgroundPlay,
    bool? pictureInPicture,
    bool? audioOnly,
    bool? previewsEnabled,
    bool? previewsWifiOnly,
    int? revision,
    Set<String>? contentLanguages,
    Set<String>? hiddenLanguages,
    double? localRatio,
    bool? strictHome,
    VideoQualityPreference? videoQualityPreference,
  }) => AppSettings(
    gl: gl ?? this.gl,
    localContent: localContent ?? this.localContent,
    autoplay: autoplay ?? this.autoplay,
    backgroundPlay: backgroundPlay ?? this.backgroundPlay,
    pictureInPicture: pictureInPicture ?? this.pictureInPicture,
    audioOnly: audioOnly ?? this.audioOnly,
    previewsEnabled: previewsEnabled ?? this.previewsEnabled,
    previewsWifiOnly: previewsWifiOnly ?? this.previewsWifiOnly,
    revision: revision ?? this.revision,
    contentLanguages: contentLanguages ?? this.contentLanguages,
    hiddenLanguages: hiddenLanguages ?? this.hiddenLanguages,
    localRatio: localRatio ?? this.localRatio,
    strictHome: strictHome ?? this.strictHome,
    videoQualityPreference:
        videoQualityPreference ?? this.videoQualityPreference,
  );
}

List<String> regionalQueries(String query, AppSettings settings) {
  if (!settings.localContent) return [query];
  final adjective = regionAdjectives[settings.gl];
  return adjective == null ? [query] : ['$adjective $query', query];
}

String homeCacheKey(AppSettings settings, {String chip = 'All'}) {
  return 'home_cache_${settings.cacheKey}_${settings.localContent ? 'local' : 'plain'}_$chip';
}

String homeSeenKey(AppSettings settings, {String chip = 'All'}) =>
    'home_seen_v2_${settings.cacheKey}_$chip';

final initialAppSettingsProvider = Provider<AppSettings>(
  (ref) => AppSettings.defaults(PlatformDispatcher.instance.locale),
);
final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

/// Shared content preferences for Home, Shorts, related videos and search.
/// `AppSettings` also contains playback and legacy region settings.
final contentPrefsProvider = appSettingsProvider;

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialAppSettingsProvider);
  Future<void> setAutoplay(bool enabled) async {
    await ref
        .read(dbProvider)
        .setValue('settings_autoplay', enabled.toString());
    state = state.copyWith(autoplay: enabled);
  }

  Future<void> setBackgroundPlay(bool enabled) async {
    if (state.backgroundPlay == enabled) return;
    final resetAudioOnly = !enabled && state.audioOnly;
    final db = ref.read(dbProvider);
    await db.transaction(() async {
      await db.setValue('settings_background_play', enabled.toString());
      if (resetAudioOnly) await db.setValue('settings_audio_only', 'false');
    });
    state = state.copyWith(
      backgroundPlay: enabled,
      audioOnly: resetAudioOnly ? false : null,
    );
    if (resetAudioOnly && ref.read(playbackProvider.exists)) {
      await ref.read(playbackProvider)?.setAudioOnly(false);
    }
  }

  Future<void> setPictureInPicture(bool enabled) async {
    if (state.pictureInPicture == enabled) return;
    await ref
        .read(dbProvider)
        .setValue('settings_picture_in_picture', enabled.toString());
    state = state.copyWith(pictureInPicture: enabled);
  }

  Future<void> setAudioOnly(bool enabled) async {
    if (enabled && !state.backgroundPlay) return;
    if (state.audioOnly == enabled) return;
    await ref
        .read(dbProvider)
        .setValue('settings_audio_only', enabled.toString());
    if (enabled && !state.backgroundPlay) {
      await ref.read(dbProvider).setValue('settings_audio_only', 'false');
      return;
    }
    state = state.copyWith(audioOnly: enabled);
  }

  Future<void> setAudioOnlyPlayback(bool enabled) async {
    await setAudioOnly(enabled);
    if (!state.backgroundPlay || state.audioOnly != enabled) return;
    if (ref.read(playbackProvider.exists)) {
      await ref.read(playbackProvider)?.setAudioOnly(enabled);
    }
  }

  Future<void> setPreviewsEnabled(bool enabled) async {
    if (state.previewsEnabled == enabled) return;
    await ref
        .read(dbProvider)
        .setValue('settings_previews_enabled', enabled.toString());
    state = state.copyWith(previewsEnabled: enabled);
  }

  Future<void> setPreviewsWifiOnly(bool wifiOnly) async {
    if (state.previewsWifiOnly == wifiOnly) return;
    await ref
        .read(dbProvider)
        .setValue('settings_previews_wifi_only', wifiOnly.toString());
    state = state.copyWith(previewsWifiOnly: wifiOnly);
  }

  Future<void> setVideoQualityPreference(
    VideoQualityPreference preference,
  ) async {
    if (state.videoQualityPreference == preference) return;
    await ref
        .read(dbProvider)
        .setValue('settings_video_quality', preference.name);
    state = state.copyWith(videoQualityPreference: preference);
  }

  void resetAfterDatabaseClear() {
    state = AppSettings.defaults(
      PlatformDispatcher.instance.locale,
    ).copyWith(revision: state.revision + 1);
  }

  Future<void> update({
    String? hl,
    String? gl,
    bool? localContent,
    Set<String>? contentLanguages,
    Set<String>? hiddenLanguages,
    double? localRatio,
    bool? strictHome,
  }) async {
    final old = state;
    final shown = Set<String>.of(contentLanguages ?? old.contentLanguages);
    if (shown.isEmpty) shown.add('en');
    final hidden = Set<String>.of(hiddenLanguages ?? old.hiddenLanguages)
      ..removeAll(shown);
    final next = old.copyWith(
      gl: gl,
      localContent: localContent,
      contentLanguages: shown,
      hiddenLanguages: hidden,
      localRatio: localRatio,
      strictHome: strictHome,
      revision: old.revision + 1,
    );
    if (old.gl == next.gl &&
        old.localContent == next.localContent &&
        old.contentLanguages.length == next.contentLanguages.length &&
        old.contentLanguages.containsAll(next.contentLanguages) &&
        old.hiddenLanguages.length == next.hiddenLanguages.length &&
        old.hiddenLanguages.containsAll(next.hiddenLanguages) &&
        old.localRatio == next.localRatio &&
        old.strictHome == next.strictHome) {
      return;
    }
    final db = ref.read(dbProvider);
    await db.deleteValue('settings_hl');
    await db.setValue('settings_gl', next.gl);
    await db.setValue('settings_local_content', next.localContent.toString());
    await db.setValue(
      'settings_content_languages',
      next.contentLanguages.join(','),
    );
    await db.setValue(
      'settings_hidden_languages',
      next.hiddenLanguages.join(','),
    );
    await db.setValue('settings_local_ratio', next.localRatio.toString());
    await db.setValue('settings_strict_home', next.strictHome.toString());
    await db.setValue('settings_prefs_version', next.prefsVersion.toString());
    await db.deleteValue(homeCacheKey(old));
    await db.deleteValue(homeCacheKey(next));
    await db.deleteValue('home_seen_videos_v1');
    ref.read(shortsSelectionProvider.notifier).clear();
    state = next;
  }
}
