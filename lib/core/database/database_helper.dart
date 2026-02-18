import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // For testing only
  static void setDatabase(Database db) {
    _database = db;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'novalex.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create dictionaries table
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

    // 2. Create word_index FTS5 virtual table
    await db.execute('''
      CREATE VIRTUAL TABLE word_index USING fts5(
        word,
        dict_id UNINDEXED,
        offset UNINDEXED,
        length UNINDEXED,
        tokenize = 'unicode61'
      )
    ''');

    // 3. Create search_history table
    await db.execute('''
      CREATE TABLE search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 4. Create flash_card_scores table
    await db.execute('''
      CREATE TABLE flash_card_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Add word_count column if it doesn't exist
      // Note: We use try-catch because if someone is on a fresh install,
      // onCreate might have already added it depending on timing, though version check should prevent this.
      try {
        await db.execute(
          'ALTER TABLE dictionaries ADD COLUMN word_count INTEGER DEFAULT 0',
        );
      } catch (e) {
        debugPrint('Column word_count might already exist: $e');
      }

      // 2. Populate word counts for existing dictionaries to make the migration seamless
      final List<Map<String, dynamic>> dicts = await db.query('dictionaries');
      for (final dict in dicts) {
        final id = dict['id'];
        final countResult = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM word_index WHERE dict_id = ?',
          [id],
        );
        final count = Sqflite.firstIntValue(countResult) ?? 0;
        await db.update(
          'dictionaries',
          {'word_count': count},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE dictionaries ADD COLUMN display_order INTEGER DEFAULT 0',
        );
        // Initialize display_order with id or sequential number
        final List<Map<String, dynamic>> dicts = await db.query('dictionaries');
        for (int i = 0; i < dicts.length; i++) {
          await db.update(
            'dictionaries',
            {'display_order': i},
            where: 'id = ?',
            whereArgs: [dicts[i]['id']],
          );
        }
      } catch (e) {
        debugPrint('Column display_order might already exist: $e');
      }
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS search_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS flash_card_scores (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          score INTEGER NOT NULL,
          total INTEGER NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');
    }
  }

  // --- Dictionary Management ---

  Future<int> insertDictionary(String name, String path) async {
    final db = await database;
    return await db.insert('dictionaries', {
      'name': name,
      'path': path,
      'is_enabled': 1,
    });
  }

  Future<void> updateDictionaryWordCount(int id, int wordCount) async {
    final db = await database;
    await db.update(
      'dictionaries',
      {'word_count': wordCount},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getWordCountForDict(int dictId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM word_index WHERE dict_id = ?',
      [dictId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns a few sample words from a dictionary for verification.
  Future<List<String>> getSampleWords(int dictId, {int limit = 5}) async {
    final db = await database;
    final results = await db.query(
      'word_index',
      columns: ['word'],
      where: 'dict_id = ?',
      whereArgs: [dictId],
      limit: limit,
    );
    return results.map((r) => r['word'] as String).toList();
  }

  Future<void> updateDictionaryEnabled(int id, bool isEnabled) async {
    final db = await database;
    await db.update(
      'dictionaries',
      {'is_enabled': isEnabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDictionary(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete from dictionaries table
      await txn.delete('dictionaries', where: 'id = ?', whereArgs: [id]);
      // Delete from word_index
      await txn.delete('word_index', where: 'dict_id = ?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, dynamic>>> getDictionaries() async {
    final db = await database;
    return await db.query('dictionaries', orderBy: 'display_order ASC');
  }

  Future<void> reorderDictionaries(List<int> sortedIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < sortedIds.length; i++) {
        await txn.update(
          'dictionaries',
          {'display_order': i},
          where: 'id = ?',
          whereArgs: [sortedIds[i]],
        );
      }
    });
  }

  Future<Map<String, dynamic>?> getDictionaryById(int id) async {
    final db = await database;
    final results = await db.query(
      'dictionaries',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) return results.first;
    return null;
  }

  // --- Search History ---

  Future<void> addSearchHistory(String word) async {
    final db = await database;
    // Remove if exists to move it to top
    await db.delete('search_history', where: 'word = ?', whereArgs: [word]);
    await db.insert('search_history', {
      'word': word,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getSearchHistory() async {
    final db = await database;
    return await db.query('search_history', orderBy: 'timestamp DESC');
  }

  Future<void> clearSearchHistory() async {
    final db = await database;
    await db.delete('search_history');
  }

  Future<void> deleteOldSearchHistory(int days) async {
    final db = await database;
    final int cutOff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    await db.delete(
      'search_history',
      where: 'timestamp < ?',
      whereArgs: [cutOff],
    );
  }

  // --- Flash Card Scores ---

  Future<void> addFlashCardScore(int score, int total) async {
    final db = await database;
    await db.insert('flash_card_scores', {
      'score': score,
      'total': total,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getFlashCardScores() async {
    final db = await database;
    return await db.query('flash_card_scores', orderBy: 'timestamp DESC');
  }

  // --- Indexing ---

  /// Batched insertion for high performance.
  Future<void> batchInsertWords(
    int dictId,
    List<Map<String, dynamic>> words,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var word in words) {
        batch.insert('word_index', {
          'word': word['word'],
          'dict_id': dictId,
          'offset': word['offset'],
          'length': word['length'],
        });
      }
      await batch.commit(noResult: true);
    });
  }

  /// Searches for words using FTS5 and wildcards.
  ///
  /// Supports exact matches and custom wildcards (* for multiple chars, ? for single char).
  /// Exact matches use FTS5 [MATCH] operator for near O(1) performance.
  /// Wildcard matches use the [GLOB] operator.
  Future<List<Map<String, dynamic>>> searchWords(
    String query, {
    int limit = 50,
    bool fuzzy = false,
  }) async {
    final db = await database;

    final bool hasWildcards = query.contains('*') || query.contains('?');

    try {
      if (hasWildcards) {
        final String sql = '''
          SELECT word, dict_id, offset, length 
          FROM word_index 
          WHERE word GLOB ? 
          LIMIT ?
        ''';
        return await db.rawQuery(sql, [query, limit]);
      } else if (fuzzy) {
        // Simple fuzzy: prefix match OR contains match
        // Use UNION to avoid "MATCH in requested context" error with OR
        final String sql = '''
          SELECT word, dict_id, offset, length FROM word_index WHERE word MATCH ?
          UNION
          SELECT word, dict_id, offset, length FROM word_index WHERE word LIKE ?
          LIMIT ?
        ''';
        return await db.rawQuery(sql, ['$query*', '%$query%', limit]);
      } else {
        final String sql = '''
          SELECT word, dict_id, offset, length 
          FROM word_index 
          WHERE word MATCH ?
          LIMIT ?
        ''';
        return await db.rawQuery(sql, [query, limit]);
      }
    } catch (e) {
      debugPrint("Search error: $e");
      return [];
    }
  }

  /// Specialized search for prefix suggestions used in the Autocomplete widget.
  /// Uses FTS5 prefix matching (MATCH 'prefix*') for extremely fast lookups.
  Future<List<String>> getPrefixSuggestions(
    String prefix, {
    int limit = 10,
    bool fuzzy = false,
  }) async {
    final db = await database;
    try {
      if (fuzzy) {
        final String sql = '''
          SELECT word FROM word_index WHERE word MATCH ?
          UNION
          SELECT word FROM word_index WHERE word LIKE ?
          ORDER BY word ASC
          LIMIT ?
        ''';
        final results = await db.rawQuery(sql, [
          '$prefix*',
          '%$prefix%',
          limit,
        ]);
        return results.map((r) => r['word'] as String).toList();
      } else {
        final String sql = '''
          SELECT DISTINCT word FROM word_index 
          WHERE word MATCH ? 
          ORDER BY word ASC
          LIMIT ?
        ''';
        final results = await db.rawQuery(sql, ['$prefix*', limit]);
        return results.map((r) => r['word'] as String).toList();
      }
    } catch (e) {
      return [];
    }
  }
}
