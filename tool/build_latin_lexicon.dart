import 'dart:convert';
import 'dart:io';

final _wordSeparator = RegExp(r'[^a-z\u00c0-\u024f\u1e00-\u1eff]+');

Iterable<String> _words(String text) =>
    text.toLowerCase().split(_wordSeparator).where((word) => word.isNotEmpty);

Future<void> main(List<String> args) async {
  if (args.length < 4 || !RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(args[0])) {
    stderr.writeln(
      'Usage: dart run tool/build_latin_lexicon.dart <code> <sample.txt> [sample.txt ...] --stopwords <file> [--min-length N] [--min-frequency N] [--limit N]',
    );
    exitCode = 64;
    return;
  }
  final code = args.first;
  final samples = <String>[];
  String? stopwordPath;
  var minLength = 3;
  var minFrequency = 2;
  var limit = 1000;
  for (var index = 1; index < args.length; index++) {
    final arg = args[index];
    if (!arg.startsWith('--')) {
      samples.add(arg);
      continue;
    }
    if (index + 1 >= args.length) {
      throw FormatException('Missing value for $arg');
    }
    final value = args[++index];
    switch (arg) {
      case '--stopwords':
        stopwordPath = value;
      case '--min-length':
        minLength = int.parse(value);
      case '--min-frequency':
        minFrequency = int.parse(value);
      case '--limit':
        limit = int.parse(value);
      default:
        throw FormatException('Unknown option: $arg');
    }
  }
  if (samples.isEmpty ||
      stopwordPath == null ||
      minLength < 1 ||
      minFrequency < 1 ||
      limit < 1) {
    throw const FormatException(
      'Samples, stopwords, and positive thresholds are required',
    );
  }
  final stopwords = _words(await File(stopwordPath).readAsString()).toSet();
  final counts = <String, int>{};
  for (final path in samples) {
    final lines = await File(path).readAsLines();
    for (final line in lines) {
      for (final word in _words(line).toSet()) {
        if (word.length >= minLength && !stopwords.contains(word)) {
          counts.update(word, (count) => count + 1, ifAbsent: () => 1);
        }
      }
    }
  }
  final ranked =
      counts.entries.where((entry) => entry.value >= minFrequency).toList()
        ..sort((a, b) {
          final frequency = b.value.compareTo(a.value);
          return frequency != 0 ? frequency : a.key.compareTo(b.key);
        });
  if (ranked.isEmpty) {
    throw const FormatException('No words meet the thresholds');
  }
  final output = File('assets/lexicons/$code.json');
  await output.parent.create(recursive: true);
  await output.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert({'code': code, 'source': 'Frequency counts from supplied sample lines', 'words': ranked.take(limit).map((entry) => entry.key).toList()})}\n',
  );
  stdout.writeln('Wrote ${ranked.take(limit).length} words to ${output.path}');
}
