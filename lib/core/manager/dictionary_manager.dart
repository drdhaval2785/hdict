import 'package:hdict/core/utils/logger.dart';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:hdict/core/database/database_helper.dart';
import 'package:hdict/core/parser/ifo_parser.dart';
import 'package:hdict/core/parser/idx_parser.dart';
import 'package:hdict/core/parser/syn_parser.dart';
import 'package:hdict/core/parser/dict_reader.dart';
import 'package:hdict/core/parser/mdict_reader.dart';
import 'package:hdict/core/parser/slob_reader.dart';
import 'package:hdict/core/parser/dictd_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_7zip/flutter_7zip.dart';
import 'package:hdict/core/utils/folder_scanner.dart';
import 'package:docman/docman.dart';
import 'package:hdict/core/parser/bookmark_manager.dart';

// Top-level functions for compute
List<int> _decompressGzip(List<int> bytes) {
  return GZipDecoder().decodeBytes(bytes);
}

List<int> _decompressBZip2(List<int> bytes) {
  return BZip2Decoder().decodeBytes(bytes);
}

List<int> _decompressXZ(List<int> bytes) {
  return XZDecoder().decodeBytes(bytes);
}

// New classes for progress and isolate arguments
class ImportProgress {
  final String message;
  final double value; // 0.0 to 1.0
  final bool isCompleted;
  final int? dictId;
  final String? error;
  final String? ifoPath;
  final List<String>? sampleWords;
  final int headwordCount;
  final int definitionWordCount;
  final String? dictionaryName;

  /// Dictionaries that were skipped due to missing mandatory files.
  /// Each entry is a human-readable string, e.g.:
  ///   "mydict (StarDict): missing .idx, .dict / .dict.dz"
  final List<String>? incompleteEntries;

  /// The suggested group name for the dictionary.
  final String? groupName;

  ImportProgress({
    required this.message,
    required this.value,
    this.isCompleted = false,
    this.dictId,
    this.error,
    this.ifoPath,
    this.sampleWords,
    this.headwordCount = 0,
    this.definitionWordCount = 0,
    this.dictionaryName,
    this.incompleteEntries,
    this.groupName,
  });
}

class DeletionProgress {
  final String message;
  final double value;
  final bool isCompleted;
  final String? error;

  DeletionProgress({
    required this.message,
    required this.value,
    this.isCompleted = false,
    this.error,
  });
}

// Data class to pass to isolate
class _ImportArgs {
  final String archivePath;
  final String tempDirPath;
  final SendPort sendPort;
  final RootIsolateToken rootIsolateToken;

  _ImportArgs(
    this.archivePath,
    this.tempDirPath,
    this.sendPort,
    this.rootIsolateToken,
  );
}

// Data class for indexing isolate
class _IndexArgs {
  final int dictId;
  final String idxPath;
  final String dictPath;
  final String? synPath;
  final bool indexDefinitions;
  final IfoParser ifoParser;
  final String? sourceType;
  final String? sourceBookmark;
  final SendPort sendPort;
  final RootIsolateToken rootIsolateToken;

  _IndexArgs(
    this.dictId,
    this.idxPath,
    this.dictPath,
    this.synPath,
    this.indexDefinitions,
    this.ifoParser,
    this.sourceType,
    this.sourceBookmark,
    this.sendPort,
    this.rootIsolateToken,
  );
}

class _IndexMdictArgs {
  final int dictId;
  final String mdxPath;
  final bool indexDefinitions;
  final String bookName;
  final String? sourceType;
  final String? sourceBookmark;
  final SendPort sendPort;
  final RootIsolateToken rootIsolateToken;

  _IndexMdictArgs({
    required this.dictId,
    required this.mdxPath,
    required this.indexDefinitions,
    required this.bookName,
    this.sourceType,
    this.sourceBookmark,
    required this.sendPort,
    required this.rootIsolateToken,
  });
}

class _IndexSlobArgs {
  final int dictId;
  final String slobPath;
  final bool indexDefinitions;
  final String bookName;
  final String? sourceType;
  final String? sourceBookmark;
  final SendPort sendPort;
  final RootIsolateToken rootIsolateToken;

  _IndexSlobArgs({
    required this.dictId,
    required this.slobPath,
    required this.indexDefinitions,
    required this.bookName,
    this.sourceType,
    this.sourceBookmark,
    required this.sendPort,
    required this.rootIsolateToken,
  });
}

class _IndexDictdArgs {
  final int dictId;
  final String indexPath;
  final String dictPath;
  final bool indexDefinitions;
  final String bookName;
  final String? sourceType;
  final String? sourceBookmark;
  final SendPort sendPort;
  final RootIsolateToken rootIsolateToken;

  _IndexDictdArgs({
    required this.dictId,
    required this.indexPath,
    required this.dictPath,
    required this.indexDefinitions,
    required this.bookName,
    this.sourceType,
    this.sourceBookmark,
    required this.sendPort,
    required this.rootIsolateToken,
  });
}

// Top-level function for indexing isolate
Future<void> _indexEntry(_IndexArgs args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootIsolateToken);
  await DatabaseHelper.initializeDatabaseFactory();
  final SendPort sendPort = args.sendPort;
  final dbHelper = DatabaseHelper(); // Assumes singleton or initialized factory

  try {
    final idxParser = IdxParser(args.ifoParser);
    final stream = idxParser.parse(args.idxPath);
    final dictReader =
        args.sourceType == 'linked' && args.sourceBookmark != null
        ? await DictReader.fromUri(args.sourceBookmark!)
        : await DictReader.fromPath(args.dictPath);
    await dictReader.open();

    List<({int offset, int length, String content})> wordOffsets = [];

    final List<Map<String, dynamic>> entriesList = [];
    await for (final entry in stream) {
      entriesList.add(entry);
    }

    final int totalHeadwords = entriesList.length;
    // synWordCount comes from the .ifo file — known before opening the .syn file
    final int totalSyns = args.ifoParser.synWordCount;
    final int totalAll = totalHeadwords + totalSyns; // unified denominator
    int headwordCount = 0;
    int defWordCount = 0;
    const int readBatchSize = 100;
    const int dbBatchSize = 10000;
    List<Map<String, dynamic>> dbBatch = [];

    for (int i = 0; i < totalHeadwords; i += readBatchSize) {
      final end = (i + readBatchSize < totalHeadwords)
          ? i + readBatchSize
          : totalHeadwords;
      final currentBatch = entriesList.sublist(i, end);

      final List<({int offset, int length})> readEntries = currentBatch
          .map((e) => (offset: e['offset'] as int, length: e['length'] as int))
          .toList();

      final List<String> contents = args.indexDefinitions
          ? await dictReader.readBulk(readEntries)
          : List.filled(currentBatch.length, '');

      for (int j = 0; j < currentBatch.length; j++) {
        final entry = currentBatch[j];
        final content = contents[j];
        final word = entry['word'] as String;
        final offset = entry['offset'] as int;
        final length = entry['length'] as int;

        wordOffsets.add((offset: offset, length: length, content: content));

        dbBatch.add({
          'word': word,
          'content': content,
          'dict_id': args.dictId,
          'offset': offset,
          'length': length,
        });

        headwordCount++;
        if (args.indexDefinitions && content.isNotEmpty) {
          defWordCount += content
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty)
              .length;
        }

        if (dbBatch.length >= dbBatchSize) {
          await dbHelper.batchInsertWords(args.dictId, dbBatch);
          dbBatch.clear();
          sendPort.send(
            ImportProgress(
              message:
                  '${args.ifoParser.bookName}: $headwordCount / $totalAll indexed',
              value:
                  0.5 + (headwordCount / (totalAll == 0 ? 1 : totalAll)) * 0.45,
              headwordCount: headwordCount,
              definitionWordCount: defWordCount,
              dictionaryName: args.ifoParser.bookName,
            ),
          );
        }
      }
    }
    if (dbBatch.isNotEmpty)
      await dbHelper.batchInsertWords(args.dictId, dbBatch);

    if (args.synPath != null) {
      final synParser = SynParser();
      List<Map<String, dynamic>> synBatch = [];
      await for (final syn in synParser.parse(args.synPath!)) {
        final originalIndex = syn['original_word_index'] as int;
        if (originalIndex < wordOffsets.length) {
          final originalInfo = wordOffsets[originalIndex];
          synBatch.add({
            'word': syn['word'],
            'content': originalInfo.content,
            'dict_id': args.dictId,
            'offset': originalInfo.offset,
            'length': originalInfo.length,
          });
          headwordCount++;
        }
        if (synBatch.length >= 10000) {
          await dbHelper.batchInsertWords(args.dictId, synBatch);
          synBatch.clear();
          sendPort.send(
            ImportProgress(
              message:
                  '${args.ifoParser.bookName}: $headwordCount / $totalAll indexed',
              value:
                  0.5 + (headwordCount / (totalAll == 0 ? 1 : totalAll)) * 0.45,
              headwordCount: headwordCount,
              definitionWordCount: defWordCount,
              dictionaryName: args.ifoParser.bookName,
            ),
          );
        }
      }
      if (synBatch.isNotEmpty) {
        await dbHelper.batchInsertWords(args.dictId, synBatch);
      }
    }

    await dictReader.close();
    await dbHelper.updateDictionaryWordCount(
      args.dictId,
      headwordCount,
      defWordCount,
    );

    sendPort.send(
      ImportProgress(
        message:
            '${args.ifoParser.bookName}: $headwordCount headwords, $defWordCount words in definition',
        value: 1.0,
        isCompleted: true,
        headwordCount: headwordCount,
        definitionWordCount: defWordCount,
        dictionaryName: args.ifoParser.bookName,
      ),
    );
  } catch (e, s) {
    hDebugPrint('Error in _indexEntry: $e\n$s');
    sendPort.send(
      ImportProgress(
        message: 'Error during indexing: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      ),
    );
  }
}

// Top-level function for MDict indexing isolate
Future<void> _indexMdictEntry(_IndexMdictArgs args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootIsolateToken);
  await DatabaseHelper.initializeDatabaseFactory();
  final dbHelper = DatabaseHelper();
  final sendPort = args.sendPort;

  try {
    final reader = args.sourceType == 'linked' && args.sourceBookmark != null
        ? await MdictReader.fromUri(args.sourceBookmark!)
        : await MdictReader.fromPath(args.mdxPath);
    await reader.open();

    // Fetch all keys via prefix search with empty prefix
    final allKeys = await reader.prefixSearch('', limit: 500000);
    final totalKeys = allKeys.length;

    List<Map<String, dynamic>> batch = [];
    int indexed = 0;
    int defWordCount = 0;

    for (final word in allKeys) {
      String content = '';
      if (args.indexDefinitions) {
        content = await reader.lookup(word) ?? '';
      }

      batch.add({
        'word': word,
        'content': content,
        'dict_id': args.dictId,
        'offset': 0,
        'length': 0,
      });
      indexed++;
      if (args.indexDefinitions && content.isNotEmpty) {
        defWordCount += content
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length;
      }

      if (batch.length >= 10000) {
        await dbHelper.batchInsertWords(args.dictId, batch);
        batch.clear();
        sendPort.send(
          ImportProgress(
            message:
                '${args.bookName}: $indexed / $totalKeys headwords indexed',
            value: 0.5 + (indexed / (totalKeys == 0 ? 1 : totalKeys)) * 0.45,
            headwordCount: indexed,
            definitionWordCount: defWordCount,
            dictionaryName: args.bookName,
          ),
        );
      }
    }

    if (batch.isNotEmpty) await dbHelper.batchInsertWords(args.dictId, batch);
    await reader.close();
    await dbHelper.updateDictionaryWordCount(
      args.dictId,
      indexed,
      defWordCount,
    );

    sendPort.send(
      ImportProgress(
        message: 'MDict indexing complete!',
        value: 1.0,
        isCompleted: true,
        headwordCount: indexed,
        definitionWordCount: defWordCount,
        dictionaryName: args.bookName,
      ),
    );
  } catch (e, s) {
    hDebugPrint('MDict indexing error: $e\n$s');
    sendPort.send(
      ImportProgress(
        message: 'MDict indexing error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      ),
    );
  }
}

