import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/features/settings/settings_provider.dart';

void main() {
  // Initialize FFI for unit tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper Tests', () {
    late DatabaseHelper dbHelper;
    late Database db;

    setUp(() async {
      // Create an in-memory database
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // Re-create schema for in-memory DB
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
          definition_word_count INTEGER DEFAULT 0,
          checksum TEXT,
          source_url TEXT,
          source_type TEXT DEFAULT 'managed',
          source_bookmark TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE word_metadata(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT,
          dict_id INTEGER,
          offset INTEGER,
          length INTEGER
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

      await db.execute('''
        CREATE TABLE search_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          search_type TEXT DEFAULT 'Headword Search'
        )
      ''');

      await db.execute('''
        CREATE TABLE flash_card_scores (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          score INTEGER NOT NULL,
          total INTEGER NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');

      // Inject the test database
      DatabaseHelper.setDatabase(db);
      dbHelper = DatabaseHelper();

      // Ensure at least one enabled dictionary exists for enabled filter tests
      await dbHelper.insertDictionary('Test Dict', '/path/to/dict');
    });

    tearDown(() async {
      await db.close();
    });

    test('Insert and Retrieve Dictionary', () async {
      int id = await dbHelper.insertDictionary('Another Dict', '/path/other');
      expect(id, greaterThan(0));

      List<Map<String, dynamic>> dicts = await dbHelper.getDictionaries();
      expect(dicts.length, 2);
      expect(dicts.last['name'], 'Another Dict');
    });

    test('Search Words (Advanced Modes)', () async {
      int dictId = 1;
      List<Map<String, dynamic>> words = [
        {'word': 'apple', 'offset': 100, 'length': 50},
        {'word': 'application', 'offset': 200, 'length': 60},
        {'word': 'banana', 'offset': 300, 'length': 40},
      ];

      await dbHelper.batchInsertWords(dictId, words);

      // 1. Exact match 'apple'
      List<Map<String, dynamic>> results = await dbHelper.searchWords(
        headwordQuery: 'apple',
        headwordMode: SearchMode.exact,
      );
      expect(results.length, 1);
      expect(results.first['word'], 'apple');

      // 2. Prefix 'app'
      results = await dbHelper.searchWords(
        headwordQuery: 'app',
        headwordMode: SearchMode.prefix,
      );
      expect(results.length, 2);

      // 3. Suffix 'nana'
      results = await dbHelper.searchWords(
        headwordQuery: 'nana',
        headwordMode: SearchMode.suffix,
      );
      expect(results.length, 1);
      expect(results.first['word'], 'banana');

      // 4. Substring 'at'
      results = await dbHelper.searchWords(
        headwordQuery: 'at',
        headwordMode: SearchMode.substring,
      );
      expect(results.length, 1);
      expect(results.first['word'], 'application');
    });

    test('Search within Definitions', () async {
      int dictId = 1;
      List<Map<String, dynamic>> words = [
        {
          'word': 'apple',
          'content': 'A red fruit that grows on trees.',
          'offset': 100,
          'length': 50,
        },
        {
          'word': 'banana',
          'content': 'A long yellow fruit.',
          'offset': 300,
          'length': 40,
        },
      ];
      await dbHelper.batchInsertWords(dictId, words);

      // Search for 'fruit' in definition
      List<Map<String, dynamic>> results = await dbHelper.searchWords(
        definitionQuery: 'fruit',
        definitionMode: SearchMode.substring,
      );
      expect(results.length, 2);

      // Search for partial 'frui' utilizing LIKE exact subset match
      results = await dbHelper.searchWords(
        definitionQuery: 'frui',
        definitionMode: SearchMode.substring,
      );
      expect(results.length, 2);

      // Search for 'red' (only in apple content)
      results = await dbHelper.searchWords(
        definitionQuery: 'red',
        definitionMode: SearchMode.exact, // MATCH "red"
      );
      expect(results.length, 1);
      expect(results.first['word'], 'apple');
    });

    test('Autocomplete Prefix Suggestions', () async {
      int dictId = 1;
      List<Map<String, dynamic>> words = [
        {'word': 'apple', 'offset': 100, 'length': 50},
        {'word': 'application', 'offset': 200, 'length': 60},
        {'word': 'banana', 'offset': 300, 'length': 40},
      ];
      await dbHelper.batchInsertWords(dictId, words);

      List<String> suggestions = await dbHelper.getPrefixSuggestions('app');
      expect(suggestions.length, 2);
      expect(suggestions, contains('apple'));
      expect(suggestions, contains('application'));
    });

    test('Fuzzy Search and Suggestions', () async {
      int dictId = 1;
      List<Map<String, dynamic>> words = [
        {'word': 'apple', 'offset': 100, 'length': 50},
        {'word': 'banana', 'offset': 300, 'length': 40},
      ];
      await dbHelper.batchInsertWords(dictId, words);

      // Fuzzy search "ple" should find "apple" via LIKE '%ple%'
      List<Map<String, dynamic>> results = await dbHelper.searchWords(
        headwordQuery: 'ple',
        headwordMode: SearchMode.substring,
      );
      expect(results.any((r) => r['word'] == 'apple'), isTrue);

      // Fuzzy suggestions for "nan" should find "banana" via LIKE '%nan%'
      List<String> suggestions = await dbHelper.getPrefixSuggestions(
        'nan',
        fuzzy: true,
      );
      expect(suggestions, contains('banana'));
    });

    test('Search History Management', () async {
      await dbHelper.addSearchHistory('apple');
      await Future.delayed(const Duration(milliseconds: 10));
      await dbHelper.addSearchHistory('banana');

      List<Map<String, dynamic>> history = await dbHelper.getSearchHistory();
      expect(history.length, 2);
      expect(history.first['word'], 'banana'); // Most recent first

      await dbHelper.clearSearchHistory();
      history = await dbHelper.getSearchHistory();
      expect(history.isEmpty, isTrue);
    });

    test('Dictionary display_order is respected in search results', () async {
      // Setup: Two dictionaries. dict_2 has a LOWER display_order (higher priority).
      // Even though dict_1 was inserted first (lower auto-id), dict_2 should appear first.
      final int dict1Id = await dbHelper.insertDictionary('Dict Alpha', '/path/alpha');
      final int dict2Id = await dbHelper.insertDictionary('Dict Zeta', '/path/zeta');

      // Set display_order: dict2 = 0 (first), dict1 = 1 (second)
      await dbHelper.reorderDictionaries([dict2Id, dict1Id]);

      // Insert the same word in both dictionaries
      await dbHelper.batchInsertWords(dict1Id, [
        {'word': 'test', 'offset': 0, 'length': 10},
      ]);
      await dbHelper.batchInsertWords(dict2Id, [
        {'word': 'test', 'offset': 100, 'length': 10},
      ]);

      // Search for the word
      final results = await dbHelper.searchWords(
        headwordQuery: 'test',
        headwordMode: SearchMode.exact,
      );

      // Verify that results are returned in display_order:
      // dict2 (display_order=0) should come before dict1 (display_order=1)
      expect(results.length, 2);
      expect(results[0]['dict_id'], dict2Id,
          reason: 'dict2 has higher priority (lower display_order) so it should appear first');
      expect(results[1]['dict_id'], dict1Id,
          reason: 'dict1 has lower priority (higher display_order) so it should appear second');
    });

    test('Reordering dictionaries updates display_order correctly', () async {
      final int id1 = await dbHelper.insertDictionary('Dict A', '/path/a');
      final int id2 = await dbHelper.insertDictionary('Dict B', '/path/b');
      final int id3 = await dbHelper.insertDictionary('Dict C', '/path/c');

      // Reorder: C first, A second, B third
      await dbHelper.reorderDictionaries([id3, id1, id2]);

      final dicts = await dbHelper.getDictionaries();
      // Filter to just our three (setUp also inserts one dict)
      final our3 = dicts.where((d) => [id1, id2, id3].contains(d['id'])).toList();
      expect(our3.length, 3);

      // getDictionaries returns in display_order ASC, so order should be C, A, B
      expect(our3[0]['id'], id3, reason: 'Dict C should be first (display_order=0)');
      expect(our3[1]['id'], id1, reason: 'Dict A should be second (display_order=1)');
      expect(our3[2]['id'], id2, reason: 'Dict B should be third (display_order=2)');
    });
  });
}
