import 'dart:io';

import 'package:hivetube/services/search_suggestion_source.dart';

Future<void> main(List<String> args) async {
  final query = args.isEmpty ? 'VJ siddhu' : args.join(' ');
  final source = YoutubeSearchSuggestionSource(hl: 'en', gl: 'IN');
  try {
    final suggestions = await source.fetch(query);
    stdout.writeln('HTTP status: ${source.lastStatusCode}');
    stdout.writeln('Raw body length: ${source.lastRawBody?.length ?? 0}');
    stdout.writeln('Parsed count: ${suggestions.length}');
  } catch (error, stackTrace) {
    stderr.writeln('HTTP status: ${source.lastStatusCode}');
    stderr.writeln('Raw body length: ${source.lastRawBody?.length ?? 0}');
    stderr.writeln('Parsed count: ${source.lastParsedSuggestions.length}');
    stderr.writeln('Suggestion probe failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    source.dispose();
  }
}
