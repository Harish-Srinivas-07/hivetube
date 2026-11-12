import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../../features/shorts/shorts_screen.dart';

const languages = <String, String>{
  'en': 'English',
  'hi': 'हिन्दी',
  'ta': 'தமிழ்',
  'ml': 'മലയാളം',
  'te': 'తెలుగు',
  'kn': 'ಕನ್ನಡ',
  'bn': 'বাংলা',
  'mr': 'मराठी',
  'gu': 'ગુજરાતી',
  'pa': 'ਪੰਜਾਬੀ',
  'ur': 'اردو',
  'or': 'ଓଡ଼ିଆ',
  'other': 'Other',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'pt': 'Português',
  'ja': '日本語',
  'ko': '한국어',
  'ar': 'العربية',
  'ru': 'Русский',
  'it': 'Italiano',
};
const regions = <String, String>{
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
const languageAdjectives = <String, String>{
  'hi': 'hindi',
  'ta': 'tamil',
  'ml': 'malayalam',
  'te': 'telugu',
  'kn': 'kannada',
  'bn': 'bengali',
  'mr': 'marathi',
  'gu': 'gujarati',
  'pa': 'punjabi',
  'es': 'spanish',
  'fr': 'french',
  'de': 'german',
  'pt': 'portuguese',
  'ja': 'japanese',
  'ko': 'korean',
  'ar': 'arabic',
  'ru': 'russian',
  'it': 'italian',
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
    required this.hl,
    required this.gl,
    this.localContent = true,
    this.autoplay = false,
    this.revision = 0,
    this.contentLanguages = const {'ta', 'en'},
    this.hiddenLanguages = const {'hi'},
    this.localRatio = 0.6,
  });
  final String hl, gl;
  final bool localContent;
  final bool autoplay;
  final int revision;
  final Set<String> contentLanguages, hiddenLanguages;
  final double localRatio;
  int get prefsVersion => revision;
  String get cacheKey => '${hl}_$gl';
  static AppSettings defaults(Locale locale) =>
      const AppSettings(hl: 'en', gl: 'IN');
  AppSettings copyWith({
    String? hl,
    String? gl,
    bool? localContent,
    bool? autoplay,
    int? revision,
    Set<String>? contentLanguages,
    Set<String>? hiddenLanguages,
    double? localRatio,
  }) => AppSettings(
    hl: hl ?? this.hl,
    gl: gl ?? this.gl,
    localContent: localContent ?? this.localContent,
    autoplay: autoplay ?? this.autoplay,
    revision: revision ?? this.revision,
    contentLanguages: contentLanguages ?? this.contentLanguages,
    hiddenLanguages: hiddenLanguages ?? this.hiddenLanguages,
    localRatio: localRatio ?? this.localRatio,
  );
}

List<String> regionalQueries(String query, AppSettings settings) {
  if (!settings.localContent) return [query];
  final adjective = languageAdjectives[settings.hl];
  return adjective == null ? [query] : ['$adjective $query', query];
}

String homeCacheKey(AppSettings settings) {
  final content = settings.contentLanguages.toList()..sort();
  final hidden = settings.hiddenLanguages.toList()..sort();
  return 'home_cache_${settings.cacheKey}_${settings.localContent ? 'local' : 'plain'}_${content.join('-')}_${hidden.join('-')}_${settings.localRatio}';
}

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
  }) async {
    final old = state;
    final shown = Set<String>.of(contentLanguages ?? old.contentLanguages);
    if (shown.isEmpty) shown.add('en');
    final hidden = Set<String>.of(hiddenLanguages ?? old.hiddenLanguages)
      ..removeAll(shown);
    final nextHl =
        hl ??
        (contentLanguages == null
            ? old.hl
            : shown.contains('en')
            ? 'en'
            : shown.contains('other')
            ? 'en'
            : shown.length == 1 && shown.single != 'other'
            ? shown.single
            : old.hl);
    final next = old.copyWith(
      hl: nextHl,
      gl: gl,
      localContent: localContent,
      contentLanguages: shown,
      hiddenLanguages: hidden,
      localRatio: localRatio,
      revision: old.revision + 1,
    );
    if (old.hl == next.hl &&
        old.gl == next.gl &&
        old.localContent == next.localContent &&
        old.contentLanguages.length == next.contentLanguages.length &&
        old.contentLanguages.containsAll(next.contentLanguages) &&
        old.hiddenLanguages.length == next.hiddenLanguages.length &&
        old.hiddenLanguages.containsAll(next.hiddenLanguages) &&
        old.localRatio == next.localRatio) {
      return;
    }
    final db = ref.read(dbProvider);
    await db.setValue('settings_hl', next.hl);
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
    await db.setValue('settings_prefs_version', next.prefsVersion.toString());
    await db.deleteValue(homeCacheKey(old));
    await db.deleteValue(homeCacheKey(next));
    ref.read(shortsSelectionProvider.notifier).clear();
    state = next;
  }
}
