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
    this.revision = 0,
  });
  final String hl, gl;
  final bool localContent;
  final int revision;
  String get cacheKey => '${hl}_$gl';
  static AppSettings defaults(Locale locale) => AppSettings(
    hl: languages.containsKey(locale.languageCode) ? locale.languageCode : 'en',
    gl: regions.containsKey(locale.countryCode?.toUpperCase())
        ? locale.countryCode!.toUpperCase()
        : 'IN',
  );
  AppSettings copyWith({
    String? hl,
    String? gl,
    bool? localContent,
    int? revision,
  }) => AppSettings(
    hl: hl ?? this.hl,
    gl: gl ?? this.gl,
    localContent: localContent ?? this.localContent,
    revision: revision ?? this.revision,
  );
}

List<String> regionalQueries(String query, AppSettings settings) {
  if (!settings.localContent) return [query];
  final adjective =
      languageAdjectives[settings.hl] ??
      (settings.hl == 'en' ? regionAdjectives[settings.gl] : null);
  return adjective == null ? [query] : ['$adjective $query', query];
}

String homeCacheKey(AppSettings settings) =>
    'home_cache_${settings.cacheKey}_${settings.localContent ? 'local' : 'plain'}';
final initialAppSettingsProvider = Provider<AppSettings>(
  (ref) => AppSettings.defaults(PlatformDispatcher.instance.locale),
);
final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialAppSettingsProvider);
  Future<void> update({String? hl, String? gl, bool? localContent}) async {
    final old = state;
    final next = old.copyWith(
      hl: hl,
      gl: gl,
      localContent: localContent,
      revision: old.revision + 1,
    );
    if (old.hl == next.hl &&
        old.gl == next.gl &&
        old.localContent == next.localContent) {
      return;
    }
    final db = ref.read(dbProvider);
    await db.setValue('settings_hl', next.hl);
    await db.setValue('settings_gl', next.gl);
    await db.setValue('settings_local_content', next.localContent.toString());
    await db.deleteValue(homeCacheKey(old));
    await db.deleteValue(homeCacheKey(next));
    ref.read(shortsSelectionProvider).clear();
    state = next;
  }
}
