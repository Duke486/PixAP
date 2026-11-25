import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pixez/models/glance_illust_persist.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'upgrades a widget cache and replaces only the refreshed source',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp(
        'pixap_widget_test_',
      );
      addTearDown(() => directory.delete(recursive: true));

      final old = await openDatabase(
        path.join(directory.path, 'glanceillustpersist.db'),
        version: 2,
        onCreate: (db, _) async {
          await db.execute('''
          CREATE TABLE glanceillustpersist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            illust_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            picture_url TEXT NOT NULL,
            type TEXT NOT NULL,
            title TEXT,
            large_url TEXT,
            original_url TEXT,
            user_name TEXT,
            time INTEGER NOT NULL
          )
        ''');
          await db.insert(tableIllustPersist, artwork(1, 'recom', 1).toJson());
          await db.insert(tableIllustPersist, artwork(2, 'rank', 1).toJson());
        },
      );
      await old.close();

      final provider = TestWidgetCache(directory.path);
      await provider.open();
      addTearDown(provider.close);
      expect(await provider.db.getVersion(), 3);

      await provider.replaceSource('recom', [artwork(1, 'recom', 2)]);
      await provider.saveThumbnails('recom', 2, {
        1: Uint8List.fromList([10]),
      });
      await provider.saveThumbnails('recom', 1, {
        1: Uint8List.fromList([20]),
      });

      final rows = await provider.db.query(tableIllustPersist, orderBy: 'type');
      expect(rows.map((row) => row['illust_id']), [2, 1]);
      expect(rows.first['thumbnail'], isNull);
      expect(rows.last['thumbnail'], [10]);
    },
  );
}

GlanceIllustPersist artwork(int id, String type, int time) =>
    GlanceIllustPersist(
      illustId: id,
      userId: 1,
      pictureUrl: 'https://example.test/$id.jpg',
      originalUrl: null,
      largeUrl: null,
      time: time,
      title: null,
      userName: null,
      type: type,
    );

class TestWidgetCache extends GlanceIllustPersistProvider {
  TestWidgetCache(this.directory);

  final String directory;

  @override
  Future<String> getPath() async => directory;
}