// Top-level function for Slob indexing isolate
Future<void> _indexSlobEntry(_IndexSlobArgs args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootIsolateToken);
  await DatabaseHelper.initializeDatabaseFactory();
  final dbHelper = DatabaseHelper();
  final sendPort = args.sendPort;

  try {
    final reader = args.sourceType == 'linked' && args.sourceBookmark != null
        ? await SlobReader.fromUri(args.sourceBookmark!)
        : await SlobReader.fromPath(args.slobPath);
    await reader.open();

    int headwordCount = 0;
    int defWordCount = 0;
    final totalBlobs = reader.blobCount;
    // Use larger batches — getBlobs() decompresses each bin once, so bigger
    // batches hit fewer bins per call and yield best throughput.
    const int readBatchSize = 500;
    const int dbBatchSize = 10000;
    List<Map<String, dynamic>> dbBatch = [];

    for (int i = 0; i < totalBlobs; i += readBatchSize) {
      final batchCount = (i + readBatchSize < totalBlobs)
          ? readBatchSize
          : totalBlobs - i;

      // getBlobs([(start, length)]) reads key + content in a single pass,
      // decompressing each compressed bin only once — no double-fetching.
      final List<SlobBlob> blobs = await reader.getBlobsByRange(i, batchCount);

      for (final blob in blobs) {
        final content = args.indexDefinitions
            ? utf8.decode(blob.content, allowMalformed: true)
            : '';

        dbBatch.add({
          'word': blob.key,
          'content': content,
          'dict_id': args.dictId,
          'offset': blob.id,
          'length': blob.content.length,
        });

        headwordCount++;
        if (args.indexDefinitions && content.isNotEmpty) {
          defWordCount += content
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty)
              .length;
        }

        if (dbBatch.length >= dbBatchSize) {
          await dbHelper.batchInsertWords(args.dictId, dbBatch);
          dbBatch.clear();
          sendPort.send(
            ImportProgress(
              message:
                  '${args.bookName}: $headwordCount / $totalBlobs headwords indexed',
              value:
                  0.45 +
                  (headwordCount / (totalBlobs == 0 ? 1 : totalBlobs)) * 0.5,
              headwordCount: headwordCount,
              definitionWordCount: defWordCount,
              dictionaryName: args.bookName,
            ),
          );
        }
      }

      // Send progress after every read-batch (ensures UI updates even when
      // dbBatch hasn't filled yet, e.g. small dictionaries).
      sendPort.send(
        ImportProgress(
          message:
              '${args.bookName}: $headwordCount / $totalBlobs headwords indexed',
          value:
              0.45 + (headwordCount / (totalBlobs == 0 ? 1 : totalBlobs)) * 0.5,
          headwordCount: headwordCount,
          definitionWordCount: defWordCount,
          dictionaryName: args.bookName,
        ),
      );
    }

    if (dbBatch.isNotEmpty)
      await dbHelper.batchInsertWords(args.dictId, dbBatch);
    await reader.close();
    await dbHelper.updateDictionaryWordCount(
      args.dictId,
      headwordCount,
      defWordCount,
    );

    sendPort.send(
      ImportProgress(
        message:
            '${args.bookName}: $headwordCount headwords, $defWordCount words in definition',
        value: 1.0,
        isCompleted: true,
        headwordCount: headwordCount,
        definitionWordCount: defWordCount,
        dictionaryName: args.bookName,
      ),
    );
  } catch (e, s) {
    hDebugPrint('Slob indexing error: $e\n$s');
    sendPort.send(
      ImportProgress(
        message: 'Slob indexing error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      ),
    );
  }
}

// Top-level function for DICTD indexing isolate
Future<void> _indexDictdEntry(_IndexDictdArgs args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootIsolateToken);
  await DatabaseHelper.initializeDatabaseFactory();
  final dbHelper = DatabaseHelper();
  final sendPort = args.sendPort;

  try {
    final dictdParser = DictdParser();
    final dictdReader =
        args.sourceType == 'linked' && args.sourceBookmark != null
        ? await DictdReader.fromUri(args.sourceBookmark!)
        : await DictdReader.fromPath(args.dictPath);
    await dictdReader.open();
    final indexStream = dictdParser.parseIndex(args.indexPath);

    final List<Map<String, dynamic>> entriesList = [];
    await for (final entry in indexStream) {
      entriesList.add(entry);
    }

    final int totalHeadwords = entriesList.length;
    int headwordCount = 0;
    int defWordCount = 0;
    const int readBatchSize = 100;
    const int dbBatchSize = 10000;
    List<Map<String, dynamic>> dbBatch = [];

    for (int i = 0; i < totalHeadwords; i += readBatchSize) {
      final end = (i + readBatchSize < totalHeadwords)
          ? i + readBatchSize
          : totalHeadwords;
      final currentBatch = entriesList.sublist(i, end);

      final List<({int offset, int length})> readEntries = currentBatch
          .map((e) => (offset: e['offset'] as int, length: e['length'] as int))
          .toList();

      final List<String> contents = args.indexDefinitions
          ? await dictdReader.readEntries(readEntries)
          : List.filled(currentBatch.length, '');

      for (int j = 0; j < currentBatch.length; j++) {
        final entry = currentBatch[j];
        final content = contents[j];
        final word = entry['word'] as String;
        final offset = entry['offset'] as int;
        final length = entry['length'] as int;

        dbBatch.add({
          'word': word,
          'content': content,
          'dict_id': args.dictId,
          'offset': offset,
          'length': length,
        });
        headwordCount++;
        if (args.indexDefinitions && content.isNotEmpty) {
          defWordCount += content
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty)
              .length;
        }

        if (dbBatch.length >= dbBatchSize) {
          await dbHelper.batchInsertWords(args.dictId, dbBatch);
          dbBatch.clear();
          sendPort.send(
            ImportProgress(
              message:
                  '${args.bookName}: $headwordCount / $totalHeadwords headwords indexed',
              value:
                  0.45 +
                  (headwordCount / (totalHeadwords == 0 ? 1 : totalHeadwords)) *
                      0.5,
              headwordCount: headwordCount,
              definitionWordCount: defWordCount,
              dictionaryName: args.bookName,
            ),
          );
        }
      }
    }

    if (dbBatch.isNotEmpty)
      await dbHelper.batchInsertWords(args.dictId, dbBatch);
    await dictdReader.close();
    await dbHelper.updateDictionaryWordCount(
      args.dictId,
      headwordCount,
      defWordCount,
    );

    sendPort.send(
      ImportProgress(
        message:
            '${args.bookName}: $headwordCount headwords, $defWordCount words in definition',
        value: 1.0,
        isCompleted: true,
        headwordCount: headwordCount,
        definitionWordCount: defWordCount,
        dictionaryName: args.bookName,
      ),
    );
  } catch (e, s) {
    hDebugPrint('DICTD indexing error: $e\n$s');
    sendPort.send(
      ImportProgress(
        message: 'DICTD indexing error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      ),
    );
  }
}

// Helper for compute
class _ExtractArgs {
  final String filePath;
  final String workspacePath;
  _ExtractArgs(this.filePath, this.workspacePath);
}

Future<void> _extractToWorkspaceSync(_ExtractArgs args) async {
  final filePath = args.filePath;
  final workspacePath = args.workspacePath;
  try {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    Archive archive;
    final lowerPath = filePath.toLowerCase();

    if (lowerPath.endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bytes);
    } else if (lowerPath.endsWith('.tar.gz') || lowerPath.endsWith('.tgz')) {
      archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    } else if (lowerPath.endsWith('.tar')) {
      archive = TarDecoder().decodeBytes(bytes);
    } else if (lowerPath.endsWith('.tar.bz2') || lowerPath.endsWith('.tbz2')) {
      archive = TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));
    } else if (lowerPath.endsWith('.tar.xz')) {
      try {
        archive = TarDecoder().decodeBytes(XZDecoder().decodeBytes(bytes));
      } catch (e) {
        if (Platform.isMacOS || Platform.isLinux) {
          hDebugPrint(
            'Dart archive package failed to extract .tar.xz ($e). Falling back to system tar.',
          );
          final result = Process.runSync('tar', [
            '-xf',
            filePath,
            '-C',
            workspacePath,
          ]);
          if (result.exitCode != 0) {
            throw Exception('Native tar extraction failed: ${result.stderr}');
          }
          return;
        } else {
          rethrow;
        }
      }
    } else if (lowerPath.endsWith('.7z')) {
      SZArchive.extract(filePath, workspacePath);
      return;
    } else {
      // Not an archive, just copy it
      final fileName = p.basename(filePath);
      final targetPath = p.join(workspacePath, fileName);
      if (filePath == targetPath) return; // Already there
      await File(filePath).copy(targetPath);
      return;
    }

    for (final archiveFile in archive) {
      final filename = archiveFile.name;
      if (archiveFile.isFile) {
        final data = archiveFile.content as List<int>;
        File(p.join(workspacePath, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory(p.join(workspacePath, filename)).createSync(recursive: true);
      }
    }
  } catch (e) {
    hDebugPrint('Error extracting $filePath: $e');
  }
}

// Updated _importEntry to support extracting to a specific workspace and discovering multiple files
Future<void> _extractToWorkspace(String filePath, String workspacePath) async {
  await compute(_extractToWorkspaceSync, _ExtractArgs(filePath, workspacePath));
}

Future<void> _importEntry(_ImportArgs args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootIsolateToken);
  final SendPort sendPort = args.sendPort;
  final String archivePath = args.archivePath;
  final String tempDirPath = args.tempDirPath;

  try {
    sendPort.send(ImportProgress(message: 'Reading archive...', value: 0.05));
    await _extractToWorkspace(archivePath, tempDirPath);

    sendPort.send(
      ImportProgress(message: 'Locating dictionary files...', value: 0.45),
    );

    final scanResult = await scanFolderForDictionaries(
      tempDirPath,
      extractArchives: false, // Already extracted above
    );

    if (scanResult.discovered.isEmpty && scanResult.incomplete.isEmpty) {
      throw Exception('No valid dictionary files found in archive.');
    }

    // Encode discovered as a list of maps and incomplete as human-readable strings
    final discoveredMaps = scanResult.discovered.map((d) => d.toMap()).toList();
    final incompleteMessages = scanResult.incomplete
        .map(
          (i) =>
              '${i.name} (${i.format}): missing ${i.missingFiles.join(', ')}',
        )
        .toList();

    sendPort.send(
      ImportProgress(
        message: 'Extraction complete.',
        value: 0.5,
        isCompleted: true,
        ifoPath: jsonEncode(discoveredMaps),
        incompleteEntries: incompleteMessages.isEmpty
            ? null
            : incompleteMessages,
      ),
    );
  } catch (e, s) {
    hDebugPrint('Error in _importEntry: $e\n$s');
    sendPort.send(
      ImportProgress(
        message: 'Error during extraction: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      ),
    );
  }
}

/// Manages high-level dictionary operations: importing, downloading, and enabling/disabling dictionaries.
class DictionaryManager {
  final DatabaseHelper _dbHelper;
  final http.Client _client;

  static DictionaryManager? _instance;
  static DictionaryManager get instance => _instance ??= DictionaryManager();

  String? _currentImportSourceUrl;

  DictionaryManager({DatabaseHelper? dbHelper, http.Client? client})
    : _dbHelper = dbHelper ?? DatabaseHelper(),
      _client = client ?? http.Client();

  /// Cache of open dictionary readers to avoid re-opening files.
  static final Map<int, dynamic> _readerCache = {};

  /// Per-dictionary locks to prevent concurrent file access on the same reader.
  static final Map<int, Future<void>> _readerLocks = {};

  /// Executes a task while ensuring only one task runs per dictionary ID.
  Future<T> _synchronized<T>(int dictId, Future<T> Function() task) async {
    final prev = _readerLocks[dictId] ?? Future.value();
    final completer = Completer<void>();
    _readerLocks[dictId] = completer.future;

    try {
      await prev;
      return await task();
    } finally {
      completer.complete();
      // Cleanup the lock if no one else is waiting (optional but cleaner)
      if (_readerLocks[dictId] == completer.future) {
        _readerLocks.remove(dictId);
      }
    }
  }

  /// Gets a cached reader or creates a new one.
  Future<dynamic> _getReader(Map<String, dynamic> dict) async {
    final int? dictId = dict['id'] as int?;
    if (dictId == null) return null;

    if (_readerCache.containsKey(dictId)) {
      return _readerCache[dictId];
    }

    final String format = dict['format'];
    final String rawPath = dict['path'];
    final String? sourceType = dict['source_type'];
    final String? sourceBookmark = dict['source_bookmark'];

    dynamic reader;
    if (sourceType == 'linked' && sourceBookmark != null) {
      if (format == 'mdict') {
        reader = await MdictReader.fromLinkedSource(sourceBookmark);
      } else if (format == 'slob') {
        reader = await SlobReader.fromLinkedSource(sourceBookmark);
      } else if (format == 'stardict') {
        reader = await DictReader.fromLinkedSource(sourceBookmark);
      } else if (format == 'dictd') {
        reader = await DictdReader.fromLinkedSource(sourceBookmark);
      }
    } else {
      final String dictPath = await _dbHelper.resolvePath(rawPath);
      if (format == 'mdict') {
        reader = await MdictReader.fromPath(dictPath);
      } else if (format == 'slob') {
        reader = await SlobReader.fromPath(dictPath);
      } else if (format == 'stardict') {
        reader = await DictReader.fromPath(dictPath);
      } else if (format == 'dictd') {
        reader = await DictdReader.fromPath(dictPath);
      }
    }

    if (reader != null) {
      if (reader is MdictReader) await reader.open();
      if (reader is SlobReader) await reader.open();
      if (reader is DictReader) await reader.open();
      if (reader is DictdReader) await reader.open();
      _readerCache[dictId] = reader;
    }
    return reader;
  }

  /// Closes and removes a reader from the cache.
  static Future<void> closeReader(int dictId) async {
    final reader = _readerCache.remove(dictId);
    if (reader != null) {
      if (reader is MdictReader) await reader.close();
      if (reader is SlobReader) await reader.close();
      if (reader is DictReader) await reader.close();
      if (reader is DictdReader) await reader.close();
    }
  }

