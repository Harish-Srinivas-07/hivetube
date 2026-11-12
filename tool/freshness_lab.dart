// Live feed experiment. Run with: dart run tool/freshness_lab.dart
// This script sends real YouTube, Suggestions, RSS, and player requests.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
Random random = Random(DateTime.now().microsecondsSinceEpoch);
var requestCount = 0;

Future<dynamic> getJson(Uri uri, {Map<String, String> headers = const {}}) async {
  requestCount++;
  final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
  headers.forEach(request.headers.set);
  final response = await request.close().timeout(const Duration(seconds: 15));
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException('GET $uri returned ${response.statusCode}');
  }
  return jsonDecode(body);
}

Future<String> getText(Uri uri) async {
  requestCount++;
  final request = await client.getUrl(uri).timeout(const Duration(seconds: 10));
  final response = await request.close().timeout(const Duration(seconds: 15));
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('GET $uri returned ${response.statusCode}');
  return body;
}

List<Map<String, String>> rssVideos(String xml) {
  final result = <Map<String, String>>[];
  for (final entry in RegExp(r'<entry>(.*?)</entry>', dotAll: true).allMatches(xml)) {
    final body = entry.group(1)!;
    String value(String tag) => RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true).firstMatch(body)?.group(1)?.replaceAll('&amp;', '&') ?? '';
    result.add({'id': value('yt:videoId'), 'title': value('title'), 'channel': value('name'), 'channelId': value('yt:channelId'), 'published': value('published')});
  }
  return result.where((e) => (e['id'] ?? '').isNotEmpty).toList();
}

Future<dynamic> postJson(Uri uri, Map<String, dynamic> body,
    {Map<String, String> headers = const {}}) async {
  requestCount++;
  final request = await client.postUrl(uri).timeout(const Duration(seconds: 10));
  request.headers.contentType = ContentType.json;
  headers.forEach(request.headers.set);
  request.write(jsonEncode(body));
  final response = await request.close().timeout(const Duration(seconds: 15));
  final text = await response.transform(utf8.decoder).join();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException('POST ${uri.path} returned ${response.statusCode}: $text');
  }
  return jsonDecode(text);
}

Iterable<Map> walk(dynamic value) sync* {
  if (value is Map) {
    yield value;
    for (final child in value.values) {
      yield* walk(child);
    }
  } else if (value is List) {
    for (final child in value) {
      yield* walk(child);
    }
  }
}

String text(dynamic value) {
  if (value is String) return value;
  if (value is Map) {
    if (value['simpleText'] is String) return value['simpleText'] as String;
    final runs = value['runs'];
    if (runs is List) return runs.map((e) => e is Map ? e['text'] ?? '' : '').join();
  }
  return '';
}

List<Map<String, String>> videos(dynamic response) {
  final output = <Map<String, String>>[];
  final seen = <String>{};
  for (final node in walk(response)) {
    final renderer = node['videoRenderer'];
    if (renderer is! Map) continue;
    final id = renderer['videoId'] as String? ?? '';
    if (id.isEmpty || !seen.add(id)) continue;
    String channelId = '';
    String channel = '';
    for (final child in walk(renderer)) {
      if (child['browseEndpoint'] is Map) {
        final id = (child['browseEndpoint'] as Map)['browseId'];
        if (id is String && id.startsWith('UC')) channelId = id;
      }
    }
    for (final key in ['ownerText', 'longBylineText', 'shortBylineText']) {
      final value = text(renderer[key]);
      if (value.isNotEmpty) { channel = value; break; }
    }
    final published = text(renderer['publishedTimeText']);
    output.add({
      'id': id,
      'title': text(renderer['title']),
      'channel': channel,
      'channelId': channelId,
      'published': published,
    });
  }
  return output;
}

List<String> searchParams(dynamic response, bool Function(String) match) {
  final values = <String>[];
  for (final node in walk(response)) {
    final group = node['searchFilterGroupRenderer'];
    if (group is! Map) continue;
    final title = text(group['title']).toLowerCase();
    for (final item in walk(group)) {
      final filter = item['searchFilterRenderer'];
      if (filter is! Map) continue;
      final label = text(filter['label']).toLowerCase();
      if (!match('$title $label')) continue;
      final ep = filter['navigationEndpoint'];
      final query = ep is Map ? ep['searchEndpoint'] : null;
      final params = query is Map ? query['params'] : null;
      if (params is String && params.isNotEmpty && !values.contains(params)) values.add(params);
    }
  }
  return values;
}

