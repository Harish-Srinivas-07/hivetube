class TakeoutSubscription {
  const TakeoutSubscription({required this.channelId, required this.title});
  final String channelId;
  final String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TakeoutSubscription &&
          runtimeType == other.runtimeType &&
          channelId == other.channelId;

  @override
  int get hashCode => channelId.hashCode;
}

List<TakeoutSubscription> parseTakeoutCsv(String csvContent) {
  final lines = csvContent.split(RegExp(r'\r?\n'));
  final results = <TakeoutSubscription>[];

  if (lines.isEmpty) return results;

  int channelIdIdx = -1;
  int titleIdx = -1;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final columns = _parseCsvLine(line);
    if (channelIdIdx == -1 || titleIdx == -1) {
      for (var col = 0; col < columns.length; col++) {
        final lower = columns[col].trim().toLowerCase();
        if (lower == 'channel id' || lower == 'channelid') {
          channelIdIdx = col;
        } else if (lower == 'channel title' || lower == 'channeltitle' || lower == 'title') {
          titleIdx = col;
        }
      }
      if (channelIdIdx != -1 && titleIdx != -1) continue;
    }

    // Process data rows
    final idIdx = channelIdIdx != -1 ? channelIdIdx : 0;
    final tIdx = titleIdx != -1 ? titleIdx : (columns.length > 2 ? 2 : 1);

    if (idIdx < columns.length) {
      final id = columns[idIdx].trim();
      final title = tIdx < columns.length ? columns[tIdx].trim() : id;
      if (id.startsWith('UC') && id.length >= 20) {
        results.add(TakeoutSubscription(channelId: id, title: title));
      }
    }
  }

  return results;
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  var inQuotes = false;
  final current = StringBuffer();

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      result.add(current.toString());
      current.clear();
    } else {
      current.write(char);
    }
  }
  result.add(current.toString());
  return result;
}

