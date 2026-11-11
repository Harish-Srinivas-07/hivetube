import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'net_family.dart';
import 'stream_selector.dart';

class RelayServer {
  RelayServer(this.network, this.userAgent);
  final NetworkFamily network;
  final String userAgent;
  HttpServer? _server;
  final Map<String, StreamFormat> _items = {};
  final _random = Random.secure();
  Future<void> start() async {
    _server ??= await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  Future<Uri> register(StreamFormat format) async {
    try {
      await start();
    } catch (_) {
      return format.url;
    }
    final token = List.generate(
      24,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();
    _items[token] = format;
    if (_items.length > 64) _items.remove(_items.keys.first);
    return Uri.parse('http://127.0.0.1:${_server!.port}/s/$token');
  }

  Future<({int status, Uint8List bytes})> _fetch(
    StreamFormat format,
    int start,
    int end,
  ) async {
    final request = await network.client.getUrl(format.url);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      format.userAgent ?? userAgent,
    );
    final client = format.url.queryParameters['c'];
    if (client == 'WEB' ||
        client == 'MWEB' ||
        client == 'WEB_REMIX' ||
        client == 'TVHTML5') {
      final origin = client == 'WEB_REMIX'
          ? 'https://music.youtube.com'
          : 'https://www.youtube.com';
      request.headers.set('Origin', origin);
      request.headers.set('Referer', '$origin/');
    }
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    final response = await request.close();
    final builder = BytesBuilder(copy: false);
    await for (final bytes in response) {
      builder.add(bytes);
    }
    return (status: response.statusCode, bytes: builder.takeBytes());
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final segments = request.uri.pathSegments;
    final format = segments.length == 2 && segments[0] == 's'
        ? _items[segments[1]]
        : null;
    if (format == null ||
        (request.method != 'GET' && request.method != 'HEAD')) {
      response.statusCode = 404;
      await response.close();
      return;
    }
    final size = format.length;
    if (size <= 0) {
      response.statusCode = 502;
      await response.close();
      return;
    }
    var start = 0, end = size - 1;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null) {
      final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
      if (match == null) {
        response.statusCode = 416;
        await response.close();
        return;
      }
      start = int.parse(match[1]!);
      if (match[2]!.isNotEmpty) end = min(end, int.parse(match[2]!));
      if (start > end || start >= size) {
        response.statusCode = 416;
        response.headers.set('Content-Range', 'bytes */$size');
        await response.close();
        return;
      }
    }
    Socket? downstream;
    try {
      final firstEnd = min(end, start + 1024 * 1024 - 1);
      final first = await _fetch(format, start, firstEnd);
      if (first.status != 206 || first.bytes.length != firstEnd - start + 1) {
        response.statusCode = first.status >= 400 && first.status < 500
            ? first.status
            : 502;
        await response.close();
        return;
      }
      response.statusCode = range == null ? 200 : 206;
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.set(
        HttpHeaders.contentTypeHeader,
        format.mimeType.split(';').first,
      );
      response.headers.set(HttpHeaders.contentLengthHeader, end - start + 1);
      if (range != null) {
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$size',
        );
      }
      if (request.method == 'HEAD') {
        await response.close();
        return;
      }
      downstream = await response.detachSocket(writeHeaders: false);
      downstream.done.ignore();
      downstream.write(
        'HTTP/1.1 ${range == null ? '200 OK' : '206 Partial Content'}\r\n'
        'Content-Type: ${format.mimeType.split(';').first}\r\n'
        'Content-Length: ${end - start + 1}\r\n'
        'Accept-Ranges: bytes\r\n'
        '${range == null ? '' : 'Content-Range: bytes $start-$end/$size\r\n'}'
        'Connection: close\r\n\r\n',
      );
      downstream.add(first.bytes);
      for (var offset = firstEnd + 1; offset <= end;) {
        final chunkEnd = min(end, offset + 1024 * 1024 - 1);
        final chunk = await _fetch(format, offset, chunkEnd);
        if (chunk.status != 206 ||
            chunk.bytes.length != chunkEnd - offset + 1) {
          throw const HttpException('Upstream chunk failed');
        }
        downstream.add(chunk.bytes);
        offset = chunkEnd + 1;
      }
      await downstream.flush();
      await downstream.close();
    } catch (_) {
      if (downstream != null) {
        downstream.destroy();
      } else {
        response.statusCode = 502;
        await response.close();
      }
    }
  }

  Future<void> close() async {
    await _server?.close(force: true);
  }
}
