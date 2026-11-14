import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('language assets are valid JSON with nonempty topic templates', () {
    final files = Directory(
      'assets/languages',
    ).listSync().whereType<File>().where((file) => file.path.endsWith('.json'));

    expect(files, isNotEmpty);
    for (final file in files) {
      final profile =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final topicTemplates = profile['topicTemplates'] as Map<String, dynamic>;

      expect(topicTemplates['All'], isA<List>(), reason: file.path);
      expect((topicTemplates['All'] as List), isNotEmpty, reason: file.path);
      for (final entry in topicTemplates.entries) {
        expect(entry.value, isA<List>(), reason: '${file.path}: ${entry.key}');
        expect(entry.value, isNotEmpty, reason: '${file.path}: ${entry.key}');
      }
    }
  });
}
