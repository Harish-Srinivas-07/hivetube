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
    final key = 'ryd_$videoId';
    int? cached;
    try {
      final data = jsonDecode(await db.getValue(key) ?? '{}') as Map;
      cached = data['count'] as int?;
      final saved = DateTime.tryParse('${data['at']}');
      if (saved != null &&
          clock().difference(saved) < const Duration(hours: 24) &&
          !clock().isBefore(saved)) {
        return cached;
      }
    } catch (_) {}
    try {
      final response = await dio.get<Map<String, dynamic>>(
        'https://returnyoutubedislikeapi.com/votes',
        queryParameters: {'videoId': videoId},
      );
      final value = response.data?['dislikes'];
      if (value is! int) return cached;
      await db.setValue(
        key,
        jsonEncode({'at': clock().toIso8601String(), 'count': value}),
      );
      return value;
    } on DioException {
      return cached;
    }
  }
}
