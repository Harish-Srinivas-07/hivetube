import 'dart:io';

import 'package:hivetube/services/search_suggestions.dart';

Future<void> main(List<String> args) async {
  final query = args.isEmpty ? 'VJ siddhu' : args.join(' ');
  final source = YoutubeSearchSuggestionSource(hl: 'en', gl: 'IN');
  try {
    await source.fetch(query);
    stdout.writeln('HTTP status: ${source.lastStatusCode}');
    stdout.writeln('Raw body: ${source.lastRawBody}');
    stdout.writeln('Parsed suggestions: ${source.lastParsedSuggestions}');
  } catch (error, stackTrace) {
    stderr.writeln('HTTP status: ${source.lastStatusCode}');
    stderr.writeln('Raw body: ${source.lastRawBody}');
    stderr.writeln('Live suggestion probe failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    source.dispose();
  }
}