  /// Calculates the MD5 checksum of a file.
  Future<String> _calculateChecksum(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return '';
    final bytes = await file.readAsBytes();
    return md5.convert(bytes).toString();
  }

  /// Scans the 'dictionaries' directory and returns folder names that are not referenced in the database.
  Future<List<String>> getOrphanedDictionaryFolders() async {
    final List<String> orphanedFolders = [];
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dictsDir = Directory(p.join(appDocDir.path, 'dictionaries'));
      if (!await dictsDir.exists()) return orphanedFolders;

      final List<Map<String, dynamic>> activeDicts = await _dbHelper
          .getDictionaries();
      final Set<String> activeFolderNames = {};

      for (final dict in activeDicts) {
        final String path = dict['path'] ?? '';
        if (path.isEmpty) continue;

        final parts = p.split(path);
        // Look for 'dictionaries' in the path, the folder name should follow it
        final dictsIdx = parts.lastIndexOf('dictionaries');
        if (dictsIdx != -1 && dictsIdx + 1 < parts.length) {
          activeFolderNames.add(parts[dictsIdx + 1]);
        } else if (parts.length >= 2) {
          // Fallback: if it's a relative path starting with the dict folder
          activeFolderNames.add(parts[0]);
        }
      }

      await for (final entity in dictsDir.list()) {
        if (entity is Directory) {
          final folderName = p.basename(entity.path);
          if (!activeFolderNames.contains(folderName)) {
            orphanedFolders.add(folderName);
          }
        }
      }
    } catch (e) {
      hDebugPrint('Error getting orphaned folders: $e');
    }
    return orphanedFolders;
  }

  /// Deletes specifically requested folders from the 'dictionaries' directory.
  Future<void> deleteOrphanedFolders(List<String> folderNames) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dictsDir = p.join(appDocDir.path, 'dictionaries');

      for (final folderName in folderNames) {
        final dir = Directory(p.join(dictsDir, folderName));
        if (await dir.exists()) {
          hDebugPrint('Deleting requested orphaned folder: $folderName');
          await dir.delete(recursive: true);
        }
      }
    } catch (e) {
      hDebugPrint('Error deleting orphaned folders: $e');
    }
  }

  /// Closes all cached readers.
  static Future<void> clearReaderCache() async {
    final keys = _readerCache.keys.toList();
    for (final id in keys) {
      await closeReader(id);
    }
  }

  /// Helper to handle decompression of individual dictionary components.
  Future<String> _maybeDecompress(String path) async {
    if (path.endsWith('.gz') || path.endsWith('.dz')) {
      final target = path.substring(0, path.length - 3);
      if (await File(target).exists()) return target;
      final bytes = await File(path).readAsBytes();
      final decompressed = await compute(_decompressGzip, bytes);
      await File(target).writeAsBytes(decompressed);
      return target;
    }
    if (path.endsWith('.bz2')) {
      final target = path.substring(0, path.length - 4);
      if (await File(target).exists()) return target;
      final bytes = await File(path).readAsBytes();
      final decompressed = await compute(_decompressBZip2, bytes);
      await File(target).writeAsBytes(decompressed);
      return target;
    }
    if (path.endsWith('.xz')) {
      final target = path.substring(0, path.length - 3);
      if (await File(target).exists()) return target;
      try {
        final bytes = await File(path).readAsBytes();
        final decompressed = await compute(_decompressXZ, bytes);
        await File(target).writeAsBytes(decompressed);
      } catch (e) {
        if (Platform.isMacOS || Platform.isLinux) {
          hDebugPrint(
            'Dart archive package failed to decompress .xz ($e). Falling back to system xz.',
          );
          final result = Process.runSync('xz', [
            '-dc',
            path,
          ], stdoutEncoding: null);
          if (result.exitCode != 0) {
            throw Exception('Native xz decompression failed: ${result.stderr}');
          }
          await File(target).writeAsBytes(result.stdout as List<int>);
        } else {
          rethrow;
        }
      }
      return target;
    }
    return path;
  }

  /// Imports a dictionary with progress updates.
  Stream<ImportProgress> importDictionaryStream(
    String archivePath, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Preparing...', value: 0.0);

    if (kIsWeb) {
      yield ImportProgress(
        message: 'Error: Path-based import not supported on Web.',
        value: 0.0,
        error: 'Web requires byte-based import',
        isCompleted: true,
      );
      return;
    }

    final tempBaseDir = await getTemporaryDirectory();
    await tempBaseDir.create(recursive: true);
    final tempDir = await tempBaseDir.createTemp('import_');
    final receivePort = ReceivePort();
    final rootIsolateToken = RootIsolateToken.instance!;

    try {
      await Isolate.spawn(
        _importEntry,
        _ImportArgs(
          archivePath,
          tempDir.path,
          receivePort.sendPort,
          rootIsolateToken,
        ),
      );

      List<Map<String, dynamic>> discovered = [];

      await for (final message in receivePort) {
        if (message is ImportProgress) {
          yield message;

          if (message.isCompleted) {
            if (message.error != null) {
              receivePort.close();
              if (message.error == 'ALREADY_EXISTS') {
                throw Exception('ALREADY_EXISTS: ${message.message}');
              }
              throw Exception(message.error);
            } else if (message.ifoPath != null) {
              final raw = jsonDecode(message.ifoPath!) as List;
              discovered = raw
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
              break;
            }
          }
        }
      }

      if (discovered.isEmpty) {
        throw Exception('Extraction completed but no dictionaries were found.');
      }

      int total = discovered.length;
      int current = 0;

      for (final dict in discovered) {
        current++;
        final primaryPath = dict['path'] as String;
        final format = dict['format'] as String;
        final companionPath = dict['companionPath'] as String?;

        Stream<ImportProgress> subStream;
        switch (format) {
          case 'mdict':
            final mddPath = p.join(
              p.dirname(primaryPath),
              '${p.basenameWithoutExtension(primaryPath)}.mdd',
            );
            subStream = importMdictStream(
              primaryPath,
              mddPath: File(mddPath).existsSync() ? mddPath : null,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'slob':
            subStream = importSlobStream(
              primaryPath,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'dictd':
            if (companionPath == null)
              throw Exception('DICTD .dict file missing');
            subStream = importDictdStream(
              primaryPath,
              companionPath,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'stardict':
          default:
            subStream = _processDictionaryFiles(
              primaryPath,
              indexDefinitions: indexDefinitions,
            );
            break;
        }

        await for (final progress in subStream) {
          yield ImportProgress(
            message: total > 1
                ? '[$current/$total] ${progress.message}'
                : progress.message,
            value: 0.5 + ((current - 1) + progress.value) / total * 0.5,
            headwordCount: progress.headwordCount,
            isCompleted: progress.isCompleted && current == total,
            dictId: progress.dictId,
            sampleWords: progress.sampleWords,
            error: progress.error,
          );
          if (progress.isCompleted) break;
        }
      }
    } catch (e, s) {
      hDebugPrint('Error in importDictionaryStream: $e\n$s');
      yield ImportProgress(
        message: 'Error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    } finally {
      receivePort.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  /// Imports a dictionary from raw archive bytes (Web-friendly).
  Stream<ImportProgress> importDictionaryWebStream(
    String fileName,
    Uint8List bytes, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Preparing web import...', value: 0.0);

    try {
      final lowerName = fileName.toLowerCase();

      // 1. Handle Archives
      if (lowerName.endsWith('.zip') ||
          lowerName.endsWith('.tar.gz') ||
          lowerName.endsWith('.tgz') ||
          lowerName.endsWith('.tar.bz2') ||
          lowerName.endsWith('.tbz2') ||
          lowerName.endsWith('.tar.xz') ||
          lowerName.endsWith('.tar')) {
        Archive archive;
        if (lowerName.endsWith('.zip')) {
          archive = ZipDecoder().decodeBytes(bytes);
        } else if (lowerName.endsWith('.tar.gz') ||
            lowerName.endsWith('.tgz')) {
          archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
        } else if (lowerName.endsWith('.tar.bz2') ||
            lowerName.endsWith('.tbz2')) {
          archive = TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));
        } else if (lowerName.endsWith('.tar.xz')) {
          archive = TarDecoder().decodeBytes(XZDecoder().decodeBytes(bytes));
        } else {
          archive = TarDecoder().decodeBytes(bytes);
        }

        Map<String, Uint8List> files = {};
        String? ifoName;

        for (final file in archive) {
          if (file.isFile) {
            final content = file.content as List<int>;
            files[file.name] = Uint8List.fromList(content);
            if (file.name.toLowerCase().endsWith('.ifo')) ifoName = file.name;
          }
        }

        if (ifoName != null) {
          yield* _processDictionaryFilesWeb(
            ifoName,
            files,
            indexDefinitions: indexDefinitions,
          );
        } else {
          // Check for other formats inside archive
          final mdxNames = files.keys
              .where((n) => n.toLowerCase().endsWith('.mdx'))
              .toList();
          if (mdxNames.isNotEmpty) {
            // Handle MDict in archive... (add implementation if needed)
            throw Exception(
              'MDict inside archive is not yet supported on Web. Try importing the .mdx file directly.',
            );
          }
          throw Exception(
            'No supported dictionary files (.ifo, .mdx) found in archive.',
          );
        }
        return;
      }

      // 2. Handle Direct Files
      if (lowerName.endsWith('.ifo')) {
        yield* _processDictionaryFilesWeb(fileName, {
          fileName: bytes,
        }, indexDefinitions: indexDefinitions);
      } else if (lowerName.endsWith('.mdx')) {
        // TODO: implement importMdictWebStream if possible
        throw Exception('MDict (.mdx) import on Web is not yet implemented.');
      } else {
        throw Exception('Unsupported dictionary or archive format.');
      }
    } catch (e) {
      yield ImportProgress(
        message: 'Import error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  /// Imports a dictionary from a set of individual files.
  Stream<ImportProgress> importMultipleFilesStream(
    List<String> filePaths, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Preparing workspace...', value: 0.0);

    final tempBaseDir = await getTemporaryDirectory();
    await tempBaseDir.create(recursive: true);
    final workspaceDir = await tempBaseDir.createTemp('workspace_');

    try {
      int processedFiles = 0;
      for (final path in filePaths) {
        yield ImportProgress(
          message: 'Extracting/Copying ${p.basename(path)}...',
          value: (processedFiles / filePaths.length) * 0.4,
        );
        await _extractToWorkspace(path, workspaceDir.path);
        processedFiles++;
      }

      // ── Scan workspace for all supported formats ───────────────────────────
      yield ImportProgress(
        message: 'Scanning for dictionaries...',
        value: 0.45,
      );

      final scanResult = await scanFolderForDictionaries(
        workspaceDir.path,
        extractArchives: false, // already extracted above
      );
      if (scanResult.discovered.isEmpty) {
        throw Exception(
          'No valid dictionary files found. Supported formats: StarDict (.ifo), MDict (.mdx), Slob (.slob), DICTD (.index+.dict)',
        );
      }

      final incompleteMessages = scanResult.incomplete
          .map(
            (i) =>
                '${i.name} (${i.format}): missing ${i.missingFiles.join(', ')}',
          )
          .toList();

      int totalDicts = scanResult.discovered.length;
      int currentDict = 0;

      for (final item in scanResult.discovered) {
        currentDict++;
        final primaryPath = item.path;
        final format = item.format;
        final companionPath = item.companionPath;

        final name = p.basenameWithoutExtension(primaryPath);
        yield ImportProgress(
          message: 'Importing dictionary $currentDict of $totalDicts: $name',
          value: 0.45 + (currentDict - 1) / totalDicts * 0.55,
          dictionaryName: name,
        );

        Stream<ImportProgress> subStream;
        switch (format) {
          case 'mdict':
            // Look for companion .mdd in the same folder as .mdx
            final mddPath = p.join(
              p.dirname(primaryPath),
              '${p.basenameWithoutExtension(primaryPath)}.mdd',
            );
            subStream = importMdictStream(
              primaryPath,
              mddPath: File(mddPath).existsSync() ? mddPath : null,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'slob':
            subStream = importSlobStream(
              primaryPath,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'dictd':
            if (companionPath == null)
              throw Exception('DICTD .dict file missing');
            subStream = importDictdStream(
              primaryPath,
              companionPath,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'stardict':
          default:
            subStream = _processDictionaryFiles(
              primaryPath,
              indexDefinitions: indexDefinitions,
            );
            break;
        }

        await for (final progress in subStream) {
          yield ImportProgress(
            message: '[$currentDict/$totalDicts] ${progress.message}',
            value:
                0.45 + ((currentDict - 1) + progress.value) / totalDicts * 0.55,
            headwordCount: progress.headwordCount,
            isCompleted: progress.isCompleted && currentDict == totalDicts,
            dictId: progress.dictId,
            sampleWords: progress.sampleWords,
            error: progress.error,
            dictionaryName: progress.dictionaryName ?? name,
            groupName: progress.groupName ?? item.parentFolderName,
          );
          if (progress.isCompleted) break;
        }
      }

      yield ImportProgress(
        message: 'All imports complete.',
        value: 1.0,
        isCompleted: true,
        incompleteEntries: incompleteMessages.isEmpty
            ? null
            : incompleteMessages,
      );
    } catch (e) {
      yield ImportProgress(
        message: 'Error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    } finally {
      if (await workspaceDir.exists()) {
        await workspaceDir.delete(recursive: true);
      }
    }
  }

  /// Imports all dictionaries found recursively inside [folderPath].
  ///
  /// Archives (`.zip`, `.tar.gz`, etc.) found inside the folder are extracted
  /// before scanning.  Dictionaries with all mandatory files are imported;
  /// those missing required files are reported via
  /// [ImportProgress.incompleteEntries] on the final completion event.
  Stream<ImportProgress> importFolderStream(
    String folderPath, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Scanning folder...', value: 0.0);

    if (kIsWeb) {
      yield ImportProgress(
        message: 'Folder import is not supported on Web.',
        value: 0.0,
        error: 'Folder import not supported on Web',
        isCompleted: true,
      );
      return;
    }

    // We copy the folder into a temporary workspace first so the originals are
    // never modified and archive extraction happens in a sandboxed location.
    final tempBaseDir = await getTemporaryDirectory();
    await tempBaseDir.create(recursive: true);
    final workspaceDir = await tempBaseDir.createTemp('folder_import_');

    try {
      yield ImportProgress(message: 'Copying folder contents...', value: 0.05);

      // Copy the entire source folder tree into the workspace.
      final sourceDir = Directory(folderPath);
      final entities = await sourceDir.list(recursive: true).toList();
      for (final entity in entities) {
        if (entity is File) {
          final relative = p.relative(entity.path, from: folderPath);
          final destPath = p.join(workspaceDir.path, relative);
          await File(destPath).create(recursive: true);
          await entity.copy(destPath);
        }
      }

      yield ImportProgress(
        message: 'Scanning for dictionaries (including archives)...',
        value: 0.15,
      );

      // The scanner handles archive extraction internally.
      final scanResult = await scanFolderForDictionaries(
        workspaceDir.path,
        extractArchives: true,
      );

      if (scanResult.discovered.isEmpty && scanResult.incomplete.isEmpty) {
        throw Exception(
          'No dictionary files found in the selected folder.\n'
          'Supported: StarDict (.ifo+.idx+.dict), MDict (.mdx), '
          'Slob (.slob), DICTD (.index+.dict)',
        );
      }

      // Even if only incomplete dictionaries exist, surface them nicely.
      if (scanResult.discovered.isEmpty) {
        final incompleteMessages = scanResult.incomplete
            .map(
              (i) =>
                  '${i.name} (${i.format}): missing ${i.missingFiles.join(', ')}',
            )
            .toList();
        yield ImportProgress(
          message: 'No complete dictionaries found.',
          value: 1.0,
          isCompleted: true,
          incompleteEntries: incompleteMessages,
        );
        return;
      }

      final incompleteMessages = scanResult.incomplete
          .map(
            (i) =>
                '${i.name} (${i.format}): missing ${i.missingFiles.join(', ')}',
          )
          .toList();

      int totalDicts = scanResult.discovered.length;
      int currentDict = 0;

      for (final item in scanResult.discovered) {
        currentDict++;
        final primaryPath = item.path;
        final format = item.format;
        final companionPath = item.companionPath;

        final name = p.basenameWithoutExtension(primaryPath);
        yield ImportProgress(
          message: 'Importing dictionary $currentDict of $totalDicts: $name',
          value: 0.2 + (currentDict - 1) / totalDicts * 0.8,
          dictionaryName: name,
        );

        Stream<ImportProgress> subStream;
        switch (format) {
          case 'mdict':
            final mddPath = p.join(
              p.dirname(primaryPath),
              '${p.basenameWithoutExtension(primaryPath)}.mdd',
            );
            subStream = importMdictStream(
              primaryPath,
              mddPath: File(mddPath).existsSync() ? mddPath : null,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'slob':
            subStream = importSlobStream(
              primaryPath,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'dictd':
            if (companionPath == null) {
              throw Exception('DICTD .dict file missing for $name');
            }
            subStream = importDictdStream(
              primaryPath,
              companionPath,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'stardict':
          default:
            subStream = _processDictionaryFiles(
              primaryPath,
              indexDefinitions: indexDefinitions,
            );
            break;
        }

        await for (final progress in subStream) {
          // The user wants the selected folder's name to be the group name.
          final String groupName = p.basename(folderPath);

          yield ImportProgress(
            message: '[$currentDict/$totalDicts] ${progress.message}',
            value:
                0.2 + ((currentDict - 1) + progress.value) / totalDicts * 0.8,
            headwordCount: progress.headwordCount,
            isCompleted: progress.isCompleted && currentDict == totalDicts,
            dictId: progress.dictId,
            sampleWords: progress.sampleWords,
            error: progress.error,
            dictionaryName: progress.dictionaryName ?? name,
            groupName: progress.groupName ?? groupName,
          );
          if (progress.dictId != null) {
            hDebugPrint(
              'DictionaryManager: Yielding dictId ${progress.dictId} with groupName "${progress.groupName ?? groupName}"',
            );
          }
          if (progress.isCompleted) break;
        }
      }

      yield ImportProgress(
        message: 'Folder import complete.',
        value: 1.0,
        isCompleted: true,
        incompleteEntries: incompleteMessages.isEmpty
            ? null
            : incompleteMessages,
      );
    } catch (e, s) {
      hDebugPrint('Error in importFolderStream: $e\n$s');
      yield ImportProgress(
        message: 'Error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    } finally {
      if (await workspaceDir.exists()) {
        await workspaceDir.delete(recursive: true);
      }
    }
  }

  /// Links all dictionaries found in [folderPath] (or SAF URI) without copying.
  Stream<ImportProgress> linkFolderStream(
    String folderPath, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Scanning folder...', value: 0.0);

    if (kIsWeb) {
      yield ImportProgress(
        message: 'Folder linking is not supported on Web.',
        value: 0.0,
        error: 'Folder linking not supported on Web',
        isCompleted: true,
      );
      return;
    }

    try {
      FolderScanResult scanResult;
      if (Platform.isAndroid && folderPath.startsWith('content://')) {
        // TODO: Implement SAF-specific folder scanner using docman
        // For now, we'll try to adapt the existing scanner if it can handle URIs,
        // but it likely can't. I'll need a specialized one.
        yield ImportProgress(message: 'Scanning SAF folder...', value: 0.1);
        scanResult = await _scanSafFolder(folderPath);
      } else {
        scanResult = await scanFolderForDictionaries(
          folderPath,
          extractArchives: false,
        );
      }

      if (scanResult.discovered.isEmpty && scanResult.incomplete.isEmpty) {
        throw Exception('No dictionaries found in the selected folder.');
      }

      final incompleteMessages = scanResult.incomplete
          .map(
            (i) =>
                '${i.name} (${i.format}): missing ${i.missingFiles.join(', ')}',
          )
          .toList();

      if (scanResult.discovered.isEmpty) {
        yield ImportProgress(
          message: 'No complete dictionaries found.',
          value: 1.0,
          isCompleted: true,
          incompleteEntries: incompleteMessages,
        );
        return;
      }

      int totalDicts = scanResult.discovered.length;
      int currentDict = 0;

      for (final item in scanResult.discovered) {
        currentDict++;
        final name = p.basenameWithoutExtension(item.path);
        yield ImportProgress(
          message: 'Linking dictionary $currentDict of $totalDicts: $name',
          value: 0.2 + (currentDict - 1) / totalDicts * 0.8,
          dictionaryName: name,
        );

        Stream<ImportProgress> subStream;
        switch (item.format) {
          case 'mdict':
            subStream = _linkMdict(
              item.path,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'slob':
            subStream = _linkSlob(
              item.path,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'dictd':
            subStream = _linkDictd(
              item.path,
              item.companionPath!,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'stardict':
          default:
            subStream = _linkStarDict(
              item.path,
              indexDefinitions: indexDefinitions,
            );
            break;
        }

        await for (final progress in subStream) {
          final String groupName = p.basename(folderPath);
          yield ImportProgress(
            message: '[$currentDict/$totalDicts] ${progress.message}',
            value:
                0.2 + ((currentDict - 1) + progress.value) / totalDicts * 0.8,
            headwordCount: progress.headwordCount,
            isCompleted: progress.isCompleted && currentDict == totalDicts,
            dictId: progress.dictId,
            sampleWords: progress.sampleWords,
            error: progress.error,
            dictionaryName: progress.dictionaryName ?? name,
            groupName: progress.groupName ?? groupName,
          );
          if (progress.isCompleted) break;
        }
      }

      yield ImportProgress(
        message: 'Link complete.',
        value: 1.0,
        isCompleted: true,
        incompleteEntries: incompleteMessages.isEmpty
            ? null
            : incompleteMessages,
      );
    } catch (e, s) {
      hDebugPrint('Error in linkFolderStream: $e\n$s');
      yield ImportProgress(
        message: 'Error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  /// Specialized SAF folder scanner for Android.
  Future<FolderScanResult> _scanSafFolder(String treeUri) async {
    final List<DiscoveredDict> discovered = [];
    final List<IncompleteDict> incomplete = [];

    final result = FolderScanResult(discovered: discovered, incomplete: incomplete);

    // docman's DirectoryInfo for the tree URI
    final dir = await DocumentFile.fromUri(treeUri);
    if (dir == null) return result;

    // We need to list files recursively. docman might not have a recursive list,
    // so we'll implement a simple one.
    Future<void> scan(DocumentFile d) async {
      final List<DocumentFile> entities = await d.listDocuments();
      final String parentName = d.name;

      for (final entity in entities) {
        if (entity.isDirectory) {
          await scan(entity);
        } else {
          final String name = entity.name;
          final String lowerName = name.toLowerCase();
          final String path = entity.uri.toString();

          // -- StarDict --
          if (lowerName.endsWith('.ifo')) {
            final String baseName = name.substring(0, name.length - 4);
            bool hasIdx = false;
            bool hasDict = false;
            for (final f in entities) {
              final n = f.name.toLowerCase();
              if (n.startsWith(baseName.toLowerCase())) {
                if (n.endsWith('.idx')) hasIdx = true;
                if (n.endsWith('.dict') || n.endsWith('.dict.dz'))
                  hasDict = true;
              }
            }
            if (hasIdx && hasDict) {
              String? idxUri, dictUri, synUri;
              for (final f in entities) {
                final n = f.name.toLowerCase();
                if (n.startsWith(baseName.toLowerCase())) {
                  if (n.endsWith('.idx')) idxUri = f.uri;
                  if (n.endsWith('.dict') || n.endsWith('.dict.dz')) dictUri = f.uri;
                  if (n.endsWith('.syn')) synUri = f.uri;
                }
              }
              discovered.add(
                DiscoveredDict(
                  path: path,
                  format: 'stardict',
                  parentFolderName: parentName,
                  safUris: {
                    'ifo': path,
                    if (idxUri != null) 'idx': idxUri,
                    if (dictUri != null) 'dict': dictUri,
                    if (synUri != null) 'syn': synUri,
                  },
                ),
              );
            } else {
              incomplete.add(
                IncompleteDict(
                  name: baseName,
                  format: 'stardict',
                  missingFiles: [if (!hasIdx) '.idx', if (!hasDict) '.dict'],
                  parentFolderName: parentName,
                ),
              );
            }
          }
          // -- MDict --
          else if (lowerName.endsWith('.mdx')) {
            discovered.add(
              DiscoveredDict(
                path: path,
                format: 'mdict',
                parentFolderName: parentName,
              ),
            );
          }
          // -- Slob --
          else if (lowerName.endsWith('.slob')) {
            discovered.add(
              DiscoveredDict(
                path: path,
                format: 'slob',
                parentFolderName: parentName,
              ),
            );
          }
          // -- DICTD --
          else if (lowerName.endsWith('.index')) {
            final String baseName = name.substring(0, name.length - 6);
            String? dictPath;
            for (final f in entities) {
              final n = f.name.toLowerCase();
              if (n.startsWith(baseName.toLowerCase()) &&
                  (n.endsWith('.dict') || n.endsWith('.dict.dz'))) {
                dictPath = f.uri.toString();
                break;
              }
            }
            if (dictPath != null) {
              discovered.add(
                DiscoveredDict(
                  path: path,
                  format: 'dictd',
                  companionPath: dictPath,
                  parentFolderName: parentName,
                ),
              );
            } else {
              incomplete.add(
                IncompleteDict(
                  name: baseName,
                  format: 'dictd',
                  missingFiles: ['.dict'],
                  parentFolderName: parentName,
                ),
              );
            }
          }
        }
      }
    }

    await scan(dir);
    return FolderScanResult(discovered: discovered, incomplete: incomplete);
  }

  String? _resolveLocalFile(String basePath, List<String> extensions) {
    for (final ext in extensions) {
      final f = File('$basePath$ext');
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  Stream<ImportProgress> _linkStarDict(
    String ifoPath, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Linking StarDict...', value: 0.1);
    try {
      final ifoParser = IfoParser();
      await ifoParser.parse(ifoPath);
      final bookName = ifoParser.bookName;

      // Create bookmark for the folder or file
      final String? bookmark = await BookmarkManager.createBookmark(ifoPath);
      if (bookmark == null) throw Exception('Failed to create bookmark');

      final basePath = p.withoutExtension(ifoPath);
      final idxPath = _resolveLocalFile(basePath, [
        '.idx',
        '.idx.gz',
        '.idx.dz',
        '.idx.bz2',
        '.idx.xz',
      ])!;
      final dictPath = _resolveLocalFile(basePath, [
        '.dict',
        '.dict.dz',
        '.dict.gz',
        '.dict.bz2',
        '.dict.xz',
      ])!;
      final synPath = _resolveLocalFile(basePath, [
        '.syn',
        '.syn.gz',
        '.syn.dz',
        '.syn.bz2',
        '.syn.xz',
      ]);

      final dictId = await _dbHelper.insertDictionary(
        bookName,
        ifoPath, // Anchor path
        format: 'stardict',
        sourceType: 'linked',
        sourceBookmark: bookmark,
      );

      final receivePort = ReceivePort();
      await Isolate.spawn(
        _indexEntry,
        _IndexArgs(
          dictId,
          idxPath,
          dictPath,
          synPath,
          indexDefinitions,
          ifoParser,
          'linked',
          bookmark,
          receivePort.sendPort,
          RootIsolateToken.instance!,
        ),
      );

      await for (final progress in receivePort) {
        yield progress;
        if (progress.isCompleted) break;
      }
    } catch (e) {
      yield ImportProgress(
        message: 'Link error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  Stream<ImportProgress> _linkMdict(
    String mdxPath, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Linking MDict...', value: 0.1);
    try {
      final String? bookmark = await BookmarkManager.createBookmark(mdxPath);
      if (bookmark == null) throw Exception('Failed to create bookmark');

      final reader = await MdictReader.fromLinkedSource(bookmark);
      await reader.open();
      // MDict book name usually comes from the header or filename
      final bookName = p.basenameWithoutExtension(mdxPath);

      final dictId = await _dbHelper.insertDictionary(
        bookName,
        mdxPath,
        format: 'mdict',
        sourceType: 'linked',
        sourceBookmark: bookmark,
      );

      final receivePort = ReceivePort();
      await Isolate.spawn(
        _indexMdictEntry,
        _IndexMdictArgs(
          dictId: dictId,
          mdxPath: mdxPath,
          indexDefinitions: indexDefinitions,
          bookName: bookName,
          sourceType: 'linked',
          sourceBookmark: bookmark,
          sendPort: receivePort.sendPort,
          rootIsolateToken: RootIsolateToken.instance!,
        ),
      );

      await for (final progress in receivePort) {
        yield progress;
        if (progress.isCompleted) break;
      }
      await reader.close();
    } catch (e) {
      yield ImportProgress(
        message: 'Link error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  Stream<ImportProgress> _linkSlob(
    String slobPath, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Linking Slob...', value: 0.1);
    try {
      final String? bookmark = await BookmarkManager.createBookmark(slobPath);
      if (bookmark == null) throw Exception('Failed to create bookmark');

      final bookName = p.basenameWithoutExtension(slobPath);
      final dictId = await _dbHelper.insertDictionary(
        bookName,
        slobPath,
        format: 'slob',
        sourceType: 'linked',
        sourceBookmark: bookmark,
      );

      final receivePort = ReceivePort();
      await Isolate.spawn(
        _indexSlobEntry,
        _IndexSlobArgs(
          dictId: dictId,
          slobPath: slobPath,
          bookName: bookName,
          indexDefinitions: indexDefinitions,
          sourceType: 'linked',
          sourceBookmark: bookmark,
          sendPort: receivePort.sendPort,
          rootIsolateToken: RootIsolateToken.instance!,
        ),
      );

      await for (final progress in receivePort) {
        yield progress;
        if (progress.isCompleted) break;
      }
    } catch (e) {
      yield ImportProgress(
        message: 'Link error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  Stream<ImportProgress> _linkDictd(
    String indexPath,
    String dictPath, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Linking DICTD...', value: 0.1);
    try {
      // For DICTD, we link based on the index file, but we need both.
      // We'll store the index path and bookmark it.
      final String? bookmark = await BookmarkManager.createBookmark(indexPath);
      if (bookmark == null) throw Exception('Failed to create bookmark');

      final bookName = p.basenameWithoutExtension(indexPath);
      final dictId = await _dbHelper.insertDictionary(
        bookName,
        indexPath,
        format: 'dictd',
        sourceType: 'linked',
        sourceBookmark: bookmark,
      );

      final receivePort = ReceivePort();
      await Isolate.spawn(
        _indexDictdEntry,
        _IndexDictdArgs(
          dictId: dictId,
          indexPath: indexPath,
          dictPath: dictPath,
          bookName: bookName,
          indexDefinitions: indexDefinitions,
          sourceType: 'linked',
          sourceBookmark: bookmark,
          sendPort: receivePort.sendPort,
          rootIsolateToken: RootIsolateToken.instance!,
        ),
      );

      await for (final progress in receivePort) {
        yield progress;
        if (progress.isCompleted) break;
      }
    } catch (e) {
      yield ImportProgress(
        message: 'Link error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  Stream<ImportProgress> importMultipleFilesWebStream(
    List<({String name, Uint8List bytes})> files, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Preparing web workspace...', value: 0.0);

    try {
      Map<String, Uint8List> allFiles = {};
      int processedFiles = 0;

      for (final file in files) {
        yield ImportProgress(
          message: 'Extracting/Processing ${file.name}...',
          value: (processedFiles / files.length) * 0.4,
        );

        final lowerName = file.name.toLowerCase();
        if (lowerName.endsWith('.zip')) {
          final archive = ZipDecoder().decodeBytes(file.bytes);
          for (final f in archive) {
            if (f.isFile)
              allFiles[f.name] = Uint8List.fromList(f.content as List<int>);
          }
        } else if (lowerName.endsWith('.tar.gz') ||
            lowerName.endsWith('.tgz')) {
          final archive = TarDecoder().decodeBytes(
            GZipDecoder().decodeBytes(file.bytes),
          );
          for (final f in archive) {
            if (f.isFile)
              allFiles[f.name] = Uint8List.fromList(f.content as List<int>);
          }
        } else if (lowerName.endsWith('.tar.bz2') ||
            lowerName.endsWith('.tbz2')) {
          final archive = TarDecoder().decodeBytes(
            BZip2Decoder().decodeBytes(file.bytes),
          );
          for (final f in archive) {
            if (f.isFile)
              allFiles[f.name] = Uint8List.fromList(f.content as List<int>);
          }
        } else if (lowerName.endsWith('.tar.xz')) {
          final archive = TarDecoder().decodeBytes(
            XZDecoder().decodeBytes(file.bytes),
          );
          for (final f in archive) {
            if (f.isFile)
              allFiles[f.name] = Uint8List.fromList(f.content as List<int>);
          }
        } else if (lowerName.endsWith('.tar')) {
          final archive = TarDecoder().decodeBytes(file.bytes);
          for (final f in archive) {
            if (f.isFile)
              allFiles[f.name] = Uint8List.fromList(f.content as List<int>);
          }
        } else {
          allFiles[file.name] = file.bytes;
        }
        processedFiles++;
      }

      // Find all dictionary entry points in the extracted file map.
      final ifoNames = allFiles.keys
          .where((n) => n.toLowerCase().endsWith('.ifo'))
          .toList();
      final mdxNames = allFiles.keys
          .where((n) => n.toLowerCase().endsWith('.mdx'))
          .toList();
      final slobNames = allFiles.keys
          .where((n) => n.toLowerCase().endsWith('.slob'))
          .toList();

      if (ifoNames.isEmpty && mdxNames.isEmpty && slobNames.isEmpty) {
        throw Exception(
          'No supported dictionary files (.ifo, .mdx, .slob) found in archive.',
        );
      }

      // --- StarDict dictionaries ---
      int totalDicts = ifoNames.length + mdxNames.length + slobNames.length;
      int currentDict = 0;

      for (final ifoName in ifoNames) {
        currentDict++;
        yield ImportProgress(
          message:
              'Importing dictionary $currentDict of $totalDicts: ${p.basenameWithoutExtension(ifoName)}',
          value: 0.5 + (currentDict - 1) / totalDicts * 0.5,
          dictionaryName: p.basenameWithoutExtension(ifoName),
        );

        try {
          final stream = _processDictionaryFilesWeb(
            ifoName,
            allFiles,
            indexDefinitions: indexDefinitions,
          );
          await for (final progress in stream) {
            yield ImportProgress(
              message: '[$currentDict/$totalDicts] ${progress.message}',
              value:
                  0.5 +
                  ((currentDict - 1) + (progress.value)) / totalDicts * 0.5,
              dictionaryName:
                  progress.dictionaryName ??
                  p.basenameWithoutExtension(ifoName),
            );
            if (progress.isCompleted) break;
          }
        } catch (e) {
          hDebugPrint('Web error importing $ifoName: $e');
        }
      }

      // --- MDict dictionaries (extracted from archive) ---
      // MDict import on Web requires a real file path, which isn't possible
      // in a web context. Surface a clear error instead of silently skipping.
      for (final mdxName in mdxNames) {
        currentDict++;
        yield ImportProgress(
          message:
              '[$currentDict/$totalDicts] MDict (.mdx) files inside archives are not supported on Web. '
              'Please import the .mdx file directly using "Import File".',
          value: 0.5 + (currentDict - 1) / totalDicts * 0.5,
          error: 'MDict inside archive not supported on Web',
          isCompleted: totalDicts == currentDict,
          dictionaryName: p.basenameWithoutExtension(mdxName),
        );
        hDebugPrint('Web: skipped MDict $mdxName — not supported in archive');
      }

      // --- Slob dictionaries (extracted from archive) ---
      // Same limitation as MDict on Web — needs a file path.
      for (final slobName in slobNames) {
        currentDict++;
        yield ImportProgress(
          message:
              '[$currentDict/$totalDicts] Slob (.slob) files inside archives are not supported on Web. '
              'Please import the .slob file directly using "Import File".',
          value: 0.5 + (currentDict - 1) / totalDicts * 0.5,
          error: 'Slob inside archive not supported on Web',
          isCompleted: totalDicts == currentDict,
          dictionaryName: p.basenameWithoutExtension(slobName),
        );
        hDebugPrint('Web: skipped Slob $slobName — not supported in archive');
      }

      yield ImportProgress(
        message: 'All web imports complete.',
        value: 1.0,
        isCompleted: true,
      );
    } catch (e) {
      yield ImportProgress(
        message: 'Web error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  /// Shared logic for processing dictionary files and saving them permanently on Native.
  Stream<ImportProgress> _processDictionaryFiles(
    String ifoPath, {
    bool indexDefinitions = false,
  }) async* {
    try {
      yield ImportProgress(
        message: 'Processing dictionary files...',
        value: 0.55,
      );

      final actualIfoPath = await _maybeDecompress(ifoPath);
      final checksum = await _calculateChecksum(actualIfoPath);

      final existing = await _dbHelper.getDictionaryByChecksum(checksum);
      if (existing != null) {
        yield ImportProgress(
          message:
              'Dictionary "${existing['name']}" is already in your library.',
          value: 1.0,
          error: 'ALREADY_EXISTS',
          isCompleted: true,
        );
        return;
      }

      final basePath = p.withoutExtension(actualIfoPath);

      // Robust file finding: checking local directory first
      String? findLocalFile(List<String> extensions) {
        for (final ext in extensions) {
          final path = '$basePath$ext';
          if (File(path).existsSync()) {
            return path;
          }
        }
        return null;
      }

      String? idxPath = findLocalFile([
        '.idx',
        '.idx.gz',
        '.idx.dz',
        '.idx.bz2',
        '.idx.xz',
      ]);
      if (idxPath == null)
        throw Exception('No .idx file found for ${p.basename(ifoPath)}');

      String? dictPath = findLocalFile([
        '.dict',
        '.dict.dz',
        '.dict.gz',
        '.dict.bz2',
        '.dict.xz',
      ]);
      if (dictPath == null)
        throw Exception('No .dict file found for ${p.basename(ifoPath)}');

      String? synPath = findLocalFile([
        '.syn',
        '.syn.gz',
        '.syn.dz',
        '.syn.bz2',
        '.syn.xz',
      ]);

      final ifoParser = IfoParser();
      await ifoParser.parse(actualIfoPath);
      final bookName = ifoParser.bookName ?? 'Unknown Dictionary';

      yield ImportProgress(
        message: 'Saving dictionary files...',
        value: 0.75,
        dictionaryName: bookName,
      );

      // Native: Move to permanent location
      final appDocDir = await getApplicationDocumentsDirectory();
      final dictsDir = Directory(p.join(appDocDir.path, 'dictionaries'));
      if (!await dictsDir.exists()) await dictsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final permanentDir = Directory(p.join(dictsDir.path, 'dict_$timestamp'));
      await permanentDir.create(recursive: true);

      // For the .idx and .syn files (small), decompress if needed so IdxParser / SynParser
      // can read them as plain bytes. For .dict/.dict.dz we keep the file as-is since
      // DictReader now handles .dict.dz directly via DictzipReader (no disk decompression).
      final preparedIdxPath = await _maybeDecompress(idxPath);
      final preparedSynPath = synPath != null
          ? await _maybeDecompress(synPath)
          : null;

      // Copy the .dict or .dict.dz file without decompressing it.
      final finalDictPath = p.join(permanentDir.path, p.basename(dictPath));
      await File(dictPath).copy(finalDictPath);
      await File(
        preparedIdxPath,
      ).copy(p.join(permanentDir.path, p.basename(preparedIdxPath)));
      await File(
        actualIfoPath,
      ).copy(p.join(permanentDir.path, p.basename(actualIfoPath)));
      if (preparedSynPath != null) {
        await File(
          preparedSynPath,
        ).copy(p.join(permanentDir.path, p.basename(preparedSynPath)));
      }

      final dictId = await _dbHelper.insertDictionary(
        bookName,
        finalDictPath,
        indexDefinitions: indexDefinitions,
        typeSequence: ifoParser.sameTypeSequence,
        checksum: checksum,
        sourceUrl: _currentImportSourceUrl,
      );

      yield ImportProgress(
        message: 'Indexing words...',
        value: 0.85,
        dictionaryName: bookName,
      );

      final receivePort = ReceivePort();
      final rootIsolateToken = RootIsolateToken.instance!;

      await Isolate.spawn(
        _indexEntry,
        _IndexArgs(
          dictId,
          p.join(permanentDir.path, p.basename(preparedIdxPath)),
          finalDictPath,
          preparedSynPath != null
              ? p.join(permanentDir.path, p.basename(preparedSynPath))
              : null,
          indexDefinitions,
          ifoParser,
          'managed',
          null,
          receivePort.sendPort,
          rootIsolateToken,
        ),
      );

      int finalHeadwordCount = 0;
      int finalDefWordCount = 0;

      await for (final message in receivePort) {
        if (message is ImportProgress) {
          if (message.error != null) {
            receivePort.close();
            if (message.error == 'ALREADY_EXISTS') {
              throw Exception('ALREADY_EXISTS: ${message.message}');
            }
            throw Exception(message.error);
          }
          if (message.isCompleted) {
            finalHeadwordCount = message.headwordCount;
            finalDefWordCount = message.definitionWordCount;
            receivePort.close();
            break;
          }
          yield message;
        }
      }

      final sampleWords = await _dbHelper.getSampleWords(dictId);

      yield ImportProgress(
        message: 'Import complete!',
        value: 1.0,
        isCompleted: true,
        dictId: dictId,
        ifoPath: p.join(permanentDir.path, p.basename(actualIfoPath)),
        sampleWords: sampleWords.map((w) => w['word'] as String).toList(),
        headwordCount: finalHeadwordCount,
        definitionWordCount: finalDefWordCount,
        dictionaryName: bookName,
      );
    } catch (e, s) {
      hDebugPrint('Error in _processDictionaryFiles: $e\n$s');
      yield ImportProgress(
        message: 'Error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  Future<Uint8List> _maybeDecompressWeb(String name, Uint8List bytes) async {
    if (name.endsWith('.gz') || name.endsWith('.dz')) {
      return Uint8List.fromList(await compute(_decompressGzip, bytes));
    }
    if (name.endsWith('.bz2')) {
      return Uint8List.fromList(await compute(_decompressBZip2, bytes));
    }
    if (name.endsWith('.xz')) {
      return Uint8List.fromList(await compute(_decompressXZ, bytes));
    }
    return bytes;
  }

  String _getDecompressedName(String name) {
    if (name.endsWith('.gz') || name.endsWith('.dz')) {
      return name.substring(0, name.length - 3);
    }
    if (name.endsWith('.bz2')) {
      return name.substring(0, name.length - 4);
    }
    if (name.endsWith('.xz')) {
      return name.substring(0, name.length - 3);
    }
    return name;
  }

  /// Web-specific processing logic using bytes and SQLite virtual filesystem.
  Stream<ImportProgress> _processDictionaryFilesWeb(
    String ifoName,
    Map<String, Uint8List> files, {
    bool indexDefinitions = false,
  }) async* {
    try {
      yield ImportProgress(message: 'Processing web files...', value: 0.5);

      final ifoBytes = files[ifoName]!;
      // IFO files are usually not compressed, but let's be safe
      final decompressedIfoBytes = await _maybeDecompressWeb(ifoName, ifoBytes);
      final ifoContent = utf8.decode(
        decompressedIfoBytes,
        allowMalformed: true,
      );
      final ifoParser = IfoParser();
      ifoParser.parseContent(ifoContent);

      final bookName = ifoParser.bookName ?? 'Unknown Web Dictionary';
      final basePath = p.withoutExtension(ifoName);

      // Find required components in the map
      String? idxName;
      for (final name in files.keys) {
        if (name.startsWith(basePath) && name.contains('.idx')) {
          idxName = name;
          break;
        }
      }
      if (idxName == null) throw Exception('Missing .idx file');

      String? dictName;
      for (final name in files.keys) {
        if (name.startsWith(basePath) && name.contains('.dict')) {
          dictName = name;
          break;
        }
      }
      if (dictName == null) throw Exception('Missing .dict file');

      String? synName;
      for (final name in files.keys) {
        if (name.startsWith(basePath) && name.contains('.syn')) {
          synName = name;
          break;
        }
      }

      // Decompress components
      yield ImportProgress(
        message: 'Decompressing components...',
        value: 0.55,
        dictionaryName: bookName,
      );
      final decompressedIdxBytes = await _maybeDecompressWeb(
        idxName,
        files[idxName]!,
      );
      final decompressedDictBytes = await _maybeDecompressWeb(
        dictName,
        files[dictName]!,
      );
      final decompressedSynBytes = synName != null
          ? await _maybeDecompressWeb(synName, files[synName]!)
          : null;

      final finalIfoName = _getDecompressedName(p.basename(ifoName));
      final finalIdxName = _getDecompressedName(p.basename(idxName));
      final finalDictName = _getDecompressedName(p.basename(dictName));
      final finalSynName = synName != null
          ? _getDecompressedName(p.basename(synName))
          : null;

      final dictId = await _dbHelper.insertDictionary(
        bookName,
        finalDictName,
        indexDefinitions: indexDefinitions,
        typeSequence: ifoParser.sameTypeSequence,
        sourceUrl: _currentImportSourceUrl,
      );

      // Save files to virtual filesystem (SQLite 'files' table)
      yield ImportProgress(
        message: 'Saving files to database...',
        value: 0.6,
        dictionaryName: bookName,
      );
      await _dbHelper.saveFile(dictId, finalIfoName, decompressedIfoBytes);
      await _dbHelper.saveFile(dictId, finalIdxName, decompressedIdxBytes);
      await _dbHelper.saveFile(dictId, finalDictName, decompressedDictBytes);
      if (finalSynName != null && decompressedSynBytes != null) {
        await _dbHelper.saveFile(dictId, finalSynName, decompressedSynBytes);
      }

      // Indexing on Web (sequential for simplicity/stability)
      yield ImportProgress(
        message: 'Indexing words (Web)...',
        value: 0.7,
        dictionaryName: bookName,
      );

      final idxParser = IdxParser(ifoParser);
      final dictReader = await DictReader.fromPath(finalDictName, dictId: dictId);
      await dictReader.open();

      List<Map<String, dynamic>> batch = [];
      List<({int offset, int length, String content})> wordOffsets = [];
      int headwordCount = 0;
      int defWordCount = 0;

      final idxStream = idxParser.parseFromBytes(decompressedIdxBytes);
      await for (final entry in idxStream) {
        final String word = entry['word'];
        final offset = entry['offset'] as int;
        final length = entry['length'] as int;

        // When indexing definitions, we have the bytes directly available in decompressedDictBytes
        String content = '';
        if (indexDefinitions) {
          if (offset + length <= decompressedDictBytes.length) {
            content = utf8.decode(
              decompressedDictBytes.sublist(offset, offset + length),
              allowMalformed: true,
            );
          }
        }

        batch.add({
          'word': word,
          'content': content,
          'dict_id': dictId,
          'offset': offset,
          'length': length,
        });

        headwordCount++;
        if (content.isNotEmpty) {
          defWordCount += content
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty)
              .length;
        }

        wordOffsets.add((offset: offset, length: length, content: content));

        if (batch.length >= 1000) {
          await _dbHelper.batchInsertWords(dictId, batch);
          batch.clear();
          yield ImportProgress(
            message: 'Indexing $headwordCount words...',
            value:
                0.7 +
                (headwordCount /
                    (ifoParser.wordCount == 0 ? 100000 : ifoParser.wordCount) *
                    0.2),
            headwordCount: headwordCount,
            dictionaryName: bookName,
          );
        }
      }
      if (batch.isNotEmpty) await _dbHelper.batchInsertWords(dictId, batch);

      // SYN support for Web
      if (finalSynName != null && decompressedSynBytes != null) {
        yield ImportProgress(message: 'Indexing synonyms...', value: 0.9);
        final synParser = SynParser();
        final synStream = synParser.parseFromBytes(decompressedSynBytes);
        List<Map<String, dynamic>> synBatch = [];
        await for (final syn in synStream) {
          final originalIndex = syn['original_word_index'] as int;
          if (originalIndex < wordOffsets.length) {
            final originalInfo = wordOffsets[originalIndex];
            synBatch.add({
              'word': syn['word'],
              'content': originalInfo.content,
              'dict_id': dictId,
              'offset': originalInfo.offset,
              'length': originalInfo.length,
            });
            headwordCount++;
          }
          if (synBatch.length >= 1000) {
            await _dbHelper.batchInsertWords(dictId, synBatch);
            synBatch.clear();
          }
        }
        if (synBatch.isNotEmpty)
          await _dbHelper.batchInsertWords(dictId, synBatch);
      }

      await dictReader.close();
      await _dbHelper.updateDictionaryWordCount(dictId, headwordCount);

      final sampleWords = await _dbHelper.getSampleWords(dictId);

      yield ImportProgress(
        message: 'Import complete (Web)!',
        value: 1.0,
        isCompleted: true,
        dictId: dictId,
        sampleWords: sampleWords.map((w) => w['word'] as String).toList(),
        headwordCount: headwordCount,
        definitionWordCount: defWordCount,
        dictionaryName: bookName,
      );
    } catch (e, s) {
      hDebugPrint('Web import error: $e\n$s');
      yield ImportProgress(
        message: 'Web import error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getDictionaries() async {
    return await _dbHelper.getDictionaries();
  }

  Future<void> toggleDictionaryEnabled(int id, bool isEnabled) async {
    await _dbHelper.updateDictionaryEnabled(id, isEnabled);
  }

  Future<void> updateDictionaryIndexDefinitions(
    int id,
    bool indexDefinitions,
  ) async {
    await _dbHelper.updateDictionaryIndexDefinitions(id, indexDefinitions);
  }

  Stream<DeletionProgress> deleteDictionaryStream(int id) async* {
    yield DeletionProgress(message: 'Starting deletion...', value: 0.1);

    String? dictName;
    if (!kIsWeb) {
      final dict = await _dbHelper.getDictionaryById(id);
      if (dict != null) {
        dictName = dict['name'] as String?;
        final rawPath = dict['path'] as String?;
        if (rawPath != null) {
          yield DeletionProgress(
            message: 'Deleting dictionary files...',
            value: 0.3,
          );
          try {
            final String resolvedPath = await _dbHelper.resolvePath(rawPath);
            final file = File(resolvedPath);
            final dir = file.parent;

            if (await dir.exists()) {
              final dirName = p.basename(dir.path);
              if (dirName.startsWith('dict_') ||
                  dirName.startsWith('mdict_') ||
                  dirName.startsWith('dictd_') ||
                  dirName.startsWith('slob_')) {
                await dir.delete(recursive: true);
                hDebugPrint(
                  'Deleted physical dictionary directory: ${dir.path}',
                );
              }
            }
          } catch (e) {
            hDebugPrint('Failed to delete physical dictionary directory: $e');
          }
        }
      }
    }

    yield DeletionProgress(message: 'Removing from database...', value: 0.6);
    await _dbHelper.deleteDictionary(id);

    yield DeletionProgress(message: 'Optimizing database...', value: 0.9);

    yield DeletionProgress(
      message: dictName != null ? 'Deleted "$dictName"' : 'Dictionary deleted',
      value: 1.0,
      isCompleted: true,
    );
  }

  Future<void> deleteDictionary(int id) async {
    await for (final _ in deleteDictionaryStream(id)) {}
  }

  Future<void> reorderDictionaries(List<int> sortedIds) async {
    await _dbHelper.reorderDictionaries(sortedIds);
  }

  // ── MDict Import ────────────────────────────────────────────────────────────

  /// Imports a MDict (.mdx) file on native platforms.
  Stream<ImportProgress> importMdictStream(
    String mdxPath, {
    String? mddPath,
    bool indexDefinitions = false,
  }) async* {
    if (kIsWeb) {
      yield ImportProgress(
        message: 'Error: MDict import is not supported on Web.',
        value: 0.0,
        error: 'Web unsupported',
        isCompleted: true,
      );
      return;
    }

    yield ImportProgress(message: 'Opening MDict file...', value: 0.05);

    try {
      final reader = await MdictReader.fromPath(mdxPath);
      await reader.open();

      final checksum = await _calculateChecksum(mdxPath);
      final existing = await _dbHelper.getDictionaryByChecksum(checksum);
      if (existing != null) {
        await reader.close();
        yield ImportProgress(
          message:
              'MDict dictionary "${existing['name']}" is already in your library.',
          value: 1.0,
          error: 'ALREADY_EXISTS',
          isCompleted: true,
        );
        return;
      }

      // Use the filename (without extension) as a fallback book name
      final bookName = p.basenameWithoutExtension(mdxPath);

      yield ImportProgress(
        message: 'Copying to permanent storage...',
        value: 0.15,
      );

      final appDocDir = await getApplicationDocumentsDirectory();
      final dictsDir = Directory(p.join(appDocDir.path, 'dictionaries'));
      if (!await dictsDir.exists()) await dictsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final permanentDir = Directory(p.join(dictsDir.path, 'mdict_$timestamp'));
      await permanentDir.create(recursive: true);

      final finalMdxPath = p.join(permanentDir.path, p.basename(mdxPath));
      await File(mdxPath).copy(finalMdxPath);

      // Also copy the companion .mdd file if it exists
      final mddSourcePath =
          mddPath ??
          mdxPath.replaceAll(RegExp(r'\.mdx$', caseSensitive: false), '.mdd');
      if (await File(mddSourcePath).exists()) {
        final finalMddPath = p.join(
          permanentDir.path,
          p.basename(mddSourcePath),
        );
        await File(mddSourcePath).copy(finalMddPath);
      }

      await reader.close();

      yield ImportProgress(message: 'Registering dictionary...', value: 0.3);
      final dictId = await _dbHelper.insertDictionary(
        bookName,
        finalMdxPath,
        indexDefinitions: indexDefinitions,
        format: 'mdict',
        typeSequence: null,
        checksum: checksum,
        sourceUrl: _currentImportSourceUrl,
      );

      yield ImportProgress(message: 'Indexing headwords...', value: 0.5);

      final receivePort = ReceivePort();
      final rootIsolateToken = RootIsolateToken.instance!;

      await Isolate.spawn(
        _indexMdictEntry,
        _IndexMdictArgs(
          dictId: dictId,
          mdxPath: finalMdxPath,
          indexDefinitions: indexDefinitions,
          bookName: bookName,
          sendPort: receivePort.sendPort,
          rootIsolateToken: rootIsolateToken,
        ),
      );

      int finalHeadwordCount = 0;
      await for (final message in receivePort) {
        if (message is ImportProgress) {
          if (message.error != null) {
            receivePort.close();
            if (message.error == 'ALREADY_EXISTS') {
              throw Exception('ALREADY_EXISTS: ${message.message}');
            }
            throw Exception(message.error);
          }
          if (message.isCompleted) {
            finalHeadwordCount = message.headwordCount;
            receivePort.close();
            break;
          }
          yield message;
        }
      }

      final sampleWords = await _dbHelper.getSampleWords(dictId);

      yield ImportProgress(
        message: 'MDict import complete!',
        value: 1.0,
        isCompleted: true,
        dictId: dictId,
        sampleWords: sampleWords.map((w) => w['word'] as String).toList(),
        headwordCount: finalHeadwordCount,
        dictionaryName: bookName,
      );
    } catch (e, s) {
      hDebugPrint('MDict import error: $e\n$s');
      yield ImportProgress(
        message: 'MDict import error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  // ── DICTD Import ────────────────────────────────────────────────────────────

  /// Imports a DICTD dictionary (`.index` + `.dict` or `.dict.dz`).
  /// [indexPath] is the `.index` file; [dictPath] may be `.dict` or `.dict.dz`.
  Stream<ImportProgress> importDictdStream(
    String indexPath,
    String dictPath, {
    bool indexDefinitions = false,
  }) async* {
    if (kIsWeb) {
      yield ImportProgress(
        message: 'Error: DICTD import is not supported on Web.',
        value: 0.0,
        error: 'Web unsupported',
        isCompleted: true,
      );
      return;
    }

    yield ImportProgress(message: 'Setting up DICTD import...', value: 0.05);

    try {
      final checksum = await _calculateChecksum(indexPath);
      final existing = await _dbHelper.getDictionaryByChecksum(checksum);
      if (existing != null) {
        yield ImportProgress(
          message:
              'DICTD dictionary "${existing['name']}" is already in your library.',
          value: 1.0,
          error: 'ALREADY_EXISTS',
          isCompleted: true,
        );
        return;
      }

      final bookName = p
          .basenameWithoutExtension(indexPath)
          .replaceAll(RegExp(r'\.dict$'), '');

      yield ImportProgress(
        message: 'Copying to permanent storage...',
        value: 0.2,
      );

      final appDocDir = await getApplicationDocumentsDirectory();
      final dictsDir = Directory(p.join(appDocDir.path, 'dictionaries'));
      if (!await dictsDir.exists()) await dictsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final permanentDir = Directory(p.join(dictsDir.path, 'dictd_$timestamp'));
      await permanentDir.create(recursive: true);

      final finalDictPath = p.join(permanentDir.path, p.basename(dictPath));
      final finalIndexPath = p.join(permanentDir.path, p.basename(indexPath));
      await File(dictPath).copy(finalDictPath);
      await File(indexPath).copy(finalIndexPath);

      yield ImportProgress(message: 'Registering dictionary...', value: 0.35);
      final dictId = await _dbHelper.insertDictionary(
        bookName,
        finalDictPath,
        indexDefinitions: indexDefinitions,
        format: 'dictd',
        typeSequence: null,
        checksum: checksum,
        sourceUrl: _currentImportSourceUrl,
      );

      yield ImportProgress(message: 'Indexing DICTD words...', value: 0.45);

      final receivePort = ReceivePort();
      final rootIsolateToken = RootIsolateToken.instance!;

      await Isolate.spawn(
        _indexDictdEntry,
        _IndexDictdArgs(
          dictId: dictId,
          indexPath: finalIndexPath,
          dictPath: finalDictPath,
          indexDefinitions: indexDefinitions,
          bookName: bookName,
          sendPort: receivePort.sendPort,
          rootIsolateToken: rootIsolateToken,
        ),
      );

      int finalHeadwordCount = 0;
      int finalDefWordCount = 0;
      await for (final message in receivePort) {
        if (message is ImportProgress) {
          if (message.error != null) {
            receivePort.close();
            throw Exception(message.error);
          }
          if (message.isCompleted) {
            finalHeadwordCount = message.headwordCount;
            finalDefWordCount = message.definitionWordCount;
            receivePort.close();
            break;
          }
          yield message;
        }
      }

      final sampleWords = await _dbHelper.getSampleWords(dictId);

      yield ImportProgress(
        message: 'DICTD import complete!',
        value: 1.0,
        isCompleted: true,
        dictId: dictId,
        sampleWords: sampleWords.map((w) => w['word'] as String).toList(),
        headwordCount: finalHeadwordCount,
        definitionWordCount: finalDefWordCount,
        dictionaryName: bookName,
      );
    } catch (e, s) {
      hDebugPrint('DICTD import error: $e\n$s');
      yield ImportProgress(
        message: 'DICTD import error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  // ── Slob Import ─────────────────────────────────────────────────────────────

  /// Imports a Slob (.slob) dictionary on native platforms.
  Stream<ImportProgress> importSlobStream(
    String slobPath, {
    bool indexDefinitions = false,
  }) async* {
    if (kIsWeb) {
      yield ImportProgress(
        message: 'Error: Slob import is not supported on Web.',
        value: 0.0,
        error: 'Web unsupported',
        isCompleted: true,
      );
      return;
    }

    yield ImportProgress(message: 'Opening Slob file...', value: 0.05);

    try {
      final reader = await SlobReader.fromPath(slobPath);
      await reader.open();

      final checksum = await _calculateChecksum(slobPath);
      final existing = await _dbHelper.getDictionaryByChecksum(checksum);
      if (existing != null) {
        await reader.close();
        yield ImportProgress(
          message:
              'Slob dictionary "${existing['name']}" is already in your library.',
          value: 1.0,
          error: 'ALREADY_EXISTS',
          isCompleted: true,
        );
        return;
      }

      final bookName = reader.bookName.isNotEmpty
          ? reader.bookName
          : p.basenameWithoutExtension(slobPath);

      yield ImportProgress(
        message: 'Copying to permanent storage...',
        value: 0.15,
      );

      final appDocDir = await getApplicationDocumentsDirectory();
      final dictsDir = Directory(p.join(appDocDir.path, 'dictionaries'));
      if (!await dictsDir.exists()) await dictsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final permanentDir = Directory(p.join(dictsDir.path, 'slob_$timestamp'));
      await permanentDir.create(recursive: true);

      final finalSlobPath = p.join(permanentDir.path, p.basename(slobPath));
      await File(slobPath).copy(finalSlobPath);

      await reader.close();

      yield ImportProgress(message: 'Registering dictionary...', value: 0.3);
      final dictId = await _dbHelper.insertDictionary(
        bookName,
        finalSlobPath,
        indexDefinitions: indexDefinitions,
        format: 'slob',
        typeSequence: null,
        checksum: checksum,
        sourceUrl: _currentImportSourceUrl,
      );

      yield ImportProgress(message: 'Indexing Slob blobs...', value: 0.45);

      final receivePort = ReceivePort();
      final rootIsolateToken = RootIsolateToken.instance!;

      await Isolate.spawn(
        _indexSlobEntry,
        _IndexSlobArgs(
          dictId: dictId,
          slobPath: finalSlobPath,
          indexDefinitions: indexDefinitions,
          bookName: bookName,
          sendPort: receivePort.sendPort,
          rootIsolateToken: rootIsolateToken,
        ),
      );

      int finalHeadwordCount = 0;
      int finalDefWordCount = 0;
      await for (final message in receivePort) {
        if (message is ImportProgress) {
          if (message.error != null) {
            receivePort.close();
            throw Exception(message.error);
          }
          if (message.isCompleted) {
            finalHeadwordCount = message.headwordCount;
            finalDefWordCount = message.definitionWordCount;
            receivePort.close();
            break;
          }
          yield message;
        }
      }

      final sampleWords = await _dbHelper.getSampleWords(dictId);

      yield ImportProgress(
        message: 'Slob import complete!',
        value: 1.0,
        isCompleted: true,
        dictId: dictId,
        sampleWords: sampleWords.map((w) => w['word'] as String).toList(),
        headwordCount: finalHeadwordCount,
        definitionWordCount: finalDefWordCount,
        dictionaryName: bookName,
      );
    } catch (e, s) {
      hDebugPrint('Slob import error: $e\n$s');
      yield ImportProgress(
        message: 'Slob import error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    } finally {
      // Any cleanup if needed
    }
  }

  // ── Definition Lookup Dispatch ──────────────────────────────────────────────

  /// Fetches the definition for a word entry from the correct format reader.
  ///
  /// [dictRecord] is the full dictionary row from the DB (includes `format`, `path`).
  /// [word] is the headword string (used for MDict lookup).
  /// [offset] and [length] are the values stored in `word_index`.
  Future<String?> fetchDefinition(
    Map<String, dynamic> dictRecord,
    String word,
    int offset,
    int length,
  ) async {
    if (kIsWeb) return null;
    final format = (dictRecord['format'] as String?) ?? 'stardict';

    final fetchWatch = HPerf.start('fetchDef_Total[$format]');
    String? result;

    try {
      final int? dictId = dictRecord['id'] as int?;
      if (dictId == null) return null;

      // Fast path: plain .dict readers use File.openRead — fully stateless, one
      // fresh OS stream per call, no shared seek position. Concurrent reads are
      // safe without any lock once the reader is cached.
      final cached = _readerCache[dictId];
      if (cached is DictReader && !cached.isDz) {
        // Already cached and stateless — read directly, no lock.
        final ioWatch = HPerf.start('fetchDef_IO[$format]');
        result = await cached.readAtIndex(offset, length);
        HPerf.end(ioWatch, 'fetchDef_IO[$format]');
      } else if (cached == null) {
        // First access for this dict: take the lock to create + cache the reader.
        result = await _synchronized(dictId, () async {
          final reader = await _getReader(dictRecord);
          final ioWatch = HPerf.start('fetchDef_IO[$format]');
          String? res;
          if (reader is DictReader && !reader.isDz) {
            res = await reader.readAtIndex(offset, length);
          } else if (reader is MdictReader) {
            res = await reader.lookup(word);
          } else if (reader is SlobReader) {
            res = await reader.getBlobContentById(offset);
          } else if (reader is DictdReader) {
            res = await reader.readEntry(offset, length);
          } else if (reader is DictReader) {
            res = await reader.readAtIndex(offset, length);
          }
          HPerf.end(ioWatch, 'fetchDef_IO[$format]');
          return res;
        });
      } else {
        // Reader cached but stateful (MDict, Slob, DictD, or .dict.dz) — lock.
        result = await _synchronized(dictId, () async {
          final ioWatch = HPerf.start('fetchDef_IO[$format]');
          String? res;
          if (cached is MdictReader) {
            res = await cached.lookup(word);
          } else if (cached is SlobReader) {
            res = await cached.getBlobContentById(offset);
          } else if (cached is DictdReader) {
            res = await cached.readEntry(offset, length);
          } else if (cached is DictReader) {
            res = await cached.readAtIndex(offset, length);
          }
          HPerf.end(ioWatch, 'fetchDef_IO[$format]');
          return res;
        });
      }
    } catch (e) {
      hDebugPrint('Error fetching definition ($format): $e');
    }

    HPerf.end(fetchWatch, 'fetchDef_Total[$format]');

    // We already recorded actual IO time inside the lock,
    // so Queue time is just (Total - IO).
    return result;
  }

  /// Fetches multiple definitions from the SAME dictionary in a single batch.
  ///
  /// For stateful readers (.dz, .mdx, .slob), this acquires the lock ONCE and
  /// performs all reads sequentially. This eliminates queue contention overhead
  /// and maximizes the benefit of internal chunk caches (e.g. DictzipLocalReader).
  ///
  /// For stateless readers (plain .dict), it fires all reads in parallel since
  /// they don't share state or need a lock.
  Future<List<String?>> fetchDefinitionsBatch(
    Map<String, dynamic> dictRecord,
    List<Map<String, dynamic>> requests,
  ) async {
    if (kIsWeb || requests.isEmpty) return List.filled(requests.length, null);

    final format = (dictRecord['format'] as String?) ?? 'stardict';
    final int? dictId = dictRecord['id'] as int?;
    if (dictId == null) return List.filled(requests.length, null);

    final totalWatch = HPerf.start('fetchBatch_Total[$format]');

    try {
      // 1. Check cache for fast path (plain .dict)
      final cached = _readerCache[dictId];
      if (cached is DictReader && !cached.isDz) {
        // FAST PATH: truly parallel, no locks
        final ioWatch = HPerf.start('fetchBatch_IO_Parallel[$format]');
        final results = await Future.wait(
          requests.map((req) {
            return cached.readAtIndex(
              req['offset'] as int,
              req['length'] as int,
            );
          }),
        );
        HPerf.end(ioWatch, 'fetchBatch_IO_Parallel[$format]');
        HPerf.end(totalWatch, 'fetchBatch_Total[$format]');
        return results;
      }

      // 2. Stateful readers (or first access): acquire lock ONCE for the whole batch
      final results = await _synchronized(dictId, () async {
        final reader = await _getReader(dictRecord);
        if (reader == null) return List<String?>.filled(requests.length, null);

        final ioWatch = HPerf.start('fetchBatch_IO_Seq[$format]');
        final batchResults = <String?>[];

        // Perform all reads sequentially inside the lock
        for (final req in requests) {
          final word = req['word'] as String;
          final offset = req['offset'] as int;
          final length = req['length'] as int;

          if (reader is MdictReader) {
            batchResults.add(await reader.lookup(word));
          } else if (reader is SlobReader) {
            batchResults.add(await reader.getBlobContentById(offset));
          } else if (reader is DictdReader) {
            batchResults.add(await reader.readEntry(offset, length));
          } else if (reader is DictReader) {
            batchResults.add(await reader.readAtIndex(offset, length));
          } else {
            batchResults.add(null);
          }
        }
        HPerf.end(ioWatch, 'fetchBatch_IO_Seq[$format]');
        return batchResults;
      });

      HPerf.end(totalWatch, 'fetchBatch_Total[$format]');
      return results;
    } catch (e) {
      hDebugPrint('Error in fetchDefinitionsBatch ($format): $e');
      HPerf.end(totalWatch, 'fetchBatch_Total[$format]');
      return List.filled(requests.length, null);
    }
  }

  Stream<ImportProgress> reIndexDictionariesStream() async* {
    yield ImportProgress(
      message: 'Re-indexing not fully implemented for Web yet.',
      value: 1.0,
      isCompleted: true,
    );
  }

  /// Re-indexes a dictionary.
  Stream<ImportProgress> reindexDictionaryStream(
    int dictId, {
    bool indexDefinitions = true,
  }) async* {
    yield ImportProgress(message: 'Preparing to re-index...', value: 0.1);

    if (kIsWeb) {
      yield ImportProgress(
        message: 'Re-indexing not fully implemented for Web yet.',
        value: 1.0,
        isCompleted: true,
      );
      return;
    }

    try {
      final dict = await _dbHelper.getDictionaryById(dictId);
      if (dict == null) throw Exception('Dictionary not found');

      final String dictPath = await _dbHelper.resolvePath(dict['path']);
      final String format = dict['format'] as String? ?? 'stardict';
      final String bookName = dict['name'] as String? ?? 'Unknown Dictionary';

      // Wipe existing index
      yield ImportProgress(
        message: 'Wiping existing index...',
        value: 0.2,
        dictionaryName: bookName,
      );
      await _dbHelper.deleteWordsByDictionaryId(dictId);
      await _dbHelper.updateDictionaryIndexDefinitions(
        dictId,
        indexDefinitions,
      );

      yield ImportProgress(
        message: 'Starting re-indexing...',
        value: 0.3,
        dictionaryName: bookName,
      );

      final receivePort = ReceivePort();
      final rootIsolateToken = RootIsolateToken.instance!;

      switch (format) {
        case 'mdict':
          await Isolate.spawn(
            _indexMdictEntry,
            _IndexMdictArgs(
              dictId: dictId,
              mdxPath: dictPath,
              indexDefinitions: indexDefinitions,
              bookName: bookName,
              sendPort: receivePort.sendPort,
              rootIsolateToken: rootIsolateToken,
            ),
          );
          break;

        case 'slob':
          await Isolate.spawn(
            _indexSlobEntry,
            _IndexSlobArgs(
              dictId: dictId,
              slobPath: dictPath,
              indexDefinitions: indexDefinitions,
              bookName: bookName,
              sendPort: receivePort.sendPort,
              rootIsolateToken: rootIsolateToken,
            ),
          );
          break;

        case 'dictd':
          // For DICTD, we need the .index file. It should be in the same folder.
          final indexPath = dictPath.replaceFirst(
            RegExp(r'\.dict(\.dz)?$'),
            '.index',
          );
          if (!File(indexPath).existsSync()) {
            throw Exception('DICTD .index file not found at $indexPath');
          }
          await Isolate.spawn(
            _indexDictdEntry,
            _IndexDictdArgs(
              dictId: dictId,
              indexPath: indexPath,
              dictPath: dictPath,
              indexDefinitions: indexDefinitions,
              bookName: bookName,
              sendPort: receivePort.sendPort,
              rootIsolateToken: rootIsolateToken,
            ),
          );
          break;

        case 'stardict':
        default:
          // If the stored path is .dict.dz, strip the .dz before deriving sibling paths.
          final String dictBasePath = dictPath.endsWith('.dz')
              ? dictPath.substring(
                  0,
                  dictPath.length - 3,
                ) // 'something.dict.dz' → 'something.dict'
              : dictPath;
          final String ifoPath = dictBasePath.replaceAll('.dict', '.ifo');
          final String idxPath = dictBasePath.replaceAll('.dict', '.idx');
          final String synPathCandidate = dictBasePath.replaceAll(
            '.dict',
            '.syn',
          );
          final String? synPath = File(synPathCandidate).existsSync()
              ? synPathCandidate
              : null;

          final ifoParser = IfoParser();
          await ifoParser.parse(ifoPath);

          await Isolate.spawn(
            _indexEntry,
            _IndexArgs(dictId, idxPath, dictPath, synPath, indexDefinitions, ifoParser, 'managed', null, receivePort.sendPort, rootIsolateToken,
            ),
          );
          break;
      }

      int finalHeadwordCount = 0;
      int finalDefWordCount = 0;
      await for (final message in receivePort) {
        if (message is ImportProgress) {
          if (message.error != null) {
            receivePort.close();
            throw Exception(message.error);
          }
          if (message.isCompleted) {
            finalHeadwordCount = message.headwordCount;
            finalDefWordCount = message.definitionWordCount;
            receivePort.close();
            break;
          }
          yield message;
        }
      }
      yield ImportProgress(
        message:
            '$bookName: $finalHeadwordCount headwords, $finalDefWordCount words in definition',
        value: 1.0,
        isCompleted: true,
        headwordCount: finalHeadwordCount,
        definitionWordCount: finalDefWordCount,
        dictionaryName: bookName,
      );
    } catch (e) {
      yield ImportProgress(
        message: 'Re-indexing failed: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }

  String _resolveDownloadFilename(String url, Map<String, String> headers) {
    final contentDisposition = headers['content-disposition'];
    if (contentDisposition != null) {
      final filenameMatch = RegExp(
        r'filename[*]?=["\s]*([^";\s]+)',
      ).firstMatch(contentDisposition);
      if (filenameMatch != null) {
        final name = filenameMatch.group(1)!;
        if (_isRecognizedExtension(name)) return name;
      }
    }
    final uri = Uri.parse(url);
    if (uri.pathSegments.isNotEmpty) {
      final urlName = uri.pathSegments.last;
      if (_isRecognizedExtension(urlName)) return urlName;
    }
    return 'downloaded_dict.zip';
  }

  bool _isRecognizedExtension(String name) {
    final lower = name.toLowerCase();
    final recognized = [
      '.zip',
      '.tar.gz',
      '.tgz',
      '.tar.bz2',
      '.tbz2',
      '.tar.xz',
      '.tar', // Archives
      '.slob', // Slob format (direct download)
      '.mdx', '.mdd', // MDict formats
      '.ifo', '.ifo.gz', '.ifo.dz', '.ifo.bz2', '.ifo.xz', // StarDict
      '.idx', '.idx.gz', '.idx.dz', '.idx.bz2', '.idx.xz',
      '.dict', '.dict.dz', '.dict.gz', '.dict.bz2', '.dict.xz',
      '.syn', '.syn.gz', '.syn.dz', '.syn.bz2', '.syn.xz',
      '.index', '.index.gz', '.index.dz', // DICTD
    ];
    return recognized.any((ext) => lower.endsWith(ext));
  }

  Stream<ImportProgress> downloadAndImportDictionaryStream(
    String url, {
    bool indexDefinitions = false,
    String? sourceUrl,
  }) async* {
    yield ImportProgress(message: 'Connecting...', value: 0.0);

    String effectiveUrl = url.trim().replaceAll(' ', '');
    if (effectiveUrl.contains('github.com/')) {
      effectiveUrl = effectiveUrl
          .replaceFirst('github.com/', 'raw.githubusercontent.com/')
          .replaceFirst('/blob/', '/')
          .replaceFirst('/raw/', '/');
    }

    _currentImportSourceUrl = sourceUrl ?? url;

    if (kIsWeb) {
      // On Web, we must use byte-based download and import
      try {
        final response = await http.get(Uri.parse(effectiveUrl));
        if (response.statusCode == 200) {
          String fileName = _resolveDownloadFilename(
            effectiveUrl,
            response.headers,
          );
          yield* importDictionaryWebStream(
            fileName,
            response.bodyBytes,
            indexDefinitions: indexDefinitions,
          );
        } else {
          throw Exception('Failed to download: HTTP ${response.statusCode}');
        }
      } catch (e) {
        String errorMsg = e.toString();
        if (errorMsg.contains('ClientException') &&
            errorMsg.contains('Failed to fetch')) {
          errorMsg =
              'Download failed due to a CORS error. This happens when the server hosting the file doesn\'t allow web browsers from other domains to download it directly. Try downloading the file manually and then use "Import File".';
        }
        yield ImportProgress(
          message: 'Download error: $errorMsg',
          value: 0.0,
          error: errorMsg,
          isCompleted: true,
        );
      }
      return;
    }

    final tempBaseDir = await getTemporaryDirectory();
    await tempBaseDir.create(recursive: true);
    final tempDir = await tempBaseDir.createTemp('download_');

    try {
      final request = http.Request('GET', Uri.parse(effectiveUrl));
      final response = await _client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      String fileName = _resolveDownloadFilename(
        effectiveUrl,
        response.headers,
      );
      final tempFile = File(p.join(tempDir.path, fileName));

      final contentLength = response.contentLength ?? -1;
      int bytesReceived = 0;

      final fileSink = tempFile.openWrite();
      await for (final chunk in response.stream) {
        fileSink.add(chunk);
        bytesReceived += chunk.length;
        if (contentLength > 0) {
          yield ImportProgress(
            message:
                'Downloading... ${(bytesReceived / contentLength * 100).round()}%',
            value: (bytesReceived / contentLength) * 0.5,
          );
        }
      }
      await fileSink.close();

      yield ImportProgress(
        message: 'Download complete. Importing...',
        value: 0.5,
      );
      yield* importDictionaryStream(
        tempFile.path,
        indexDefinitions: indexDefinitions,
      );
    } catch (e) {
      yield ImportProgress(
        message: 'Download error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    }
  }
}
