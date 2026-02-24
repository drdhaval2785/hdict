import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hdict/core/database/database_helper.dart';

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
          end_rowid INTEGER
        )
      ''');

      await db.execute('''
        CREATE VIRTUAL TABLE word_index USING fts5(
          word,
          content,
          dict_id UNINDEXED,
          offset UNINDEXED,
          length UNINDEXED,
          tokenize = 'unicode61'
        )
      ''');

      await db.execute('''
        CREATE TABLE search_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT NOT NULL,
          timestamp INTEGER NOT NULL
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

    test('Search Words (Exact vs Wildcard)', () async {
      int dictId = 1;
      List<Map<String, dynamic>> words = [
        {'word': 'apple', 'offset': 100, 'length': 50},
        {'word': 'application', 'offset': 200, 'length': 60},
        {'word': 'banana', 'offset': 300, 'length': 40},
      ];

      await dbHelper.batchInsertWords(dictId, words);

      // 1. Exact match 'apple'
      List<Map<String, dynamic>> results = await dbHelper.searchWords('apple');
      expect(results.length, 1);
      expect(results.first['word'], 'apple');

      // 2. Search for 'app'
      // Production code now has a prefix fallback logic. 
      // It tries exact match (0 found), then falls back to prefix matches.
      results = await dbHelper.searchWords('app');
      expect(results.length, 2); // 'apple' and 'application'
      expect(results.any((r) => r['word'] == 'apple'), isTrue);

      // 3. Explicit wildcard 'app*'
      results = await dbHelper.searchWords('app*');
      expect(results.length, 2);

      // 4. Wildcard 'a?ple'
      results = await dbHelper.searchWords('a?ple');
      expect(results.length, 1);
      expect(results.first['word'], 'apple');
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

      // Search for 'fruit' with searchDefinitions: true
      List<Map<String, dynamic>> results = await dbHelper.searchWords(
        'fruit',
        searchDefinitions: true,
      );
      expect(results.length, 2);

      // Search for 'red' (only in apple content)
      results = await dbHelper.searchWords('red', searchDefinitions: true);
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
        'ple',
        fuzzy: true,
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
      await dbHelper.addSearchHistory('banana');

      List<Map<String, dynamic>> history = await dbHelper.getSearchHistory();
      expect(history.length, 2);
      expect(history.first['word'], 'banana'); // Most recent first

      await dbHelper.clearSearchHistory();
      history = await dbHelper.getSearchHistory();
      expect(history.isEmpty, isTrue);
    });
  });
}
