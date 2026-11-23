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

/// Parses the `subscriptions.csv` file in a YouTube Google Takeout archive.
///
/// Takeout's standard header is `Channel Id,Channel Url,Channel Title`. The
/// parser also accepts headerless CSVs, UTF-8 BOMs, quoted commas, escaped
/// quotes, and quoted values containing line breaks.
List<TakeoutSubscription> parseTakeoutCsv(String csvContent) {
  final rows = _parseCsv(csvContent.replaceFirst('\uFEFF', ''));
  if (rows.isEmpty) return const [];

  var channelIdIdx = -1;
  var titleIdx = -1;
  final result = <TakeoutSubscription>[];
  final seen = <String>{};

  for (final columns in rows) {
    if (columns.every((column) => column.trim().isEmpty)) continue;

    if (channelIdIdx == -1 || titleIdx == -1) {
      for (var col = 0; col < columns.length; col++) {
        final header = columns[col].trim().toLowerCase();
        if (header == 'channel id' || header == 'channelid') {
          channelIdIdx = col;
        } else if (header == 'channel title' ||
            header == 'channeltitle' ||
            header == 'title') {
          titleIdx = col;
        }
      }
      if (channelIdIdx != -1 && titleIdx != -1) continue;
    }

    final idIdx = channelIdIdx == -1 ? 0 : channelIdIdx;
    final nameIdx = titleIdx == -1 ? (columns.length > 2 ? 2 : 1) : titleIdx;
    if (idIdx >= columns.length) continue;

    final id = columns[idIdx].trim();
    final title = nameIdx < columns.length ? columns[nameIdx].trim() : '';
    if (!RegExp(r'^UC[A-Za-z0-9_-]{20,}$').hasMatch(id) || !seen.add(id)) {
      continue;
    }
    result.add(
      TakeoutSubscription(channelId: id, title: title.isEmpty ? id : title),
    );
  }

  return result;
}

List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == '"') {
      if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      row.add(field.toString());
      field.clear();
    } else if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(char);
    }
  }

  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
