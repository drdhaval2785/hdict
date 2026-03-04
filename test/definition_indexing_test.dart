import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/manager/dictionary_manager.dart';
import 'package:dictd_reader/dictd_reader.dart';
import 'package:hdict/core/parser/ifo_parser.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const MethodChannel('plugins.flutter.io/path_provider')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return '.';
    }
    return null;
  });

  group('Definition Indexing Tests', () {
    late Directory tempDir;
    late DatabaseHelper dbHelper;
    late DictionaryManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hdict_indexing_test_');
      dbHelper = DatabaseHelper();
      final db = await openDatabase(inMemoryDatabasePath, version: 13,
          onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE dictionaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            path TEXT NOT NULL,
            is_enabled INTEGER DEFAULT 1,
            index_definitions INTEGER DEFAULT 0,
            word_count INTEGER DEFAULT 0,
            display_order INTEGER DEFAULT 0,
            start_rowid INTEGER,
            end_rowid INTEGER,
            format TEXT DEFAULT 'stardict',
            type_sequence TEXT,
            css TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE word_index (
            word TEXT,
            content TEXT,
            dict_id INTEGER,
            offset INTEGER,
            length INTEGER
          )
        ''');
      });
      DatabaseHelper.setDatabase(db);
      manager = DictionaryManager(dbHelper: dbHelper);
    });

    tearDown(() async {
      await (await dbHelper.database).close();
      await tempDir.delete(recursive: true);
    });

    test('Word counting logic works correctly for all formats', () {
      // This is the core logic used in all _indexXXXEntry functions
      String content = "hello world  \n  this is a test  ";
      int count = content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      expect(count, 6);

      String devanagari = "शतपत्त्र कमल";
      int devCount = devanagari.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      expect(devCount, 2);
    });

    test('DICTD indexing logic (direct call)', () async {
      final indexPath = p.join(tempDir.path, 'test.index');
      final dictPath = p.join(tempDir.path, 'test.dict');
      await File(indexPath).writeAsString('hello\tA\tL\ntest\tL\tS\n');
      await File(dictPath).writeAsString('hello worlddefinition of test');

      final reader = DictdReader(dictPath);
      await reader.open();
      final parser = DictdParser();
      final entries = await parser.parseIndex(indexPath).toList();
      
      int headwordCount = 0;
      int defWordCount = 0;
      for (final entry in entries) {
        headwordCount++;
        final content = await reader.readAtOffset(entry['offset'] as int, entry['length'] as int);
        defWordCount += content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      }
      expect(headwordCount, 2);
      expect(defWordCount, 5);
      await reader.close();
    });

    test('StarDict parsing logic (direct call)', () async {
      final ifo = IfoParser();
      final content = "version=2.4.2\nwordcount=2\nbookname=Test\nidxoffsetbits=32\n";
      ifo.parseContent(content);
      expect(ifo.bookName, 'Test');
      expect(ifo.wordCount, 2);
    });
  });
}
