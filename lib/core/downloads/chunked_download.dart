import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';

/// A refreshed URL must still identify the same rendition.
class DownloadSource {
  const DownloadSource({
    required this.url,
    required this.itag,
    required this.length,
    this.userAgent,
  });
  final Uri url;
  final int itag;
  final int length;
  final String? userAgent;
}

class DownloadRangeException implements Exception {
  const DownloadRangeException(this.message);
  final String message;
  @override
  String toString() => 'DownloadRangeException: $message';
}

/// Downloads validated byte ranges directly to disk. Partial chunks roll back.
class ChunkedDownload {
  ChunkedDownload(this.dio, {this.chunkSize = 1024 * 1024});
  final Dio dio;
  final int chunkSize;

  Future<void> transfer({
    required File file,
    required DownloadSource source,
    required Future<DownloadSource> Function(int itag) refresh,
    required CancelToken cancelToken,
    void Function(int done, int total)? onProgress,
    String? expectedEtag,
    Future<void> Function(String etag)? onValidator,
  }) async {
    if (source.length <= 0 || chunkSize <= 0) {
      throw const DownloadRangeException(
        'Missing length or invalid chunk size',
      );
    }
    await file.parent.create(recursive: true);
    if (!await file.exists()) await file.create();
    final output = await file.open(mode: FileMode.append);
    var current = source;
    var offset = await output.length();
    var validator = expectedEtag;
    var refreshes = 0;
    try {
      if (offset > current.length) {
        throw const DownloadRangeException(
          'Partial file exceeds stream length',
        );
      }
      if (offset > 0 && (validator == null || validator.startsWith('W/'))) {
        throw const DownloadRangeException(
          'Cannot resume without a strong ETag',
        );
      }
      while (offset < current.length) {
        if (cancelToken.isCancelled) throw cancelToken.cancelError!;
        final end = math.min(offset + chunkSize - 1, current.length - 1);
        Response<ResponseBody> response;
        try {
          response = await dio.getUri<ResponseBody>(
            current.url,
            cancelToken: cancelToken,
            options: Options(
              responseType: ResponseType.stream,
              headers: {
                HttpHeaders.rangeHeader: 'bytes=$offset-$end',
                HttpHeaders.acceptEncodingHeader: 'identity',
                HttpHeaders.ifRangeHeader: ?validator,
                if (current.userAgent != null)
                  HttpHeaders.userAgentHeader: current.userAgent,
              },
              validateStatus: (status) => status != null && status < 500,
            ),
          );
        } on DioException {
          rethrow;
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          await response.data?.stream.drain<void>();
          if (offset > 0 && validator == null) {
            throw const DownloadRangeException(
              'Cannot safely refresh a partial transfer without a strong ETag',
            );
          }
          if (refreshes++ >= 3) {
            throw const DownloadRangeException(
              'Stream URL refresh limit reached',
            );
          }
          final replacement = await refresh(current.itag);
          if (replacement.itag != current.itag ||
              replacement.length != current.length) {
            throw const DownloadRangeException('Refreshed rendition changed');
          }
          current = replacement;
          continue;
        }
        final headers = response.headers;
        final range = headers.value(HttpHeaders.contentRangeHeader);
        final length = int.tryParse(
          headers.value(HttpHeaders.contentLengthHeader) ?? '',
        );
        final etag = headers.value(HttpHeaders.etagHeader);
        if (response.statusCode != 206 ||
            range != 'bytes $offset-$end/${current.length}' ||
            length != end - offset + 1 ||
            (validator != null && etag != validator) ||
            response.data == null) {
          await response.data?.stream.drain<void>();
          throw const DownloadRangeException('Invalid range, length, or ETag');
        }
        if (validator == null && etag != null && !etag.startsWith('W/')) {
          validator = etag;
          await onValidator?.call(etag);
        }
        final start = offset;
        try {
          await output.setPosition(start);
          var received = 0;
          await for (final bytes in response.data!.stream) {
            received += bytes.length;
            if (received > end - start + 1) {
              throw const DownloadRangeException('Range body too long');
            }
            await output.writeFrom(bytes);
          }
          if (received != end - start + 1) {
            throw const DownloadRangeException('Range body truncated');
          }
          await output.flush();
          offset = end + 1;
          onProgress?.call(offset, current.length);
        } catch (_) {
          await output.truncate(start);
          rethrow;
        }
      }
    } finally {
      await output.close();
    }
  }
}
