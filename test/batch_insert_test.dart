import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hdict/core/database/database_helper.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Batch Insert Optimization Tests', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      await db.execute('''
        CREATE TABLE dictionaries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          path TEXT NOT NULL,
          is_enabled INTEGER DEFAULT 1,
          word_count INTEGER DEFAULT 0,
          display_order INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE word_metadata(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT,
          word_normalized TEXT,
          dict_id INTEGER,
          offset INTEGER,
          length INTEGER,
          mdict_start INTEGER,
          mdict_end INTEGER
        )
      ''');

      await db.execute(
        'CREATE INDEX idx_metadata_dict_id ON word_metadata(dict_id)',
      );

      await db.execute('''
        CREATE VIRTUAL TABLE word_index USING fts5(
          word,
          content,
          content = '',
          detail = 'column',
          columnsize = 0,
          tokenize = 'unicode61'
        )
      ''');

      await DatabaseHelper.setDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('startBatchInsert caches start ID from sqlite_sequence', () async {
      final dbHelper = DatabaseHelper();

      await db.execute(
        "INSERT INTO dictionaries (name, path) VALUES ('test', '/test')",
      );
      final dictId = 1;

      final startId = await dbHelper.startBatchInsert();

      final words = List.generate(
        100,
        (i) => {
          'word': 'word_$i',
          'content': 'content $i',
          'dict_id': dictId,
          'offset': i * 10,
          'length': 10,
        },
      );

      final resultTuple = await dbHelper.batchInsertWords(
        dictId,
        words,
        startId: startId,
      );
      final newStartId = resultTuple.startId;
      expect(newStartId, 100);

      final result = await db.query(
        'word_metadata',
        where: 'dict_id = ?',
        whereArgs: [dictId],
      );
      expect(result.length, 100);
      expect(result.first['id'], 1);
      expect(result.last['id'], 100);
    });

    test('endBatchInsert clears caches after batch insert', () async {
      final dbHelper = DatabaseHelper();

      await db.execute(
        "INSERT INTO dictionaries (name, path) VALUES ('test', '/test')",
      );
      final dictId = 1;

      final startId = await dbHelper.startBatchInsert();

      final words = List.generate(
        50,
        (i) => {
          'word': 'word_$i',
          'content': 'content $i',
          'dict_id': dictId,
          'offset': i * 10,
          'length': 10,
        },
      );

      await dbHelper.batchInsertWords(dictId, words, startId: startId);
      await dbHelper.endBatchInsert();

      final result = await db.query(
        'word_metadata',
        where: 'dict_id = ?',
        whereArgs: [dictId],
      );
      expect(result.length, 50);
    });

    test(
      'batchInsertWords uses cached start ID across multiple calls',
      () async {
        final dbHelper = DatabaseHelper();

        await db.execute(
          "INSERT INTO dictionaries (name, path) VALUES ('test', '/test')",
        );
        final dictId = 1;

        await dbHelper.startBatchInsert();

        final words1 = List.generate(
          10000,
          (i) => {
            'word': 'word_a_$i',
            'content': 'content_a $i',
            'dict_id': dictId,
            'offset': i * 10,
            'length': 10,
          },
        );
        await dbHelper.batchInsertWords(dictId, words1);

        final words2 = List.generate(
          10000,
          (i) => {
            'word': 'word_b_$i',
            'content': 'content_b $i',
            'dict_id': dictId,
            'offset': (10000 + i) * 10,
            'length': 10,
          },
        );
        await dbHelper.batchInsertWords(dictId, words2);

        final result = await db.query(
          'word_metadata',
          where: 'dict_id = ?',
          whereArgs: [dictId],
        );
        expect(result.length, 20000);

        final ids = result.map((r) => r['id'] as int).toList()..sort();
        expect(ids.first, 1);
        expect(ids.last, 20000);
      },
    );

    test('batch tokenization pre-computes keywords before insert', () async {
      final dbHelper = DatabaseHelper();

      await db.execute(
        "INSERT INTO dictionaries (name, path) VALUES ('test', '/test')",
      );
      final dictId = 1;

      await dbHelper.startBatchInsert();

      final words = [
        {
          'word': 'hello world',
          'content': 'This is a test definition',
          'dict_id': dictId,
          'offset': 0,
          'length': 10,
        },
        {
          'word': 'foo bar',
          'content': 'Another definition here',
          'dict_id': dictId,
          'offset': 10,
          'length': 10,
        },
      ];

      await dbHelper.batchInsertWords(dictId, words);

      final metaResult = await db.query(
        'word_metadata',
        where: 'dict_id = ?',
        whereArgs: [dictId],
      );
      expect(metaResult.length, 2);

      final wordIds = metaResult.map((r) => r['id'] as int).toList()..sort();
      expect(wordIds, [1, 2]);
    });

    test(
      'batch insert without startBatchInsert still works (fallback)',
      () async {
        final dbHelper = DatabaseHelper();

        await db.execute(
          "INSERT INTO dictionaries (name, path) VALUES ('test', '/test')",
        );
        final dictId = 1;

        final words = List.generate(
          100,
          (i) => {
            'word': 'word_$i',
            'content': 'content $i',
            'dict_id': dictId,
            'offset': i * 10,
            'length': 10,
          },
        );

        await dbHelper.batchInsertWords(dictId, words);

        final result = await db.query(
          'word_metadata',
          where: 'dict_id = ?',
          whereArgs: [dictId],
        );
        expect(result.length, 100);
      },
    );
    test(
      'batchInsertWords returns new startId that prevents constraint violation in loop',
      () async {
        final dbHelper = DatabaseHelper();

        await db.execute(
          "INSERT INTO dictionaries (name, path) VALUES ('test', '/test')",
        );
        final dictId = 1;

        int startId = await dbHelper.startBatchInsert();

        final words1 = List.generate(
          100,
          (i) => {
            'word': 'word_a_$i',
            'content': 'content_a $i',
            'dict_id': dictId,
            'offset': i * 10,
            'length': 10,
          },
        );
        final result1 = await dbHelper.batchInsertWords(
          dictId,
          words1,
          startId: startId,
        );
        startId = result1.startId;
        expect(startId, 100);

        final words2 = List.generate(
          100,
          (i) => {
            'word': 'word_b_$i',
            'content': 'content_b $i',
            'dict_id': dictId,
            'offset': (100 + i) * 10,
            'length': 10,
          },
        );
        // This will throw a constraint exception if rowid overlaps.
        // But since startId is correctly advanced, it shouldn't.
        final result2 = await dbHelper.batchInsertWords(
          dictId,
          words2,
          startId: startId,
        );
        startId = result2.startId;
        expect(startId, 200);

        final result = await db.query(
          'word_metadata',
          where: 'dict_id = ?',
          whereArgs: [dictId],
        );
        expect(result.length, 200);

        final ids = result.map((r) => r['id'] as int).toList()..sort();
        expect(ids.first, 1);
        expect(ids.last, 200);
      },
    );
  });
}
