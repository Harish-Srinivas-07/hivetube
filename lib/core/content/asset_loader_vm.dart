import 'dart:io';

Future<Map<String, String>> loadLanguageAssets() async => {};

Future<String?> loadLexiconAsset(String path) async {
  final file = File(path);
  return await file.exists() ? file.readAsString() : null;
}
