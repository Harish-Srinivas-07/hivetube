import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hivetube/core/yt/models.dart';
import 'package:hivetube/core/yt/yt_rss.dart';

void main() async {
  stdout.writeln('=== RSS Feed Smoke Test ===');
  final dio = Dio();
  final rss = YtRss(dio);

  final channels = [
    ('UCK8sQmJBp8GCxrOtXWBpyEA', '@Google'),
    ('UCwXdFgeE9KYzlDdR7TG9cMw', '@flutterdev'),
    ('UCBR8-60-B28hp2BmDPdntcQ', '@YouTube'),
  ];

  final allVideos = <VideoItem>[];

  for (final (id, name) in channels) {
    stdout.writeln('Fetching RSS for $name ($id)...');
    try {
      final items = await rss.uploads(id);
      stdout.writeln('  Found ${items.length} videos from RSS.');
      for (final item in items.take(3)) {
        stdout.writeln('    - "${item.title}" (${item.id}) published at ${item.publishedAt}');
      }
      allVideos.addAll(items);
    } catch (e) {
      stdout.writeln('  Error fetching RSS for $name: $e');
    }
  }

  // Merge & sort top 10 by publish date
  allVideos.sort((a, b) {
    final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  });

  stdout.writeln('\n=== Merged Top 10 RSS Entries ===');
  final top10 = allVideos.take(10).toList();
  for (var i = 0; i < top10.length; i++) {
    final v = top10[i];
    stdout.writeln('  ${i + 1}. [${v.channelName}] "${v.title}" (${v.publishedAt})');
  }

  stdout.writeln('\nTotal RSS items fetched across 3 channels: ${allVideos.length}');
  stdout.writeln('Top 10 count: ${top10.length}');
  dio.close();
}
