import 'dart:convert';
import 'package:dio/dio.dart';
import '../db/app_db.dart';

class RydService {
  RydService(this.dio, this.db, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  final Dio dio;
  final AppDb db;
  final DateTime Function() clock;

  Future<int?> dislikes(String videoId) async {
    int? cached;
    try {
      final row = await db.rydDao.getRyd(videoId);
      if (row != null) {
        cached = row.dislikes;
        final saved = DateTime.fromMillisecondsSinceEpoch(row.fetchedAt, isUtc: true);
        final current = clock().toUtc();
        if (current.difference(saved) < const Duration(hours: 24) &&
            !current.isBefore(saved)) {
          return cached;
        }
      } else {
        final legacyRaw = await db.getValue('ryd_$videoId');
        if (legacyRaw != null) {
          final data = jsonDecode(legacyRaw) as Map<String, dynamic>;
          cached = data['count'] as int?;
          final atStr = data['at'] as String?;
          if (atStr != null) {
            final saved = DateTime.tryParse(atStr)?.toUtc();
            final current = clock().toUtc();
            if (saved != null &&
                current.difference(saved) < const Duration(hours: 24) &&
                !current.isBefore(saved)) {
              return cached;
            }
          }
        }
      }
    } catch (_) {}

    try {
      final response = await dio.get<Map<String, dynamic>>(
        'https://returnyoutubedislikeapi.com/votes',
        queryParameters: {'videoId': videoId},
      );
      final dislikes = response.data?['dislikes'];
      final likes = response.data?['likes'] as int? ?? 0;
      if (dislikes is! int) return cached;

      final now = clock();
      await db.rydDao.putRyd(
        videoId,
        likes,
        dislikes,
        fetchedAt: now.millisecondsSinceEpoch,
      );
      await db.setValue(
        'ryd_$videoId',
        jsonEncode({'at': now.toIso8601String(), 'count': dislikes}),
      );
      return dislikes;
    } on DioException {
      return cached;
    } catch (_) {
      return cached;
    }
  }
}
