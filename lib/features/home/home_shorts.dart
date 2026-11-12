import 'dart:math';
import '../../core/yt/models.dart';
import 'home_variety.dart';

const homeTopics = <String, String>{
  'Music': 'tamil songs',
  'Movies': 'tamil movie trailer',
  'Gaming': 'tamil gaming',
  'Live': 'tamil live stream',
  'News': 'tamil news live',
  'Podcasts': 'tamil podcast',
  'Sports': 'ipl highlights',
  'Comedy': 'tamil comedy',
  'Cooking': 'tamil samayal',
  'Science': 'tamil science',
  'Tech': 'tamil tech review',
  'Education': 'tamil education',
};

List<String> shortsQueries({
  required String chip,
  required Iterable<String> channels,
  Random? random,
  double localRatio = 0.6,
  Set<String> shownLanguages = const {'ta', 'en'},
  bool hasHistory = false,
}) {
  final rng = random ?? Random();
  return chooseHomeQueries(
    chip: chip,
    hasHistory: hasHistory,
    localRatio: localRatio,
    shownLanguages: shownLanguages,
    random: rng,
  );
}

List<ShortItem> buildShortsShelf(
  Iterable<List<ShortItem>> pages,
  Set<String> watched, {
  Random? random,
  Set<String> preferred = const {'ta', 'en'},
  Set<String> hidden = const {'hi'},
  Set<String> seen = const {},
}) {
  final rng = random ?? Random();
  final uniqueIds = <String>{};
  final all = [
    for (final page in pages)
      for (final item in page)
        if (uniqueIds.add(item.id)) item,
  ];
  final ranked = rankHomeItems(
    [
      for (final item in all)
        VideoItem(
          id: item.id,
          title: item.title ?? '',
          channelId: item.channelId ?? '',
          channelName: item.channelName ?? '',
          channelAvatarUrl: item.channelAvatarUrl ?? '',
          thumbUrl: item.thumbUrl,
          isShort: true,
        ),
    ],
    preferred: preferred,
    hidden: hidden,
    seen: seen,
    random: rng,
  ).map((item) => item.id).toList();
  final byId = {for (final item in all) item.id: item};
  final ordered = ranked.map((id) => byId[id]!).toList();
  return [
    ...ordered.where((item) => !watched.contains(item.id)),
    ...ordered.where((item) => watched.contains(item.id)),
  ].take(12).toList();
}
