import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';
import 'package:hivetube/core/yt/channel_avatars.dart';

void main() {
  test('persists and reloads channel avatars from prefs', () async {
    final db = AppDb(NativeDatabase.memory());
    final first = ChannelAvatarCache(read: db.getValue, write: db.setValue);
    await first.put('UCtest', 'https://yt3.ggpht.com/avatar');
    final second = ChannelAvatarCache(read: db.getValue, write: db.setValue);
    await second.load();
    expect(second.get('UCtest'), 'https://yt3.ggpht.com/avatar');
    await db.close();
  });

  test('deduplicates concurrent avatar backfills', () async {
    final coordinator = AvatarBackfillCoordinator();
    var calls = 0;
    Future<String> fetch() async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return 'https://yt3.ggpht.com/avatar';
    }

    final values = await Future.wait([
      coordinator.resolve('UCtest', fetch),
      coordinator.resolve('UCtest', fetch),
    ]);
    expect(calls, 1);
    expect(values.toSet(), {'https://yt3.ggpht.com/avatar'});
  });
}
