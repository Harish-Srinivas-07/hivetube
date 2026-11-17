import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/downloads/chunked_download.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);
  final ResponseBody Function(RequestOptions) reply;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => reply(options);
}

void main() {
  late Directory dir;
  late File file;
  late Dio dio;
  final source = DownloadSource(
    url: Uri(scheme: 'https', host: 'example.com'),
    itag: 137,
    length: 4,
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('download_test_');
    file = File('${dir.path}/video.part');
    dio = Dio();
  });
  tearDown(() async {
    dio.close(force: true);
    await dir.delete(recursive: true);
  });
  ResponseBody response(List<int> body, String range, {int status = 206}) =>
      ResponseBody.fromBytes(
        body,
        status,
        headers: {
          HttpHeaders.contentRangeHeader: [range],
          HttpHeaders.contentLengthHeader: ['${body.length}'],
          HttpHeaders.etagHeader: ['"v1"'],
        },
      );
  test('resumes validated chunks and reports committed progress', () async {
    await file.writeAsBytes([1, 2]);
    dio.httpClientAdapter = _Adapter((options) {
      expect(options.headers[HttpHeaders.rangeHeader], 'bytes=2-3');
      expect(options.headers[HttpHeaders.ifRangeHeader], '"v1"');
      return response([3, 4], 'bytes 2-3/4');
    });
    final progress = <int>[];
    await ChunkedDownload(dio, chunkSize: 2).transfer(
      file: file,
      source: source,
      refresh: (_) async => source,
      cancelToken: CancelToken(),
      expectedEtag: '"v1"',
      onProgress: (done, _) => progress.add(done),
    );
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
    expect(progress, [4]);
  });
  test('rejects incorrect Content-Range without writing', () async {
    dio.httpClientAdapter = _Adapter((_) => response([1, 2], 'bytes 1-2/4'));
    await expectLater(
      ChunkedDownload(dio, chunkSize: 2).transfer(
        file: file,
        source: source,
        refresh: (_) async => source,
        cancelToken: CancelToken(),
      ),
      throwsA(isA<DownloadRangeException>()),
    );
    expect(await file.length(), 0);
  });
  test('refuses unverified partial resume', () async {
    await file.writeAsBytes([1, 2]);
    await expectLater(
      ChunkedDownload(dio).transfer(
        file: file,
        source: source,
        refresh: (_) async => source,
        cancelToken: CancelToken(),
      ),
      throwsA(isA<DownloadRangeException>()),
    );
    expect(await file.readAsBytes(), [1, 2]);
  });
  test('refreshes an expired URL and preserves the rendition', () async {
    var requests = 0;
    var refreshes = 0;
    dio.httpClientAdapter = _Adapter((options) {
      requests++;
      if (requests == 1) return ResponseBody.fromBytes([], 403);
      return response([1, 2, 3, 4], 'bytes 0-3/4');
    });
    await ChunkedDownload(dio).transfer(
      file: file,
      source: source,
      refresh: (itag) async {
        expect(itag, source.itag);
        refreshes++;
        return source;
      },
      cancelToken: CancelToken(),
    );
    expect(refreshes, 1);
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
  });
  test('cancelled transfer does not request or write bytes', () async {
    final token = CancelToken()..cancel();
    dio.httpClientAdapter = _Adapter((_) => fail('unexpected request'));
    await expectLater(
      ChunkedDownload(dio).transfer(
        file: file,
        source: source,
        refresh: (_) async => source,
        cancelToken: token,
      ),
      throwsA(isA<DioException>()),
    );
    expect(await file.length(), 0);
  });
}
