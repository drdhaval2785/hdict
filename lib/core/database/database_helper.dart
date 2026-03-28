import 'dart:collection';
import 'package:hdict/core/utils/logger.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'dart:math';
import 'package:hdict/features/settings/settings_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  /// Cached result of whether FTS5 is available on this device's SQLite.
  /// Set during [_onOpen]; null means not yet determined.
  static bool? _fts5Available;

  /// Cached app documents directory to avoid redundant platform channel calls.
  static Directory? _appDocDir;

  /// Whether the user just upgraded from version 16 and needs a notice.
  static bool needsMigrationAlert = false;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  /// LRU Cache for SQLite search results.
  /// Key: "$headwordQuery|$headwordMode|$definitionQuery|$definitionMode|$dictId|$limit"
  final LinkedHashMap<String, List<Map<String, dynamic>>> _queryCache =
      LinkedHashMap<String, List<Map<String, dynamic>>>();
  static const int _maxQueryCacheEntries = 100;

  void _addToQueryCache(String key, List<Map<String, dynamic>> value) {
    if (_queryCache.containsKey(key)) {
      _queryCache.remove(key);
    } else if (_queryCache.length >= _maxQueryCacheEntries) {
      _queryCache.remove(_queryCache.keys.first);
    }
    _queryCache[key] = value;
  }

  List<Map<String, dynamic>>? _getFromQueryCache(String key) {
    if (!_queryCache.containsKey(key)) return null;
    final value = _queryCache.remove(key);
    _queryCache[key] = value!;
    return value;
  }

  void clearQueryCache() {
    _queryCache.clear();
    hDebugPrint('DatabaseHelper: Query cache cleared.');
  }

  /// In-memory cache for dictionary metadata.
  List<Map<String, dynamic>>? _dictionaryCache;
  Map<int, Map<String, dynamic>>? _dictionaryMapCache;

  void clearDictionaryCache() {
    _dictionaryCache = null;
    _dictionaryMapCache = null;
    hDebugPrint('DatabaseHelper: Dictionary metadata cache cleared.');
  }

  void _log(String type, String sql, [dynamic args, dynamic result]) {
    hDebugPrint('--- SQL $type ---');
    hDebugPrint('Query: $sql');
    if (args != null) hDebugPrint('Args: $args');
    if (result != null) {
      if (result is List) {
        hDebugPrint('Result Count: ${result.length}');
        if (result.isNotEmpty && result.length <= 5) {
          hDebugPrint('Sample Results: $result');
        }
      } else {
        hDebugPrint('Result: $result');
      }
    }
    hDebugPrint('-----------------');
  }

  static Future<void> initializeDatabaseFactory() async {
    if (kIsWeb) {
      databaseFactory = createDatabaseFactoryFfiWeb();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isAndroid) {
      // On Android, sqflite_common_ffi + sqlite3 (3.x+) provides a bundled
      // SQLite compiled with FTS5 support, bypassing the device's system SQLite
      // which may lack FTS5 on older Android versions.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // On macOS and iOS, the system SQLite includes FTS5; use default sqflite.
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // For testing only — also probes FTS5 availability on the injected DB.
  static void setDatabase(Database db) {
    _database = db;
    // Run the probe synchronously-ish: fire-and-forget is fine for tests
    // since the database open is already complete before the first query.
    _checkFts5Available(db).then((available) {
      _fts5Available = available;
    });
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
        hDebugPrint('Error getting documents directory: $e');
        path = 'novalex.db'; // Fallback to local path
      }
    }

    // Verify factory is initialized
    try {
      databaseFactory;
    } catch (e) {
      hDebugPrint('Database factory not initialized: $e');
      throw StateError('Database factory not initialized. Check main.dart');
    }

    return await openDatabase(
      path,
      version: 32, // Version 32: Add mdd_path column for MDD multimedia support
      onCreate: _onCreate,
      onConfigure: (db) async {
        try {
          // Use rawQuery for PRAGMAs that return results to avoid "not an error" on Darwin
          await db.rawQuery('PRAGMA journal_mode = WAL;');
          await db.rawQuery('PRAGMA synchronous = NORMAL;');
          await db.rawQuery('PRAGMA cache_size = -64000'); // 64MB cache
          hDebugPrint(
            'DatabaseHelper: Performance PRAGMAs applied (WAL mode, 64MB cache)',
          );
        } catch (e) {
          hDebugPrint(
            'DatabaseHelper: Failed to apply performance PRAGMAs: $e',
          );
          // We don't rethrow here so the database can still open in default mode
        }
      },
      onOpen: _onOpen,
      onUpgrade: _onUpgrade,
    );
  }

  /// Tests whether the FTS5 module is available in the current SQLite build.
  /// Creates a temporary test table, then drops it.
  static Future<bool> _checkFts5Available(Database db) async {
    try {
      await db.execute('CREATE VIRTUAL TABLE _fts5_probe USING fts5(x)');
      await db.execute('DROP TABLE IF EXISTS _fts5_probe');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ensures the word_index table exists and matches FTS5 availability.
  /// - If word_index doesn't exist: creates FTS5 virtual table (or regular fallback).
  /// - If word_index exists as FTS5 but FTS5 is unavailable: drops & recreates as regular.
  /// - If word_index exists and is correct: does nothing.
  static Future<void> _ensureWordIndexTable(Database db) async {
    final bool fts5Available = await _checkFts5Available(db);

    // Check if word_index already exists and what type it is.
    final existing = await db.rawQuery(
      "SELECT type FROM sqlite_master WHERE name = 'word_index'",
    );
    final bool tableExists = existing.isNotEmpty;
    // FTS5 virtual tables contain 'fts5' in their DDL sql stored in sqlite_master.
    final bool tableIsFts5 =
        tableExists &&
        (await db.rawQuery(
              "SELECT sql FROM sqlite_master WHERE name = 'word_index'",
            )).firstOrNull?['sql']?.toString().contains('fts5') ==
            true;

    if (tableExists && tableIsFts5 && !fts5Available) {
      // The stored table is FTS5 but the runtime doesn't support it.
      // Drop and recreate as a regular table to restore functionality.
      hDebugPrint(
        'word_index is FTS5 but FTS5 module is unavailable — migrating to regular table.',
      );
      await db.execute('DROP TABLE word_index');
    }

    // Re-check existence after potential drop.
    final existsNow = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE name = 'word_index'",
    )).isNotEmpty;

    if (!existsNow) {
      if (fts5Available) {
        // 1. Physical metadata table (supports scanning/SQL joins/deletes)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS word_metadata(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT COLLATE NOCASE,
            dict_id INTEGER,
            offset INTEGER,
            length INTEGER
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_metadata_dict_id ON word_metadata(dict_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_metadata_word ON word_metadata(word)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_metadata_dict_word ON word_metadata(dict_id, word COLLATE NOCASE)',
        );

        await db.execute('''
          CREATE VIRTUAL TABLE word_index USING fts5(
            word,
            content,
            tokenize = 'unicode61'
          )
        ''');
        hDebugPrint('word_index created as FTS5 virtual table.');
      } else {
        hDebugPrint(
          'FTS5 unavailable — creating word_index as regular indexed table.',
        );
        await db.execute('''
          CREATE TABLE IF NOT EXISTS word_index (
            word TEXT,
            content TEXT,
            dict_id INTEGER,
            offset INTEGER,
            length INTEGER
          )
        ''');
        try {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_word_index_word ON word_index(word)',
          );
        } catch (_) {}
      }
    }
  }

  /// Called every time the database is opened (after onCreate/onUpgrade).
  /// Ensures word_index is usable on this device's SQLite build.
  Future<void> _onOpen(Database db) async {
    await _ensureWordIndexTable(db);
    // Cache FTS5 availability for the lifetime of this DB session.
    _fts5Available = await _checkFts5Available(db);
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create dictionaries table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dictionaries (
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
        source_bookmark TEXT,
        companion_uri TEXT,
        mdd_path TEXT
      )
    ''');

    // 2. Create word_index table (FTS5 if available, regular indexed otherwise).
    await DatabaseHelper._ensureWordIndexTable(db);

    // 3. Create search_history table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        search_type TEXT DEFAULT 'Headword Search'
      )
    ''');

    // 4. Create flash_card_scores table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS flash_card_scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        score INTEGER NOT NULL,
        total INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        dict_ids TEXT
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

    // 6. Create freedict_dictionaries table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS freedict_dictionaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        source_lang TEXT NOT NULL,
        target_lang TEXT NOT NULL,
        headwords TEXT,
        url TEXT,
        version TEXT,
        date TEXT,
        releases_json TEXT NOT NULL
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
    if (oldVersion < 8) {
      try {
        await db.execute(
          'ALTER TABLE dictionaries ADD COLUMN start_rowid INTEGER',
        );
        await db.execute(
          'ALTER TABLE dictionaries ADD COLUMN end_rowid INTEGER',
        );
      } catch (e) {
        hDebugPrint('Migration error (version 8): $e');
      }
    }
    if (oldVersion < 9) {
      try {
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info('dictionaries')",
        );
        bool hasIndexDefinitions = false;
        for (final row in tableInfo) {
          if (row['name'] == 'index_definitions') {
            hasIndexDefinitions = true;
            break;
          }
        }
        if (!hasIndexDefinitions) {
          await db.execute(
            'ALTER TABLE dictionaries ADD COLUMN index_definitions INTEGER DEFAULT 0',
          );
        }
      } catch (e) {
        hDebugPrint('Migration error (version 9): $e');
      }
    }
    if (oldVersion < 10) {
      try {
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info('dictionaries')",
        );
        bool hasFormat = false;
        for (final row in tableInfo) {
          if (row['name'] == 'format') {
            hasFormat = true;
            break;
          }
        }
        if (!hasFormat) {
          await db.execute(
            "ALTER TABLE dictionaries ADD COLUMN format TEXT DEFAULT 'stardict'",
          );
        }
      } catch (e) {
        hDebugPrint('Migration error (version 10): $e');
      }
    }
    if (oldVersion < 11) {
      try {
        await db.execute(
          'ALTER TABLE flash_card_scores ADD COLUMN dict_ids TEXT',
        );
      } catch (e) {
        hDebugPrint('Migration error (version 11): $e');
      }
    }
    if (oldVersion < 12) {
      try {
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info('dictionaries')",
        );
        bool hasTypeSequence = false;
        for (final row in tableInfo) {
          if (row['name'] == 'type_sequence') {
            hasTypeSequence = true;
            break;
          }
        }
        if (!hasTypeSequence) {
          await db.execute(
            'ALTER TABLE dictionaries ADD COLUMN type_sequence TEXT',
          );
        }
      } catch (e) {
        hDebugPrint('Migration error (version 12): $e');
      }
    }
    if (oldVersion < 13) {
      try {
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info('dictionaries')",
        );
        bool hasCss = false;
        for (final row in tableInfo) {
          if (row['name'] == 'css') {
            hasCss = true;
            break;
          }
        }
        if (!hasCss) {
          await db.execute('ALTER TABLE dictionaries ADD COLUMN css TEXT');
        }
      } catch (e) {
        hDebugPrint('Migration error (version 13): $e');
      }
    }
    if (oldVersion < 14) {
      try {
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info('dictionaries')",
        );
        bool hasDefWordCount = false;
        for (final row in tableInfo) {
          if (row['name'] == 'definition_word_count') {
            hasDefWordCount = true;
            break;
          }
        }
        if (!hasDefWordCount) {
          await db.execute(
            'ALTER TABLE dictionaries ADD COLUMN definition_word_count INTEGER DEFAULT 0',
          );
        }
      } catch (e) {
        hDebugPrint('Migration error (version 14): $e');
      }
    }
    if (oldVersion < 15) {
      try {
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info('search_history')",
        );
        bool hasSearchType = false;
        for (final row in tableInfo) {
          if (row['name'] == 'search_type') {
            hasSearchType = true;
            break;
          }
        }
        if (!hasSearchType) {
          await db.execute(
            "ALTER TABLE search_history ADD COLUMN search_type TEXT DEFAULT 'Headword Search'",
          );
        }
      } catch (e) {
        hDebugPrint('Migration error (version 15): $e');
      }
    }
    if (oldVersion < 16) {
      try {
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info('dictionaries')",
        );
        bool hasChecksum = false;
        for (final row in tableInfo) {
          if (row['name'] == 'checksum') {
            hasChecksum = true;
            break;
          }
        }
        if (!hasChecksum) {
          await db.execute('ALTER TABLE dictionaries ADD COLUMN checksum TEXT');
        }
      } catch (e) {
        hDebugPrint('Migration error (version 16): $e');
      }
    }
    if (oldVersion == 16) {
      needsMigrationAlert = true;
    }
    if (oldVersion < 18) {
      try {
        hDebugPrint('Migration to version 18: Hybrid FTS5 indexing');
        // Drop everything related to old word index
        await db.execute('DROP TABLE IF EXISTS word_index');
        await db.execute('DROP TABLE IF EXISTS word_metadata');
        // Reset dictionaries word counts and index setting to force re-indexing
        await db.execute(
          'UPDATE dictionaries SET word_count = 0, definition_word_count = 0, index_definitions = 0',
        );
        // Tables will be recreated in _onOpen -> _ensureWordIndexTable
      } catch (e) {
        hDebugPrint('Migration error (version 18): $e');
      }
    }
    if (oldVersion < 19) {
      try {
        hDebugPrint('Migration to version 19: Pre-tokenized keyword indexing');
        // Re-index is required because content storage format has changed.
        await db.execute('DROP TABLE IF EXISTS word_index');
        // Safely clear metadata if it exists
        try {
          await db.execute('DELETE FROM word_metadata');
        } catch (_) {
          // Table might have been dropped in v18 and not yet recreated
        }
        await db.execute(
          'UPDATE dictionaries SET word_count = 0, definition_word_count = 0, index_definitions = 0',
        );
        // word_index will be recreated in _onOpen -> _ensureWordIndexTable
      } catch (e) {
        hDebugPrint('Migration error (version 19): $e');
      }
    }
    if (oldVersion < 20) {
      try {
        hDebugPrint(
          'Migration to version 20: Full language-agnostic FTS5 indexing',
        );
        // Re-index is required because content storage format has changed (removed English tokenization).
        await db.execute('DROP TABLE IF EXISTS word_index');
        try {
          await db.execute('DELETE FROM word_metadata');
        } catch (_) {}
        await db.execute(
          'UPDATE dictionaries SET word_count = 0, definition_word_count = 0, index_definitions = 0',
        );
        try {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_metadata_word ON word_metadata(word)',
          );
        } catch (_) {}
      } catch (e) {
        hDebugPrint('Migration error (version 20): $e');
      }
    }
    if (oldVersion < 21) {
      try {
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info('dictionaries')",
        );
        bool hasTypeSequence = false;
        for (final row in tableInfo) {
          if (row['name'] == 'type_sequence') {
            hasTypeSequence = true;
            break;
          }
        }
        if (!hasTypeSequence) {
          await db.execute(
            'ALTER TABLE dictionaries ADD COLUMN type_sequence TEXT',
          );
        }
      } catch (e) {
        hDebugPrint('Migration error (version 21): $e');
      }
    }

    if (oldVersion < 22) {
      try {
        hDebugPrint(
          'Migrating database to v22: Adding COLLATE NOCASE to word_metadata...',
        );

        // Check if word_metadata exists before trying to rename it
        final tableExists = (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='word_metadata'",
        )).isNotEmpty;

        if (tableExists) {
          await db.transaction((txn) async {
            // 1. Rename existing table
            await txn.execute(
              'ALTER TABLE word_metadata RENAME TO word_metadata_old',
            );

            // 2. Create new table with COLLATE NOCASE
            await txn.execute('''
              CREATE TABLE word_metadata(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                word TEXT COLLATE NOCASE,
                dict_id INTEGER,
                offset INTEGER,
                length INTEGER
              )
            ''');

            // 3. Copy data
            await txn.execute('''
              INSERT INTO word_metadata (id, word, dict_id, offset, length)
              SELECT id, word, dict_id, offset, length FROM word_metadata_old
            ''');

            // 4. Drop old table
            await txn.execute('DROP TABLE word_metadata_old');

            // 5. Recreate indexes
            await txn.execute(
              'CREATE INDEX idx_metadata_dict_id ON word_metadata(dict_id)',
            );
            await txn.execute(
              'CREATE INDEX idx_metadata_word ON word_metadata(word)',
            );
          });
        } else {
          // If table doesn't exist, just create it fresh
          await db.execute('''
            CREATE TABLE IF NOT EXISTS word_metadata(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              word TEXT COLLATE NOCASE,
              dict_id INTEGER,
              offset INTEGER,
              length INTEGER
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_metadata_dict_id ON word_metadata(dict_id)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_metadata_word ON word_metadata(word)',
          );
        }
        hDebugPrint('Database migration to v22 complete.');
      } catch (e) {
        hDebugPrint('Migration error (version 22): $e');
      }
    }

    if (oldVersion < 23) {
      try {
        hDebugPrint(
          'Migration to version 23: Adding composite index for search speed',
        );
        // Ensure table exists before creating index
        final tableExists = (await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='word_metadata'",
        )).isNotEmpty;

        if (tableExists) {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_metadata_dict_word ON word_metadata(dict_id, word COLLATE NOCASE)',
          );
        }
      } catch (e) {
        hDebugPrint('Migration error (version 23): $e');
      }
    }

    if (oldVersion < 24) {
      try {
        hDebugPrint(
          'Migration to version 24: Adding freedict_dictionaries table',
        );
        await db.execute('''
          CREATE TABLE IF NOT EXISTS freedict_dictionaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            source_lang TEXT NOT NULL,
            target_lang TEXT NOT NULL,
            headwords TEXT,
            releases_json TEXT NOT NULL
          )
        ''');
      } catch (e) {
        hDebugPrint('Migration error (version 24): $e');
      }
    }

    if (oldVersion < 25) {
      try {
        hDebugPrint(
          'Migration to version 25: Adding url, version, date columns to freedict_dictionaries',
        );
        await db.execute(
          'ALTER TABLE freedict_dictionaries ADD COLUMN url TEXT',
        );
        await db.execute(
          'ALTER TABLE freedict_dictionaries ADD COLUMN version TEXT',
        );
        await db.execute(
          'ALTER TABLE freedict_dictionaries ADD COLUMN date TEXT',
        );
      } catch (e) {
        hDebugPrint('Migration error (version 25): $e');
      }
    }

    if (oldVersion < 26) {
      try {
        hDebugPrint(
          'Migration to version 26: Adding source_url column to dictionaries',
        );
        await db.execute('ALTER TABLE dictionaries ADD COLUMN source_url TEXT');
      } catch (e) {
        hDebugPrint('Migration error (version 26): $e');
      }
    }

    if (oldVersion < 27) {
      try {
        hDebugPrint(
          'Migration to version 27: Ensuring source_url column exists in dictionaries',
        );
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info('dictionaries')",
        );
        bool hasSourceUrl = false;
        for (final row in tableInfo) {
          if (row['name'] == 'source_url') {
            hasSourceUrl = true;
            break;
          }
        }
        if (!hasSourceUrl) {
          await db.execute(
            'ALTER TABLE dictionaries ADD COLUMN source_url TEXT',
          );
        }
      } catch (e) {
        hDebugPrint('Migration error (version 27): $e');
      }
    }

    if (oldVersion < 28) {
      try {
        hDebugPrint(
          'Migration to version 28: Making word_index a standard FTS5 table to allow deletions',
        );
        // Drastically simplifies things by just dropping the old index and forcing a background re-index
        await db.execute('DROP TABLE IF EXISTS word_index');
        try {
          await db.execute('DELETE FROM word_metadata');
        } catch (_) {}
        await db.execute(
          'UPDATE dictionaries SET word_count = 0, definition_word_count = 0, index_definitions = 0',
        );
        // word_index will be recreated without content='' in _onOpen -> _ensureWordIndexTable
      } catch (e) {
        hDebugPrint('Migration error (version 28): $e');
      }
    }

    if (oldVersion < 29) {
      try {
        await db.execute(
          "ALTER TABLE dictionaries ADD COLUMN source_type TEXT DEFAULT 'managed'",
        );
        await db.execute(
          'ALTER TABLE dictionaries ADD COLUMN source_bookmark TEXT',
        );
      } catch (e) {
        hDebugPrint('Migration error (version 29): $e');
      }
    }

    if (oldVersion < 30) {
      try {
        hDebugPrint(
          'Migration to version 30: Adding companion_uri to store pre-resolved SAF dict file URI',
        );
        await db.execute(
          'ALTER TABLE dictionaries ADD COLUMN companion_uri TEXT',
        );
      } catch (e) {
        hDebugPrint('Migration error (version 30): $e');
      }
    }

    if (oldVersion < 31) {
      try {
        hDebugPrint(
          'Migration to version 31: Performance optimizations (WAL mode)',
        );
      } catch (e) {
        hDebugPrint('Migration error (version 31): $e');
      }
    }

    if (oldVersion < 32) {
      try {
        hDebugPrint(
          'Migration to version 32: Adding mdd_path column to dictionaries',
        );
        await db.execute("ALTER TABLE dictionaries ADD COLUMN mdd_path TEXT");
      } catch (e) {
        hDebugPrint('Migration error (version 32): $e');
      }
    }
  } // end _onUpgrade

  // ---------------------------------------------------------------------------
  // Content Tokenizer
  // ---------------------------------------------------------------------------

  /// Tokenizes definition content into a compact space-separated keyword string.
  ///
  /// Strategy (Option C):
  /// - Lowercases all text
  /// - Strips punctuation
  /// - Removes common English stopwords
  /// - Removes very short tokens (< 3 chars) and pure numbers
  /// - Deduplicates (Set)
  ///
  /// Result: ~11% smaller FTS5 index vs storing raw definition text, while
  /// preserving meaningful definition-keyword search via FTS5 MATCH.
  ///
  /// Limitation: phrase searches (e.g. "red fruit") won't work — each token
  /// is an independent search unit. Individual token searches ("red", "fruit") work.
  /// Returning raw lowercased text lets FTS5's unicode61 handle all languages natively
  static String _tokenizeContent(String? text) {
    if (text == null || text.isEmpty) return '';
    return text.toLowerCase();
  }

  /// Translates user-facing wildcards (? and *) to SQLite LIKE wildcards (_ and %).
  String _translateWildcards(String query) {
    return query.replaceAll('?', '_').replaceAll('*', '%');
  }

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

    _appDocDir ??= await getApplicationDocumentsDirectory();
    return join(_appDocDir!.path, relativePart);
  }

  // --- Virtual Filesystem Methods ---

  Future<void> saveFile(int dictId, String fileName, Uint8List bytes) async {
    final db = await database;
    await db.insert('files', {
      'dict_id': dictId,
      'file_name': fileName,
      'content': bytes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    final results = await db.rawQuery(sql, [
      offset + 1,
      length,
      dictId,
      fileName,
    ]);
    _log('RAW_QUERY', sql, [offset + 1, length, dictId, fileName], results);
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
    String format = 'stardict',
    String? typeSequence,
    String? checksum,
    String? sourceUrl,
    String sourceType = 'managed',
    String? sourceBookmark,
    String?
    companionUri, // Pre-resolved companion file URI (e.g. SAF .dict URI)
    String? mddPath, // Path to the associated MDD file
  }) async {
    final db = await database;

    // For native, store a path relative to Documents if possible
    String storedPath = path;
    if (!kIsWeb && path.contains('dictionaries/') && sourceType == 'managed') {
      storedPath = path.substring(path.indexOf('dictionaries/'));
    }

    // Store MDD path relative as well
    String? storedMddPath = mddPath;
    if (!kIsWeb &&
        mddPath != null &&
        mddPath.contains('dictionaries/') &&
        sourceType == 'managed') {
      storedMddPath = mddPath.substring(mddPath.indexOf('dictionaries/'));
    }

    // Get the next display_order (max + 1) to ensure correct ordering
    final maxOrderResult = await db.rawQuery(
      'SELECT COALESCE(MAX(display_order), -1) + 1 as next_order FROM dictionaries',
    );
    final nextOrder = maxOrderResult.first['next_order'] as int;

    clearQueryCache();
    clearDictionaryCache();
    return await db.insert('dictionaries', {
      'name': name,
      'path': storedPath,
      'is_enabled': 1,
      'index_definitions': indexDefinitions ? 1 : 0,
      'format': format,
      'type_sequence': typeSequence,
      'css': null,
      'checksum': checksum,
      'source_url': sourceUrl,
      'source_type': sourceType,
      'source_bookmark': sourceBookmark,
      'companion_uri': companionUri,
      'mdd_path': storedMddPath,
      'display_order': nextOrder,
    });
  }

  Future<void> updateDictionaryWordCount(
    int id,
    int wordCount, [
    int? definitionWordCount,
  ]) async {
    final db = await database;
    final Map<String, dynamic> updateData = {'word_count': wordCount};
    if (definitionWordCount != null) {
      updateData['definition_word_count'] = definitionWordCount;
    }
    await db.update(
      'dictionaries',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
    clearDictionaryCache();
  }

  Future<void> updateDictionaryRowIdRange(int id, int start, int end) async {
    final db = await database;
    await db.update(
      'dictionaries',
      {'start_rowid': start, 'end_rowid': end},
      where: 'id = ?',
      whereArgs: [id],
    );
    // In-place update map cache to avoid full reload
    if (_dictionaryMapCache != null && _dictionaryMapCache!.containsKey(id)) {
      final updated = Map<String, dynamic>.from(_dictionaryMapCache![id]!);
      updated['start_rowid'] = start;
      updated['end_rowid'] = end;
      _dictionaryMapCache![id] = updated;
    }
    _dictionaryCache = null;
  }

  Future<int> getWordCountForDict(int dictId) async {
    final db = await database;
    final bool useFts5 = _fts5Available ?? true;
    final String targetTable = useFts5 ? 'word_metadata' : 'word_index';

    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $targetTable WHERE dict_id = ?',
      [dictId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Returns random sample words using O(1) rowid lookup if available, or O(N) fallback.
  /// Returns a specified number of sample words across multiple dictionaries.
  /// Uses a single SQL query for efficiency.
  Future<List<Map<String, dynamic>>> getBatchSampleWords(
    int totalCount,
    List<int> dictIds,
  ) async {
    final db = await database;
    final List<int> allRandomIds = [];
    final random = Random();

    // 1. Ensure map cache is ready for O(1) lookups
    await _ensureDictionaryMapCache();

    // 2. Generate random rowid candidates across requested dictionaries
    // Always compute MIN/MAX inline to guarantee fresh, correct values.
    // Also track computed ranges to update the cache afterward.
    final Map<int, Map<String, int>> computedRanges = {};
    for (final dictId in dictIds) {
      final dict = _dictionaryMapCache?[dictId];
      if (dict == null) continue;

      int wordCount = (dict['word_count'] as num).toInt();
      if (wordCount == 0) continue;

      final targetTable = (_fts5Available ?? true)
          ? 'word_metadata'
          : 'word_index';
      final minMax = await db.rawQuery(
        'SELECT MIN(rowid) as min, MAX(rowid) as max FROM $targetTable WHERE dict_id = ?',
        [dictId],
      );

      if (minMax.isEmpty || minMax.first['min'] == null) {
        hDebugPrint(
          'DatabaseHelper: getBatchSampleWords: Warning: Dict $dictId has no words',
        );
        continue;
      }

      final int start = (minMax.first['min'] as num).toInt();
      final int end = (minMax.first['max'] as num).toInt();
      computedRanges[dictId] = {'start': start, 'end': end};
      final int range = end - start + 1;
      hDebugPrint(
        'DatabaseHelper: getBatchSampleWords: Dict $dictId: start=$start, end=$end, range=$range, count=$wordCount',
      );

      // Distribute totalCount. Fetch a small excess (50% now instead of 20% to be safer)
      int toFetchThisDict = (totalCount * 1.5 / dictIds.length).ceil();
      if (toFetchThisDict < 2)
        toFetchThisDict = 2; // Always get at least 2 candidates per dict

      for (int i = 0; i < toFetchThisDict; i++) {
        int randomId = start + random.nextInt(range);
        allRandomIds.add(randomId);
      }
    }

    // 3. Update dictionary cache with computed ranges (for other callers)
    if (computedRanges.isNotEmpty) {
      await db.transaction((txn) async {
        for (final entry in computedRanges.entries) {
          final dictId = entry.key;
          final range = entry.value;
          await txn.update(
            'dictionaries',
            {'start_rowid': range['start'], 'end_rowid': range['end']},
            where: 'id = ?',
            whereArgs: [dictId],
          );
          // Update in-memory cache
          if (_dictionaryMapCache != null &&
              _dictionaryMapCache!.containsKey(dictId)) {
            final updated = Map<String, dynamic>.from(
              _dictionaryMapCache![dictId]!,
            );
            updated['start_rowid'] = range['start'];
            updated['end_rowid'] = range['end'];
            _dictionaryMapCache![dictId] = updated;
          }
        }
      });
      _dictionaryCache = null; // Sync list cache
    }

    if (allRandomIds.isEmpty) {
      hDebugPrint(
        'DatabaseHelper: getBatchSampleWords: No candidates generated. Check dictionary word counts.',
      );
      return [];
    }

    // 4. Perform ONE bulk query
    final bool useMetadataTable = (_fts5Available ?? true);
    final String targetTable = useMetadataTable
        ? 'word_metadata'
        : 'word_index';
    final String idColumn = useMetadataTable ? 'id' : 'rowid';

    final idList = allRandomIds.join(',');
    final dictIdList = dictIds.join(',');

    List<Map<String, dynamic>> resultsList = [];
    try {
      final query =
          'SELECT word, dict_id, offset, length FROM $targetTable '
          'WHERE $idColumn IN ($idList) AND dict_id IN ($dictIdList) '
          'LIMIT ${totalCount + 10}';
      hDebugPrint('DatabaseHelper: getBatchSampleWords: Stage 1 Query: $query');

      final results = await db.rawQuery(query);
      resultsList = List<Map<String, dynamic>>.from(results);
    } catch (e) {
      hDebugPrint(
        'DatabaseHelper: getBatchSampleWords: Stage 1 Query error: $e',
      );
    }

    hDebugPrint(
      'DatabaseHelper: getBatchSampleWords: Stage 1 fetched ${resultsList.length} words using $targetTable ($idColumn)',
    );

    // 5. Fallback Stage: If we didn't get enough words, fetch them one-by-one using OFFSET (Guaranteed but slower)
    if (resultsList.length < totalCount) {
      final int missing = totalCount - resultsList.length;
      hDebugPrint(
        'DatabaseHelper: getBatchSampleWords: Stage 2 Fallback: Fetching $missing more words from ${dictIds.length} possible dicts',
      );

      // Shuffle dictIds to not just pick from the first few
      final shuffledDictIds = List<int>.from(dictIds)..shuffle();
      hDebugPrint(
        'DatabaseHelper: getBatchSampleWords: Shuffle order: ${shuffledDictIds.take(10).toList()}...',
      );

      int fetchedCount = 0;
      for (
        int i = 0;
        i < missing * 10 && resultsList.length < totalCount;
        i++
      ) {
        final dictId = shuffledDictIds[i % shuffledDictIds.length];
        final dict = _dictionaryMapCache?[dictId];
        if (dict == null) continue;

        int wordCount = (dict['word_count'] as num).toInt();
        if (wordCount == 0) continue;

        int randomOffset = random.nextInt(wordCount);
        final fallback = await db.rawQuery(
          'SELECT word, dict_id, offset, length FROM $targetTable '
          'WHERE dict_id = ? LIMIT 1 OFFSET ?',
          [dictId, randomOffset],
        );

        if (fallback.isNotEmpty) {
          final word = fallback.first['word'];
          // Avoid duplicates if possible
          bool isDuplicate = resultsList.any(
            (r) => r['word'] == word && r['dict_id'] == dictId,
          );
          if (!isDuplicate) {
            resultsList.add(fallback.first);
            fetchedCount++;
            hDebugPrint(
              'DatabaseHelper: getBatchSampleWords: Stage 2: Added "$word" from dict $dictId (total: ${resultsList.length})',
            );
          }
        }
      }
      hDebugPrint(
        'DatabaseHelper: getBatchSampleWords: Stage 2 Fallback complete. Added $fetchedCount words.',
      );
    }

    // Final Shuffle to ensure Stage 1 and Stage 2 words are mixed
    resultsList.shuffle();
    return resultsList;
  }

  Future<List<Map<String, dynamic>>> getSampleWords(
    int dictId, {
    int limit = 5,
  }) async {
    final db = await database;

    // 1. Get dictionary metadata
    final dictResult = await db.query(
      'dictionaries',
      columns: ['word_count', 'start_rowid', 'end_rowid'],
      where: 'id = ?',
      whereArgs: [dictId],
    );
    hDebugPrint(
      'DatabaseHelper: getSampleWords ($dictId) metadata fetch complete',
    );

    if (dictResult.isEmpty) return [];

    int total = (dictResult.first['word_count'] as num).toInt();
    int? startRowId = dictResult.first['start_rowid'] as int?;
    int? endRowId = dictResult.first['end_rowid'] as int?;

    if (total == 0) return [];

    final random = Random();
    final List<Map<String, dynamic>> results = [];

    // 2. High-speed bulk rowid strategy (if metadata is available)
    if (startRowId != null && endRowId != null) {
      final int range = endRowId - startRowId + 1;
      final Set<int> randomIds = {};
      // Oversample by 20% to account for potential gaps, but at least fetch 'limit' unique IDs or range size
      int fetchCount = (limit * 1.2).ceil();
      if (fetchCount > range) fetchCount = range;

      while (randomIds.length < fetchCount && randomIds.length < range) {
        randomIds.add(startRowId + random.nextInt(range));
      }

      if (randomIds.isNotEmpty) {
        final String idList = randomIds.join(',');
        final res = await db.query(
          'word_metadata',
          columns: ['word', 'offset', 'length', 'dict_id'],
          where: 'id IN ($idList) AND dict_id = ?',
          whereArgs: [dictId],
        );

        if (res.isNotEmpty) {
          results.addAll(res);
          // Shuffle because IN clause doesn't guarantee order and we want randomness
          results.shuffle();
          if (results.length > limit) {
            return results.sublist(0, limit);
          }
          return results;
        }
      }
    }

    // 3. Fallback: Slow O(N) scan strategy (if rowid metadata missing)
    try {
      final rangeRes = await db.rawQuery(
        'SELECT MIN(rowid) as min_id, MAX(rowid) as max_id FROM word_metadata WHERE dict_id = ?',
        [dictId],
      );
      if (rangeRes.isNotEmpty && rangeRes.first['min_id'] != null) {
        int min = (rangeRes.first['min_id'] as num).toInt();
        int max = (rangeRes.first['max_id'] as num).toInt();
        await updateDictionaryRowIdRange(dictId, min, max);
        return getSampleWords(dictId, limit: limit); // Recurse
      }
    } catch (e) {
      hDebugPrint('Fallback random word lookup error: $e');
    }

    // Last resort: standard offset
    for (int i = 0; i < limit; i++) {
      int randomOffset = random.nextInt(total);
      final res = await db.query(
        'word_metadata',
        columns: ['word', 'offset', 'length', 'dict_id'],
        where: 'dict_id = ?',
        whereArgs: [dictId],
        limit: 1,
        offset: randomOffset,
      );
      if (res.isNotEmpty) results.add(res.first);
    }

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
    clearQueryCache();
    clearDictionaryCache();
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
    clearQueryCache();
    clearDictionaryCache();
  }

  Future<void> deleteWordsByDictionaryId(int dictId) async {
    final db = await database;
    await db.transaction((txn) async {
      final bool useFts5 = _fts5Available ?? true;
      if (useFts5) {
        // Delete FTS5 index first, using the metadata row mapping
        await txn.delete(
          'word_index',
          where: 'rowid IN (SELECT id FROM word_metadata WHERE dict_id = ?)',
          whereArgs: [dictId],
        );
        await txn.delete(
          'word_metadata',
          where: 'dict_id = ?',
          whereArgs: [dictId],
        );
      } else {
        await txn.delete(
          'word_index',
          where: 'dict_id = ?',
          whereArgs: [dictId],
        );
      }
    });
  }

  Future<void> deleteDictionary(int id) async {
    hDebugPrint('DatabaseHelper: Starting delete for dict_id=$id');
    final db = await database;

    // First delete from dictionaries table
    hDebugPrint('DatabaseHelper: Deleting from dictionaries table');
    await db.delete('dictionaries', where: 'id = ?', whereArgs: [id]);
    clearQueryCache();
    clearDictionaryCache();

    // Delete from word_index using subquery (avoids SQL variable limit)
    hDebugPrint('DatabaseHelper: Deleting from word_index (FTS5)');
    await db.delete(
      'word_index',
      where: "rowid IN (SELECT id FROM word_metadata WHERE dict_id = ?)",
      whereArgs: [id],
    );

    // Delete from word_metadata
    hDebugPrint('DatabaseHelper: Deleting from word_metadata');
    await db.delete('word_metadata', where: 'dict_id = ?', whereArgs: [id]);

    // Delete from files table
    hDebugPrint('DatabaseHelper: Deleting from files table');
    await db.delete('files', where: 'dict_id = ?', whereArgs: [id]);

    hDebugPrint('DatabaseHelper: Dictionary delete complete for id=$id');
  }

  Future<void> optimizeDatabase() async {
    final db = await database;
    try {
      await db.execute("INSERT INTO word_index(word_index) VALUES('optimize')");
      await db.execute('VACUUM');

      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');

      hDebugPrint('Database optimized and vacuumed successfully');
    } catch (e) {
      hDebugPrint('Error vacuuming database: $e');
    }
  }

  Future<int> getDatabaseSize() async {
    String path;
    if (kIsWeb) {
      path = 'hdict_v4.db';
    } else {
      try {
        Directory documentsDirectory = await getApplicationDocumentsDirectory();
        path = join(documentsDirectory.path, 'novalex.db');
      } catch (e) {
        hDebugPrint('Error getting documents directory: $e');
        return 0;
      }
    }

    try {
      final dir = Directory(dirname(path));
      int totalSize = 0;

      await for (final entity in dir.list()) {
        final fileName = basename(entity.path);
        if (fileName.startsWith('novalex.db') || fileName.startsWith('hdict')) {
          totalSize += await File(entity.path).length();
        }
      }

      return totalSize;
    } catch (e) {
      hDebugPrint('Error getting database size: $e');
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> getDictionaries() async {
    if (_dictionaryCache != null) return _dictionaryCache!;
    try {
      final db = await database;
      _dictionaryCache = await db.query(
        'dictionaries',
        orderBy: 'display_order ASC',
      );
      return _dictionaryCache!;
    } catch (e) {
      hDebugPrint('Error getting dictionaries: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getEnabledDictionaries() async {
    final all = await getDictionaries();
    return all.where((d) => d['is_enabled'] == 1).toList();
  }

  Future<bool> isDictionaryUrlDownloaded(String url) async {
    try {
      final db = await database;
      final result = await db.query(
        'dictionaries',
        where: 'source_url = ?',
        whereArgs: [url],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      hDebugPrint('Error checking dictionary URL: $e');
      return false;
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
    clearQueryCache();
    clearDictionaryCache();
  }

  Future<void> _ensureDictionaryMapCache() async {
    if (_dictionaryMapCache != null) return;
    final dicts = await getDictionaries();
    _dictionaryMapCache = {for (final d in dicts) d['id'] as int: d};
  }

  Map<String, dynamic>? getDictionaryByIdSync(int id) {
    return _dictionaryMapCache?[id];
  }

  Future<Map<String, dynamic>?> getDictionaryById(int id) async {
    await _ensureDictionaryMapCache();
    return _dictionaryMapCache?[id];
  }

  Future<Map<String, dynamic>?> getDictionaryByChecksum(String checksum) async {
    final db = await database;
    final results = await db.query(
      'dictionaries',
      where: 'checksum = ?',
      whereArgs: [checksum],
    );
    if (results.isNotEmpty) return results.first;
    return null;
  }

  // --- Search History ---

  Future<void> addSearchHistory(
    String word, {
    String searchType = 'Headword Search',
  }) async {
    try {
      final db = await database;
      await db.delete('search_history', where: 'word = ?', whereArgs: [word]);
      await db.insert('search_history', {
        'word': word,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'search_type': searchType,
      });
    } catch (e) {
      hDebugPrint('Error adding search history: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSearchHistory() async {
    try {
      final db = await database;
      return await db.query('search_history', orderBy: 'timestamp DESC');
    } catch (e) {
      hDebugPrint('Error getting search history: $e');
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
      hDebugPrint('Error deleting old search history: $e');
    }
  }

  // --- Flash Card Scores ---

  Future<void> addFlashCardScore(int score, int total, String dictIds) async {
    final db = await database;
    await db.insert('flash_card_scores', {
      'score': score,
      'total': total,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'dict_ids': dictIds,
    });
  }

  Future<List<Map<String, dynamic>>> getFlashCardScores() async {
    final db = await database;
    return await db.query('flash_card_scores', orderBy: 'timestamp DESC');
  }

  // --- Indexing ---

  Future<int> startBatchInsert() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COALESCE(MAX(id), 0) as max_id FROM word_metadata",
    );
    return (result.first['max_id'] as int?) ?? 0;
  }

  Future<void> endBatchInsert() async {
    final db = await database;
    // Restore synchronous to NORMAL after bulk insert
    await db.execute('PRAGMA synchronous = NORMAL');
    clearQueryCache();
    clearDictionaryCache();
  }

  Future<void> enableBulkInsertMode() async {
    final db = await database;
    await db.execute('PRAGMA synchronous = OFF');
    await db.execute('PRAGMA cache_size = 64000'); // 64MB cache
    final result = await db.rawQuery('PRAGMA synchronous');
    hDebugPrint(
      'DatabaseHelper: PRAGMA synchronous = ${result.first.values.first}',
    );
  }

  Future<({int startId, int duplicateCount})> batchInsertWords(
    int dictId,
    List<Map<String, dynamic>> words, {
    int? startId,
    bool populateFts5 = true,
    String? dictName,
  }) async {
    if (words.isEmpty) return (startId: startId ?? 0, duplicateCount: 0);
    final db = await database;
    return await db.transaction<({int startId, int duplicateCount})>((
      txn,
    ) async {
      final bool useFts5 = (_fts5Available ?? true) && populateFts5;
      int newStartId = startId ?? 0;
      int duplicateCount = 0;

      if (useFts5) {
        final List<String> tokenizedContents = words
            .map((w) => _tokenizeContent(w['content'] as String?))
            .toList();

        final metaBatch = txn.batch();
        for (final word in words) {
          metaBatch.insert('word_metadata', {
            'word': word['word'],
            'dict_id': dictId,
            'offset': word['offset'],
            'length': word['length'],
          });
        }
        final metaResults = await metaBatch.commit(noResult: false);

        final idxBatch = txn.batch();
        for (int i = 0; i < words.length; i++) {
          final int actualInsertedId = metaResults[i] as int;
          idxBatch.rawInsert(
            'INSERT OR IGNORE INTO word_index(rowid, word, content) VALUES (?, ?, ?)',
            [actualInsertedId, words[i]['word'], tokenizedContents[i]],
          );
        }
        final idxResult = await idxBatch.commit(noResult: false);

        for (final r in idxResult) {
          if (r == 0) duplicateCount++;
        }
        if (duplicateCount > 0) {
          final dupWords = words
              .skip(duplicateCount > 10 ? 0 : 0)
              .take(duplicateCount > 10 ? 10 : duplicateCount)
              .map((w) => w['word'] as String)
              .toList();
          final suffix = duplicateCount > 10 ? ' (first 10 shown)' : '';
          hDebugPrint(
            'DatabaseHelper: Skipped $duplicateCount duplicate entries in "$dictName"$suffix: $dupWords',
          );
        }

        newStartId = (metaResults.last as int);
      } else {
        final batch = txn.batch();
        for (final word in words) {
          batch.insert('word_metadata', {
            'word': word['word'],
            'dict_id': dictId,
            'offset': word['offset'],
            'length': word['length'],
          });
        }
        await batch.commit(noResult: true);
      }
      return (startId: newStartId, duplicateCount: duplicateCount);
    });
  }

  /// Rebuilds FTS5 index for a specific dictionary in the background.
  /// This is called after import when populateFts5 was false.
  Future<void> rebuildFts5IndexForDict(int dictId) async {
    final db = await database;
    if (_fts5Available != true) return;

    hDebugPrint('DatabaseHelper: Rebuilding FTS5 index for dict_id=$dictId');

    // Get all word_metadata for this dictionary
    final words = await db.query(
      'word_metadata',
      where: 'dict_id = ?',
      whereArgs: [dictId],
    );

    if (words.isEmpty) return;

    await db.delete(
      'word_index',
      where: 'rowid IN (SELECT id FROM word_metadata WHERE dict_id = ?)',
      whereArgs: [dictId],
    );

    const batchSize = 50000;
    for (int i = 0; i < words.length; i += batchSize) {
      final end = (i + batchSize < words.length) ? words.length : i + batchSize;
      final batch = words.sublist(i, end);

      final idxBatch = db.batch();
      for (int j = 0; j < batch.length; j++) {
        final word = batch[j];
        final content = word['content'] as String?;
        final tokenized = _tokenizeContent(content);
        idxBatch.rawInsert(
          'INSERT OR IGNORE INTO word_index(rowid, word, content) VALUES (?, ?, ?)',
          [word['id'], word['word'], tokenized],
        );
      }
      await idxBatch.commit(noResult: true);
    }

    await db.execute("INSERT INTO word_index(word_index) VALUES('optimize')");

    hDebugPrint('DatabaseHelper: FTS5 index rebuilt for dict_id=$dictId');
  }

  Future<List<Map<String, dynamic>>> searchWords({
    String? headwordQuery,
    SearchMode headwordMode = SearchMode.prefix,
    String? definitionQuery,
    SearchMode definitionMode = SearchMode.substring,
    int? dictId,
    int limit = 50,
  }) async {
    // Check cache FIRST before any DB calls - use simple cache key
    // (dictOrderKey affects result ordering but not results themselves)
    final String cacheKey =
        '$headwordQuery|$headwordMode|$definitionQuery|$definitionMode|$dictId|$limit';
    final cachedResults = _getFromQueryCache(cacheKey);
    if (cachedResults != null) {
      HPerf.record('searchWords_CacheHit', 0);
      hDebugPrint('DatabaseHelper: Query cache HIT for $cacheKey');
      return cachedResults;
    }

    final dbWatch = HPerf.start('searchWords_TotalExecution');
    try {
      final db = await database;

      // OPTIMIZATION: If this is a simple headword search (no multi-dictionary definition search),
      // we can iterate through dictionaries sequentially to avoid the expensive cross-table SQLite sort.
      if (definitionQuery == null &&
          (headwordMode == SearchMode.prefix ||
              headwordMode == SearchMode.exact)) {
        final res = await _searchWordsSequential(
          headwordQuery: headwordQuery,
          headwordMode: headwordMode,
          dictId: dictId,
          limit: limit,
        );
        _addToQueryCache(cacheKey, res);
        HPerf.end(dbWatch, 'searchWords_TotalExecution');
        return res;
      }

      final List<String> whereClauses = [];
      final List<Object?> whereArgs = [];
      bool needsFts5Join = false; // only JOIN word_index when MATCH is used

      whereClauses.add(
        'm.dict_id IN (SELECT id FROM dictionaries WHERE is_enabled = 1)',
      );

      // 1. Process Headword Query
      if (headwordQuery != null && headwordQuery.trim().isNotEmpty) {
        final String hq = headwordQuery.trim();

        // Helper to safely convert user query to FTS5 AND query avoiding phrase query issues
        String toFts5Query(String query, bool isPrefix) {
          final terms = query.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
          if (terms.isEmpty) return '';
          return terms
              .map((t) {
                // For FTS5, we can only use prefix matching. If there's a wildcard
                // elsewhere, we use the part before it to narrow down results.
                int wildcardIdx = t.indexOf(RegExp(r'[*?]'));
                String cleanPart = wildcardIdx != -1
                    ? t.substring(0, wildcardIdx)
                    : t;
                String clean = cleanPart.replaceAll(RegExp(r'["\(\)]'), '');
                if (clean.isEmpty) return '';
                return (isPrefix || wildcardIdx != -1) ? '$clean*' : clean;
              })
              .where((s) => s.isNotEmpty)
              .join(' AND ');
        }

        switch (headwordMode) {
          case SearchMode.exact:
            if (_fts5Available ?? true) {
              final ftsQuery = toFts5Query(hq, false);
              if (ftsQuery.isNotEmpty) {
                whereClauses.add('i.word MATCH ?');
                whereArgs.add(ftsQuery);

                final bool hasWildcards = hq.contains('*') || hq.contains('?');
                if (hasWildcards) {
                  whereClauses.add('m.word LIKE ?');
                  whereArgs.add(_translateWildcards(hq));
                } else {
                  whereClauses.add('m.word = ?');
                  whereArgs.add(hq);
                }
                needsFts5Join = true;
              }
            } else {
              final bool hasWildcards = hq.contains('*') || hq.contains('?');
              if (hasWildcards) {
                whereClauses.add('m.word LIKE ?');
                whereArgs.add(_translateWildcards(hq));
              } else {
                whereClauses.add('m.word = ?');
                whereArgs.add(hq);
              }
            }
            break;
          case SearchMode.prefix:
            if (_fts5Available ?? true) {
              final ftsQuery = toFts5Query(hq, true);
              if (ftsQuery.isNotEmpty) {
                whereClauses.add('i.word MATCH ?');
                whereArgs.add(ftsQuery);
                // Augment with SQL LIKE to ensure precise prefix matching.
                // With NOCASE collation, LIKE is now index-optimized.
                final translatedHq = _translateWildcards(hq);
                whereClauses.add('m.word LIKE ?');
                whereArgs.add('$translatedHq%');
                needsFts5Join = true;
              }
            } else {
              final translatedHq = _translateWildcards(hq);
              whereClauses.add('m.word LIKE ?');
              whereArgs.add('$translatedHq%');
            }
            break;
          case SearchMode.suffix:
            // FTS5 does not support suffix wildcards - always use LIKE on metadata
            whereClauses.add('m.word LIKE ?');
            whereArgs.add('%$hq');
            break;
          case SearchMode.substring:
            // FTS5 does not support leading wildcards - always use LIKE on metadata
            whereClauses.add('m.word LIKE ?');
            whereArgs.add('%$hq%');
            break;
        }
      }

      if (dictId != null) {
        whereClauses.add('m.dict_id = ?');
        whereArgs.add(dictId);
      }

      if (definitionQuery != null) {
        // FTS5 contentless tables ONLY support MATCH - no LIKE on content.
        final String dq = definitionQuery.trim();
        final terms = dq.split(RegExp(r'\s+')).where((s) => s.isNotEmpty);

        if (terms.isNotEmpty) {
          final bool isPrefixSearch =
              definitionMode == SearchMode.substring ||
              definitionMode == SearchMode.prefix;

          final ftsQuery = terms
              .map((t) {
                String clean = t.replaceAll(RegExp(r'["*\(\)]'), '');
                return isPrefixSearch ? '$clean*' : clean;
              })
              .join(' AND ');

          if (ftsQuery.isNotEmpty) {
            whereClauses.add('i.content MATCH ?');
            whereArgs.add(ftsQuery);
            needsFts5Join = true;
          }
        }
      }

      // If no search terms, return empty
      if (whereArgs.isEmpty) return [];

      // Only JOIN word_index when a MATCH clause is actually used
      final bool useFts5 = _fts5Available ?? true;
      final String fromClause;
      if (!useFts5) {
        // FTS5 unavailable: word_index is a plain table with all columns
        fromClause =
            'FROM word_index m JOIN dictionaries d ON m.dict_id = d.id';
      } else if (needsFts5Join) {
        fromClause =
            'FROM word_metadata m JOIN word_index i ON m.id = i.rowid JOIN dictionaries d ON m.dict_id = d.id';
      } else {
        // Suffix/substring headword search: just query word_metadata, no FTS5
        fromClause =
            'FROM word_metadata m JOIN dictionaries d ON m.dict_id = d.id';
      }

      // For combined searches with definition query, simplify ORDER BY to avoid slow sorting
      // The definition query already filters heavily, so exact ordering is less critical
      final bool isCombinedSearch =
          definitionQuery != null && headwordQuery != null;
      String orderBy;
      if (isCombinedSearch) {
        // Simplified: just order by dict priority, then word
        orderBy = 'd.display_order ASC, m.word ASC';
      } else {
        orderBy =
            '''
          d.display_order ASC,
          ${headwordQuery != null ? "(m.word = ?) DESC," : ""}
          m.word ASC,
          d.id ASC
        ''';
      }

      final String sql =
          '''
        SELECT m.word, m.dict_id, m.offset, m.length 
        $fromClause
        WHERE ${whereClauses.join(' AND ')}
        ORDER BY $orderBy
        LIMIT ?
      ''';

      if (headwordQuery != null && !isCombinedSearch) {
        whereArgs.add(headwordQuery.trim());
      }
      whereArgs.add(limit);

      final bool hasWildcards =
          (headwordQuery?.contains('*') ?? false) ||
          (headwordQuery?.contains('?') ?? false);
      final String opDescriptor = hasWildcards
          ? 'LIKE (Wildcard)'
          : (headwordMode == SearchMode.prefix ? 'LIKE (Prefix)' : '=');

      hDebugPrint(
        'DatabaseHelper.searchWords: Executing query for "$headwordQuery" (mode=$headwordMode, op=$opDescriptor)',
      );
      final result = await db.rawQuery(sql, whereArgs);
      hDebugPrint(
        'DatabaseHelper.searchWords: Query returned ${result.length} results for "$headwordQuery"',
      );
      _log('RAW_QUERY [$opDescriptor]', sql, whereArgs, result);
      _addToQueryCache(cacheKey, result);
      HPerf.end(dbWatch, 'searchWords_TotalExecution');
      return result;
    } catch (e) {
      HPerf.end(dbWatch, 'searchWords_TotalExecution');
      hDebugPrint("Search error: $e");
      return [];
    }
  }

  /// Sequential dictionary search to leverage indexing and avoid global sorts.
  Future<List<Map<String, dynamic>>> _searchWordsSequential({
    String? headwordQuery,
    required SearchMode headwordMode,
    int? dictId,
    required int limit,
  }) async {
    final db = await database;
    final String hq = headwordQuery?.trim() ?? '';
    if (hq.isEmpty) return [];

    // 1. Get enabled dictionaries in order
    final List<Map<String, dynamic>> dicts;
    if (dictId != null) {
      final d = await getDictionaryById(dictId);
      dicts = (d != null && d['is_enabled'] == 1) ? [d] : [];
    } else {
      dicts = await getEnabledDictionaries();
    }

    if (dicts.isEmpty) return [];

    final bool hasWildcards = hq.contains('*') || hq.contains('?');
    final String translatedHq = _translateWildcards(hq);

    final String likePattern;
    final String operator;

    if (headwordMode == SearchMode.prefix) {
      operator = 'LIKE';
      likePattern = '$translatedHq%';
    } else if (hasWildcards) {
      operator = 'LIKE';
      likePattern = translatedHq;
    } else {
      operator = '=';
      likePattern = hq;
    }

    // 2. Build multi-query using UNION ALL to fetch early limits per dictionary natively,
    // avoiding the overhead of N sequential Flutter-to-Native SQLite method channels.
    // By nesting, we ensure each table lookup stops at `limit` internally.
    final List<String> subQueries = [];
    final List<Object?> args = [];

    for (int i = 0; i < dicts.length; i++) {
      final sortOrder = dicts[i]['display_order'] as int? ?? i;
      subQueries.add('''
        SELECT * FROM (
          SELECT word, dict_id, offset, length, ? as sort_order 
          FROM word_metadata 
          WHERE dict_id = ? AND word $operator ? 
          ORDER BY word ASC LIMIT ?
        )
      ''');
      args.addAll([sortOrder, dicts[i]['id'], likePattern, limit]);
    }

    final String finalSql =
        '''
      SELECT word, dict_id, offset, length 
      FROM (
        ${subQueries.join(' UNION ALL ')}
      )
      ORDER BY sort_order ASC, dict_id ASC, word ASC
      LIMIT ?
    ''';
    args.add(limit);

    final results = await db.rawQuery(finalSql, args);

    _log(
      'UNION_ALL_QUERY [$operator]',
      'SELECT ... UNION ALL ... LIMIT $limit',
      ['[IDs of \${dicts.length} dicts]', likePattern],
      results,
    );
    return results;
  }

  Future<List<String>> getPrefixSuggestions(
    String prefix, {
    int limit = 10,
    bool fuzzy = false,
  }) async {
    try {
      final db = await database;
      // prefix may have quotes, clean them
      final String cleanPrefix = prefix
          .replaceAll(RegExp(r'["*\(\)]'), '')
          .trim();
      final bool useFts5 = _fts5Available ?? true;
      final String fallbackTable = useFts5 ? 'word_metadata' : 'word_index';

      // Use sequential search for standard prefix suggestions to leverage idx_metadata_dict_word
      if (!fuzzy && !cleanPrefix.contains(' ')) {
        final List<Map<String, dynamic>> dicts = await getEnabledDictionaries();
        final List<String> suggestions = [];

        for (final dict in dicts) {
          // dicts already filtered by is_enabled

          final int currentLimit = limit - suggestions.length;
          if (currentLimit <= 0) break;

          final results = await db.query(
            'word_metadata',
            columns: ['word'],
            where: 'dict_id = ? AND word LIKE ?',
            whereArgs: [dict['id'], '$cleanPrefix%'],
            orderBy: 'word ASC',
            limit: currentLimit,
          );

          for (var r in results) {
            String w = r['word'] as String;
            if (!suggestions.contains(w)) suggestions.add(w);
          }
        }
        _log(
          'SEQUENTIAL_SUGGEST (Prefix)',
          'Iterated ${dicts.length} dicts',
          [cleanPrefix, limit],
          suggestions,
        );
        return suggestions;
      }

      // Fallback for fuzzy/multi-word/no-FTS suggestions
      final String sql =
          '''
        SELECT DISTINCT word 
        FROM $fallbackTable 
        WHERE dict_id IN (SELECT id FROM dictionaries WHERE is_enabled = 1) 
        AND word LIKE ?
        ORDER BY word ASC
        LIMIT ?
      ''';
      final results = await db.rawQuery(sql, [
        fuzzy ? '%$cleanPrefix%' : '$cleanPrefix%',
        limit,
      ]);
      _log('RAW_QUERY (Suggest Fallback)', sql, [cleanPrefix, limit], results);
      return results.map((r) => r['word'] as String).toList();
    } catch (e) {
      hDebugPrint('Error getting prefix suggestions: $e');
      return [];
    }
  }

  // --- FreeDict Cache ---

  Future<void> insertFreedictDictionaries(
    List<Map<String, dynamic>> dictionaries,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('freedict_dictionaries');
      final batch = txn.batch();
      for (final dict in dictionaries) {
        batch.insert('freedict_dictionaries', dict);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> getFreedictDictionaries() async {
    final db = await database;
    return await db.query('freedict_dictionaries');
  }

  Future<void> clearFreedictDictionaries() async {
    final db = await database;
    await db.delete('freedict_dictionaries');
  }
}
