import 'package:path_provider/path_provider.dart';

Future<void> cleanStaleUpdateFiles() async {
  final cache = await getTemporaryDirectory();
  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  await for (final entity in cache.list()) {
    final name = entity.uri.pathSegments.last;
    if (!name.startsWith('hivetube-') ||
        !(name.endsWith('.apk') || name.endsWith('.apk.part'))) {
      continue;
    }
    final modified = await entity.stat();
    if (name.endsWith('.part') || modified.modified.isBefore(cutoff)) {
      await entity.delete();
    }
  }
}
