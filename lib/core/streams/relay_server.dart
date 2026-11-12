import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'net_family.dart';
import 'stream_selector.dart';

class _ChunkCache {
  static const int chunkSize = 1024 * 1024; // 1 MiB
  static const int maxChunks = 8; // 8 MiB total LRU
  final LinkedHashMap<int, Uint8List> _chunks = LinkedHashMap();

  Uint8List? get(int index) {
    final data = _chunks.remove(index);
    if (data != null) {
      _chunks[index] = data; // Move to most recently used
    }
    return data;
  }

  void put(int index, Uint8List data) {
    _chunks.remove(index);
    while (_chunks.length >= maxChunks) {
      _chunks.remove(_chunks.keys.first);
    }
    _chunks[index] = data;
  }
}

class _StreamLimiter {
  static const int maxConcurrent = 2;
  int active = 0;
  final List<({Completer<void> completer, bool Function() isStale})> queue = [];

  Future<void> acquire(bool Function() isStale) async {
    if (active < maxConcurrent) {
      active++;
      return;
    }
    final completer = Completer<void>();
    // LIFO: newest request first
    queue.insert(0, (completer: completer, isStale: isStale));
    await completer.future;
  }

  void release() {
    active--;
    while (queue.isNotEmpty) {
      final next = queue.removeAt(0);
      if (next.isStale()) {
        if (!next.completer.isCompleted) {
          next.completer.completeError(const HttpException('Stale request cancelled'));
        }
        continue;
      }
      active++;
      if (!next.completer.isCompleted) {
        next.completer.complete();
      }
      return;
    }
  }
}

class RelayServer {
  RelayServer(this.network, this.userAgent);
  final NetworkFamily network;
  final String userAgent;
  HttpServer? _server;
  final Map<String, StreamFormat> _items = {};
  final Map<String, _ChunkCache> _caches = {};
  final Map<String, _StreamLimiter> _limiters = {};
  final _random = Random.secure();

