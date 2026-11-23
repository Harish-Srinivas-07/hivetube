Iterable<dynamic> findAll(dynamic json, String key) sync* {
  if (json is Map) {
    for (final entry in json.entries) {
      if (entry.key == key) yield entry.value;
      yield* findAll(entry.value, key);
    }
  } else if (json is List) {
    for (final value in json) {
      yield* findAll(value, key);
    }
  }
}

dynamic safeNav(dynamic json, List<Object> path) {
  var value = json;
  for (final key in path) {
    if (value is Map && value.containsKey(key)) {
      value = value[key];
    } else if (value is List && key is int && key >= 0 && key < value.length) {
      value = value[key];
    } else {
      return null;
    }
  }
  return value;
}
