import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/yt/ryd.dart';

class _Adapter implements HttpClientAdapter {
  int status = 200;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      status == 200 ? '{"dislikes": 123}' : '{}',
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('uses 24-hour cache and keeps old value when rate limited', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final dio = Dio();
    addTearDown(dio.close);
    final adapter = _Adapter();
    dio.httpClientAdapter = adapter;
    var now = DateTime.utc(2026, 1, 1);
    final service = RydService(dio, db, clock: () => now);
    expect(await service.dislikes('video'), 123);
    expect(await service.dislikes('video'), 123);
    expect(adapter.calls, 1);
    now = now.add(const Duration(hours: 25));
    adapter.status = 429;
    expect(await service.dislikes('video'), 123);
    expect(adapter.calls, 2);
    expect(
      (jsonDecode((await db.getValue('ryd_video'))!) as Map)['count'],
      123,
    );
  });
}
