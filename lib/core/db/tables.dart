import 'package:drift/drift.dart';

class Prefs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('ProfileRow')
class Profile extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get avatarPath => text().nullable()();
  IntColumn get createdAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SubscriptionRow')
class Subscriptions extends Table {
  TextColumn get channelId => text()();
  TextColumn get name => text()();
  TextColumn get avatarUrl => text()();
  IntColumn get subscribedAt => integer()();
  IntColumn get lastFeedAt => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {channelId};
}

@DataClassName('FeedItemRow')
class FeedItems extends Table {
  TextColumn get videoId => text()();
  TextColumn get channelId => text()();
  TextColumn get title => text()();
  IntColumn get publishedAt => integer()();
  TextColumn get thumbUrl => text()();
  IntColumn get durationSec => integer().nullable()();
  IntColumn get fetchedAt => integer()();
  @override
  Set<Column> get primaryKey => {videoId};
}

@DataClassName('MediaRow')
class Media extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get channelId => text()();
  TextColumn get channelName => text()();
  IntColumn get durationSec => integer().nullable()();
  TextColumn get thumbUrl => text()();
  BoolColumn get isMusic => boolean().withDefault(const Constant(false))();
  TextColumn get musicVideoType => text().nullable()();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {videoId};
}

@DataClassName('ReactionRow')
class Reactions extends Table {
  TextColumn get videoId => text()();
  IntColumn get value => integer()(); // 1 like, -1 dislike
  IntColumn get at => integer()();
  TextColumn get scope => text().withDefault(const Constant('yt'))();
  @override
  Set<Column> get primaryKey => {videoId, scope};
}

@DataClassName('HistoryRow')
class History extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get videoId => text()();
  IntColumn get positionMs => integer()();
  IntColumn get durationMs => integer()();
  IntColumn get at => integer()();
  TextColumn get scope => text().withDefault(const Constant('yt'))();
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get scope => text().withDefault(const Constant('yt'))();
  TextColumn get remoteId => text().nullable()();
  TextColumn get thumbUrl => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

@DataClassName('PlaylistItemRow')
class PlaylistItems extends Table {
  IntColumn get playlistId => integer()();
  TextColumn get videoId => text()();
  IntColumn get position => integer()();
  IntColumn get addedAt => integer()();
  @override
  Set<Column> get primaryKey => {playlistId, videoId};
}

@DataClassName('SavedRemoteRow')
class SavedRemote extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()(); // playlist|album|artist|channel
  TextColumn get title => text()();
  TextColumn get thumbUrl => text().nullable()();
  IntColumn get savedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SearchHistoryRow')
class SearchHistory extends Table {
  TextColumn get query => text()();
  TextColumn get scope => text().withDefault(const Constant('yt'))();
  IntColumn get at => integer()();
  @override
  Set<Column> get primaryKey => {query, scope};
}

@DataClassName('RydCacheRow')
class RydCache extends Table {
  TextColumn get videoId => text()();
  IntColumn get likes => integer()();
  IntColumn get dislikes => integer()();
  IntColumn get fetchedAt => integer()();
  @override
  Set<Column> get primaryKey => {videoId};
}

@DataClassName('DownloadRow')
class Downloads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get videoId => text()();
  TextColumn get kind => text()(); // video|audio
  IntColumn get vItag => integer().nullable()();
  IntColumn get aItag => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get container => text().nullable()();
  TextColumn get path => text().nullable()();
  IntColumn get total => integer().withDefault(const Constant(0))();
  IntColumn get done => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get error => text().nullable()();
  IntColumn get createdAt => integer()();
}

@DataClassName('AudioCacheRow')
class AudioCache extends Table {
  TextColumn get videoId => text()();
  IntColumn get itag => integer()();
  TextColumn get path => text()();
  IntColumn get bytes => integer()();
  IntColumn get lastPlayedAt => integer()();
  @override
  Set<Column> get primaryKey => {videoId};
}

@DataClassName('LyricsCacheRow')
class LyricsCache extends Table {
  TextColumn get videoId => text()();
  TextColumn get source => text()();
  TextColumn get format => text()();
  TextColumn get raw => text()();
  IntColumn get offsetMs => integer().withDefault(const Constant(0))();
  IntColumn get fetchedAt => integer()();
  @override
  Set<Column> get primaryKey => {videoId};
}

@DataClassName('SbCacheRow')
class SbCache extends Table {
  TextColumn get videoId => text()();
  TextColumn get json => text()();
  IntColumn get fetchedAt => integer()();
  @override
  Set<Column> get primaryKey => {videoId};
}
