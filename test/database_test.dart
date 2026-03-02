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
          type_sequence TEXT
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
  });
}
