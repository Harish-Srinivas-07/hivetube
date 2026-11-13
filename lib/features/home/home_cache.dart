import 'dart:convert';
import '../../core/content/language_profile.dart';
import '../../core/yt/models.dart';

class HomeCache {
  const HomeCache(this.videos, this.shorts, this.savedAt);
  final List<VideoItem> videos;
  final List<ShortItem> shorts;
  final DateTime savedAt;
  String encode() => jsonEncode({
    'classifierVersion': CLASSIFIER_VERSION,
    'savedAt': savedAt.toIso8601String(),
    'videos': videos.map((e) => e.toJson()).toList(),
    'shorts': shorts.map((e) => e.toJson()).toList(),
  });
  static HomeCache? decode(String? raw, DateTime now) {
    try {
      final j = jsonDecode(raw!) as Map<String, dynamic>;
      if (j['classifierVersion'] != CLASSIFIER_VERSION) return null;
      final saved = DateTime.parse(j['savedAt'] as String);
      if (now.isBefore(saved) ||
          now.difference(saved) >= const Duration(minutes: 30)) {
        return null;
      }
      final videos = (j['videos'] as List)
          .map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final shorts = (j['shorts'] as List)
          .map((e) => ShortItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (videos.isEmpty && shorts.isEmpty) return null;
      return HomeCache(videos, shorts, saved);
    } catch (_) {
      return null;
    }
  }
}