Future<dynamic> search(String query, {String? params}) => postJson(
  Uri.parse('https://www.youtube.com/youtubei/v1/search?prettyPrint=false'),
  {
    'context': {'client': {'clientName': 'WEB', 'clientVersion': '2.20260805.01.00', 'hl': 'en', 'gl': 'IN'}},
    'query': query,
    'params': ?params,
  },
  headers: const {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36',
    'Origin': 'https://www.youtube.com',
    'Referer': 'https://www.youtube.com/',
  },
);

String? ageDays(String value) {
  final timestamp = DateTime.tryParse(value);
  if (timestamp != null) return DateTime.now().difference(timestamp).inDays.clamp(0, 36500).toString();
  final s = value.toLowerCase();
  final n = int.tryParse(RegExp(r'\d+').firstMatch(s)?.group(0) ?? '');
  if (n == null) return null;
  if (s.contains('minute') || s.contains('hour')) return '0';
  if (s.contains('day')) return '$n';
  if (s.contains('week')) return '${n * 7}';
  if (s.contains('month')) return '${n * 30}';
  if (s.contains('year')) return '${n * 365}';
  return null;
}

String scriptVerdict(String value) => RegExp(r'[\u0B80-\u0BFF]').hasMatch(value) ? 'ta' : 'latin/unknown';

