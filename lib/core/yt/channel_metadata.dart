String normalizeChannelAvatarUrl(String url) {
  var normalized = url.trim();
  if (normalized.startsWith('//')) normalized = 'https:$normalized';
  if (normalized.isEmpty) return '';
  final queryAt = normalized.indexOf(RegExp(r'[?#]'));
  final base = queryAt == -1 ? normalized : normalized.substring(0, queryAt);
  final suffix = queryAt == -1 ? '' : normalized.substring(queryAt);
  final sizeParam = RegExp(r'=(?:s|w)\d+(?:-[^/?#]*)?$');
  normalized = sizeParam.hasMatch(base)
      ? '${base.replaceFirst(sizeParam, '=s88')}$suffix'
      : '$base=s88$suffix';
  return normalized;
}

bool isMissingChannelName(String name, String channelId) {
  final value = name.trim();
  return value.isEmpty || value == channelId || value.startsWith('UC');
}

bool isMissingVideoTitle(String title, String videoId) {
  final value = title.trim();
  return value.isEmpty || value == videoId;
}
