import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/streams/net_family.dart';
import 'package:hivetube/core/streams/relay_server.dart';
import 'package:hivetube/core/streams/stream_selector.dart';

void main() {
  late HttpServer upstream;
  late NetworkFamily network;
  late RelayServer relay;
  const size = 2 * 1024 * 1024 + 100;
  setUp(() async {
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstream.listen((request) async {
      final match = RegExp(
        r'bytes=(\d+)-(\d+)',
      ).firstMatch(request.headers.value('range') ?? '');
      if (request.uri.path == '/forbidden') {
        request.response.statusCode = 403;
        await request.response.close();
        return;
      }
      final start = int.parse(match![1]!);
      final end = int.parse(match[2]!);
      if (request.uri.path == '/broken' && start >= 1024 * 1024) {
        request.response.statusCode = 502;
        await request.response.close();
        return;
      }
      request.response.statusCode = 206;
      request.response.headers.set('content-range', 'bytes $start-$end/$size');
      request.response.add(
        List.generate(end - start + 1, (i) => (start + i) % 251),
      );
      await request.response.close();
    });
    network = NetworkFamily();
    relay = RelayServer(network, 'test');
  });
  tearDown(() async {
    await relay.close();
    network.close();
    await upstream.close(force: true);
  });
  Future<Uri> register(String path) => relay.register(
    StreamFormat({
      'contentLength': '$size',
      'mimeType': 'video/mp4',
    }, Uri.parse('http://127.0.0.1:${upstream.port}/$path')),
  );
  test('ranges span chunk boundaries and HEAD reports length', () async {
    final uri = await register('ok');
    final client = HttpClient();
    final get = await client.getUrl(uri);
    get.headers.set('range', 'bytes=1048500-1048700');
    final response = await get.close();
    final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(response.statusCode, 206);
    expect(bytes.length, 201);
    expect(bytes.first, 1048500 % 251);
    expect(bytes.last, 1048700 % 251);
    final head = await client.openUrl('HEAD', uri);
    final h = await head.close();
    expect(h.contentLength, size);
    await h.drain<void>();
    client.close(force: true);
  });
  test('first chunk 403 passes through', () async {
    final client = HttpClient();
    final response = await (await client.getUrl(
      await register('forbidden'),
    )).close();
    expect(response.statusCode, 403);
    await response.drain<void>();
    client.close(force: true);
  });
  test('open-ended range request bytes=0- works with correct bounds', () async {
    final uri = await register('ok');
    final client = HttpClient();
    final get = await client.getUrl(uri);
    get.headers.set('range', 'bytes=0-');
    final response = await get.close();
    expect(response.statusCode, 206);
    expect(response.headers.value('content-range'), 'bytes 0-${size - 1}/$size');
    expect(response.contentLength, size);
    client.close(force: true);
  });

  test('LRU chunk cache serves repeated requests without re-fetching upstream', () async {
    int upstreamHits = 0;
    final testServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    testServer.listen((req) async {
      upstreamHits++;
      req.response.statusCode = 206;
      req.response.headers.set('content-range', 'bytes 0-1048575/$size');
      req.response.add(Uint8List(1024 * 1024));
      await req.response.close();
    });

    final testUri = await relay.register(
      StreamFormat({
        'contentLength': '$size',
        'mimeType': 'video/mp4',
      }, Uri.parse('http://127.0.0.1:${testServer.port}/cached')),
    );

    final client = HttpClient();
    final get1 = await client.getUrl(testUri);
    get1.headers.set('range', 'bytes=0-100');
    final res1 = await get1.close();
    await res1.drain<void>();

    final initialHits = upstreamHits;
    expect(initialHits, greaterThan(0));

    // Second request within the same 1 MiB chunk should hit LRU cache
    final get2 = await client.getUrl(testUri);
    get2.headers.set('range', 'bytes=50-150');
    final res2 = await get2.close();
    await res2.drain<void>();

    expect(upstreamHits, equals(initialHits)); // No new upstream request
    client.close(force: true);
    await testServer.close(force: true);
  });

  test('client early disconnect cancels gracefully', () async {
    final uri = await register('ok');
    final socket = await Socket.connect('127.0.0.1', uri.port);
    socket.write('GET ${uri.path} HTTP/1.1\r\nHost: 127.0.0.1\r\nRange: bytes=0-\r\n\r\n');
    await socket.flush();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await socket.close();
    socket.destroy();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
}
