// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $PrefsTable extends Prefs with TableInfo<$PrefsTable, Pref> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pref> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Pref map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pref(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $PrefsTable createAlias(String alias) {
    return $PrefsTable(attachedDatabase, alias);
  }
}

class Pref extends DataClass implements Insertable<Pref> {
  final String key;
  final String value;
  const Pref({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  PrefsCompanion toCompanion(bool nullToAbsent) {
    return PrefsCompanion(key: Value(key), value: Value(value));
  }

  factory Pref.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pref(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Pref copyWith({String? key, String? value}) =>
      Pref(key: key ?? this.key, value: value ?? this.value);
  Pref copyWithCompanion(PrefsCompanion data) {
    return Pref(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pref(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pref && other.key == this.key && other.value == this.value);
}

class PrefsCompanion extends UpdateCompanion<Pref> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const PrefsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrefsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Pref> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrefsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return PrefsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrefsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfileTable extends Profile with TableInfo<$ProfileTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarPathMeta = const VerificationMeta(
    'avatarPath',
  );
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
    'avatar_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, avatarPath, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
        _avatarPathMeta,
        avatarPath.isAcceptableOrUnknown(data['avatar_path']!, _avatarPathMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatarPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProfileTable createAlias(String alias) {
    return $ProfileTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final int id;
  final String name;
  final String? avatarPath;
  final int createdAt;
  const ProfileRow({
    required this.id,
    required this.name,
    this.avatarPath,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ProfileCompanion toCompanion(bool nullToAbsent) {
    return ProfileCompanion(
      id: Value(id),
      name: Value(name),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      createdAt: Value(createdAt),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ProfileRow copyWith({
    int? id,
    String? name,
    Value<String?> avatarPath = const Value.absent(),
    int? createdAt,
  }) => ProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
    createdAt: createdAt ?? this.createdAt,
  );
  ProfileRow copyWithCompanion(ProfileCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatarPath: data.avatarPath.present
          ? data.avatarPath.value
          : this.avatarPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, avatarPath, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatarPath == this.avatarPath &&
          other.createdAt == this.createdAt);
}

class ProfileCompanion extends UpdateCompanion<ProfileRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> avatarPath;
  final Value<int> createdAt;
  const ProfileCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ProfileCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.avatarPath = const Value.absent(),
    required int createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<ProfileRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? avatarPath,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ProfileCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? avatarPath,
    Value<int>? createdAt,
  }) {
    return ProfileCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarPath: avatarPath ?? this.avatarPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfileCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SubscriptionsTable extends Subscriptions
    with TableInfo<$SubscriptionsTable, SubscriptionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubscriptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subscribedAtMeta = const VerificationMeta(
    'subscribedAt',
  );
  @override
  late final GeneratedColumn<int> subscribedAt = GeneratedColumn<int>(
    'subscribed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastFeedAtMeta = const VerificationMeta(
    'lastFeedAt',
  );
  @override
  late final GeneratedColumn<int> lastFeedAt = GeneratedColumn<int>(
    'last_feed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    channelId,
    name,
    avatarUrl,
    subscribedAt,
    lastFeedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subscriptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubscriptionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_avatarUrlMeta);
    }
    if (data.containsKey('subscribed_at')) {
      context.handle(
        _subscribedAtMeta,
        subscribedAt.isAcceptableOrUnknown(
          data['subscribed_at']!,
          _subscribedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subscribedAtMeta);
    }
    if (data.containsKey('last_feed_at')) {
      context.handle(
        _lastFeedAtMeta,
        lastFeedAt.isAcceptableOrUnknown(
          data['last_feed_at']!,
          _lastFeedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {channelId};
  @override
  SubscriptionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubscriptionRow(
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      )!,
      subscribedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subscribed_at'],
      )!,
      lastFeedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_feed_at'],
      )!,
    );
  }

  @override
  $SubscriptionsTable createAlias(String alias) {
    return $SubscriptionsTable(attachedDatabase, alias);
  }
}

class SubscriptionRow extends DataClass implements Insertable<SubscriptionRow> {
  final String channelId;
  final String name;
  final String avatarUrl;
  final int subscribedAt;
  final int lastFeedAt;
  const SubscriptionRow({
    required this.channelId,
    required this.name,
    required this.avatarUrl,
    required this.subscribedAt,
    required this.lastFeedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['channel_id'] = Variable<String>(channelId);
    map['name'] = Variable<String>(name);
    map['avatar_url'] = Variable<String>(avatarUrl);
    map['subscribed_at'] = Variable<int>(subscribedAt);
    map['last_feed_at'] = Variable<int>(lastFeedAt);
    return map;
  }

  SubscriptionsCompanion toCompanion(bool nullToAbsent) {
    return SubscriptionsCompanion(
      channelId: Value(channelId),
      name: Value(name),
      avatarUrl: Value(avatarUrl),
      subscribedAt: Value(subscribedAt),
      lastFeedAt: Value(lastFeedAt),
    );
  }

  factory SubscriptionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubscriptionRow(
      channelId: serializer.fromJson<String>(json['channelId']),
      name: serializer.fromJson<String>(json['name']),
      avatarUrl: serializer.fromJson<String>(json['avatarUrl']),
      subscribedAt: serializer.fromJson<int>(json['subscribedAt']),
      lastFeedAt: serializer.fromJson<int>(json['lastFeedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'channelId': serializer.toJson<String>(channelId),
      'name': serializer.toJson<String>(name),
      'avatarUrl': serializer.toJson<String>(avatarUrl),
      'subscribedAt': serializer.toJson<int>(subscribedAt),
      'lastFeedAt': serializer.toJson<int>(lastFeedAt),
    };
  }

  SubscriptionRow copyWith({
    String? channelId,
    String? name,
    String? avatarUrl,
    int? subscribedAt,
    int? lastFeedAt,
  }) => SubscriptionRow(
    channelId: channelId ?? this.channelId,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    subscribedAt: subscribedAt ?? this.subscribedAt,
    lastFeedAt: lastFeedAt ?? this.lastFeedAt,
  );
  SubscriptionRow copyWithCompanion(SubscriptionsCompanion data) {
    return SubscriptionRow(
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      name: data.name.present ? data.name.value : this.name,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      subscribedAt: data.subscribedAt.present
          ? data.subscribedAt.value
          : this.subscribedAt,
      lastFeedAt: data.lastFeedAt.present
          ? data.lastFeedAt.value
          : this.lastFeedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionRow(')
          ..write('channelId: $channelId, ')
          ..write('name: $name, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('subscribedAt: $subscribedAt, ')
          ..write('lastFeedAt: $lastFeedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(channelId, name, avatarUrl, subscribedAt, lastFeedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubscriptionRow &&
          other.channelId == this.channelId &&
          other.name == this.name &&
          other.avatarUrl == this.avatarUrl &&
          other.subscribedAt == this.subscribedAt &&
          other.lastFeedAt == this.lastFeedAt);
}

class SubscriptionsCompanion extends UpdateCompanion<SubscriptionRow> {
  final Value<String> channelId;
  final Value<String> name;
  final Value<String> avatarUrl;
  final Value<int> subscribedAt;
  final Value<int> lastFeedAt;
  final Value<int> rowid;
  const SubscriptionsCompanion({
    this.channelId = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.subscribedAt = const Value.absent(),
    this.lastFeedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubscriptionsCompanion.insert({
    required String channelId,
    required String name,
    required String avatarUrl,
    required int subscribedAt,
    this.lastFeedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : channelId = Value(channelId),
       name = Value(name),
       avatarUrl = Value(avatarUrl),
       subscribedAt = Value(subscribedAt);
  static Insertable<SubscriptionRow> custom({
    Expression<String>? channelId,
    Expression<String>? name,
    Expression<String>? avatarUrl,
    Expression<int>? subscribedAt,
    Expression<int>? lastFeedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (channelId != null) 'channel_id': channelId,
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (subscribedAt != null) 'subscribed_at': subscribedAt,
      if (lastFeedAt != null) 'last_feed_at': lastFeedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubscriptionsCompanion copyWith({
    Value<String>? channelId,
    Value<String>? name,
    Value<String>? avatarUrl,
    Value<int>? subscribedAt,
    Value<int>? lastFeedAt,
    Value<int>? rowid,
  }) {
    return SubscriptionsCompanion(
      channelId: channelId ?? this.channelId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subscribedAt: subscribedAt ?? this.subscribedAt,
      lastFeedAt: lastFeedAt ?? this.lastFeedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (subscribedAt.present) {
      map['subscribed_at'] = Variable<int>(subscribedAt.value);
    }
    if (lastFeedAt.present) {
      map['last_feed_at'] = Variable<int>(lastFeedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubscriptionsCompanion(')
          ..write('channelId: $channelId, ')
          ..write('name: $name, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('subscribedAt: $subscribedAt, ')
          ..write('lastFeedAt: $lastFeedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FeedItemsTable extends FeedItems
    with TableInfo<$FeedItemsTable, FeedItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<int> publishedAt = GeneratedColumn<int>(
    'published_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbUrlMeta = const VerificationMeta(
    'thumbUrl',
  );
  @override
  late final GeneratedColumn<String> thumbUrl = GeneratedColumn<String>(
    'thumb_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    videoId,
    channelId,
    title,
    publishedAt,
    thumbUrl,
    durationSec,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feed_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeedItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_publishedAtMeta);
    }
    if (data.containsKey('thumb_url')) {
      context.handle(
        _thumbUrlMeta,
        thumbUrl.isAcceptableOrUnknown(data['thumb_url']!, _thumbUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_thumbUrlMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  FeedItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedItemRow(
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}published_at'],
      )!,
      thumbUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_url'],
      )!,
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $FeedItemsTable createAlias(String alias) {
    return $FeedItemsTable(attachedDatabase, alias);
  }
}

class FeedItemRow extends DataClass implements Insertable<FeedItemRow> {
  final String videoId;
  final String channelId;
  final String title;
  final int publishedAt;
  final String thumbUrl;
  final int? durationSec;
  final int fetchedAt;
  const FeedItemRow({
    required this.videoId,
    required this.channelId,
    required this.title,
    required this.publishedAt,
    required this.thumbUrl,
    this.durationSec,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['channel_id'] = Variable<String>(channelId);
    map['title'] = Variable<String>(title);
    map['published_at'] = Variable<int>(publishedAt);
    map['thumb_url'] = Variable<String>(thumbUrl);
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<int>(durationSec);
    }
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  FeedItemsCompanion toCompanion(bool nullToAbsent) {
    return FeedItemsCompanion(
      videoId: Value(videoId),
      channelId: Value(channelId),
      title: Value(title),
      publishedAt: Value(publishedAt),
      thumbUrl: Value(thumbUrl),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory FeedItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeedItemRow(
      videoId: serializer.fromJson<String>(json['videoId']),
      channelId: serializer.fromJson<String>(json['channelId']),
      title: serializer.fromJson<String>(json['title']),
      publishedAt: serializer.fromJson<int>(json['publishedAt']),
      thumbUrl: serializer.fromJson<String>(json['thumbUrl']),
      durationSec: serializer.fromJson<int?>(json['durationSec']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'channelId': serializer.toJson<String>(channelId),
      'title': serializer.toJson<String>(title),
      'publishedAt': serializer.toJson<int>(publishedAt),
      'thumbUrl': serializer.toJson<String>(thumbUrl),
      'durationSec': serializer.toJson<int?>(durationSec),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  FeedItemRow copyWith({
    String? videoId,
    String? channelId,
    String? title,
    int? publishedAt,
    String? thumbUrl,
    Value<int?> durationSec = const Value.absent(),
    int? fetchedAt,
  }) => FeedItemRow(
    videoId: videoId ?? this.videoId,
    channelId: channelId ?? this.channelId,
    title: title ?? this.title,
    publishedAt: publishedAt ?? this.publishedAt,
    thumbUrl: thumbUrl ?? this.thumbUrl,
    durationSec: durationSec.present ? durationSec.value : this.durationSec,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  FeedItemRow copyWithCompanion(FeedItemsCompanion data) {
    return FeedItemRow(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      title: data.title.present ? data.title.value : this.title,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      thumbUrl: data.thumbUrl.present ? data.thumbUrl.value : this.thumbUrl,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeedItemRow(')
          ..write('videoId: $videoId, ')
          ..write('channelId: $channelId, ')
          ..write('title: $title, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('durationSec: $durationSec, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    videoId,
    channelId,
    title,
    publishedAt,
    thumbUrl,
    durationSec,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedItemRow &&
          other.videoId == this.videoId &&
          other.channelId == this.channelId &&
          other.title == this.title &&
          other.publishedAt == this.publishedAt &&
          other.thumbUrl == this.thumbUrl &&
          other.durationSec == this.durationSec &&
          other.fetchedAt == this.fetchedAt);
}

class FeedItemsCompanion extends UpdateCompanion<FeedItemRow> {
  final Value<String> videoId;
  final Value<String> channelId;
  final Value<String> title;
  final Value<int> publishedAt;
  final Value<String> thumbUrl;
  final Value<int?> durationSec;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const FeedItemsCompanion({
    this.videoId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.title = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeedItemsCompanion.insert({
    required String videoId,
    required String channelId,
    required String title,
    required int publishedAt,
    required String thumbUrl,
    this.durationSec = const Value.absent(),
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : videoId = Value(videoId),
       channelId = Value(channelId),
       title = Value(title),
       publishedAt = Value(publishedAt),
       thumbUrl = Value(thumbUrl),
       fetchedAt = Value(fetchedAt);
  static Insertable<FeedItemRow> custom({
    Expression<String>? videoId,
    Expression<String>? channelId,
    Expression<String>? title,
    Expression<int>? publishedAt,
    Expression<String>? thumbUrl,
    Expression<int>? durationSec,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (channelId != null) 'channel_id': channelId,
      if (title != null) 'title': title,
      if (publishedAt != null) 'published_at': publishedAt,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (durationSec != null) 'duration_sec': durationSec,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeedItemsCompanion copyWith({
    Value<String>? videoId,
    Value<String>? channelId,
    Value<String>? title,
    Value<int>? publishedAt,
    Value<String>? thumbUrl,
    Value<int?>? durationSec,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return FeedItemsCompanion(
      videoId: videoId ?? this.videoId,
      channelId: channelId ?? this.channelId,
      title: title ?? this.title,
      publishedAt: publishedAt ?? this.publishedAt,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      durationSec: durationSec ?? this.durationSec,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<int>(publishedAt.value);
    }
    if (thumbUrl.present) {
      map['thumb_url'] = Variable<String>(thumbUrl.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedItemsCompanion(')
          ..write('videoId: $videoId, ')
          ..write('channelId: $channelId, ')
          ..write('title: $title, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('durationSec: $durationSec, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MediaTable extends Media with TableInfo<$MediaTable, MediaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelNameMeta = const VerificationMeta(
    'channelName',
  );
  @override
  late final GeneratedColumn<String> channelName = GeneratedColumn<String>(
    'channel_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbUrlMeta = const VerificationMeta(
    'thumbUrl',
  );
  @override
  late final GeneratedColumn<String> thumbUrl = GeneratedColumn<String>(
    'thumb_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isMusicMeta = const VerificationMeta(
    'isMusic',
  );
  @override
  late final GeneratedColumn<bool> isMusic = GeneratedColumn<bool>(
    'is_music',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_music" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _musicVideoTypeMeta = const VerificationMeta(
    'musicVideoType',
  );
  @override
  late final GeneratedColumn<String> musicVideoType = GeneratedColumn<String>(
    'music_video_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    videoId,
    title,
    channelId,
    channelName,
    durationSec,
    thumbUrl,
    isMusic,
    musicVideoType,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_channelIdMeta);
    }
    if (data.containsKey('channel_name')) {
      context.handle(
        _channelNameMeta,
        channelName.isAcceptableOrUnknown(
          data['channel_name']!,
          _channelNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_channelNameMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('thumb_url')) {
      context.handle(
        _thumbUrlMeta,
        thumbUrl.isAcceptableOrUnknown(data['thumb_url']!, _thumbUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_thumbUrlMeta);
    }
    if (data.containsKey('is_music')) {
      context.handle(
        _isMusicMeta,
        isMusic.isAcceptableOrUnknown(data['is_music']!, _isMusicMeta),
      );
    }
    if (data.containsKey('music_video_type')) {
      context.handle(
        _musicVideoTypeMeta,
        musicVideoType.isAcceptableOrUnknown(
          data['music_video_type']!,
          _musicVideoTypeMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  MediaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaRow(
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      )!,
      channelName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_name'],
      )!,
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      ),
      thumbUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_url'],
      )!,
      isMusic: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_music'],
      )!,
      musicVideoType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}music_video_type'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MediaTable createAlias(String alias) {
    return $MediaTable(attachedDatabase, alias);
  }
}

class MediaRow extends DataClass implements Insertable<MediaRow> {
  final String videoId;
  final String title;
  final String channelId;
  final String channelName;
  final int? durationSec;
  final String thumbUrl;
  final bool isMusic;
  final String? musicVideoType;
  final int updatedAt;
  const MediaRow({
    required this.videoId,
    required this.title,
    required this.channelId,
    required this.channelName,
    this.durationSec,
    required this.thumbUrl,
    required this.isMusic,
    this.musicVideoType,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['title'] = Variable<String>(title);
    map['channel_id'] = Variable<String>(channelId);
    map['channel_name'] = Variable<String>(channelName);
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<int>(durationSec);
    }
    map['thumb_url'] = Variable<String>(thumbUrl);
    map['is_music'] = Variable<bool>(isMusic);
    if (!nullToAbsent || musicVideoType != null) {
      map['music_video_type'] = Variable<String>(musicVideoType);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MediaCompanion toCompanion(bool nullToAbsent) {
    return MediaCompanion(
      videoId: Value(videoId),
      title: Value(title),
      channelId: Value(channelId),
      channelName: Value(channelName),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
      thumbUrl: Value(thumbUrl),
      isMusic: Value(isMusic),
      musicVideoType: musicVideoType == null && nullToAbsent
          ? const Value.absent()
          : Value(musicVideoType),
      updatedAt: Value(updatedAt),
    );
  }

  factory MediaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaRow(
      videoId: serializer.fromJson<String>(json['videoId']),
      title: serializer.fromJson<String>(json['title']),
      channelId: serializer.fromJson<String>(json['channelId']),
      channelName: serializer.fromJson<String>(json['channelName']),
      durationSec: serializer.fromJson<int?>(json['durationSec']),
      thumbUrl: serializer.fromJson<String>(json['thumbUrl']),
      isMusic: serializer.fromJson<bool>(json['isMusic']),
      musicVideoType: serializer.fromJson<String?>(json['musicVideoType']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'title': serializer.toJson<String>(title),
      'channelId': serializer.toJson<String>(channelId),
      'channelName': serializer.toJson<String>(channelName),
      'durationSec': serializer.toJson<int?>(durationSec),
      'thumbUrl': serializer.toJson<String>(thumbUrl),
      'isMusic': serializer.toJson<bool>(isMusic),
      'musicVideoType': serializer.toJson<String?>(musicVideoType),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MediaRow copyWith({
    String? videoId,
    String? title,
    String? channelId,
    String? channelName,
    Value<int?> durationSec = const Value.absent(),
    String? thumbUrl,
    bool? isMusic,
    Value<String?> musicVideoType = const Value.absent(),
    int? updatedAt,
  }) => MediaRow(
    videoId: videoId ?? this.videoId,
    title: title ?? this.title,
    channelId: channelId ?? this.channelId,
    channelName: channelName ?? this.channelName,
    durationSec: durationSec.present ? durationSec.value : this.durationSec,
    thumbUrl: thumbUrl ?? this.thumbUrl,
    isMusic: isMusic ?? this.isMusic,
    musicVideoType: musicVideoType.present
        ? musicVideoType.value
        : this.musicVideoType,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MediaRow copyWithCompanion(MediaCompanion data) {
    return MediaRow(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      title: data.title.present ? data.title.value : this.title,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      channelName: data.channelName.present
          ? data.channelName.value
          : this.channelName,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      thumbUrl: data.thumbUrl.present ? data.thumbUrl.value : this.thumbUrl,
      isMusic: data.isMusic.present ? data.isMusic.value : this.isMusic,
      musicVideoType: data.musicVideoType.present
          ? data.musicVideoType.value
          : this.musicVideoType,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaRow(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('channelId: $channelId, ')
          ..write('channelName: $channelName, ')
          ..write('durationSec: $durationSec, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('isMusic: $isMusic, ')
          ..write('musicVideoType: $musicVideoType, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    videoId,
    title,
    channelId,
    channelName,
    durationSec,
    thumbUrl,
    isMusic,
    musicVideoType,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaRow &&
          other.videoId == this.videoId &&
          other.title == this.title &&
          other.channelId == this.channelId &&
          other.channelName == this.channelName &&
          other.durationSec == this.durationSec &&
          other.thumbUrl == this.thumbUrl &&
          other.isMusic == this.isMusic &&
          other.musicVideoType == this.musicVideoType &&
          other.updatedAt == this.updatedAt);
}

class MediaCompanion extends UpdateCompanion<MediaRow> {
  final Value<String> videoId;
  final Value<String> title;
  final Value<String> channelId;
  final Value<String> channelName;
  final Value<int?> durationSec;
  final Value<String> thumbUrl;
  final Value<bool> isMusic;
  final Value<String?> musicVideoType;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MediaCompanion({
    this.videoId = const Value.absent(),
    this.title = const Value.absent(),
    this.channelId = const Value.absent(),
    this.channelName = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.isMusic = const Value.absent(),
    this.musicVideoType = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaCompanion.insert({
    required String videoId,
    required String title,
    required String channelId,
    required String channelName,
    this.durationSec = const Value.absent(),
    required String thumbUrl,
    this.isMusic = const Value.absent(),
    this.musicVideoType = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : videoId = Value(videoId),
       title = Value(title),
       channelId = Value(channelId),
       channelName = Value(channelName),
       thumbUrl = Value(thumbUrl),
       updatedAt = Value(updatedAt);
  static Insertable<MediaRow> custom({
    Expression<String>? videoId,
    Expression<String>? title,
    Expression<String>? channelId,
    Expression<String>? channelName,
    Expression<int>? durationSec,
    Expression<String>? thumbUrl,
    Expression<bool>? isMusic,
    Expression<String>? musicVideoType,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (title != null) 'title': title,
      if (channelId != null) 'channel_id': channelId,
      if (channelName != null) 'channel_name': channelName,
      if (durationSec != null) 'duration_sec': durationSec,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (isMusic != null) 'is_music': isMusic,
      if (musicVideoType != null) 'music_video_type': musicVideoType,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaCompanion copyWith({
    Value<String>? videoId,
    Value<String>? title,
    Value<String>? channelId,
    Value<String>? channelName,
    Value<int?>? durationSec,
    Value<String>? thumbUrl,
    Value<bool>? isMusic,
    Value<String?>? musicVideoType,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MediaCompanion(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      durationSec: durationSec ?? this.durationSec,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      isMusic: isMusic ?? this.isMusic,
      musicVideoType: musicVideoType ?? this.musicVideoType,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (channelName.present) {
      map['channel_name'] = Variable<String>(channelName.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (thumbUrl.present) {
      map['thumb_url'] = Variable<String>(thumbUrl.value);
    }
    if (isMusic.present) {
      map['is_music'] = Variable<bool>(isMusic.value);
    }
    if (musicVideoType.present) {
      map['music_video_type'] = Variable<String>(musicVideoType.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaCompanion(')
          ..write('videoId: $videoId, ')
          ..write('title: $title, ')
          ..write('channelId: $channelId, ')
          ..write('channelName: $channelName, ')
          ..write('durationSec: $durationSec, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('isMusic: $isMusic, ')
          ..write('musicVideoType: $musicVideoType, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReactionsTable extends Reactions
    with TableInfo<$ReactionsTable, ReactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('yt'),
  );
  @override
  List<GeneratedColumn> get $columns => [videoId, value, at, scope];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId, scope};
  @override
  ReactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReactionRow(
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
    );
  }

  @override
  $ReactionsTable createAlias(String alias) {
    return $ReactionsTable(attachedDatabase, alias);
  }
}

class ReactionRow extends DataClass implements Insertable<ReactionRow> {
  final String videoId;
  final int value;
  final int at;
  final String scope;
  const ReactionRow({
    required this.videoId,
    required this.value,
    required this.at,
    required this.scope,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['value'] = Variable<int>(value);
    map['at'] = Variable<int>(at);
    map['scope'] = Variable<String>(scope);
    return map;
  }

  ReactionsCompanion toCompanion(bool nullToAbsent) {
    return ReactionsCompanion(
      videoId: Value(videoId),
      value: Value(value),
      at: Value(at),
      scope: Value(scope),
    );
  }

  factory ReactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReactionRow(
      videoId: serializer.fromJson<String>(json['videoId']),
      value: serializer.fromJson<int>(json['value']),
      at: serializer.fromJson<int>(json['at']),
      scope: serializer.fromJson<String>(json['scope']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'value': serializer.toJson<int>(value),
      'at': serializer.toJson<int>(at),
      'scope': serializer.toJson<String>(scope),
    };
  }

  ReactionRow copyWith({String? videoId, int? value, int? at, String? scope}) =>
      ReactionRow(
        videoId: videoId ?? this.videoId,
        value: value ?? this.value,
        at: at ?? this.at,
        scope: scope ?? this.scope,
      );
  ReactionRow copyWithCompanion(ReactionsCompanion data) {
    return ReactionRow(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      value: data.value.present ? data.value.value : this.value,
      at: data.at.present ? data.at.value : this.at,
      scope: data.scope.present ? data.scope.value : this.scope,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReactionRow(')
          ..write('videoId: $videoId, ')
          ..write('value: $value, ')
          ..write('at: $at, ')
          ..write('scope: $scope')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(videoId, value, at, scope);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReactionRow &&
          other.videoId == this.videoId &&
          other.value == this.value &&
          other.at == this.at &&
          other.scope == this.scope);
}

class ReactionsCompanion extends UpdateCompanion<ReactionRow> {
  final Value<String> videoId;
  final Value<int> value;
  final Value<int> at;
  final Value<String> scope;
  final Value<int> rowid;
  const ReactionsCompanion({
    this.videoId = const Value.absent(),
    this.value = const Value.absent(),
    this.at = const Value.absent(),
    this.scope = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReactionsCompanion.insert({
    required String videoId,
    required int value,
    required int at,
    this.scope = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : videoId = Value(videoId),
       value = Value(value),
       at = Value(at);
  static Insertable<ReactionRow> custom({
    Expression<String>? videoId,
    Expression<int>? value,
    Expression<int>? at,
    Expression<String>? scope,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (value != null) 'value': value,
      if (at != null) 'at': at,
      if (scope != null) 'scope': scope,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReactionsCompanion copyWith({
    Value<String>? videoId,
    Value<int>? value,
    Value<int>? at,
    Value<String>? scope,
    Value<int>? rowid,
  }) {
    return ReactionsCompanion(
      videoId: videoId ?? this.videoId,
      value: value ?? this.value,
      at: at ?? this.at,
      scope: scope ?? this.scope,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReactionsCompanion(')
          ..write('videoId: $videoId, ')
          ..write('value: $value, ')
          ..write('at: $at, ')
          ..write('scope: $scope, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HistoryTable extends History with TableInfo<$HistoryTable, HistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('yt'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    videoId,
    positionMs,
    durationMs,
    at,
    scope,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
    );
  }

  @override
  $HistoryTable createAlias(String alias) {
    return $HistoryTable(attachedDatabase, alias);
  }
}

class HistoryRow extends DataClass implements Insertable<HistoryRow> {
  final int id;
  final String videoId;
  final int positionMs;
  final int durationMs;
  final int at;
  final String scope;
  const HistoryRow({
    required this.id,
    required this.videoId,
    required this.positionMs,
    required this.durationMs,
    required this.at,
    required this.scope,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['video_id'] = Variable<String>(videoId);
    map['position_ms'] = Variable<int>(positionMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['at'] = Variable<int>(at);
    map['scope'] = Variable<String>(scope);
    return map;
  }

  HistoryCompanion toCompanion(bool nullToAbsent) {
    return HistoryCompanion(
      id: Value(id),
      videoId: Value(videoId),
      positionMs: Value(positionMs),
      durationMs: Value(durationMs),
      at: Value(at),
      scope: Value(scope),
    );
  }

  factory HistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryRow(
      id: serializer.fromJson<int>(json['id']),
      videoId: serializer.fromJson<String>(json['videoId']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      at: serializer.fromJson<int>(json['at']),
      scope: serializer.fromJson<String>(json['scope']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'videoId': serializer.toJson<String>(videoId),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'at': serializer.toJson<int>(at),
      'scope': serializer.toJson<String>(scope),
    };
  }

  HistoryRow copyWith({
    int? id,
    String? videoId,
    int? positionMs,
    int? durationMs,
    int? at,
    String? scope,
  }) => HistoryRow(
    id: id ?? this.id,
    videoId: videoId ?? this.videoId,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    at: at ?? this.at,
    scope: scope ?? this.scope,
  );
  HistoryRow copyWithCompanion(HistoryCompanion data) {
    return HistoryRow(
      id: data.id.present ? data.id.value : this.id,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      at: data.at.present ? data.at.value : this.at,
      scope: data.scope.present ? data.scope.value : this.scope,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRow(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('at: $at, ')
          ..write('scope: $scope')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, videoId, positionMs, durationMs, at, scope);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryRow &&
          other.id == this.id &&
          other.videoId == this.videoId &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.at == this.at &&
          other.scope == this.scope);
}

class HistoryCompanion extends UpdateCompanion<HistoryRow> {
  final Value<int> id;
  final Value<String> videoId;
  final Value<int> positionMs;
  final Value<int> durationMs;
  final Value<int> at;
  final Value<String> scope;
  const HistoryCompanion({
    this.id = const Value.absent(),
    this.videoId = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.at = const Value.absent(),
    this.scope = const Value.absent(),
  });
  HistoryCompanion.insert({
    this.id = const Value.absent(),
    required String videoId,
    required int positionMs,
    required int durationMs,
    required int at,
    this.scope = const Value.absent(),
  }) : videoId = Value(videoId),
       positionMs = Value(positionMs),
       durationMs = Value(durationMs),
       at = Value(at);
  static Insertable<HistoryRow> custom({
    Expression<int>? id,
    Expression<String>? videoId,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<int>? at,
    Expression<String>? scope,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (videoId != null) 'video_id': videoId,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (at != null) 'at': at,
      if (scope != null) 'scope': scope,
    });
  }

  HistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? videoId,
    Value<int>? positionMs,
    Value<int>? durationMs,
    Value<int>? at,
    Value<String>? scope,
  }) {
    return HistoryCompanion(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      at: at ?? this.at,
      scope: scope ?? this.scope,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryCompanion(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('at: $at, ')
          ..write('scope: $scope')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, PlaylistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('yt'),
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbUrlMeta = const VerificationMeta(
    'thumbUrl',
  );
  @override
  late final GeneratedColumn<String> thumbUrl = GeneratedColumn<String>(
    'thumb_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    scope,
    remoteId,
    thumbUrl,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('thumb_url')) {
      context.handle(
        _thumbUrlMeta,
        thumbUrl.isAcceptableOrUnknown(data['thumb_url']!, _thumbUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      thumbUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class PlaylistRow extends DataClass implements Insertable<PlaylistRow> {
  final int id;
  final String name;
  final String scope;
  final String? remoteId;
  final String? thumbUrl;
  final int createdAt;
  final int updatedAt;
  const PlaylistRow({
    required this.id,
    required this.name,
    required this.scope,
    this.remoteId,
    this.thumbUrl,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['scope'] = Variable<String>(scope);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    if (!nullToAbsent || thumbUrl != null) {
      map['thumb_url'] = Variable<String>(thumbUrl);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      scope: Value(scope),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      thumbUrl: thumbUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbUrl),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaylistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      scope: serializer.fromJson<String>(json['scope']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      thumbUrl: serializer.fromJson<String?>(json['thumbUrl']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'scope': serializer.toJson<String>(scope),
      'remoteId': serializer.toJson<String?>(remoteId),
      'thumbUrl': serializer.toJson<String?>(thumbUrl),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PlaylistRow copyWith({
    int? id,
    String? name,
    String? scope,
    Value<String?> remoteId = const Value.absent(),
    Value<String?> thumbUrl = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => PlaylistRow(
    id: id ?? this.id,
    name: name ?? this.name,
    scope: scope ?? this.scope,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    thumbUrl: thumbUrl.present ? thumbUrl.value : this.thumbUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaylistRow copyWithCompanion(PlaylistsCompanion data) {
    return PlaylistRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      scope: data.scope.present ? data.scope.value : this.scope,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      thumbUrl: data.thumbUrl.present ? data.thumbUrl.value : this.thumbUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('scope: $scope, ')
          ..write('remoteId: $remoteId, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, scope, remoteId, thumbUrl, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.scope == this.scope &&
          other.remoteId == this.remoteId &&
          other.thumbUrl == this.thumbUrl &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlaylistsCompanion extends UpdateCompanion<PlaylistRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> scope;
  final Value<String?> remoteId;
  final Value<String?> thumbUrl;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.scope = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.scope = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PlaylistRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? scope,
    Expression<String>? remoteId,
    Expression<String>? thumbUrl,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (scope != null) 'scope': scope,
      if (remoteId != null) 'remote_id': remoteId,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? scope,
    Value<String?>? remoteId,
    Value<String?>? thumbUrl,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      scope: scope ?? this.scope,
      remoteId: remoteId ?? this.remoteId,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (thumbUrl.present) {
      map['thumb_url'] = Variable<String>(thumbUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('scope: $scope, ')
          ..write('remoteId: $remoteId, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistItemsTable extends PlaylistItems
    with TableInfo<$PlaylistItemsTable, PlaylistItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playlistId,
    videoId,
    position,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, videoId};
  @override
  PlaylistItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistItemRow(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $PlaylistItemsTable createAlias(String alias) {
    return $PlaylistItemsTable(attachedDatabase, alias);
  }
}

class PlaylistItemRow extends DataClass implements Insertable<PlaylistItemRow> {
  final int playlistId;
  final String videoId;
  final int position;
  final int addedAt;
  const PlaylistItemRow({
    required this.playlistId,
    required this.videoId,
    required this.position,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['video_id'] = Variable<String>(videoId);
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  PlaylistItemsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistItemsCompanion(
      playlistId: Value(playlistId),
      videoId: Value(videoId),
      position: Value(position),
      addedAt: Value(addedAt),
    );
  }

  factory PlaylistItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistItemRow(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      videoId: serializer.fromJson<String>(json['videoId']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'videoId': serializer.toJson<String>(videoId),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  PlaylistItemRow copyWith({
    int? playlistId,
    String? videoId,
    int? position,
    int? addedAt,
  }) => PlaylistItemRow(
    playlistId: playlistId ?? this.playlistId,
    videoId: videoId ?? this.videoId,
    position: position ?? this.position,
    addedAt: addedAt ?? this.addedAt,
  );
  PlaylistItemRow copyWithCompanion(PlaylistItemsCompanion data) {
    return PlaylistItemRow(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistItemRow(')
          ..write('playlistId: $playlistId, ')
          ..write('videoId: $videoId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, videoId, position, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistItemRow &&
          other.playlistId == this.playlistId &&
          other.videoId == this.videoId &&
          other.position == this.position &&
          other.addedAt == this.addedAt);
}

class PlaylistItemsCompanion extends UpdateCompanion<PlaylistItemRow> {
  final Value<int> playlistId;
  final Value<String> videoId;
  final Value<int> position;
  final Value<int> addedAt;
  final Value<int> rowid;
  const PlaylistItemsCompanion({
    this.playlistId = const Value.absent(),
    this.videoId = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistItemsCompanion.insert({
    required int playlistId,
    required String videoId,
    required int position,
    required int addedAt,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       videoId = Value(videoId),
       position = Value(position),
       addedAt = Value(addedAt);
  static Insertable<PlaylistItemRow> custom({
    Expression<int>? playlistId,
    Expression<String>? videoId,
    Expression<int>? position,
    Expression<int>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (videoId != null) 'video_id': videoId,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistItemsCompanion copyWith({
    Value<int>? playlistId,
    Value<String>? videoId,
    Value<int>? position,
    Value<int>? addedAt,
    Value<int>? rowid,
  }) {
    return PlaylistItemsCompanion(
      playlistId: playlistId ?? this.playlistId,
      videoId: videoId ?? this.videoId,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistItemsCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('videoId: $videoId, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedRemoteTable extends SavedRemote
    with TableInfo<$SavedRemoteTable, SavedRemoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedRemoteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbUrlMeta = const VerificationMeta(
    'thumbUrl',
  );
  @override
  late final GeneratedColumn<String> thumbUrl = GeneratedColumn<String>(
    'thumb_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<int> savedAt = GeneratedColumn<int>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, title, thumbUrl, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_remote';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedRemoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('thumb_url')) {
      context.handle(
        _thumbUrlMeta,
        thumbUrl.isAcceptableOrUnknown(data['thumb_url']!, _thumbUrlMeta),
      );
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedRemoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedRemoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      thumbUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_url'],
      ),
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $SavedRemoteTable createAlias(String alias) {
    return $SavedRemoteTable(attachedDatabase, alias);
  }
}

class SavedRemoteRow extends DataClass implements Insertable<SavedRemoteRow> {
  final String id;
  final String kind;
  final String title;
  final String? thumbUrl;
  final int savedAt;
  const SavedRemoteRow({
    required this.id,
    required this.kind,
    required this.title,
    this.thumbUrl,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || thumbUrl != null) {
      map['thumb_url'] = Variable<String>(thumbUrl);
    }
    map['saved_at'] = Variable<int>(savedAt);
    return map;
  }

  SavedRemoteCompanion toCompanion(bool nullToAbsent) {
    return SavedRemoteCompanion(
      id: Value(id),
      kind: Value(kind),
      title: Value(title),
      thumbUrl: thumbUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbUrl),
      savedAt: Value(savedAt),
    );
  }

  factory SavedRemoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedRemoteRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      thumbUrl: serializer.fromJson<String?>(json['thumbUrl']),
      savedAt: serializer.fromJson<int>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'thumbUrl': serializer.toJson<String?>(thumbUrl),
      'savedAt': serializer.toJson<int>(savedAt),
    };
  }

  SavedRemoteRow copyWith({
    String? id,
    String? kind,
    String? title,
    Value<String?> thumbUrl = const Value.absent(),
    int? savedAt,
  }) => SavedRemoteRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    thumbUrl: thumbUrl.present ? thumbUrl.value : this.thumbUrl,
    savedAt: savedAt ?? this.savedAt,
  );
  SavedRemoteRow copyWithCompanion(SavedRemoteCompanion data) {
    return SavedRemoteRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      thumbUrl: data.thumbUrl.present ? data.thumbUrl.value : this.thumbUrl,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedRemoteRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, title, thumbUrl, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedRemoteRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.thumbUrl == this.thumbUrl &&
          other.savedAt == this.savedAt);
}

class SavedRemoteCompanion extends UpdateCompanion<SavedRemoteRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> title;
  final Value<String?> thumbUrl;
  final Value<int> savedAt;
  final Value<int> rowid;
  const SavedRemoteCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedRemoteCompanion.insert({
    required String id,
    required String kind,
    required String title,
    this.thumbUrl = const Value.absent(),
    required int savedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       title = Value(title),
       savedAt = Value(savedAt);
  static Insertable<SavedRemoteRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? thumbUrl,
    Expression<int>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedRemoteCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? title,
    Value<String?>? thumbUrl,
    Value<int>? savedAt,
    Value<int>? rowid,
  }) {
    return SavedRemoteCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (thumbUrl.present) {
      map['thumb_url'] = Variable<String>(thumbUrl.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<int>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedRemoteCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchHistoryTable extends SearchHistory
    with TableInfo<$SearchHistoryTable, SearchHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('yt'),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [query, scope, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {query, scope};
  @override
  SearchHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchHistoryRow(
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $SearchHistoryTable createAlias(String alias) {
    return $SearchHistoryTable(attachedDatabase, alias);
  }
}

class SearchHistoryRow extends DataClass
    implements Insertable<SearchHistoryRow> {
  final String query;
  final String scope;
  final int at;
  const SearchHistoryRow({
    required this.query,
    required this.scope,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['query'] = Variable<String>(query);
    map['scope'] = Variable<String>(scope);
    map['at'] = Variable<int>(at);
    return map;
  }

  SearchHistoryCompanion toCompanion(bool nullToAbsent) {
    return SearchHistoryCompanion(
      query: Value(query),
      scope: Value(scope),
      at: Value(at),
    );
  }

  factory SearchHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchHistoryRow(
      query: serializer.fromJson<String>(json['query']),
      scope: serializer.fromJson<String>(json['scope']),
      at: serializer.fromJson<int>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'query': serializer.toJson<String>(query),
      'scope': serializer.toJson<String>(scope),
      'at': serializer.toJson<int>(at),
    };
  }

  SearchHistoryRow copyWith({String? query, String? scope, int? at}) =>
      SearchHistoryRow(
        query: query ?? this.query,
        scope: scope ?? this.scope,
        at: at ?? this.at,
      );
  SearchHistoryRow copyWithCompanion(SearchHistoryCompanion data) {
    return SearchHistoryRow(
      query: data.query.present ? data.query.value : this.query,
      scope: data.scope.present ? data.scope.value : this.scope,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryRow(')
          ..write('query: $query, ')
          ..write('scope: $scope, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(query, scope, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHistoryRow &&
          other.query == this.query &&
          other.scope == this.scope &&
          other.at == this.at);
}

class SearchHistoryCompanion extends UpdateCompanion<SearchHistoryRow> {
  final Value<String> query;
  final Value<String> scope;
  final Value<int> at;
  final Value<int> rowid;
  const SearchHistoryCompanion({
    this.query = const Value.absent(),
    this.scope = const Value.absent(),
    this.at = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchHistoryCompanion.insert({
    required String query,
    this.scope = const Value.absent(),
    required int at,
    this.rowid = const Value.absent(),
  }) : query = Value(query),
       at = Value(at);
  static Insertable<SearchHistoryRow> custom({
    Expression<String>? query,
    Expression<String>? scope,
    Expression<int>? at,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (query != null) 'query': query,
      if (scope != null) 'scope': scope,
      if (at != null) 'at': at,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchHistoryCompanion copyWith({
    Value<String>? query,
    Value<String>? scope,
    Value<int>? at,
    Value<int>? rowid,
  }) {
    return SearchHistoryCompanion(
      query: query ?? this.query,
      scope: scope ?? this.scope,
      at: at ?? this.at,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchHistoryCompanion(')
          ..write('query: $query, ')
          ..write('scope: $scope, ')
          ..write('at: $at, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RydCacheTable extends RydCache
    with TableInfo<$RydCacheTable, RydCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RydCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _likesMeta = const VerificationMeta('likes');
  @override
  late final GeneratedColumn<int> likes = GeneratedColumn<int>(
    'likes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dislikesMeta = const VerificationMeta(
    'dislikes',
  );
  @override
  late final GeneratedColumn<int> dislikes = GeneratedColumn<int>(
    'dislikes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [videoId, likes, dislikes, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ryd_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<RydCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('likes')) {
      context.handle(
        _likesMeta,
        likes.isAcceptableOrUnknown(data['likes']!, _likesMeta),
      );
    } else if (isInserting) {
      context.missing(_likesMeta);
    }
    if (data.containsKey('dislikes')) {
      context.handle(
        _dislikesMeta,
        dislikes.isAcceptableOrUnknown(data['dislikes']!, _dislikesMeta),
      );
    } else if (isInserting) {
      context.missing(_dislikesMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  RydCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RydCacheRow(
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      likes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}likes'],
      )!,
      dislikes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dislikes'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $RydCacheTable createAlias(String alias) {
    return $RydCacheTable(attachedDatabase, alias);
  }
}

class RydCacheRow extends DataClass implements Insertable<RydCacheRow> {
  final String videoId;
  final int likes;
  final int dislikes;
  final int fetchedAt;
  const RydCacheRow({
    required this.videoId,
    required this.likes,
    required this.dislikes,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['likes'] = Variable<int>(likes);
    map['dislikes'] = Variable<int>(dislikes);
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  RydCacheCompanion toCompanion(bool nullToAbsent) {
    return RydCacheCompanion(
      videoId: Value(videoId),
      likes: Value(likes),
      dislikes: Value(dislikes),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory RydCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RydCacheRow(
      videoId: serializer.fromJson<String>(json['videoId']),
      likes: serializer.fromJson<int>(json['likes']),
      dislikes: serializer.fromJson<int>(json['dislikes']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'likes': serializer.toJson<int>(likes),
      'dislikes': serializer.toJson<int>(dislikes),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  RydCacheRow copyWith({
    String? videoId,
    int? likes,
    int? dislikes,
    int? fetchedAt,
  }) => RydCacheRow(
    videoId: videoId ?? this.videoId,
    likes: likes ?? this.likes,
    dislikes: dislikes ?? this.dislikes,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  RydCacheRow copyWithCompanion(RydCacheCompanion data) {
    return RydCacheRow(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      likes: data.likes.present ? data.likes.value : this.likes,
      dislikes: data.dislikes.present ? data.dislikes.value : this.dislikes,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RydCacheRow(')
          ..write('videoId: $videoId, ')
          ..write('likes: $likes, ')
          ..write('dislikes: $dislikes, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(videoId, likes, dislikes, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RydCacheRow &&
          other.videoId == this.videoId &&
          other.likes == this.likes &&
          other.dislikes == this.dislikes &&
          other.fetchedAt == this.fetchedAt);
}

class RydCacheCompanion extends UpdateCompanion<RydCacheRow> {
  final Value<String> videoId;
  final Value<int> likes;
  final Value<int> dislikes;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const RydCacheCompanion({
    this.videoId = const Value.absent(),
    this.likes = const Value.absent(),
    this.dislikes = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RydCacheCompanion.insert({
    required String videoId,
    required int likes,
    required int dislikes,
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : videoId = Value(videoId),
       likes = Value(likes),
       dislikes = Value(dislikes),
       fetchedAt = Value(fetchedAt);
  static Insertable<RydCacheRow> custom({
    Expression<String>? videoId,
    Expression<int>? likes,
    Expression<int>? dislikes,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (likes != null) 'likes': likes,
      if (dislikes != null) 'dislikes': dislikes,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RydCacheCompanion copyWith({
    Value<String>? videoId,
    Value<int>? likes,
    Value<int>? dislikes,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return RydCacheCompanion(
      videoId: videoId ?? this.videoId,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (likes.present) {
      map['likes'] = Variable<int>(likes.value);
    }
    if (dislikes.present) {
      map['dislikes'] = Variable<int>(dislikes.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RydCacheCompanion(')
          ..write('videoId: $videoId, ')
          ..write('likes: $likes, ')
          ..write('dislikes: $dislikes, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, DownloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vItagMeta = const VerificationMeta('vItag');
  @override
  late final GeneratedColumn<int> vItag = GeneratedColumn<int>(
    'v_itag',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aItagMeta = const VerificationMeta('aItag');
  @override
  late final GeneratedColumn<int> aItag = GeneratedColumn<int>(
    'a_itag',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _containerMeta = const VerificationMeta(
    'container',
  );
  @override
  late final GeneratedColumn<String> container = GeneratedColumn<String>(
    'container',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<int> done = GeneratedColumn<int>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    videoId,
    kind,
    vItag,
    aItag,
    height,
    container,
    path,
    total,
    done,
    status,
    error,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('v_itag')) {
      context.handle(
        _vItagMeta,
        vItag.isAcceptableOrUnknown(data['v_itag']!, _vItagMeta),
      );
    }
    if (data.containsKey('a_itag')) {
      context.handle(
        _aItagMeta,
        aItag.isAcceptableOrUnknown(data['a_itag']!, _aItagMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('container')) {
      context.handle(
        _containerMeta,
        container.isAcceptableOrUnknown(data['container']!, _containerMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      vItag: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}v_itag'],
      ),
      aItag: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}a_itag'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      container: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}container'],
      ),
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      ),
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }
}

class DownloadRow extends DataClass implements Insertable<DownloadRow> {
  final int id;
  final String videoId;
  final String kind;
  final int? vItag;
  final int? aItag;
  final int? height;
  final String? container;
  final String? path;
  final int total;
  final int done;
  final String status;
  final String? error;
  final int createdAt;
  const DownloadRow({
    required this.id,
    required this.videoId,
    required this.kind,
    this.vItag,
    this.aItag,
    this.height,
    this.container,
    this.path,
    required this.total,
    required this.done,
    required this.status,
    this.error,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['video_id'] = Variable<String>(videoId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || vItag != null) {
      map['v_itag'] = Variable<int>(vItag);
    }
    if (!nullToAbsent || aItag != null) {
      map['a_itag'] = Variable<int>(aItag);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || container != null) {
      map['container'] = Variable<String>(container);
    }
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    map['total'] = Variable<int>(total);
    map['done'] = Variable<int>(done);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      id: Value(id),
      videoId: Value(videoId),
      kind: Value(kind),
      vItag: vItag == null && nullToAbsent
          ? const Value.absent()
          : Value(vItag),
      aItag: aItag == null && nullToAbsent
          ? const Value.absent()
          : Value(aItag),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      container: container == null && nullToAbsent
          ? const Value.absent()
          : Value(container),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      total: Value(total),
      done: Value(done),
      status: Value(status),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
    );
  }

  factory DownloadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadRow(
      id: serializer.fromJson<int>(json['id']),
      videoId: serializer.fromJson<String>(json['videoId']),
      kind: serializer.fromJson<String>(json['kind']),
      vItag: serializer.fromJson<int?>(json['vItag']),
      aItag: serializer.fromJson<int?>(json['aItag']),
      height: serializer.fromJson<int?>(json['height']),
      container: serializer.fromJson<String?>(json['container']),
      path: serializer.fromJson<String?>(json['path']),
      total: serializer.fromJson<int>(json['total']),
      done: serializer.fromJson<int>(json['done']),
      status: serializer.fromJson<String>(json['status']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'videoId': serializer.toJson<String>(videoId),
      'kind': serializer.toJson<String>(kind),
      'vItag': serializer.toJson<int?>(vItag),
      'aItag': serializer.toJson<int?>(aItag),
      'height': serializer.toJson<int?>(height),
      'container': serializer.toJson<String?>(container),
      'path': serializer.toJson<String?>(path),
      'total': serializer.toJson<int>(total),
      'done': serializer.toJson<int>(done),
      'status': serializer.toJson<String>(status),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  DownloadRow copyWith({
    int? id,
    String? videoId,
    String? kind,
    Value<int?> vItag = const Value.absent(),
    Value<int?> aItag = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<String?> container = const Value.absent(),
    Value<String?> path = const Value.absent(),
    int? total,
    int? done,
    String? status,
    Value<String?> error = const Value.absent(),
    int? createdAt,
  }) => DownloadRow(
    id: id ?? this.id,
    videoId: videoId ?? this.videoId,
    kind: kind ?? this.kind,
    vItag: vItag.present ? vItag.value : this.vItag,
    aItag: aItag.present ? aItag.value : this.aItag,
    height: height.present ? height.value : this.height,
    container: container.present ? container.value : this.container,
    path: path.present ? path.value : this.path,
    total: total ?? this.total,
    done: done ?? this.done,
    status: status ?? this.status,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
  );
  DownloadRow copyWithCompanion(DownloadsCompanion data) {
    return DownloadRow(
      id: data.id.present ? data.id.value : this.id,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      kind: data.kind.present ? data.kind.value : this.kind,
      vItag: data.vItag.present ? data.vItag.value : this.vItag,
      aItag: data.aItag.present ? data.aItag.value : this.aItag,
      height: data.height.present ? data.height.value : this.height,
      container: data.container.present ? data.container.value : this.container,
      path: data.path.present ? data.path.value : this.path,
      total: data.total.present ? data.total.value : this.total,
      done: data.done.present ? data.done.value : this.done,
      status: data.status.present ? data.status.value : this.status,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadRow(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('kind: $kind, ')
          ..write('vItag: $vItag, ')
          ..write('aItag: $aItag, ')
          ..write('height: $height, ')
          ..write('container: $container, ')
          ..write('path: $path, ')
          ..write('total: $total, ')
          ..write('done: $done, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    videoId,
    kind,
    vItag,
    aItag,
    height,
    container,
    path,
    total,
    done,
    status,
    error,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadRow &&
          other.id == this.id &&
          other.videoId == this.videoId &&
          other.kind == this.kind &&
          other.vItag == this.vItag &&
          other.aItag == this.aItag &&
          other.height == this.height &&
          other.container == this.container &&
          other.path == this.path &&
          other.total == this.total &&
          other.done == this.done &&
          other.status == this.status &&
          other.error == this.error &&
          other.createdAt == this.createdAt);
}

class DownloadsCompanion extends UpdateCompanion<DownloadRow> {
  final Value<int> id;
  final Value<String> videoId;
  final Value<String> kind;
  final Value<int?> vItag;
  final Value<int?> aItag;
  final Value<int?> height;
  final Value<String?> container;
  final Value<String?> path;
  final Value<int> total;
  final Value<int> done;
  final Value<String> status;
  final Value<String?> error;
  final Value<int> createdAt;
  const DownloadsCompanion({
    this.id = const Value.absent(),
    this.videoId = const Value.absent(),
    this.kind = const Value.absent(),
    this.vItag = const Value.absent(),
    this.aItag = const Value.absent(),
    this.height = const Value.absent(),
    this.container = const Value.absent(),
    this.path = const Value.absent(),
    this.total = const Value.absent(),
    this.done = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DownloadsCompanion.insert({
    this.id = const Value.absent(),
    required String videoId,
    required String kind,
    this.vItag = const Value.absent(),
    this.aItag = const Value.absent(),
    this.height = const Value.absent(),
    this.container = const Value.absent(),
    this.path = const Value.absent(),
    this.total = const Value.absent(),
    this.done = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    required int createdAt,
  }) : videoId = Value(videoId),
       kind = Value(kind),
       createdAt = Value(createdAt);
  static Insertable<DownloadRow> custom({
    Expression<int>? id,
    Expression<String>? videoId,
    Expression<String>? kind,
    Expression<int>? vItag,
    Expression<int>? aItag,
    Expression<int>? height,
    Expression<String>? container,
    Expression<String>? path,
    Expression<int>? total,
    Expression<int>? done,
    Expression<String>? status,
    Expression<String>? error,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (videoId != null) 'video_id': videoId,
      if (kind != null) 'kind': kind,
      if (vItag != null) 'v_itag': vItag,
      if (aItag != null) 'a_itag': aItag,
      if (height != null) 'height': height,
      if (container != null) 'container': container,
      if (path != null) 'path': path,
      if (total != null) 'total': total,
      if (done != null) 'done': done,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DownloadsCompanion copyWith({
    Value<int>? id,
    Value<String>? videoId,
    Value<String>? kind,
    Value<int?>? vItag,
    Value<int?>? aItag,
    Value<int?>? height,
    Value<String?>? container,
    Value<String?>? path,
    Value<int>? total,
    Value<int>? done,
    Value<String>? status,
    Value<String?>? error,
    Value<int>? createdAt,
  }) {
    return DownloadsCompanion(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      kind: kind ?? this.kind,
      vItag: vItag ?? this.vItag,
      aItag: aItag ?? this.aItag,
      height: height ?? this.height,
      container: container ?? this.container,
      path: path ?? this.path,
      total: total ?? this.total,
      done: done ?? this.done,
      status: status ?? this.status,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (vItag.present) {
      map['v_itag'] = Variable<int>(vItag.value);
    }
    if (aItag.present) {
      map['a_itag'] = Variable<int>(aItag.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (container.present) {
      map['container'] = Variable<String>(container.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (done.present) {
      map['done'] = Variable<int>(done.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('id: $id, ')
          ..write('videoId: $videoId, ')
          ..write('kind: $kind, ')
          ..write('vItag: $vItag, ')
          ..write('aItag: $aItag, ')
          ..write('height: $height, ')
          ..write('container: $container, ')
          ..write('path: $path, ')
          ..write('total: $total, ')
          ..write('done: $done, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AudioCacheTable extends AudioCache
    with TableInfo<$AudioCacheTable, AudioCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AudioCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itagMeta = const VerificationMeta('itag');
  @override
  late final GeneratedColumn<int> itag = GeneratedColumn<int>(
    'itag',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<int> lastPlayedAt = GeneratedColumn<int>(
    'last_played_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    videoId,
    itag,
    path,
    bytes,
    lastPlayedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audio_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<AudioCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('itag')) {
      context.handle(
        _itagMeta,
        itag.isAcceptableOrUnknown(data['itag']!, _itagMeta),
      );
    } else if (isInserting) {
      context.missing(_itagMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastPlayedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  AudioCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AudioCacheRow(
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      itag: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}itag'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_played_at'],
      )!,
    );
  }

  @override
  $AudioCacheTable createAlias(String alias) {
    return $AudioCacheTable(attachedDatabase, alias);
  }
}

class AudioCacheRow extends DataClass implements Insertable<AudioCacheRow> {
  final String videoId;
  final int itag;
  final String path;
  final int bytes;
  final int lastPlayedAt;
  const AudioCacheRow({
    required this.videoId,
    required this.itag,
    required this.path,
    required this.bytes,
    required this.lastPlayedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['itag'] = Variable<int>(itag);
    map['path'] = Variable<String>(path);
    map['bytes'] = Variable<int>(bytes);
    map['last_played_at'] = Variable<int>(lastPlayedAt);
    return map;
  }

  AudioCacheCompanion toCompanion(bool nullToAbsent) {
    return AudioCacheCompanion(
      videoId: Value(videoId),
      itag: Value(itag),
      path: Value(path),
      bytes: Value(bytes),
      lastPlayedAt: Value(lastPlayedAt),
    );
  }

  factory AudioCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AudioCacheRow(
      videoId: serializer.fromJson<String>(json['videoId']),
      itag: serializer.fromJson<int>(json['itag']),
      path: serializer.fromJson<String>(json['path']),
      bytes: serializer.fromJson<int>(json['bytes']),
      lastPlayedAt: serializer.fromJson<int>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'itag': serializer.toJson<int>(itag),
      'path': serializer.toJson<String>(path),
      'bytes': serializer.toJson<int>(bytes),
      'lastPlayedAt': serializer.toJson<int>(lastPlayedAt),
    };
  }

  AudioCacheRow copyWith({
    String? videoId,
    int? itag,
    String? path,
    int? bytes,
    int? lastPlayedAt,
  }) => AudioCacheRow(
    videoId: videoId ?? this.videoId,
    itag: itag ?? this.itag,
    path: path ?? this.path,
    bytes: bytes ?? this.bytes,
    lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
  );
  AudioCacheRow copyWithCompanion(AudioCacheCompanion data) {
    return AudioCacheRow(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      itag: data.itag.present ? data.itag.value : this.itag,
      path: data.path.present ? data.path.value : this.path,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheRow(')
          ..write('videoId: $videoId, ')
          ..write('itag: $itag, ')
          ..write('path: $path, ')
          ..write('bytes: $bytes, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(videoId, itag, path, bytes, lastPlayedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AudioCacheRow &&
          other.videoId == this.videoId &&
          other.itag == this.itag &&
          other.path == this.path &&
          other.bytes == this.bytes &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class AudioCacheCompanion extends UpdateCompanion<AudioCacheRow> {
  final Value<String> videoId;
  final Value<int> itag;
  final Value<String> path;
  final Value<int> bytes;
  final Value<int> lastPlayedAt;
  final Value<int> rowid;
  const AudioCacheCompanion({
    this.videoId = const Value.absent(),
    this.itag = const Value.absent(),
    this.path = const Value.absent(),
    this.bytes = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AudioCacheCompanion.insert({
    required String videoId,
    required int itag,
    required String path,
    required int bytes,
    required int lastPlayedAt,
    this.rowid = const Value.absent(),
  }) : videoId = Value(videoId),
       itag = Value(itag),
       path = Value(path),
       bytes = Value(bytes),
       lastPlayedAt = Value(lastPlayedAt);
  static Insertable<AudioCacheRow> custom({
    Expression<String>? videoId,
    Expression<int>? itag,
    Expression<String>? path,
    Expression<int>? bytes,
    Expression<int>? lastPlayedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (itag != null) 'itag': itag,
      if (path != null) 'path': path,
      if (bytes != null) 'bytes': bytes,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AudioCacheCompanion copyWith({
    Value<String>? videoId,
    Value<int>? itag,
    Value<String>? path,
    Value<int>? bytes,
    Value<int>? lastPlayedAt,
    Value<int>? rowid,
  }) {
    return AudioCacheCompanion(
      videoId: videoId ?? this.videoId,
      itag: itag ?? this.itag,
      path: path ?? this.path,
      bytes: bytes ?? this.bytes,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (itag.present) {
      map['itag'] = Variable<int>(itag.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<int>(lastPlayedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AudioCacheCompanion(')
          ..write('videoId: $videoId, ')
          ..write('itag: $itag, ')
          ..write('path: $path, ')
          ..write('bytes: $bytes, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LyricsCacheTable extends LyricsCache
    with TableInfo<$LyricsCacheTable, LyricsCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricsCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawMeta = const VerificationMeta('raw');
  @override
  late final GeneratedColumn<String> raw = GeneratedColumn<String>(
    'raw',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _offsetMsMeta = const VerificationMeta(
    'offsetMs',
  );
  @override
  late final GeneratedColumn<int> offsetMs = GeneratedColumn<int>(
    'offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    videoId,
    source,
    format,
    raw,
    offsetMs,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricsCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('raw')) {
      context.handle(
        _rawMeta,
        raw.isAcceptableOrUnknown(data['raw']!, _rawMeta),
      );
    } else if (isInserting) {
      context.missing(_rawMeta);
    }
    if (data.containsKey('offset_ms')) {
      context.handle(
        _offsetMsMeta,
        offsetMs.isAcceptableOrUnknown(data['offset_ms']!, _offsetMsMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  LyricsCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricsCacheRow(
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      raw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw'],
      )!,
      offsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_ms'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $LyricsCacheTable createAlias(String alias) {
    return $LyricsCacheTable(attachedDatabase, alias);
  }
}

class LyricsCacheRow extends DataClass implements Insertable<LyricsCacheRow> {
  final String videoId;
  final String source;
  final String format;
  final String raw;
  final int offsetMs;
  final int fetchedAt;
  const LyricsCacheRow({
    required this.videoId,
    required this.source,
    required this.format,
    required this.raw,
    required this.offsetMs,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['source'] = Variable<String>(source);
    map['format'] = Variable<String>(format);
    map['raw'] = Variable<String>(raw);
    map['offset_ms'] = Variable<int>(offsetMs);
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  LyricsCacheCompanion toCompanion(bool nullToAbsent) {
    return LyricsCacheCompanion(
      videoId: Value(videoId),
      source: Value(source),
      format: Value(format),
      raw: Value(raw),
      offsetMs: Value(offsetMs),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory LyricsCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricsCacheRow(
      videoId: serializer.fromJson<String>(json['videoId']),
      source: serializer.fromJson<String>(json['source']),
      format: serializer.fromJson<String>(json['format']),
      raw: serializer.fromJson<String>(json['raw']),
      offsetMs: serializer.fromJson<int>(json['offsetMs']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'source': serializer.toJson<String>(source),
      'format': serializer.toJson<String>(format),
      'raw': serializer.toJson<String>(raw),
      'offsetMs': serializer.toJson<int>(offsetMs),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  LyricsCacheRow copyWith({
    String? videoId,
    String? source,
    String? format,
    String? raw,
    int? offsetMs,
    int? fetchedAt,
  }) => LyricsCacheRow(
    videoId: videoId ?? this.videoId,
    source: source ?? this.source,
    format: format ?? this.format,
    raw: raw ?? this.raw,
    offsetMs: offsetMs ?? this.offsetMs,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  LyricsCacheRow copyWithCompanion(LyricsCacheCompanion data) {
    return LyricsCacheRow(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      source: data.source.present ? data.source.value : this.source,
      format: data.format.present ? data.format.value : this.format,
      raw: data.raw.present ? data.raw.value : this.raw,
      offsetMs: data.offsetMs.present ? data.offsetMs.value : this.offsetMs,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricsCacheRow(')
          ..write('videoId: $videoId, ')
          ..write('source: $source, ')
          ..write('format: $format, ')
          ..write('raw: $raw, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(videoId, source, format, raw, offsetMs, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricsCacheRow &&
          other.videoId == this.videoId &&
          other.source == this.source &&
          other.format == this.format &&
          other.raw == this.raw &&
          other.offsetMs == this.offsetMs &&
          other.fetchedAt == this.fetchedAt);
}

class LyricsCacheCompanion extends UpdateCompanion<LyricsCacheRow> {
  final Value<String> videoId;
  final Value<String> source;
  final Value<String> format;
  final Value<String> raw;
  final Value<int> offsetMs;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const LyricsCacheCompanion({
    this.videoId = const Value.absent(),
    this.source = const Value.absent(),
    this.format = const Value.absent(),
    this.raw = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LyricsCacheCompanion.insert({
    required String videoId,
    required String source,
    required String format,
    required String raw,
    this.offsetMs = const Value.absent(),
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : videoId = Value(videoId),
       source = Value(source),
       format = Value(format),
       raw = Value(raw),
       fetchedAt = Value(fetchedAt);
  static Insertable<LyricsCacheRow> custom({
    Expression<String>? videoId,
    Expression<String>? source,
    Expression<String>? format,
    Expression<String>? raw,
    Expression<int>? offsetMs,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (source != null) 'source': source,
      if (format != null) 'format': format,
      if (raw != null) 'raw': raw,
      if (offsetMs != null) 'offset_ms': offsetMs,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LyricsCacheCompanion copyWith({
    Value<String>? videoId,
    Value<String>? source,
    Value<String>? format,
    Value<String>? raw,
    Value<int>? offsetMs,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return LyricsCacheCompanion(
      videoId: videoId ?? this.videoId,
      source: source ?? this.source,
      format: format ?? this.format,
      raw: raw ?? this.raw,
      offsetMs: offsetMs ?? this.offsetMs,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (raw.present) {
      map['raw'] = Variable<String>(raw.value);
    }
    if (offsetMs.present) {
      map['offset_ms'] = Variable<int>(offsetMs.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsCacheCompanion(')
          ..write('videoId: $videoId, ')
          ..write('source: $source, ')
          ..write('format: $format, ')
          ..write('raw: $raw, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SbCacheTable extends SbCache with TableInfo<$SbCacheTable, SbCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SbCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [videoId, json, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sb_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<SbCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_videoIdMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {videoId};
  @override
  SbCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SbCacheRow(
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $SbCacheTable createAlias(String alias) {
    return $SbCacheTable(attachedDatabase, alias);
  }
}

class SbCacheRow extends DataClass implements Insertable<SbCacheRow> {
  final String videoId;
  final String json;
  final int fetchedAt;
  const SbCacheRow({
    required this.videoId,
    required this.json,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['video_id'] = Variable<String>(videoId);
    map['json'] = Variable<String>(json);
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  SbCacheCompanion toCompanion(bool nullToAbsent) {
    return SbCacheCompanion(
      videoId: Value(videoId),
      json: Value(json),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory SbCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SbCacheRow(
      videoId: serializer.fromJson<String>(json['videoId']),
      json: serializer.fromJson<String>(json['json']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'videoId': serializer.toJson<String>(videoId),
      'json': serializer.toJson<String>(json),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  SbCacheRow copyWith({String? videoId, String? json, int? fetchedAt}) =>
      SbCacheRow(
        videoId: videoId ?? this.videoId,
        json: json ?? this.json,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  SbCacheRow copyWithCompanion(SbCacheCompanion data) {
    return SbCacheRow(
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      json: data.json.present ? data.json.value : this.json,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SbCacheRow(')
          ..write('videoId: $videoId, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(videoId, json, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SbCacheRow &&
          other.videoId == this.videoId &&
          other.json == this.json &&
          other.fetchedAt == this.fetchedAt);
}

class SbCacheCompanion extends UpdateCompanion<SbCacheRow> {
  final Value<String> videoId;
  final Value<String> json;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const SbCacheCompanion({
    this.videoId = const Value.absent(),
    this.json = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SbCacheCompanion.insert({
    required String videoId,
    required String json,
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : videoId = Value(videoId),
       json = Value(json),
       fetchedAt = Value(fetchedAt);
  static Insertable<SbCacheRow> custom({
    Expression<String>? videoId,
    Expression<String>? json,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (videoId != null) 'video_id': videoId,
      if (json != null) 'json': json,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SbCacheCompanion copyWith({
    Value<String>? videoId,
    Value<String>? json,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return SbCacheCompanion(
      videoId: videoId ?? this.videoId,
      json: json ?? this.json,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SbCacheCompanion(')
          ..write('videoId: $videoId, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $PrefsTable prefs = $PrefsTable(this);
  late final $ProfileTable profile = $ProfileTable(this);
  late final $SubscriptionsTable subscriptions = $SubscriptionsTable(this);
  late final $FeedItemsTable feedItems = $FeedItemsTable(this);
  late final $MediaTable media = $MediaTable(this);
  late final $ReactionsTable reactions = $ReactionsTable(this);
  late final $HistoryTable history = $HistoryTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistItemsTable playlistItems = $PlaylistItemsTable(this);
  late final $SavedRemoteTable savedRemote = $SavedRemoteTable(this);
  late final $SearchHistoryTable searchHistory = $SearchHistoryTable(this);
  late final $RydCacheTable rydCache = $RydCacheTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $AudioCacheTable audioCache = $AudioCacheTable(this);
  late final $LyricsCacheTable lyricsCache = $LyricsCacheTable(this);
  late final $SbCacheTable sbCache = $SbCacheTable(this);
  late final SubscriptionsDao subscriptionsDao = SubscriptionsDao(
    this as AppDb,
  );
  late final FeedItemsDao feedItemsDao = FeedItemsDao(this as AppDb);
  late final HistoryDao historyDao = HistoryDao(this as AppDb);
  late final ReactionsDao reactionsDao = ReactionsDao(this as AppDb);
  late final PlaylistsDao playlistsDao = PlaylistsDao(this as AppDb);
  late final SavedRemoteDao savedRemoteDao = SavedRemoteDao(this as AppDb);
  late final SearchHistoryDao searchHistoryDao = SearchHistoryDao(
    this as AppDb,
  );
  late final RydDao rydDao = RydDao(this as AppDb);
  late final ProfileDao profileDao = ProfileDao(this as AppDb);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    prefs,
    profile,
    subscriptions,
    feedItems,
    media,
    reactions,
    history,
    playlists,
    playlistItems,
    savedRemote,
    searchHistory,
    rydCache,
    downloads,
    audioCache,
    lyricsCache,
    sbCache,
  ];
}

typedef $$PrefsTableCreateCompanionBuilder =
    PrefsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$PrefsTableUpdateCompanionBuilder =
    PrefsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$PrefsTableFilterComposer extends Composer<_$AppDb, $PrefsTable> {
  $$PrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrefsTableOrderingComposer extends Composer<_$AppDb, $PrefsTable> {
  $$PrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrefsTableAnnotationComposer extends Composer<_$AppDb, $PrefsTable> {
  $$PrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$PrefsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PrefsTable,
          Pref,
          $$PrefsTableFilterComposer,
          $$PrefsTableOrderingComposer,
          $$PrefsTableAnnotationComposer,
          $$PrefsTableCreateCompanionBuilder,
          $$PrefsTableUpdateCompanionBuilder,
          (Pref, BaseReferences<_$AppDb, $PrefsTable, Pref>),
          Pref,
          PrefetchHooks Function()
        > {
  $$PrefsTableTableManager(_$AppDb db, $PrefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrefsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => PrefsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PrefsTable, Pref>(table),
                  BaseReferences<_$AppDb, $PrefsTable, Pref>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PrefsTable,
      Pref,
      $$PrefsTableFilterComposer,
      $$PrefsTableOrderingComposer,
      $$PrefsTableAnnotationComposer,
      $$PrefsTableCreateCompanionBuilder,
      $$PrefsTableUpdateCompanionBuilder,
      (Pref, BaseReferences<_$AppDb, $PrefsTable, Pref>),
      Pref,
      PrefetchHooks Function()
    >;
typedef $$ProfileTableCreateCompanionBuilder =
    ProfileCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> avatarPath,
      required int createdAt,
    });
typedef $$ProfileTableUpdateCompanionBuilder =
    ProfileCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> avatarPath,
      Value<int> createdAt,
    });

class $$ProfileTableFilterComposer extends Composer<_$AppDb, $ProfileTable> {
  $$ProfileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfileTableOrderingComposer extends Composer<_$AppDb, $ProfileTable> {
  $$ProfileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfileTableAnnotationComposer
    extends Composer<_$AppDb, $ProfileTable> {
  $$ProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProfileTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ProfileTable,
          ProfileRow,
          $$ProfileTableFilterComposer,
          $$ProfileTableOrderingComposer,
          $$ProfileTableAnnotationComposer,
          $$ProfileTableCreateCompanionBuilder,
          $$ProfileTableUpdateCompanionBuilder,
          (ProfileRow, BaseReferences<_$AppDb, $ProfileTable, ProfileRow>),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$ProfileTableTableManager(_$AppDb db, $ProfileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => ProfileCompanion(
                id: id,
                name: name,
                avatarPath: avatarPath,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> avatarPath = const Value.absent(),
                required int createdAt,
              }) => ProfileCompanion.insert(
                id: id,
                name: name,
                avatarPath: avatarPath,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfileTable, ProfileRow>(table),
                  BaseReferences<_$AppDb, $ProfileTable, ProfileRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfileTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ProfileTable,
      ProfileRow,
      $$ProfileTableFilterComposer,
      $$ProfileTableOrderingComposer,
      $$ProfileTableAnnotationComposer,
      $$ProfileTableCreateCompanionBuilder,
      $$ProfileTableUpdateCompanionBuilder,
      (ProfileRow, BaseReferences<_$AppDb, $ProfileTable, ProfileRow>),
      ProfileRow,
      PrefetchHooks Function()
    >;
typedef $$SubscriptionsTableCreateCompanionBuilder =
    SubscriptionsCompanion Function({
      required String channelId,
      required String name,
      required String avatarUrl,
      required int subscribedAt,
      Value<int> lastFeedAt,
      Value<int> rowid,
    });
typedef $$SubscriptionsTableUpdateCompanionBuilder =
    SubscriptionsCompanion Function({
      Value<String> channelId,
      Value<String> name,
      Value<String> avatarUrl,
      Value<int> subscribedAt,
      Value<int> lastFeedAt,
      Value<int> rowid,
    });

class $$SubscriptionsTableFilterComposer
    extends Composer<_$AppDb, $SubscriptionsTable> {
  $$SubscriptionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subscribedAt => $composableBuilder(
    column: $table.subscribedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastFeedAt => $composableBuilder(
    column: $table.lastFeedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubscriptionsTableOrderingComposer
    extends Composer<_$AppDb, $SubscriptionsTable> {
  $$SubscriptionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subscribedAt => $composableBuilder(
    column: $table.subscribedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastFeedAt => $composableBuilder(
    column: $table.lastFeedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubscriptionsTableAnnotationComposer
    extends Composer<_$AppDb, $SubscriptionsTable> {
  $$SubscriptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<int> get subscribedAt => $composableBuilder(
    column: $table.subscribedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastFeedAt => $composableBuilder(
    column: $table.lastFeedAt,
    builder: (column) => column,
  );
}

class $$SubscriptionsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SubscriptionsTable,
          SubscriptionRow,
          $$SubscriptionsTableFilterComposer,
          $$SubscriptionsTableOrderingComposer,
          $$SubscriptionsTableAnnotationComposer,
          $$SubscriptionsTableCreateCompanionBuilder,
          $$SubscriptionsTableUpdateCompanionBuilder,
          (
            SubscriptionRow,
            BaseReferences<_$AppDb, $SubscriptionsTable, SubscriptionRow>,
          ),
          SubscriptionRow,
          PrefetchHooks Function()
        > {
  $$SubscriptionsTableTableManager(_$AppDb db, $SubscriptionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubscriptionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubscriptionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubscriptionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> channelId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> avatarUrl = const Value.absent(),
                Value<int> subscribedAt = const Value.absent(),
                Value<int> lastFeedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubscriptionsCompanion(
                channelId: channelId,
                name: name,
                avatarUrl: avatarUrl,
                subscribedAt: subscribedAt,
                lastFeedAt: lastFeedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String channelId,
                required String name,
                required String avatarUrl,
                required int subscribedAt,
                Value<int> lastFeedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubscriptionsCompanion.insert(
                channelId: channelId,
                name: name,
                avatarUrl: avatarUrl,
                subscribedAt: subscribedAt,
                lastFeedAt: lastFeedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubscriptionsTable, SubscriptionRow>(table),
                  BaseReferences<_$AppDb, $SubscriptionsTable, SubscriptionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubscriptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SubscriptionsTable,
      SubscriptionRow,
      $$SubscriptionsTableFilterComposer,
      $$SubscriptionsTableOrderingComposer,
      $$SubscriptionsTableAnnotationComposer,
      $$SubscriptionsTableCreateCompanionBuilder,
      $$SubscriptionsTableUpdateCompanionBuilder,
      (
        SubscriptionRow,
        BaseReferences<_$AppDb, $SubscriptionsTable, SubscriptionRow>,
      ),
      SubscriptionRow,
      PrefetchHooks Function()
    >;
typedef $$FeedItemsTableCreateCompanionBuilder =
    FeedItemsCompanion Function({
      required String videoId,
      required String channelId,
      required String title,
      required int publishedAt,
      required String thumbUrl,
      Value<int?> durationSec,
      required int fetchedAt,
      Value<int> rowid,
    });
typedef $$FeedItemsTableUpdateCompanionBuilder =
    FeedItemsCompanion Function({
      Value<String> videoId,
      Value<String> channelId,
      Value<String> title,
      Value<int> publishedAt,
      Value<String> thumbUrl,
      Value<int?> durationSec,
      Value<int> fetchedAt,
      Value<int> rowid,
    });

class $$FeedItemsTableFilterComposer
    extends Composer<_$AppDb, $FeedItemsTable> {
  $$FeedItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FeedItemsTableOrderingComposer
    extends Composer<_$AppDb, $FeedItemsTable> {
  $$FeedItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FeedItemsTableAnnotationComposer
    extends Composer<_$AppDb, $FeedItemsTable> {
  $$FeedItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbUrl =>
      $composableBuilder(column: $table.thumbUrl, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$FeedItemsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $FeedItemsTable,
          FeedItemRow,
          $$FeedItemsTableFilterComposer,
          $$FeedItemsTableOrderingComposer,
          $$FeedItemsTableAnnotationComposer,
          $$FeedItemsTableCreateCompanionBuilder,
          $$FeedItemsTableUpdateCompanionBuilder,
          (FeedItemRow, BaseReferences<_$AppDb, $FeedItemsTable, FeedItemRow>),
          FeedItemRow,
          PrefetchHooks Function()
        > {
  $$FeedItemsTableTableManager(_$AppDb db, $FeedItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> videoId = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> publishedAt = const Value.absent(),
                Value<String> thumbUrl = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FeedItemsCompanion(
                videoId: videoId,
                channelId: channelId,
                title: title,
                publishedAt: publishedAt,
                thumbUrl: thumbUrl,
                durationSec: durationSec,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String videoId,
                required String channelId,
                required String title,
                required int publishedAt,
                required String thumbUrl,
                Value<int?> durationSec = const Value.absent(),
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => FeedItemsCompanion.insert(
                videoId: videoId,
                channelId: channelId,
                title: title,
                publishedAt: publishedAt,
                thumbUrl: thumbUrl,
                durationSec: durationSec,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FeedItemsTable, FeedItemRow>(table),
                  BaseReferences<_$AppDb, $FeedItemsTable, FeedItemRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FeedItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $FeedItemsTable,
      FeedItemRow,
      $$FeedItemsTableFilterComposer,
      $$FeedItemsTableOrderingComposer,
      $$FeedItemsTableAnnotationComposer,
      $$FeedItemsTableCreateCompanionBuilder,
      $$FeedItemsTableUpdateCompanionBuilder,
      (FeedItemRow, BaseReferences<_$AppDb, $FeedItemsTable, FeedItemRow>),
      FeedItemRow,
      PrefetchHooks Function()
    >;
typedef $$MediaTableCreateCompanionBuilder =
    MediaCompanion Function({
      required String videoId,
      required String title,
      required String channelId,
      required String channelName,
      Value<int?> durationSec,
      required String thumbUrl,
      Value<bool> isMusic,
      Value<String?> musicVideoType,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$MediaTableUpdateCompanionBuilder =
    MediaCompanion Function({
      Value<String> videoId,
      Value<String> title,
      Value<String> channelId,
      Value<String> channelName,
      Value<int?> durationSec,
      Value<String> thumbUrl,
      Value<bool> isMusic,
      Value<String?> musicVideoType,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$MediaTableFilterComposer extends Composer<_$AppDb, $MediaTable> {
  $$MediaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMusic => $composableBuilder(
    column: $table.isMusic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get musicVideoType => $composableBuilder(
    column: $table.musicVideoType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaTableOrderingComposer extends Composer<_$AppDb, $MediaTable> {
  $$MediaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMusic => $composableBuilder(
    column: $table.isMusic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get musicVideoType => $composableBuilder(
    column: $table.musicVideoType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaTableAnnotationComposer extends Composer<_$AppDb, $MediaTable> {
  $$MediaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<String> get channelName => $composableBuilder(
    column: $table.channelName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbUrl =>
      $composableBuilder(column: $table.thumbUrl, builder: (column) => column);

  GeneratedColumn<bool> get isMusic =>
      $composableBuilder(column: $table.isMusic, builder: (column) => column);

  GeneratedColumn<String> get musicVideoType => $composableBuilder(
    column: $table.musicVideoType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MediaTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $MediaTable,
          MediaRow,
          $$MediaTableFilterComposer,
          $$MediaTableOrderingComposer,
          $$MediaTableAnnotationComposer,
          $$MediaTableCreateCompanionBuilder,
          $$MediaTableUpdateCompanionBuilder,
          (MediaRow, BaseReferences<_$AppDb, $MediaTable, MediaRow>),
          MediaRow,
          PrefetchHooks Function()
        > {
  $$MediaTableTableManager(_$AppDb db, $MediaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> videoId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> channelId = const Value.absent(),
                Value<String> channelName = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<String> thumbUrl = const Value.absent(),
                Value<bool> isMusic = const Value.absent(),
                Value<String?> musicVideoType = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaCompanion(
                videoId: videoId,
                title: title,
                channelId: channelId,
                channelName: channelName,
                durationSec: durationSec,
                thumbUrl: thumbUrl,
                isMusic: isMusic,
                musicVideoType: musicVideoType,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String videoId,
                required String title,
                required String channelId,
                required String channelName,
                Value<int?> durationSec = const Value.absent(),
                required String thumbUrl,
                Value<bool> isMusic = const Value.absent(),
                Value<String?> musicVideoType = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MediaCompanion.insert(
                videoId: videoId,
                title: title,
                channelId: channelId,
                channelName: channelName,
                durationSec: durationSec,
                thumbUrl: thumbUrl,
                isMusic: isMusic,
                musicVideoType: musicVideoType,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MediaTable, MediaRow>(table),
                  BaseReferences<_$AppDb, $MediaTable, MediaRow>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $MediaTable,
      MediaRow,
      $$MediaTableFilterComposer,
      $$MediaTableOrderingComposer,
      $$MediaTableAnnotationComposer,
      $$MediaTableCreateCompanionBuilder,
      $$MediaTableUpdateCompanionBuilder,
      (MediaRow, BaseReferences<_$AppDb, $MediaTable, MediaRow>),
      MediaRow,
      PrefetchHooks Function()
    >;
typedef $$ReactionsTableCreateCompanionBuilder =
    ReactionsCompanion Function({
      required String videoId,
      required int value,
      required int at,
      Value<String> scope,
      Value<int> rowid,
    });
typedef $$ReactionsTableUpdateCompanionBuilder =
    ReactionsCompanion Function({
      Value<String> videoId,
      Value<int> value,
      Value<int> at,
      Value<String> scope,
      Value<int> rowid,
    });

class $$ReactionsTableFilterComposer
    extends Composer<_$AppDb, $ReactionsTable> {
  $$ReactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReactionsTableOrderingComposer
    extends Composer<_$AppDb, $ReactionsTable> {
  $$ReactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReactionsTableAnnotationComposer
    extends Composer<_$AppDb, $ReactionsTable> {
  $$ReactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);
}

class $$ReactionsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $ReactionsTable,
          ReactionRow,
          $$ReactionsTableFilterComposer,
          $$ReactionsTableOrderingComposer,
          $$ReactionsTableAnnotationComposer,
          $$ReactionsTableCreateCompanionBuilder,
          $$ReactionsTableUpdateCompanionBuilder,
          (ReactionRow, BaseReferences<_$AppDb, $ReactionsTable, ReactionRow>),
          ReactionRow,
          PrefetchHooks Function()
        > {
  $$ReactionsTableTableManager(_$AppDb db, $ReactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> videoId = const Value.absent(),
                Value<int> value = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReactionsCompanion(
                videoId: videoId,
                value: value,
                at: at,
                scope: scope,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String videoId,
                required int value,
                required int at,
                Value<String> scope = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReactionsCompanion.insert(
                videoId: videoId,
                value: value,
                at: at,
                scope: scope,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReactionsTable, ReactionRow>(table),
                  BaseReferences<_$AppDb, $ReactionsTable, ReactionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $ReactionsTable,
      ReactionRow,
      $$ReactionsTableFilterComposer,
      $$ReactionsTableOrderingComposer,
      $$ReactionsTableAnnotationComposer,
      $$ReactionsTableCreateCompanionBuilder,
      $$ReactionsTableUpdateCompanionBuilder,
      (ReactionRow, BaseReferences<_$AppDb, $ReactionsTable, ReactionRow>),
      ReactionRow,
      PrefetchHooks Function()
    >;
typedef $$HistoryTableCreateCompanionBuilder =
    HistoryCompanion Function({
      Value<int> id,
      required String videoId,
      required int positionMs,
      required int durationMs,
      required int at,
      Value<String> scope,
    });
typedef $$HistoryTableUpdateCompanionBuilder =
    HistoryCompanion Function({
      Value<int> id,
      Value<String> videoId,
      Value<int> positionMs,
      Value<int> durationMs,
      Value<int> at,
      Value<String> scope,
    });

class $$HistoryTableFilterComposer extends Composer<_$AppDb, $HistoryTable> {
  $$HistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryTableOrderingComposer extends Composer<_$AppDb, $HistoryTable> {
  $$HistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryTableAnnotationComposer
    extends Composer<_$AppDb, $HistoryTable> {
  $$HistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);
}

class $$HistoryTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $HistoryTable,
          HistoryRow,
          $$HistoryTableFilterComposer,
          $$HistoryTableOrderingComposer,
          $$HistoryTableAnnotationComposer,
          $$HistoryTableCreateCompanionBuilder,
          $$HistoryTableUpdateCompanionBuilder,
          (HistoryRow, BaseReferences<_$AppDb, $HistoryTable, HistoryRow>),
          HistoryRow,
          PrefetchHooks Function()
        > {
  $$HistoryTableTableManager(_$AppDb db, $HistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String> scope = const Value.absent(),
              }) => HistoryCompanion(
                id: id,
                videoId: videoId,
                positionMs: positionMs,
                durationMs: durationMs,
                at: at,
                scope: scope,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String videoId,
                required int positionMs,
                required int durationMs,
                required int at,
                Value<String> scope = const Value.absent(),
              }) => HistoryCompanion.insert(
                id: id,
                videoId: videoId,
                positionMs: positionMs,
                durationMs: durationMs,
                at: at,
                scope: scope,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HistoryTable, HistoryRow>(table),
                  BaseReferences<_$AppDb, $HistoryTable, HistoryRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $HistoryTable,
      HistoryRow,
      $$HistoryTableFilterComposer,
      $$HistoryTableOrderingComposer,
      $$HistoryTableAnnotationComposer,
      $$HistoryTableCreateCompanionBuilder,
      $$HistoryTableUpdateCompanionBuilder,
      (HistoryRow, BaseReferences<_$AppDb, $HistoryTable, HistoryRow>),
      HistoryRow,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> scope,
      Value<String?> remoteId,
      Value<String?> thumbUrl,
      required int createdAt,
      required int updatedAt,
    });
typedef $$PlaylistsTableUpdateCompanionBuilder =
    PlaylistsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> scope,
      Value<String?> remoteId,
      Value<String?> thumbUrl,
      Value<int> createdAt,
      Value<int> updatedAt,
    });

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDb, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDb, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDb, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get thumbUrl =>
      $composableBuilder(column: $table.thumbUrl, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PlaylistsTable,
          PlaylistRow,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (PlaylistRow, BaseReferences<_$AppDb, $PlaylistsTable, PlaylistRow>),
          PlaylistRow,
          PrefetchHooks Function()
        > {
  $$PlaylistsTableTableManager(_$AppDb db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                scope: scope,
                remoteId: remoteId,
                thumbUrl: thumbUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> scope = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                scope: scope,
                remoteId: remoteId,
                thumbUrl: thumbUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, PlaylistRow>(table),
                  BaseReferences<_$AppDb, $PlaylistsTable, PlaylistRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PlaylistsTable,
      PlaylistRow,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (PlaylistRow, BaseReferences<_$AppDb, $PlaylistsTable, PlaylistRow>),
      PlaylistRow,
      PrefetchHooks Function()
    >;
typedef $$PlaylistItemsTableCreateCompanionBuilder =
    PlaylistItemsCompanion Function({
      required int playlistId,
      required String videoId,
      required int position,
      required int addedAt,
      Value<int> rowid,
    });
typedef $$PlaylistItemsTableUpdateCompanionBuilder =
    PlaylistItemsCompanion Function({
      Value<int> playlistId,
      Value<String> videoId,
      Value<int> position,
      Value<int> addedAt,
      Value<int> rowid,
    });

class $$PlaylistItemsTableFilterComposer
    extends Composer<_$AppDb, $PlaylistItemsTable> {
  $$PlaylistItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlaylistItemsTableOrderingComposer
    extends Composer<_$AppDb, $PlaylistItemsTable> {
  $$PlaylistItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistItemsTableAnnotationComposer
    extends Composer<_$AppDb, $PlaylistItemsTable> {
  $$PlaylistItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get playlistId => $composableBuilder(
    column: $table.playlistId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$PlaylistItemsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $PlaylistItemsTable,
          PlaylistItemRow,
          $$PlaylistItemsTableFilterComposer,
          $$PlaylistItemsTableOrderingComposer,
          $$PlaylistItemsTableAnnotationComposer,
          $$PlaylistItemsTableCreateCompanionBuilder,
          $$PlaylistItemsTableUpdateCompanionBuilder,
          (
            PlaylistItemRow,
            BaseReferences<_$AppDb, $PlaylistItemsTable, PlaylistItemRow>,
          ),
          PlaylistItemRow,
          PrefetchHooks Function()
        > {
  $$PlaylistItemsTableTableManager(_$AppDb db, $PlaylistItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistItemsCompanion(
                playlistId: playlistId,
                videoId: videoId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int playlistId,
                required String videoId,
                required int position,
                required int addedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistItemsCompanion.insert(
                playlistId: playlistId,
                videoId: videoId,
                position: position,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistItemsTable, PlaylistItemRow>(table),
                  BaseReferences<_$AppDb, $PlaylistItemsTable, PlaylistItemRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlaylistItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $PlaylistItemsTable,
      PlaylistItemRow,
      $$PlaylistItemsTableFilterComposer,
      $$PlaylistItemsTableOrderingComposer,
      $$PlaylistItemsTableAnnotationComposer,
      $$PlaylistItemsTableCreateCompanionBuilder,
      $$PlaylistItemsTableUpdateCompanionBuilder,
      (
        PlaylistItemRow,
        BaseReferences<_$AppDb, $PlaylistItemsTable, PlaylistItemRow>,
      ),
      PlaylistItemRow,
      PrefetchHooks Function()
    >;
typedef $$SavedRemoteTableCreateCompanionBuilder =
    SavedRemoteCompanion Function({
      required String id,
      required String kind,
      required String title,
      Value<String?> thumbUrl,
      required int savedAt,
      Value<int> rowid,
    });
typedef $$SavedRemoteTableUpdateCompanionBuilder =
    SavedRemoteCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> title,
      Value<String?> thumbUrl,
      Value<int> savedAt,
      Value<int> rowid,
    });

class $$SavedRemoteTableFilterComposer
    extends Composer<_$AppDb, $SavedRemoteTable> {
  $$SavedRemoteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedRemoteTableOrderingComposer
    extends Composer<_$AppDb, $SavedRemoteTable> {
  $$SavedRemoteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedRemoteTableAnnotationComposer
    extends Composer<_$AppDb, $SavedRemoteTable> {
  $$SavedRemoteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get thumbUrl =>
      $composableBuilder(column: $table.thumbUrl, builder: (column) => column);

  GeneratedColumn<int> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$SavedRemoteTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SavedRemoteTable,
          SavedRemoteRow,
          $$SavedRemoteTableFilterComposer,
          $$SavedRemoteTableOrderingComposer,
          $$SavedRemoteTableAnnotationComposer,
          $$SavedRemoteTableCreateCompanionBuilder,
          $$SavedRemoteTableUpdateCompanionBuilder,
          (
            SavedRemoteRow,
            BaseReferences<_$AppDb, $SavedRemoteTable, SavedRemoteRow>,
          ),
          SavedRemoteRow,
          PrefetchHooks Function()
        > {
  $$SavedRemoteTableTableManager(_$AppDb db, $SavedRemoteTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedRemoteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedRemoteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedRemoteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                Value<int> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedRemoteCompanion(
                id: id,
                kind: kind,
                title: title,
                thumbUrl: thumbUrl,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String title,
                Value<String?> thumbUrl = const Value.absent(),
                required int savedAt,
                Value<int> rowid = const Value.absent(),
              }) => SavedRemoteCompanion.insert(
                id: id,
                kind: kind,
                title: title,
                thumbUrl: thumbUrl,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SavedRemoteTable, SavedRemoteRow>(table),
                  BaseReferences<_$AppDb, $SavedRemoteTable, SavedRemoteRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedRemoteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SavedRemoteTable,
      SavedRemoteRow,
      $$SavedRemoteTableFilterComposer,
      $$SavedRemoteTableOrderingComposer,
      $$SavedRemoteTableAnnotationComposer,
      $$SavedRemoteTableCreateCompanionBuilder,
      $$SavedRemoteTableUpdateCompanionBuilder,
      (
        SavedRemoteRow,
        BaseReferences<_$AppDb, $SavedRemoteTable, SavedRemoteRow>,
      ),
      SavedRemoteRow,
      PrefetchHooks Function()
    >;
typedef $$SearchHistoryTableCreateCompanionBuilder =
    SearchHistoryCompanion Function({
      required String query,
      Value<String> scope,
      required int at,
      Value<int> rowid,
    });
typedef $$SearchHistoryTableUpdateCompanionBuilder =
    SearchHistoryCompanion Function({
      Value<String> query,
      Value<String> scope,
      Value<int> at,
      Value<int> rowid,
    });

class $$SearchHistoryTableFilterComposer
    extends Composer<_$AppDb, $SearchHistoryTable> {
  $$SearchHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchHistoryTableOrderingComposer
    extends Composer<_$AppDb, $SearchHistoryTable> {
  $$SearchHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchHistoryTableAnnotationComposer
    extends Composer<_$AppDb, $SearchHistoryTable> {
  $$SearchHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$SearchHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SearchHistoryTable,
          SearchHistoryRow,
          $$SearchHistoryTableFilterComposer,
          $$SearchHistoryTableOrderingComposer,
          $$SearchHistoryTableAnnotationComposer,
          $$SearchHistoryTableCreateCompanionBuilder,
          $$SearchHistoryTableUpdateCompanionBuilder,
          (
            SearchHistoryRow,
            BaseReferences<_$AppDb, $SearchHistoryTable, SearchHistoryRow>,
          ),
          SearchHistoryRow,
          PrefetchHooks Function()
        > {
  $$SearchHistoryTableTableManager(_$AppDb db, $SearchHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> query = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryCompanion(
                query: query,
                scope: scope,
                at: at,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String query,
                Value<String> scope = const Value.absent(),
                required int at,
                Value<int> rowid = const Value.absent(),
              }) => SearchHistoryCompanion.insert(
                query: query,
                scope: scope,
                at: at,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SearchHistoryTable, SearchHistoryRow>(table),
                  BaseReferences<
                    _$AppDb,
                    $SearchHistoryTable,
                    SearchHistoryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SearchHistoryTable,
      SearchHistoryRow,
      $$SearchHistoryTableFilterComposer,
      $$SearchHistoryTableOrderingComposer,
      $$SearchHistoryTableAnnotationComposer,
      $$SearchHistoryTableCreateCompanionBuilder,
      $$SearchHistoryTableUpdateCompanionBuilder,
      (
        SearchHistoryRow,
        BaseReferences<_$AppDb, $SearchHistoryTable, SearchHistoryRow>,
      ),
      SearchHistoryRow,
      PrefetchHooks Function()
    >;
typedef $$RydCacheTableCreateCompanionBuilder =
    RydCacheCompanion Function({
      required String videoId,
      required int likes,
      required int dislikes,
      required int fetchedAt,
      Value<int> rowid,
    });
typedef $$RydCacheTableUpdateCompanionBuilder =
    RydCacheCompanion Function({
      Value<String> videoId,
      Value<int> likes,
      Value<int> dislikes,
      Value<int> fetchedAt,
      Value<int> rowid,
    });

class $$RydCacheTableFilterComposer extends Composer<_$AppDb, $RydCacheTable> {
  $$RydCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get likes => $composableBuilder(
    column: $table.likes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dislikes => $composableBuilder(
    column: $table.dislikes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RydCacheTableOrderingComposer
    extends Composer<_$AppDb, $RydCacheTable> {
  $$RydCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get likes => $composableBuilder(
    column: $table.likes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dislikes => $composableBuilder(
    column: $table.dislikes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RydCacheTableAnnotationComposer
    extends Composer<_$AppDb, $RydCacheTable> {
  $$RydCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<int> get likes =>
      $composableBuilder(column: $table.likes, builder: (column) => column);

  GeneratedColumn<int> get dislikes =>
      $composableBuilder(column: $table.dislikes, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$RydCacheTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $RydCacheTable,
          RydCacheRow,
          $$RydCacheTableFilterComposer,
          $$RydCacheTableOrderingComposer,
          $$RydCacheTableAnnotationComposer,
          $$RydCacheTableCreateCompanionBuilder,
          $$RydCacheTableUpdateCompanionBuilder,
          (RydCacheRow, BaseReferences<_$AppDb, $RydCacheTable, RydCacheRow>),
          RydCacheRow,
          PrefetchHooks Function()
        > {
  $$RydCacheTableTableManager(_$AppDb db, $RydCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RydCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RydCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RydCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> videoId = const Value.absent(),
                Value<int> likes = const Value.absent(),
                Value<int> dislikes = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RydCacheCompanion(
                videoId: videoId,
                likes: likes,
                dislikes: dislikes,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String videoId,
                required int likes,
                required int dislikes,
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => RydCacheCompanion.insert(
                videoId: videoId,
                likes: likes,
                dislikes: dislikes,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RydCacheTable, RydCacheRow>(table),
                  BaseReferences<_$AppDb, $RydCacheTable, RydCacheRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RydCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $RydCacheTable,
      RydCacheRow,
      $$RydCacheTableFilterComposer,
      $$RydCacheTableOrderingComposer,
      $$RydCacheTableAnnotationComposer,
      $$RydCacheTableCreateCompanionBuilder,
      $$RydCacheTableUpdateCompanionBuilder,
      (RydCacheRow, BaseReferences<_$AppDb, $RydCacheTable, RydCacheRow>),
      RydCacheRow,
      PrefetchHooks Function()
    >;
typedef $$DownloadsTableCreateCompanionBuilder =
    DownloadsCompanion Function({
      Value<int> id,
      required String videoId,
      required String kind,
      Value<int?> vItag,
      Value<int?> aItag,
      Value<int?> height,
      Value<String?> container,
      Value<String?> path,
      Value<int> total,
      Value<int> done,
      Value<String> status,
      Value<String?> error,
      required int createdAt,
    });
typedef $$DownloadsTableUpdateCompanionBuilder =
    DownloadsCompanion Function({
      Value<int> id,
      Value<String> videoId,
      Value<String> kind,
      Value<int?> vItag,
      Value<int?> aItag,
      Value<int?> height,
      Value<String?> container,
      Value<String?> path,
      Value<int> total,
      Value<int> done,
      Value<String> status,
      Value<String?> error,
      Value<int> createdAt,
    });

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDb, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get vItag => $composableBuilder(
    column: $table.vItag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aItag => $composableBuilder(
    column: $table.aItag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get container => $composableBuilder(
    column: $table.container,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDb, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get vItag => $composableBuilder(
    column: $table.vItag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aItag => $composableBuilder(
    column: $table.aItag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get container => $composableBuilder(
    column: $table.container,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDb, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get vItag =>
      $composableBuilder(column: $table.vItag, builder: (column) => column);

  GeneratedColumn<int> get aItag =>
      $composableBuilder(column: $table.aItag, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get container =>
      $composableBuilder(column: $table.container, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $DownloadsTable,
          DownloadRow,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (DownloadRow, BaseReferences<_$AppDb, $DownloadsTable, DownloadRow>),
          DownloadRow,
          PrefetchHooks Function()
        > {
  $$DownloadsTableTableManager(_$AppDb db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> videoId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> vItag = const Value.absent(),
                Value<int?> aItag = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> container = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> done = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => DownloadsCompanion(
                id: id,
                videoId: videoId,
                kind: kind,
                vItag: vItag,
                aItag: aItag,
                height: height,
                container: container,
                path: path,
                total: total,
                done: done,
                status: status,
                error: error,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String videoId,
                required String kind,
                Value<int?> vItag = const Value.absent(),
                Value<int?> aItag = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<String?> container = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> done = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required int createdAt,
              }) => DownloadsCompanion.insert(
                id: id,
                videoId: videoId,
                kind: kind,
                vItag: vItag,
                aItag: aItag,
                height: height,
                container: container,
                path: path,
                total: total,
                done: done,
                status: status,
                error: error,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DownloadsTable, DownloadRow>(table),
                  BaseReferences<_$AppDb, $DownloadsTable, DownloadRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $DownloadsTable,
      DownloadRow,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (DownloadRow, BaseReferences<_$AppDb, $DownloadsTable, DownloadRow>),
      DownloadRow,
      PrefetchHooks Function()
    >;
typedef $$AudioCacheTableCreateCompanionBuilder =
    AudioCacheCompanion Function({
      required String videoId,
      required int itag,
      required String path,
      required int bytes,
      required int lastPlayedAt,
      Value<int> rowid,
    });
typedef $$AudioCacheTableUpdateCompanionBuilder =
    AudioCacheCompanion Function({
      Value<String> videoId,
      Value<int> itag,
      Value<String> path,
      Value<int> bytes,
      Value<int> lastPlayedAt,
      Value<int> rowid,
    });

class $$AudioCacheTableFilterComposer
    extends Composer<_$AppDb, $AudioCacheTable> {
  $$AudioCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itag => $composableBuilder(
    column: $table.itag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AudioCacheTableOrderingComposer
    extends Composer<_$AppDb, $AudioCacheTable> {
  $$AudioCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itag => $composableBuilder(
    column: $table.itag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AudioCacheTableAnnotationComposer
    extends Composer<_$AppDb, $AudioCacheTable> {
  $$AudioCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<int> get itag =>
      $composableBuilder(column: $table.itag, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );
}

class $$AudioCacheTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $AudioCacheTable,
          AudioCacheRow,
          $$AudioCacheTableFilterComposer,
          $$AudioCacheTableOrderingComposer,
          $$AudioCacheTableAnnotationComposer,
          $$AudioCacheTableCreateCompanionBuilder,
          $$AudioCacheTableUpdateCompanionBuilder,
          (
            AudioCacheRow,
            BaseReferences<_$AppDb, $AudioCacheTable, AudioCacheRow>,
          ),
          AudioCacheRow,
          PrefetchHooks Function()
        > {
  $$AudioCacheTableTableManager(_$AppDb db, $AudioCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AudioCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AudioCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AudioCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> videoId = const Value.absent(),
                Value<int> itag = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<int> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AudioCacheCompanion(
                videoId: videoId,
                itag: itag,
                path: path,
                bytes: bytes,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String videoId,
                required int itag,
                required String path,
                required int bytes,
                required int lastPlayedAt,
                Value<int> rowid = const Value.absent(),
              }) => AudioCacheCompanion.insert(
                videoId: videoId,
                itag: itag,
                path: path,
                bytes: bytes,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AudioCacheTable, AudioCacheRow>(table),
                  BaseReferences<_$AppDb, $AudioCacheTable, AudioCacheRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AudioCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $AudioCacheTable,
      AudioCacheRow,
      $$AudioCacheTableFilterComposer,
      $$AudioCacheTableOrderingComposer,
      $$AudioCacheTableAnnotationComposer,
      $$AudioCacheTableCreateCompanionBuilder,
      $$AudioCacheTableUpdateCompanionBuilder,
      (AudioCacheRow, BaseReferences<_$AppDb, $AudioCacheTable, AudioCacheRow>),
      AudioCacheRow,
      PrefetchHooks Function()
    >;
typedef $$LyricsCacheTableCreateCompanionBuilder =
    LyricsCacheCompanion Function({
      required String videoId,
      required String source,
      required String format,
      required String raw,
      Value<int> offsetMs,
      required int fetchedAt,
      Value<int> rowid,
    });
typedef $$LyricsCacheTableUpdateCompanionBuilder =
    LyricsCacheCompanion Function({
      Value<String> videoId,
      Value<String> source,
      Value<String> format,
      Value<String> raw,
      Value<int> offsetMs,
      Value<int> fetchedAt,
      Value<int> rowid,
    });

class $$LyricsCacheTableFilterComposer
    extends Composer<_$AppDb, $LyricsCacheTable> {
  $$LyricsCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get raw => $composableBuilder(
    column: $table.raw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LyricsCacheTableOrderingComposer
    extends Composer<_$AppDb, $LyricsCacheTable> {
  $$LyricsCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get raw => $composableBuilder(
    column: $table.raw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LyricsCacheTableAnnotationComposer
    extends Composer<_$AppDb, $LyricsCacheTable> {
  $$LyricsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get raw =>
      $composableBuilder(column: $table.raw, builder: (column) => column);

  GeneratedColumn<int> get offsetMs =>
      $composableBuilder(column: $table.offsetMs, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$LyricsCacheTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LyricsCacheTable,
          LyricsCacheRow,
          $$LyricsCacheTableFilterComposer,
          $$LyricsCacheTableOrderingComposer,
          $$LyricsCacheTableAnnotationComposer,
          $$LyricsCacheTableCreateCompanionBuilder,
          $$LyricsCacheTableUpdateCompanionBuilder,
          (
            LyricsCacheRow,
            BaseReferences<_$AppDb, $LyricsCacheTable, LyricsCacheRow>,
          ),
          LyricsCacheRow,
          PrefetchHooks Function()
        > {
  $$LyricsCacheTableTableManager(_$AppDb db, $LyricsCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricsCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricsCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricsCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> videoId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> raw = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LyricsCacheCompanion(
                videoId: videoId,
                source: source,
                format: format,
                raw: raw,
                offsetMs: offsetMs,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String videoId,
                required String source,
                required String format,
                required String raw,
                Value<int> offsetMs = const Value.absent(),
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => LyricsCacheCompanion.insert(
                videoId: videoId,
                source: source,
                format: format,
                raw: raw,
                offsetMs: offsetMs,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LyricsCacheTable, LyricsCacheRow>(table),
                  BaseReferences<_$AppDb, $LyricsCacheTable, LyricsCacheRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LyricsCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LyricsCacheTable,
      LyricsCacheRow,
      $$LyricsCacheTableFilterComposer,
      $$LyricsCacheTableOrderingComposer,
      $$LyricsCacheTableAnnotationComposer,
      $$LyricsCacheTableCreateCompanionBuilder,
      $$LyricsCacheTableUpdateCompanionBuilder,
      (
        LyricsCacheRow,
        BaseReferences<_$AppDb, $LyricsCacheTable, LyricsCacheRow>,
      ),
      LyricsCacheRow,
      PrefetchHooks Function()
    >;
typedef $$SbCacheTableCreateCompanionBuilder =
    SbCacheCompanion Function({
      required String videoId,
      required String json,
      required int fetchedAt,
      Value<int> rowid,
    });
typedef $$SbCacheTableUpdateCompanionBuilder =
    SbCacheCompanion Function({
      Value<String> videoId,
      Value<String> json,
      Value<int> fetchedAt,
      Value<int> rowid,
    });

class $$SbCacheTableFilterComposer extends Composer<_$AppDb, $SbCacheTable> {
  $$SbCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SbCacheTableOrderingComposer extends Composer<_$AppDb, $SbCacheTable> {
  $$SbCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SbCacheTableAnnotationComposer
    extends Composer<_$AppDb, $SbCacheTable> {
  $$SbCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$SbCacheTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $SbCacheTable,
          SbCacheRow,
          $$SbCacheTableFilterComposer,
          $$SbCacheTableOrderingComposer,
          $$SbCacheTableAnnotationComposer,
          $$SbCacheTableCreateCompanionBuilder,
          $$SbCacheTableUpdateCompanionBuilder,
          (SbCacheRow, BaseReferences<_$AppDb, $SbCacheTable, SbCacheRow>),
          SbCacheRow,
          PrefetchHooks Function()
        > {
  $$SbCacheTableTableManager(_$AppDb db, $SbCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SbCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SbCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SbCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> videoId = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SbCacheCompanion(
                videoId: videoId,
                json: json,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String videoId,
                required String json,
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => SbCacheCompanion.insert(
                videoId: videoId,
                json: json,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SbCacheTable, SbCacheRow>(table),
                  BaseReferences<_$AppDb, $SbCacheTable, SbCacheRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SbCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $SbCacheTable,
      SbCacheRow,
      $$SbCacheTableFilterComposer,
      $$SbCacheTableOrderingComposer,
      $$SbCacheTableAnnotationComposer,
      $$SbCacheTableCreateCompanionBuilder,
      $$SbCacheTableUpdateCompanionBuilder,
      (SbCacheRow, BaseReferences<_$AppDb, $SbCacheTable, SbCacheRow>),
      SbCacheRow,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$PrefsTableTableManager get prefs =>
      $$PrefsTableTableManager(_db, _db.prefs);
  $$ProfileTableTableManager get profile =>
      $$ProfileTableTableManager(_db, _db.profile);
  $$SubscriptionsTableTableManager get subscriptions =>
      $$SubscriptionsTableTableManager(_db, _db.subscriptions);
  $$FeedItemsTableTableManager get feedItems =>
      $$FeedItemsTableTableManager(_db, _db.feedItems);
  $$MediaTableTableManager get media =>
      $$MediaTableTableManager(_db, _db.media);
  $$ReactionsTableTableManager get reactions =>
      $$ReactionsTableTableManager(_db, _db.reactions);
  $$HistoryTableTableManager get history =>
      $$HistoryTableTableManager(_db, _db.history);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistItemsTableTableManager get playlistItems =>
      $$PlaylistItemsTableTableManager(_db, _db.playlistItems);
  $$SavedRemoteTableTableManager get savedRemote =>
      $$SavedRemoteTableTableManager(_db, _db.savedRemote);
  $$SearchHistoryTableTableManager get searchHistory =>
      $$SearchHistoryTableTableManager(_db, _db.searchHistory);
  $$RydCacheTableTableManager get rydCache =>
      $$RydCacheTableTableManager(_db, _db.rydCache);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$AudioCacheTableTableManager get audioCache =>
      $$AudioCacheTableTableManager(_db, _db.audioCache);
  $$LyricsCacheTableTableManager get lyricsCache =>
      $$LyricsCacheTableTableManager(_db, _db.lyricsCache);
  $$SbCacheTableTableManager get sbCache =>
      $$SbCacheTableTableManager(_db, _db.sbCache);
}

mixin _$SubscriptionsDaoMixin on DatabaseAccessor<AppDb> {
  $SubscriptionsTable get subscriptions => attachedDatabase.subscriptions;
  SubscriptionsDaoManager get managers => SubscriptionsDaoManager(this);
}

class SubscriptionsDaoManager {
  final _$SubscriptionsDaoMixin _db;
  SubscriptionsDaoManager(this._db);
  $$SubscriptionsTableTableManager get subscriptions =>
      $$SubscriptionsTableTableManager(_db.attachedDatabase, _db.subscriptions);
}

mixin _$FeedItemsDaoMixin on DatabaseAccessor<AppDb> {
  $FeedItemsTable get feedItems => attachedDatabase.feedItems;
  FeedItemsDaoManager get managers => FeedItemsDaoManager(this);
}

class FeedItemsDaoManager {
  final _$FeedItemsDaoMixin _db;
  FeedItemsDaoManager(this._db);
  $$FeedItemsTableTableManager get feedItems =>
      $$FeedItemsTableTableManager(_db.attachedDatabase, _db.feedItems);
}

mixin _$HistoryDaoMixin on DatabaseAccessor<AppDb> {
  $HistoryTable get history => attachedDatabase.history;
  $MediaTable get media => attachedDatabase.media;
  HistoryDaoManager get managers => HistoryDaoManager(this);
}

class HistoryDaoManager {
  final _$HistoryDaoMixin _db;
  HistoryDaoManager(this._db);
  $$HistoryTableTableManager get history =>
      $$HistoryTableTableManager(_db.attachedDatabase, _db.history);
  $$MediaTableTableManager get media =>
      $$MediaTableTableManager(_db.attachedDatabase, _db.media);
}

mixin _$ReactionsDaoMixin on DatabaseAccessor<AppDb> {
  $ReactionsTable get reactions => attachedDatabase.reactions;
  $MediaTable get media => attachedDatabase.media;
  ReactionsDaoManager get managers => ReactionsDaoManager(this);
}

class ReactionsDaoManager {
  final _$ReactionsDaoMixin _db;
  ReactionsDaoManager(this._db);
  $$ReactionsTableTableManager get reactions =>
      $$ReactionsTableTableManager(_db.attachedDatabase, _db.reactions);
  $$MediaTableTableManager get media =>
      $$MediaTableTableManager(_db.attachedDatabase, _db.media);
}

mixin _$PlaylistsDaoMixin on DatabaseAccessor<AppDb> {
  $PlaylistsTable get playlists => attachedDatabase.playlists;
  $PlaylistItemsTable get playlistItems => attachedDatabase.playlistItems;
  $MediaTable get media => attachedDatabase.media;
  PlaylistsDaoManager get managers => PlaylistsDaoManager(this);
}

class PlaylistsDaoManager {
  final _$PlaylistsDaoMixin _db;
  PlaylistsDaoManager(this._db);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db.attachedDatabase, _db.playlists);
  $$PlaylistItemsTableTableManager get playlistItems =>
      $$PlaylistItemsTableTableManager(_db.attachedDatabase, _db.playlistItems);
  $$MediaTableTableManager get media =>
      $$MediaTableTableManager(_db.attachedDatabase, _db.media);
}

mixin _$SavedRemoteDaoMixin on DatabaseAccessor<AppDb> {
  $SavedRemoteTable get savedRemote => attachedDatabase.savedRemote;
  SavedRemoteDaoManager get managers => SavedRemoteDaoManager(this);
}

class SavedRemoteDaoManager {
  final _$SavedRemoteDaoMixin _db;
  SavedRemoteDaoManager(this._db);
  $$SavedRemoteTableTableManager get savedRemote =>
      $$SavedRemoteTableTableManager(_db.attachedDatabase, _db.savedRemote);
}

mixin _$SearchHistoryDaoMixin on DatabaseAccessor<AppDb> {
  $SearchHistoryTable get searchHistory => attachedDatabase.searchHistory;
  SearchHistoryDaoManager get managers => SearchHistoryDaoManager(this);
}

class SearchHistoryDaoManager {
  final _$SearchHistoryDaoMixin _db;
  SearchHistoryDaoManager(this._db);
  $$SearchHistoryTableTableManager get searchHistory =>
      $$SearchHistoryTableTableManager(_db.attachedDatabase, _db.searchHistory);
}

mixin _$RydDaoMixin on DatabaseAccessor<AppDb> {
  $RydCacheTable get rydCache => attachedDatabase.rydCache;
  RydDaoManager get managers => RydDaoManager(this);
}

class RydDaoManager {
  final _$RydDaoMixin _db;
  RydDaoManager(this._db);
  $$RydCacheTableTableManager get rydCache =>
      $$RydCacheTableTableManager(_db.attachedDatabase, _db.rydCache);
}

mixin _$ProfileDaoMixin on DatabaseAccessor<AppDb> {
  $ProfileTable get profile => attachedDatabase.profile;
  ProfileDaoManager get managers => ProfileDaoManager(this);
}

class ProfileDaoManager {
  final _$ProfileDaoMixin _db;
  ProfileDaoManager(this._db);
  $$ProfileTableTableManager get profile =>
      $$ProfileTableTableManager(_db.attachedDatabase, _db.profile);
}
