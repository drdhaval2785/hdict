import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:dictd_reader/dictd_reader.dart';
import 'package:hdict/core/parser/ifo_parser.dart';
import 'package:hdict/core/parser/idx_parser.dart';
import 'package:hdict/core/parser/dict_reader.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return '.';
    }
    return null;
  });

  group('Definition Indexing Tests', () {
    late Directory tempDir;
    late DatabaseHelper dbHelper;

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
            css TEXT,
            definition_word_count INTEGER DEFAULT 0
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

    test('StarDict indexing logic (direct call)', () async {
      final ifoPath = p.join(tempDir.path, 'test.ifo');
      final idxPath = p.join(tempDir.path, 'test.idx');
      final dictPath = p.join(tempDir.path, 'test.dict');

      await File(ifoPath).writeAsString("StarDict's dict ifo file\nversion=2.4.2\nwordcount=2\nidxfilesize=100\nbookname=Test\nidxoffsetbits=32\n");
      await File(dictPath).writeAsString('hello worlddefinition of test');

      final bytes = BytesBuilder();
      bytes.add('hello'.codeUnits); bytes.addByte(0);
      bytes.add([0, 0, 0, 0]); bytes.add([0, 0, 0, 11]);
      bytes.add('test'.codeUnits); bytes.addByte(0);
      bytes.add([0, 0, 0, 11]); bytes.add([0, 0, 0, 18]);
      await File(idxPath).writeAsBytes(bytes.toBytes());

      final ifo = IfoParser();
      await ifo.parse(ifoPath);
      final reader = DictReader(dictPath);
      final idx = IdxParser(ifo);
      final entries = await idx.parse(idxPath).toList();

      int headwordCount = 0;
      int defWordCount = 0;
      for (final entry in entries) {
        headwordCount++;
        final content = await reader.readEntry(entry['offset'] as int, entry['length'] as int);
        defWordCount += content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      }

      expect(headwordCount, 2);
      expect(defWordCount, 5);
      expect(ifo.bookName, 'Test');
    });

    test('updateDictionaryWordCount saves both counts correctly', () async {
      final dictId = await dbHelper.insertDictionary('Test Dict', 'test/path');
      await dbHelper.updateDictionaryWordCount(dictId, 100, 500);

      final dicts = await dbHelper.getDictionaries();
      final dict = dicts.firstWhere((d) => d['id'] == dictId);

      expect(dict['word_count'], 100);
      expect(dict['definition_word_count'], 500);
    });
  });
}
