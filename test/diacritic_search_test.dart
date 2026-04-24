import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/features/settings/settings_provider.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Diacritic-Insensitive Search Tests (DB v34)', () {
    late DatabaseHelper dbHelper;
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      await db.execute('''
        CREATE TABLE dictionaries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          path TEXT,
          is_enabled INTEGER DEFAULT 1,
          display_order INTEGER DEFAULT 0,
          word_count INTEGER DEFAULT 0,
          definition_word_count INTEGER DEFAULT 0,
          index_definitions INTEGER DEFAULT 0,
          format TEXT,
          type_sequence TEXT,
          css TEXT,
          checksum TEXT,
          source_url TEXT,
          source_type TEXT DEFAULT 'managed',
          source_bookmark TEXT,
          companion_uri TEXT,
          mdd_path TEXT
        )''');

      // Create word_metadata WITH word_normalized column
      await db.execute('''
        CREATE TABLE word_metadata(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT COLLATE NOCASE,
          word_normalized TEXT,
          dict_id INTEGER,
          offset INTEGER,
          length INTEGER
        )''');
      await db.execute(
        'CREATE INDEX idx_metadata_dict_id ON word_metadata(dict_id)',
      );
      await db.execute(
        'CREATE INDEX idx_word_normalized ON word_metadata(word_normalized)',
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

      DatabaseHelper.setDatabase(db);
      dbHelper = DatabaseHelper();
    });

    tearDown(() async {
      await db.close();
    });

    test('Search with diacritics finds normalized matches', () async {
      int dictId = await dbHelper.insertDictionary('French Dict', '/path');

      // Insert words with diacritics
      List<Map<String, dynamic>> words = [
        {'word': 'café', 'offset': 0, 'length': 100, 'content': 'coffee'},
        {
          'word': 'cafetière',
          'offset': 100,
          'length': 100,
          'content': 'coffee pot',
        },
        {'word': 'école', 'offset': 200, 'length': 100, 'content': 'school'},
        {'word': 'naïve', 'offset': 300, 'length': 100, 'content': 'innocent'},
      ];
      await dbHelper.batchInsertWords(dictId, words);

      // Search without diacritics - should find café
      var results = await dbHelper.searchWords(
        headwordQuery: 'cafe',
        headwordMode: SearchMode.prefix,
        ignoreDiacritics: true,
      );
      expect(
        results.any((r) => r['word'] == 'café'),
        isTrue,
        reason: 'Search "cafe" should find "café"',
      );

      // Search without diacritics - should find cafetière
      results = await dbHelper.searchWords(
        headwordQuery: 'cafetiere',
        headwordMode: SearchMode.prefix,
        ignoreDiacritics: true,
      );
      expect(
        results.any((r) => r['word'] == 'cafetière'),
        isTrue,
        reason: 'Search "cafetiere" should find "cafetière"',
      );

      // Search without diacritics - should find école
      results = await dbHelper.searchWords(
        headwordQuery: 'ecole',
        headwordMode: SearchMode.prefix,
        ignoreDiacritics: true,
      );
      expect(
        results.any((r) => r['word'] == 'école'),
        isTrue,
        reason: 'Search "ecole" should find "école"',
      );

      // Search without diacritics - should find naïve
      results = await dbHelper.searchWords(
        headwordQuery: 'naive',
        headwordMode: SearchMode.prefix,
        ignoreDiacritics: true,
      );
      expect(
        results.any((r) => r['word'] == 'naïve'),
        isTrue,
        reason: 'Search "naive" should find "naïve"',
      );
    });

    test('Search with diacritics disabled behaves normally', () async {
      int dictId = await dbHelper.insertDictionary('French Dict', '/path');

      List<Map<String, dynamic>> words = [
        {'word': 'café', 'offset': 0, 'length': 100, 'content': 'coffee'},
      ];
      await dbHelper.batchInsertWords(dictId, words);

      // Search with diacritics disabled - exact match needed
      var results = await dbHelper.searchWords(
        headwordQuery: 'café',
        headwordMode: SearchMode.exact,
        ignoreDiacritics: false,
      );
      expect(results.length, 1);
      expect(results.first['word'], 'café');

      // Search with diacritics disabled - partial won't match
      results = await dbHelper.searchWords(
        headwordQuery: 'cafe',
        headwordMode: SearchMode.prefix,
        ignoreDiacritics: false,
      );
      expect(
        results.length,
        0,
        reason: 'Without diacritic option, "cafe" should not find "café"',
      );
    });
  });
}
