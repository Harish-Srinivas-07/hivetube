import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../innertube/clients.dart';
import 'net_family.dart';

const playerFieldMask =
    'playabilityStatus,streamingData(formats,adaptiveFormats(itag,url,mimeType,bitrate,averageBitrate,width,height,contentLength,quality,audioQuality,approxDurationMs,audioSampleRate,audioChannels,loudnessDb,lastModified,xtags,audioTrack,isDrc,signatureCipher,initRange,indexRange,fps),expiresInSeconds,hlsManifestUrl,serverAbrStreamingUrl),videoDetails,playerConfig.audioConfig';

enum StreamError {
  ageRestricted,
  geoRestricted,
  unavailable,
  botCheck,
  extractionFailed,
  noStreams,
  noVideo,
}

class StreamException implements Exception {
  const StreamException(this.code);
  final StreamError code;
  @override
  String toString() => code.name;
}

class PlayerClient {
  PlayerClient(
    this.network,
    this.clients,
    this.visitor,
    this.refreshVisitor, {
    this.hl = 'en',
    this.gl = 'IN',
  });
  final String hl, gl;
  final NetworkFamily network;
  final InnertubeClients clients;
  final String? Function() visitor;
  final Future<void> Function() refreshVisitor;
  final Random _random = Random.secure();
  String _nonce(int length) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    return List.generate(
      length,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  Future<Map<String, dynamic>> request(String id, String profile) async {
    final c = clients[profile];
    final cpn = _nonce(16);
    final contextClient = <String, dynamic>{
      for (final e in c.entries)
        if (e.key != 'ua' && e.key != 'id' && e.key != 'origin') e.key: e.value,
      'hl': hl,
      'gl': gl,
      if (visitor() != null) 'visitorData': visitor(),
    };
    final uri = Uri.https(
      profile == 'VISIONOS_YTDLP'
          ? 'www.youtube.com'
          : 'youtubei.googleapis.com',
      '/youtubei/v1/player',
      {'prettyPrint': 'false', 't': _nonce(12), 'id': id},
    );
    final req = await network.client.postUrl(uri);
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.headers.set(HttpHeaders.userAgentHeader, c['ua']);
    req.headers.set('X-Goog-Api-Format-Version', '2');
    req.headers.set('X-Goog-FieldMask', playerFieldMask);
    if (profile == 'VISIONOS_YTDLP') {
      req.headers.set('X-YouTube-Client-Name', '101');
    }
    req.write(
      jsonEncode({
        'context': {
          'client': contextClient,
          'user': {'lockedSafetyMode': false},
          'request': {'useSsl': true},
        },
        'videoId': id,
        'cpn': cpn,
        'contentCheckOk': true,
        'racyCheckOk': true,
      }),
    );
    final response = await req.close().timeout(const Duration(seconds: 15));
    if (response.statusCode == 403) {
      await response.drain<void>();
      throw const StreamException(StreamError.botCheck);
    }
    if (response.statusCode != 200) {
      throw const StreamException(StreamError.extractionFailed);
    }
    final body =
        jsonDecode(await utf8.decodeStream(response)) as Map<String, dynamic>;
    final data = body['streamingData'];
    if (data is Map) {
      for (final key in ['adaptiveFormats', 'formats']) {
        final formats = data[key];
        if (formats is List) {
          for (final f in formats) {
            if (f is Map && f['url'] is String) {
              f['_userAgent'] = c['ua'];
              final uri = Uri.parse(f['url'] as String);
              f['url'] = uri
                  .replace(
                    queryParameters: {...uri.queryParameters, 'cpn': cpn},
                  )
                  .toString();
            }
          }
        }
      }
    }
    return body;
  }

  Future<Map<String, dynamic>> resolve(String id) async {
    final family = network.preferIpv4;
    for (var familyAttempt = 0; familyAttempt < 2; familyAttempt++) {
      Map<String, dynamic>? last;
      var bot = false;
      try {
        for (var attempt = 0; attempt < 3; attempt++) {
          if (attempt == 1) await refreshVisitor();
          last = await request(
            id,
            attempt == 2 ? 'VISIONOS_YTDLP' : 'VISIONOS',
          );
          final status = last['playabilityStatus'];
          if (status is Map && status['status'] == 'OK') {
            final streams = last['streamingData'];
            final formats = streams is Map ? streams['adaptiveFormats'] : null;
            if (formats is List &&
                formats.any((f) => f is Map && f['url'] is String)) {
              return last;
            }
          }
          final reason = jsonEncode(status).toLowerCase();
          if (reason.contains('not a bot') ||
              reason.contains('confirm you’re not a bot')) {
            bot = true;
            break;
          }
        }
      } on StreamException catch (error) {
        if (error.code != StreamError.botCheck) rethrow;
        bot = true;
      }
      if (bot) {
        if (familyAttempt == 0) {
          await network.flip(family);
          continue;
        }
        throw const StreamException(StreamError.botCheck);
      }
      final reason = jsonEncode(last?['playabilityStatus']).toLowerCase();
      if (reason.contains('age') || reason.contains('inappropriate')) {
        throw const StreamException(StreamError.ageRestricted);
      }
      if (reason.contains('country') || reason.contains('region')) {
        throw const StreamException(StreamError.geoRestricted);
      }
      if (last != null) throw const StreamException(StreamError.unavailable);
    }
    throw const StreamException(StreamError.extractionFailed);
  }
}
