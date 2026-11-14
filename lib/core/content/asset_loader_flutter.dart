import 'package:flutter/services.dart';

Future<Map<String, String>> loadLanguageAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final langAssets = manifest.listAssets().where(
    (asset) => asset.startsWith('assets/languages/') && asset.endsWith('.json'),
  );
  final results = <String, String>{};
  for (final asset in langAssets) {
    results[asset] = await rootBundle.loadString(asset);
  }
  if (results.isEmpty) {
    throw StateError('No language profile JSON files in Flutter asset bundle');
  }
  return results;
}
