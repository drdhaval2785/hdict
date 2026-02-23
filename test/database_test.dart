import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hdict/core/database/database_helper.dart';

void main() {
  // Initialize FFI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseHelper Tests', () {
    late DatabaseHelper dbHelper;
    late Database db;

    setUp(() async {
      // Create an in-memory database
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // Initialize the schema manually for the test DB since _initDatabase is private and uses path_provider
      // Or we can expose _onCreate.
      // Let's copy the schema creation logic here for the test to ensure environment isolation
      // OR better, since we can't easily access private _onCreate, we should just replicate the schema here
      // which also tests that the schema SQL is valid.

      await db.execute('''
        CREATE TABLE dictionaries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          path TEXT NOT NULL,
          is_enabled INTEGER DEFAULT 1,
          index_definitions INTEGER DEFAULT 0,
          word_count INTEGER DEFAULT 0,
          display_order INTEGER DEFAULT 0
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

      // make sure a dictionary row exists for search queries
      await dbHelper.insertDictionary('Test Dict', '/path/to/dict');
    });

    tearDown(() async {
      await db.close();
    });

    test('Insert and Retrieve Dictionary', () async {
      int id = await dbHelper.insertDictionary('Another Dict', '/path/other');
      expect(id, greaterThan(0));

      List<Map<String, dynamic>> dicts = await dbHelper.getDictionaries();
      expect(dicts.length, 2); // one from setUp plus new one
      expect(dicts.last['name'], 'Another Dict');
      expect(dicts.last['word_count'], 0);
    });

    test('Search Words (Exact vs Wildcard)', () async {
      int dictId = 1;
      List<Map<String, dynamic>> words = [
        {'word': 'apple', 'offset': 100, 'length': 50},
        {'word': 'application', 'offset': 200, 'length': 60},
        {'word': 'banana', 'offset': 300, 'length': 40},
      ];

      await dbHelper.batchInsertWords(dictId, words);

      // Search for 'apple' (Exact match)
      List<Map<String, dynamic>> results = await dbHelper.searchWords('apple');
      expect(results.length, 1);
      expect(results.first['word'], 'apple');

      // Search for 'app' (Exact match, should be empty now)
      results = await dbHelper.searchWords('app');
      expect(results.length, 0);

      // Search for 'app*' (Wildcard)
      results = await dbHelper.searchWords('app*');
      expect(results.length, 2);
      expect(results.any((r) => r['word'] == 'apple'), isTrue);
      expect(results.any((r) => r['word'] == 'application'), isTrue);

      // Search for 'a?ple' (Wildcard)
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
      expect(results.any((r) => r['word'] == 'apple'), isTrue);
      expect(results.any((r) => r['word'] == 'banana'), isTrue);

      // Search for 'red' (only in apple)
      results = await dbHelper.searchWords('red', searchDefinitions: true);
      expect(results.length, 1);
      expect(results.first['word'], 'apple');

      // Search for 'orange' (none)
      results = await dbHelper.searchWords('orange', searchDefinitions: true);
      expect(results.isEmpty, isTrue);
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

      // Fuzzy search "ple" should find "apple" via LIKE
      List<Map<String, dynamic>> results = await dbHelper.searchWords(
        'ple',
        fuzzy: true,
      );
      expect(results.any((r) => r['word'] == 'apple'), isTrue);

      // Fuzzy suggestions for "nan" should find "banana"
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
      expect(history.any((h) => h['word'] == 'apple'), isTrue);

      await dbHelper.clearSearchHistory();
      history = await dbHelper.getSearchHistory();
      expect(history.isEmpty, isTrue);
    });

    test('Flash Card Score Management', () async {
      await dbHelper.addFlashCardScore(8, 10);
      await dbHelper.addFlashCardScore(10, 10);

      List<Map<String, dynamic>> scores = await dbHelper.getFlashCardScores();
      expect(scores.length, 2);
      expect(scores.any((s) => s['score'] == 8), isTrue);
      expect(scores.any((s) => s['score'] == 10), isTrue);
    });
  });
}