  void _debugLog(String msg) {
    if (kDebugMode) {
      stdout.writeln('[RelayServer] $msg');
    }
  }

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
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
    _caches[token] = _ChunkCache();
    _limiters[token] = _StreamLimiter();
    if (_items.length > 64) {
      final oldest = _items.keys.first;
      _items.remove(oldest);
      _caches.remove(oldest);
      _limiters.remove(oldest);
    }
    return Uri.parse('http://127.0.0.1:${_server!.port}/s/$token');
  }

  Future<({int status, Uint8List bytes})> _fetchRange(
    StreamFormat format,
    int start,
    int end, {
    Duration timeout = const Duration(seconds: 6),
    bool isCancelled = false,
  }) async {
    if (isCancelled) {
      throw const SocketException('Client connection closed');
    }
    Future<({int status, Uint8List bytes})> doFetch() async {
      final request = await network.client.getUrl(format.url).timeout(timeout);
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
      final response = await request.close().timeout(timeout);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return (status: response.statusCode, bytes: builder.takeBytes());
    }

    try {
      return await doFetch();
    } catch (e) {
      // 1 automatic retry on timeout or network glitch
      _debugLog('_fetchRange retrying range=$start-$end error=$e');
      return await doFetch();
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final segments = request.uri.pathSegments;
    final token = segments.length == 2 && segments[0] == 's' ? segments[1] : null;
    final format = token != null ? _items[token] : null;

    if (token == null ||
        format == null ||
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
      if (match[2]!.isNotEmpty) {
        end = min(end, int.parse(match[2]!));
      }
      if (start > end || start >= size) {
        response.statusCode = 416;
        response.headers.set('Content-Range', 'bytes */$size');
        await response.close();
        return;
      }
    }

    final cache = _caches[token] ??= _ChunkCache();
    final limiter = _limiters[token] ??= _StreamLimiter();

    // HEAD request support
    if (request.method == 'HEAD') {
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
      await response.close();
      return;
    }

    // First chunk before head (with 6s timeout)
    final startChunk = start ~/ _ChunkCache.chunkSize;

    Uint8List firstChunkData;
    final cachedFirst = cache.get(startChunk);
    if (cachedFirst != null) {
      firstChunkData = cachedFirst;
    } else {
      final chunkStart = startChunk * _ChunkCache.chunkSize;
      final chunkEnd = min(size - 1, chunkStart + _ChunkCache.chunkSize - 1);
      final firstRes = await _fetchRange(
        format,
        chunkStart,
        chunkEnd,
        timeout: const Duration(seconds: 6),
      );
      if (firstRes.status != 206 && firstRes.status != 200) {
        response.statusCode = firstRes.status >= 400 && firstRes.status < 500
            ? firstRes.status
            : 502;
        await response.close();
        return;
      }
      cache.put(startChunk, firstRes.bytes);
      firstChunkData = firstRes.bytes;
    }

    Socket? downstream;
    bool clientClosed = false;

    try {
      downstream = await response.detachSocket(writeHeaders: false);
      downstream.done.then((_) => clientClosed = true).ignore();
    } catch (_) {
      clientClosed = true;
    }

    if (clientClosed || downstream == null) {
      return;
    }

    // Write initial HTTP response headers
    downstream.write(
      'HTTP/1.1 ${range == null ? '200 OK' : '206 Partial Content'}\r\n'
      'Content-Type: ${format.mimeType.split(';').first}\r\n'
      'Content-Length: ${end - start + 1}\r\n'
      'Accept-Ranges: bytes\r\n'
      '${range == null ? '' : 'Content-Range: bytes $start-$end/$size\r\n'}'
      'Connection: close\r\n\r\n',
    );

    Future<Uint8List> getOrFetchChunk(int chunkIdx) async {
      if (chunkIdx == startChunk) {
        return firstChunkData;
      }
      final cached = cache.get(chunkIdx);
      if (cached != null) {
        return cached;
      }
      final chunkStart = chunkIdx * _ChunkCache.chunkSize;
      final chunkEnd = min(size - 1, chunkStart + _ChunkCache.chunkSize - 1);

      await limiter.acquire(() => clientClosed);
      try {
        if (clientClosed) {
          throw const SocketException('Client disconnected');
        }
        final res = await _fetchRange(
          format,
          chunkStart,
          chunkEnd,
          isCancelled: clientClosed,
        );
        if (res.status == 206 || res.status == 200) {
          cache.put(chunkIdx, res.bytes);
          return res.bytes;
        } else {
          throw HttpException('Upstream status ${res.status}');
        }
      } finally {
        limiter.release();
      }
    }

    try {
      final startChunk = start ~/ _ChunkCache.chunkSize;
      final endChunk = end ~/ _ChunkCache.chunkSize;

      for (var chunkIdx = startChunk; chunkIdx <= endChunk; chunkIdx++) {
        if (clientClosed) break;

        // Prefetch next chunk in background if within range
        if (chunkIdx + 1 <= endChunk && cache.get(chunkIdx + 1) == null) {
          unawaited(getOrFetchChunk(chunkIdx + 1).catchError((_) => Uint8List(0)));
        }

        final chunkData = await getOrFetchChunk(chunkIdx);
        if (clientClosed) break;

        final chunkBase = chunkIdx * _ChunkCache.chunkSize;
        final sliceStart = max(0, start - chunkBase);
        final sliceEnd = min(chunkData.length, end - chunkBase + 1);

        if (sliceStart < sliceEnd && sliceStart < chunkData.length) {
          final toSend = chunkData.sublist(sliceStart, min(sliceEnd, chunkData.length));
          downstream.add(toSend);
          await downstream.flush();
        }
      }
      if (!clientClosed) {
        await downstream.close();
      }
    } catch (_) {
      clientClosed = true;
      try {
        downstream.destroy();
      } catch (_) {}
    }
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
    _items.clear();
    _caches.clear();
    _limiters.clear();
  }
}
