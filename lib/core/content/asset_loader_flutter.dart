import 'dart:convert';
import 'package:flutter/services.dart';

Future<Map<String, String>> loadLanguageAssets() async {
  try {
    final manifestContent = await rootBundle.loadString('AssetManifest.json').catchError((_) => '{}');
    final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;
    final langAssets = manifest.keys.where((k) => k.startsWith('assets/languages/') && k.endsWith('.json'));
    final results = <String, String>{};
    for (final asset in langAssets) {
      results[asset] = await rootBundle.loadString(asset);
    }
    return results;
  } catch (_) {
    return {};
  }
}