Future<void> main() async {
  const staticQueries = <String>[
    'தமிழ் பாடல்கள்','tamil songs','tamil new songs','tamil melody songs','kollywood hits','anirudh hits',
    'tamil movie trailer','tamil cinema news','தமிழ் திரைப்படங்கள்','kollywood updates','tamil full movie',
    'tamil comedy','vadivelu comedy','goundamani senthil comedy','tamil memes','tamil stand up',
    'tamil news live','polimer news live','puthiyathalaimurai live','sun news live','tamil nadu seithigal',
    'tamil samayal','village cooking channel','madras samayal','tamil nadu recipes','tamil gaming live',
    'tamil gamer','free fire tamil','tamil tech review','tamil mobile review','ipl tamil commentary',
  ];
  final seed = random.nextInt(1 << 32);
  stdout.writeln('Tamil freshness lab seed=$seed runs=3; direct API calls only');
  final seenFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}hivetube_freshness_seen.json');
  final persistedSeen = <String>{};
  try { persistedSeen.addAll((jsonDecode(await seenFile.readAsString()) as List).whereType<String>()); } catch (_) {}
  final seenBeforeLab = Set<String>.of(persistedSeen);
  stdout.writeln('strategy | items | script ta | ASR ta/known | <=7d | median age | unique channels | run/seen overlap | requests | status');
  final previous = <String, Set<String>>{};
  final seen = <String>{};
  const names = ['A static', 'B latest+filters', 'C suggestions', 'D seed RSS', 'E learned RSS', 'F explore/kiosk'];
  try {
    // Three independent runs measure query and item overlap. Each source is capped at 60.
    for (var run = 0; run < 3; run++) {
      random = Random(seed + run * 7919);
      for (final name in names) {
        final before = requestCount;
        final rows = <Map<String, String>>[];
        String? sourceFailure;
        try {
          if (name.startsWith('A')) {
            final pool = [...staticQueries]..shuffle(random);
            for (final q in pool.take(8)) {
              rows.addAll(videos(await search(q)));
              if (rows.length >= 60) break;
            }
          } else if (name.startsWith('B')) {
            final pool = [...staticQueries]..shuffle(random);
            for (final q in pool.take(8)) {
              final probe = await search('$q ${['latest', 'new', 'today', 'this week'][random.nextInt(4)]}');
              final params = searchParams(probe, (s) => (s.contains('upload') && (s.contains('week') || s.contains('today'))) || (s.contains('sort') && s.contains('upload')));
              final fresh = params.isEmpty ? probe : await search(q, params: params.first);
              rows.addAll(videos(fresh));
              if (rows.length >= 60) break;
            }
          } else if (name.startsWith('C')) {
            final seeds = ['tamil', 'tamil music', 'tamil movies', 'tamil news', 'tamil cooking', 'anirudh tamil music', 'tamil new film trailer', ...'abcde'.split('').map((letter) => 'tamil music $letter')];
            final suggestions = <String>{};
            for (final q in seeds.take(8)) {
              final result = await getJson(Uri.https('suggestqueries.google.com', '/complete/search', {'client':'firefox','ds':'yt','q':q,'hl':'en','gl':'IN'}));
              if (result is List && result.length > 1 && result[1] is List) suggestions.addAll((result[1] as List).whereType<String>());
            }
            final pool = suggestions.toList()..shuffle(random);
            for (final q in pool.take(10)) {
              rows.addAll(videos(await search(q)));
              if (rows.length >= 60) break;
            }
          } else if (name.startsWith('D') || name.startsWith('E')) {
            final file = File(name.startsWith('D') ? 'tool/freshness_seed_channels.json' : 'tool/freshness_learned_channels.json');
            if (!await file.exists()) {
              stdout.writeln('$name | 0 | n/a | n/a | n/a | n/a | 0 | n/a | 0 | no verified channel export');
              continue;
            }
            final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            final channels = raw['channels'];
            if (channels is List) {
              for (final entry in channels.whereType<Map>()) {
                final id = entry['channelId'];
                if (id is! String || !id.startsWith('UC')) continue;
                final response = await getText(Uri.https('www.youtube.com', '/feeds/videos.xml', {'channel_id': id}));
                rows.addAll(rssVideos(response));
                if (rows.length >= 60) break;
              }
            }
          } else {
            for (final query in ['#tamil', 'FEexplore', 'UC4R8DWoMoI7CAwX8_LjQHig']) {
              try {
                final response = query.startsWith('FE') || query.startsWith('UC')
                    ? await postJson(Uri.parse('https://www.youtube.com/youtubei/v1/browse?prettyPrint=false'), {'context': {'client': {'clientName':'WEB','clientVersion':'2.20260805.01.00','hl':'en','gl':'IN'}}, 'browseId': query})
                    : await search(query);
                rows.addAll(videos(response));
              } catch (error) { sourceFailure ??= error.toString(); }
              if (rows.length >= 60) break;
            }
          }
          final unique = <String, Map<String, String>>{for (final row in rows) row['id']!: row};
          final ids = unique.keys.take(60).toSet();
          final old = previous[name] ?? const <String>{};
          final runOverlap = ids.isEmpty ? null : ids.intersection(old).length / ids.length;
          final seenOverlap = ids.isEmpty ? null : ids.intersection(seenBeforeLab).length / ids.length;
          previous[name] = ids;
          final sample = run == 0 ? unique.values.take(30).toList() : const <Map<String, String>>[];
          var asrTa = 0;
          var asrKnown = 0;
          for (final item in sample) {
            try {
              final player = await postJson(Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'), {'context': {'client': {'clientName':'ANDROID','clientVersion':'21.03.36','hl':'en','gl':'IN'}}, 'videoId': item['id']}, headers: const {'User-Agent':'com.google.android.youtube/21.03.36 (Linux; U; Android 11) gzip'});
              for (final node in walk(player)) {
                if (node['captionTracks'] is List) {
                  final tracks = (node['captionTracks'] as List).whereType<Map>();
                  final track = tracks.where((e) => e['kind'] == 'asr').firstOrNull ?? tracks.firstOrNull;
                  final lang = track?['languageCode'] as String?;
                  if (lang != null) { asrKnown++; if (lang.startsWith('ta')) asrTa++; }
                  break;
                }
              }
            } catch (error) { sourceFailure ??= error.toString(); }
          }
          final days = unique.values.map((e) => int.tryParse(ageDays(e['published'] ?? '') ?? '')).whereType<int>().toList()..sort();
          final recent = days.where((d) => d <= 7).length;
          seen.addAll(ids);
          persistedSeen.addAll(ids);
          await seenFile.writeAsString(jsonEncode(persistedSeen.toList()));
          stdout.writeln('$name | ${ids.length} | ${ids.isEmpty ? 'n/a' : '${unique.values.where((e) => scriptVerdict(e['title'] ?? '') == 'ta').length}/${ids.length}'} | $asrTa/$asrKnown | ${days.isEmpty ? 'n/a' : '${(recent * 100 / days.length).round()}%'} | ${days.isEmpty ? 'n/a' : '${days[days.length ~/ 2]}d'} | ${unique.values.map((e) => e['channelId']).where((c) => c != null && c.isNotEmpty).toSet().length} | ${runOverlap == null ? 'n/a' : '${(runOverlap * 100).round()}%'}/${seenOverlap == null ? 'n/a' : '${(seenOverlap * 100).round()}%'} | ${requestCount - before} | ${sourceFailure ?? (ids.isEmpty ? 'no items' : 'live')}');
        } catch (error) {
          stdout.writeln('$name | 0 | n/a | n/a | n/a | n/a | 0 | n/a | ${requestCount - before} | blocked: $error');
        }
      }
    }
  } catch (error) {
    stderr.writeln('Lab setup failed: $error');
  } finally {
    stdout.writeln('seen ids persisted this process: ${seen.length}; total real requests attempted: $requestCount');
    client.close(force: true);
  }
}
