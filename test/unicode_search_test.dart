import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/features/settings/settings_provider.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Language-Agnostic Search Tests (DB v20)', () {
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
      await db.execute('''
        CREATE TABLE word_metadata(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT,
          dict_id INTEGER,
          offset INTEGER,
          length INTEGER
        )''');
      await db.execute(
        'CREATE INDEX idx_metadata_dict_id ON word_metadata(dict_id)',
      );
      await db.execute('CREATE INDEX idx_metadata_word ON word_metadata(word)');
      await db.execute(
        "CREATE VIRTUAL TABLE word_index USING fts5(word, content, content='', tokenize='unicode61')",
      );

      DatabaseHelper.setDatabase(db);
      dbHelper = DatabaseHelper();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Gujarati and English multi-word searches execute correctly without phrase errors',
      () async {
        int dictId = await dbHelper.insertDictionary('Test Dict', '/path');

        List<Map<String, dynamic>> words = [
          {
            'word': 'સફરજન',
            'offset': 0,
            'length': 100,
            'content': 'એક મીઠું ફળ (apple)',
          },
          {
            'word': 'multi word',
            'offset': 100,
            'length': 100,
            'content': 'meaning of a multi word phrase',
          },
          {
            'word': 'prefix test',
            'offset': 200,
            'length': 100,
            'content': 'testing prefix searches via FTS5 and LIKE',
          },
        ];
        await dbHelper.batchInsertWords(dictId, words);

        // 1. Headword Exact Match (Gujarati)
        var results = await dbHelper.searchWords(
          headwordQuery: 'સફરજન',
          headwordMode: SearchMode.exact,
        );
        expect(
          results.length,
          1,
          reason: 'Gujarati exact headword search failed',
        );

        // 2. Headword Exact Match (multi-word English)
        results = await dbHelper.searchWords(
          headwordQuery: 'multi word',
          headwordMode: SearchMode.exact,
        );
        expect(
          results.length,
          1,
          reason: 'Multi-word exact headword search failed',
        );

        // 3. Headword Prefix Match (English phrase)
        results = await dbHelper.searchWords(
          headwordQuery: 'prefix',
          headwordMode: SearchMode.prefix,
        );
        expect(results.length, 1, reason: 'Prefix headword search failed');

        // 4. Definition Substring Match (Gujarati)
        results = await dbHelper.searchWords(
          definitionQuery: 'મીઠું',
          definitionMode: SearchMode.substring,
        );
        expect(
          results.length,
          1,
          reason: 'Gujarati definition substring search failed',
        );

        // 5. Definition Substring Match (English multi-word)
        results = await dbHelper.searchWords(
          definitionQuery: 'multi word',
          definitionMode: SearchMode.substring,
        );
        expect(
          results.length,
          1,
          reason:
              'English multi-word definition search failed due to phrase error',
        );

        // 6. Suggestions
        var suggestions = await dbHelper.getPrefixSuggestions('prefix');
        expect(suggestions.contains('prefix test'), isTrue);

        // Multi-word suggestion (should fallback seamlessly without error)
        suggestions = await dbHelper.getPrefixSuggestions('multi word');
        expect(suggestions.contains('multi word'), isTrue);
      },
    );
  });
}
