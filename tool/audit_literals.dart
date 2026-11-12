// ignore_for_file: avoid_print
import 'dart:io';

void main(List<String> args) {
  final libDir = Directory('lib');
  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.contains('lib${Platform.pathSeparator}theme'))
      .toList();

  final uiRegexes = {
    'EdgeInsets/Padding': RegExp(r'EdgeInsets\.(all|symmetric|only)\s*\([^\)]*\d'),
    'SizedBox': RegExp(r'SizedBox\s*\(\s*(width|height)\s*:\s*\d+(\.\d+)?'),
    'BorderRadius': RegExp(r'BorderRadius\.circular\s*\(\s*\d+(\.\d+)?'),
    'Color/Colors': RegExp(r'(?<![A-Za-z0-9_])(Color\s*\(\s*0x[0-9a-fA-F]+\)|Colors\.[a-zA-Z]+)'),
    'TextStyle': RegExp(r'TextStyle\s*\([^)]*(fontSize|fontWeight)\s*:'),
    'Icon size': RegExp(r'(iconSize|size)\s*:\s*\d+(\.\d+)?'),
  };

  final allowlistedDurationRegex = RegExp(r'Duration\s*\(\s*(milliseconds|seconds|minutes)\s*:\s*\d+');

  var uiLiteralCount = 0;
  var allowlistedDurationCount = 0;
  final fileViolations = <String, List<String>>{};

  for (final file in files) {
    final p = file.path.replaceAll('\\', '/');
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final entry in uiRegexes.entries) {
        if (entry.value.hasMatch(lines[i])) {
          uiLiteralCount++;
          fileViolations.putIfAbsent(p, () => []).add('L${i + 1} [${entry.key}]: ${lines[i].trim()}');
        }
      }
      if (allowlistedDurationRegex.hasMatch(lines[i])) {
        allowlistedDurationCount++;
      }
    }
  }

  print('=== LITERALS AUDIT SUMMARY ===');
  print('UI Magic Numbers (Target 0): $uiLiteralCount');
  for (final entry in uiRegexes.keys) {
    final count = fileViolations.values
        .expand((l) => l)
        .where((s) => s.contains('[$entry]'))
        .length;
    print('  $entry: $count');
  }
  print('Allowlisted Durations (Timeouts/Cache/Timers): $allowlistedDurationCount');

  if (fileViolations.isNotEmpty) {
    print('\nViolations:');
    fileViolations.forEach((f, list) {
      print('  $f:');
      for (final l in list) {
        print('    $l');
      }
    });
  } else {
    print('\nSUCCESS: Zero UI magic numbers outside lib/theme/! All remaining durations are in the documented allowlist.');
  }
}
