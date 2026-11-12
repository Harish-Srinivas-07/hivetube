import 'dart:convert';
import '../../core/yt/models.dart';

class HomeCache {
  const HomeCache(this.videos, this.shorts, this.savedAt);
  final List<VideoItem> videos;
  final List<ShortItem> shorts;
  final DateTime savedAt;
  String encode() => jsonEncode({
    'savedAt': savedAt.toIso8601String(),
    'videos': videos.map((e) => e.toJson()).toList(),
    'shorts': shorts.map((e) => e.toJson()).toList(),
  });
  static HomeCache? decode(String? raw, DateTime now) {
    try {
      final j = jsonDecode(raw!) as Map<String, dynamic>;
      final saved = DateTime.parse(j['savedAt'] as String);
      if (now.isBefore(saved) ||
          now.difference(saved) >= const Duration(minutes: 30)) {
        return null;
      }
      return HomeCache(
        (j['videos'] as List)
            .map((e) => VideoItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        (j['shorts'] as List)
            .map((e) => ShortItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        saved,
      );
    } catch (_) {
      return null;
    }
  }
}
