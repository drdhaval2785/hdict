import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static Future<void> initializeDatabaseFactory() async {
    if (kIsWeb) {
      databaseFactory = createDatabaseFactoryFfiWeb();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isAndroid) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

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
    String path;
    if (kIsWeb) {
      path = 'hdict_v4.db'; // Incremented version for stability
    } else {
      try {
        Directory documentsDirectory = await getApplicationDocumentsDirectory();
        path = join(documentsDirectory.path, 'novalex.db');
      } catch (e) {
        debugPrint('Error getting documents directory: $e');
        path = 'novalex.db'; // Fallback to local path
      }
    }

    // Verify factory is initialized
    try {
      databaseFactory;
    } catch (e) {
      debugPrint('Database factory not initialized: $e');
      throw StateError('Database factory not initialized. Check main.dart');
    }

    return await openDatabase(
      path,
      version: 7,
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
        index_definitions INTEGER DEFAULT 0,
        word_count INTEGER DEFAULT 0,
        display_order INTEGER DEFAULT 0
      )
    ''');

    // 2. Create word_index FTS5 virtual table
    try {
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
    } catch (e) {
      debugPrint('FTS5 table creation failed, falling back to normal table: $e');
      await db.execute('''
        CREATE TABLE word_index (
          word TEXT,
          content TEXT,
          dict_id INTEGER,
          offset INTEGER,
          length INTEGER
        )
      ''');
      await db.execute('CREATE INDEX idx_word_index_word ON word_index(word)');
    }

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

    // 5. Create files table for Web Virtual Filesystem
    await db.execute('''
      CREATE TABLE IF NOT EXISTS files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dict_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        content BLOB NOT NULL,
        UNIQUE(dict_id, file_name)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS files (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dict_id INTEGER NOT NULL,
          file_name TEXT NOT NULL,
          content BLOB NOT NULL,
          UNIQUE(dict_id, file_name)
        )
      ''');
    }
  }

  // --- Path Resolution Helper (iOS/macOS Absolute Path Volatility) ---

  /// Resolves a stored path to an absolute path.
  /// Handles relative paths (stored relative to Documents) for iOS compatibility.
  Future<String> resolvePath(String storedPath) async {
    if (kIsWeb) return storedPath;
    if (isAbsolute(storedPath) && !Platform.isIOS && !Platform.isMacOS) {
      return storedPath;
    }

    // Convention: If path starts with /Users or /var, it's absolute.
    // On iOS/macOS, we extract the relative part if it matches the dictionaries structure.
    final String relativePart;
    if (storedPath.contains('dictionaries/')) {
      relativePart = storedPath.substring(storedPath.indexOf('dictionaries/'));
    } else {
      relativePart = storedPath;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    return join(appDocDir.path, relativePart);
  }

  // --- Virtual Filesystem Methods ---

  Future<void> saveFile(int dictId, String fileName, Uint8List bytes) async {
    final db = await database;
    await db.insert(
      'files',
      {
        'dict_id': dictId,
        'file_name': fileName,
        'content': bytes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Uint8List?> getFile(int dictId, String fileName) async {
    final db = await database;
    final results = await db.query(
      'files',
      where: 'dict_id = ? AND file_name = ?',
      whereArgs: [dictId, fileName],
    );
    if (results.isNotEmpty) {
      return results.first['content'] as Uint8List;
    }
    return null;
  }

  /// Efficiently reads a segment of a BLOB from the virtual filesystem.
  Future<Uint8List?> getFilePart(
    int dictId,
    String fileName,
    int offset,
    int length,
  ) async {
    final db = await database;
    // SQLite SUBSTR is 1-indexed.
    final sql =
        'SELECT SUBSTR(content, ?, ?) as part FROM files WHERE dict_id = ? AND file_name = ?';
    final results = await db.rawQuery(sql, [offset + 1, length, dictId, fileName]);
    if (results.isNotEmpty) {
      return results.first['part'] as Uint8List;
    }
    return null;
  }

  // --- Dictionary Management ---

  Future<int> insertDictionary(
    String name,
    String path, {
    bool indexDefinitions = false,
  }) async {
    final db = await database;
    
    // For native, store a path relative to Documents if possible
    String storedPath = path;
    if (!kIsWeb && path.contains('dictionaries/')) {
      storedPath = path.substring(path.indexOf('dictionaries/'));
    }

    return await db.insert('dictionaries', {
      'name': name,
      'path': storedPath,
      'is_enabled': 1,
      'index_definitions': indexDefinitions ? 1 : 0,
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

  Future<List<Map<String, dynamic>>> getSampleWords(
    int dictId, {
    int limit = 5,
  }) async {
    final db = await database;
    final results = await db.query(
      'word_index',
      columns: ['word', 'offset', 'length'],
      where: 'dict_id = ?',
      whereArgs: [dictId],
      orderBy: 'RANDOM()',
      limit: limit,
    );
    return results;
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

  Future<void> updateDictionaryIndexDefinitions(
    int id,
    bool indexDefinitions,
  ) async {
    final db = await database;
    await db.update(
      'dictionaries',
      {'index_definitions': indexDefinitions ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDictionary(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('dictionaries', where: 'id = ?', whereArgs: [id]);
      await txn.delete('word_index', where: 'dict_id = ?', whereArgs: [id]);
      await txn.delete('files', where: 'dict_id = ?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, dynamic>>> getDictionaries() async {
    try {
      final db = await database;
      return await db.query('dictionaries', orderBy: 'display_order ASC');
    } catch (e) {
      debugPrint('Error getting dictionaries: $e');
      return [];
    }
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
    try {
      final db = await database;
      await db.delete('search_history', where: 'word = ?', whereArgs: [word]);
      await db.insert('search_history', {
        'word': word,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Error adding search history: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSearchHistory() async {
    try {
      final db = await database;
      return await db.query('search_history', orderBy: 'timestamp DESC');
    } catch (e) {
      debugPrint('Error getting search history: $e');
      return [];
    }
  }

  Future<void> clearSearchHistory() async {
    final db = await database;
    await db.delete('search_history');
  }

  Future<void> deleteOldSearchHistory(int days) async {
    try {
      final db = await database;
      final int cutOff = DateTime.now()
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch;
      await db.delete(
        'search_history',
        where: 'timestamp < ?',
        whereArgs: [cutOff],
      );
    } catch (e) {
      debugPrint('Error deleting old search history: $e');
    }
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
          'content': word['content'],
          'dict_id': dictId,
          'offset': word['offset'],
          'length': word['length'],
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> searchWords(
    String query, {
    int limit = 50,
    bool fuzzy = false,
    bool searchDefinitions = false,
  }) async {
    try {
      final db = await database;
      final bool hasWildcards = query.contains('*') || query.contains('?');

      if (hasWildcards) {
        final String sql =
            '''
          SELECT word, dict_id, offset, length 
          FROM word_index 
          WHERE word GLOB ? 
          ${searchDefinitions ? "OR content MATCH ?" : ""}
          LIMIT ?
        ''';
        final List<Object?> args = [query];
        if (searchDefinitions) args.add(query);
        args.add(limit);
        return await db.rawQuery(sql, args);
      } else if (searchDefinitions) {
        final String sql = '''
          SELECT word, dict_id, offset, length 
          FROM word_index 
          WHERE word MATCH ? OR content MATCH ?
          LIMIT ?
        ''';
        return await db.rawQuery(sql, [query, query, limit]);
      } else if (fuzzy) {
        final List<Map<String, dynamic>> exactMatch = await db.query(
          'word_index',
          columns: ['word', 'dict_id', 'offset', 'length'],
          where: 'word = ?',
          whereArgs: [query],
          limit: limit,
        );
        if (exactMatch.isNotEmpty) return exactMatch;

        final String sql = '''
          SELECT word, dict_id, offset, length FROM word_index WHERE word MATCH ?
          UNION
          SELECT word, dict_id, offset, length FROM word_index WHERE word LIKE ?
          LIMIT ?
        ''';
        return await db.rawQuery(sql, ['$query*', '%$query%', limit]);
      } else {
        final List<Map<String, dynamic>> exactMatch = await db.query(
          'word_index',
          columns: ['word', 'dict_id', 'offset', 'length'],
          where: 'word = ?',
          whereArgs: [query],
          limit: limit,
        );
        if (exactMatch.isNotEmpty) return exactMatch;

        // Longest Prefix Match Fallback
        String prefix = query;
        while (prefix.length > 2) {
          prefix = prefix.substring(0, prefix.length - 1);
          final List<Map<String, dynamic>> prefixMatch = await db.query(
            'word_index',
            columns: ['word', 'dict_id', 'offset', 'length'],
            where: 'word = ?',
            whereArgs: [prefix],
            limit: limit,
          );
          if (prefixMatch.isNotEmpty) return prefixMatch;
        }

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

  Future<List<String>> getPrefixSuggestions(
    String prefix, {
    int limit = 10,
    bool fuzzy = false,
  }) async {
    try {
      final db = await database;
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
