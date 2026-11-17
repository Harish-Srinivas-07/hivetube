import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hivetube/core/db/app_db.dart';

void main() {
  test('v4 downloads survive upgrade with safe resume defaults', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('DROP TABLE downloads');
    await db.customStatement('''CREATE TABLE downloads (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, video_id TEXT NOT NULL,
      kind TEXT NOT NULL, v_itag INTEGER, a_itag INTEGER, height INTEGER,
      container TEXT, path TEXT, total INTEGER NOT NULL DEFAULT 0,
      done INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'pending',
      error TEXT, created_at INTEGER NOT NULL)''');
    await db.customStatement(
      "INSERT INTO downloads (video_id, kind, status, created_at) VALUES ('video', 'video', 'completed', 1)",
    );
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    await db.migration.onUpgrade(db.createMigrator(), 4, 5);
    final row = await db.select(db.downloads).getSingle();
    expect(row.videoId, 'video');
    expect(row.status, 'completed');
    expect(row.videoDone, 0);
    expect(row.audioDone, 0);
    expect(row.videoEtag, isNull);
    expect(row.audioEtag, isNull);
  });
}
