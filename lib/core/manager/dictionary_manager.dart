import 'dart:io';
import 'dart:isolate';
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

// Top-level functions for compute
List<int> _decompressGzip(List<int> bytes) {
  return GZipDecoder().decodeBytes(bytes);
}

Archive _decodeZip(List<int> bytes) {
  return ZipDecoder().decodeBytes(bytes);
}

Archive _decodeTarGz(List<int> bytes) {
  return TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
}

Archive _decodeTar(List<int> bytes) {
  return TarDecoder().decodeBytes(bytes);
}

Archive _decodeTarBz2(List<int> bytes) {
  return TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));
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

// Top-level function to run in the isolate for extraction
Future<void> _importEntry(_ImportArgs args) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(args.rootIsolateToken);
  final SendPort sendPort = args.sendPort;
  final String archivePath = args.archivePath;
  final String tempDirPath = args.tempDirPath;

  try {
    sendPort.send(ImportProgress(message: 'Reading archive...', value: 0.05));
    final archiveFile = File(archivePath);
    if (!await archiveFile.exists()) {
      throw Exception('Archive not found');
    }

    final bytes = await archiveFile.readAsBytes();
    Archive archive;
    if (archivePath.endsWith('.zip')) {
      archive = await compute(_decodeZip, bytes);
    } else if (archivePath.endsWith('.tar.gz') ||
        archivePath.endsWith('.tgz')) {
      archive = await compute(_decodeTarGz, bytes);
    } else if (archivePath.endsWith('.tar')) {
      archive = await compute(_decodeTar, bytes);
    } else if (archivePath.endsWith('.tar.bz2') ||
        archivePath.endsWith('.tbz2')) {
      archive = await compute(_decodeTarBz2, bytes);
    } else {
      throw Exception('Unsupported archive format');
    }

    sendPort.send(ImportProgress(message: 'Extracting files...', value: 0.2));
    int extractedCount = 0;
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File(p.join(tempDirPath, filename))
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory(p.join(tempDirPath, filename)).create(recursive: true);
      }
      extractedCount++;
      sendPort.send(
        ImportProgress(
          message:
              'Extracting files... (${(extractedCount / archive.length * 100).round()}%)',
          value: 0.2 + (extractedCount / archive.length * 0.25),
        ),
      ); // 20% to 45%
    }

    sendPort.send(
      ImportProgress(message: 'Locating .ifo file...', value: 0.45),
    );
    File? ifoFile;
    await for (final entity in Directory(tempDirPath).list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.ifo')) {
        ifoFile = entity;
        break;
      }
    }

    if (ifoFile == null) {
      throw Exception('No .ifo file found in archive');
    }

    // Send success message with ifoPath, indicating extraction is complete
    sendPort.send(
      ImportProgress(
        message: 'Extraction complete.',
        value: 0.5,
        isCompleted: true,
        ifoPath: ifoFile.path,
      ),
    );
  } catch (e, s) {
    debugPrint('Error in _importEntry: $e\n$s');
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
///
/// This class orchestrates various parsers (Ifo, Idx, Syn) and the database to
/// provides a seamless experience for adding new dictionary content.
class DictionaryManager {
  final DatabaseHelper _dbHelper;
  final http.Client _client;

  DictionaryManager({DatabaseHelper? dbHelper, http.Client? client})
    : _dbHelper = dbHelper ?? DatabaseHelper(),
      _client = client ?? http.Client();

  /// Imports a dictionary with progress updates.
  Stream<ImportProgress> importDictionaryStream(
    String archivePath, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Preparing...', value: 0.0);

    final appDocDir = await getApplicationDocumentsDirectory();
    final dictsDir = Directory(p.join(appDocDir.path, 'dictionaries'));
    if (!await dictsDir.exists()) {
      await dictsDir.create(recursive: true);
    }

    final tempDir = await dictsDir.createTemp('import_');
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

      String? ifoPathFromIsolate;

      await for (final message in receivePort) {
        if (message is ImportProgress) {
          yield message; // Yield progress from the isolate

          if (message.isCompleted) {
            if (message.error != null) {
              // Isolate reported an error
              throw Exception(message.error);
            } else if (message.ifoPath != null) {
              // Isolate successfully completed extraction and returned ifoPath
              ifoPathFromIsolate = message.ifoPath;
              break; // Exit the loop, extraction phase is done
            }
          }
        } else {
          // Unexpected message type
          throw Exception('Unexpected message from isolate: $message');
        }
      }

      if (ifoPathFromIsolate == null) {
        throw Exception('Extraction completed but no .ifo file path received.');
      }

      // Delegate the rest of the work to the shared logic
      yield* _processDictionaryFiles(ifoPathFromIsolate, dictsDir);
    } catch (e, s) {
      debugPrint('Error in importDictionaryStream: $e\n$s');
      yield ImportProgress(
        message: 'Error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    } finally {
      receivePort.close();
      // Clean up temp extraction directory (permanent files already copied)
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  /// Imports a dictionary from a set of individual files.
  Stream<ImportProgress> importMultipleFilesStream(
    List<String> filePaths, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Preparing files...', value: 0.0);

    final appDocDir = await getApplicationDocumentsDirectory();
    final dictsDir = Directory(p.join(appDocDir.path, 'dictionaries'));
    if (!await dictsDir.exists()) {
      await dictsDir.create(recursive: true);
    }

    // Group files by base name and find the .ifo file
    String? ifoPath;
    for (final path in filePaths) {
      if (path.endsWith('.ifo')) {
        ifoPath = path;
        break;
      }
    }

    if (ifoPath == null) {
      yield ImportProgress(
        message: 'Error: No .ifo file selected',
        value: 0.0,
        error: 'No .ifo file selected',
        isCompleted: true,
      );
      return;
    }

    // Verify other required files (.idx, .dict/.dict.dz) exist with the same base name
    final basePath = p.withoutExtension(ifoPath);
    final idxPossiblePaths = ['$basePath.idx'];
    final dictPossiblePaths = ['$basePath.dict', '$basePath.dict.dz'];

    bool hasIdx = false;
    for (final pth in idxPossiblePaths) {
      if (await File(pth).exists()) {
        hasIdx = true;
        break;
      }
    }
    if (!hasIdx) {
      yield ImportProgress(
        message: 'Error: Matching .idx file not found',
        value: 0.0,
        error: 'Matching .idx file not found',
        isCompleted: true,
      );
      return;
    }

    bool hasDict = false;
    for (final pth in dictPossiblePaths) {
      if (await File(pth).exists()) {
        hasDict = true;
        break;
      }
    }
    if (!hasDict) {
      yield ImportProgress(
        message: 'Error: Matching .dict/.dict.dz file not found',
        value: 0.0,
        error: 'Matching .dict/.dict.dz file not found',
        isCompleted: true,
      );
      return;
    }

    // Delegate to the shared processing logic
    yield* _processDictionaryFiles(
      ifoPath,
      dictsDir,
      indexDefinitions: indexDefinitions,
    );
  }

  /// Shared logic for processing extracted or selected dictionary files.
  Stream<ImportProgress> _processDictionaryFiles(
    String ifoPath,
    Directory dictsDir, {
    bool indexDefinitions = false,
  }) async* {
    try {
      yield ImportProgress(
        message: 'Processing dictionary files...',
        value: 0.55,
      );

      final basePath = p.withoutExtension(ifoPath);
      final idxPath = '$basePath.idx';
      String dictPath = '$basePath.dict';

      if (!await File(dictPath).exists()) {
        if (await File('$basePath.dict.dz').exists()) {
          dictPath = '$basePath.dict.dz';
          yield ImportProgress(
            message: 'Decompressing .dict.dz...',
            value: 0.6,
          );
          final dzBytes = await File(dictPath).readAsBytes();
          final dictBytes = await compute(_decompressGzip, dzBytes);

          // Write decompressed file in the same directory as .ifo
          dictPath = '$basePath.dict';
          await File(dictPath).writeAsBytes(dictBytes);
          yield ImportProgress(message: 'Decompression complete.', value: 0.65);
        } else {
          throw Exception('No .dict file found');
        }
      }

      // Support .syn and .syn.dz
      String? synPath;
      if (await File('$basePath.syn').exists()) {
        synPath = '$basePath.syn';
      } else if (await File('$basePath.syn.dz').exists()) {
        final synDzPath = '$basePath.syn.dz';
        yield ImportProgress(message: 'Decompressing .syn.dz...', value: 0.68);
        final dzBytes = await File(synDzPath).readAsBytes();
        final synBytes = await compute(_decompressGzip, dzBytes);
        synPath = '$basePath.syn';
        await File(synPath).writeAsBytes(synBytes);
      }

      // 3. Parse Metadata
      yield ImportProgress(
        message: 'Parsing dictionary metadata...',
        value: 0.75,
      );
      final ifoParser = IfoParser();
      await ifoParser.parse(ifoPath);

      // 3.5 Move files to permanent location
      yield ImportProgress(message: 'Saving dictionary files...', value: 0.78);
      final bookName = ifoParser.bookName ?? 'Unknown Dictionary';
      final sanitizedName = bookName
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final permanentDir = Directory(
        p.join(dictsDir.path, '${sanitizedName}_$timestamp'),
      );
      await permanentDir.create(recursive: true);

      final permanentDictPath = p.join(permanentDir.path, p.basename(dictPath));
      final permanentIdxPath = p.join(permanentDir.path, p.basename(idxPath));
      final permanentIfoPath = p.join(permanentDir.path, p.basename(ifoPath));

      await File(dictPath).copy(permanentDictPath);
      await File(idxPath).copy(permanentIdxPath);
      await File(ifoPath).copy(permanentIfoPath);

      String? permanentSynPath;
      if (synPath != null) {
        permanentSynPath = p.join(permanentDir.path, p.basename(synPath));
        await File(synPath).copy(permanentSynPath);
      }

      // 4. Insert into DB
      yield ImportProgress(message: 'Inserting into database...', value: 0.8);
      final dictId = await _dbHelper.insertDictionary(
        bookName,
        permanentDictPath,
        indexDefinitions: indexDefinitions,
      );

      // 5. Index Words
      yield ImportProgress(message: 'Indexing words...', value: 0.85);
      final idxParser = IdxParser(ifoParser);
      final stream = idxParser.parse(permanentIdxPath);
      final dictReader = DictReader(permanentDictPath);
      await dictReader.open();

      List<Map<String, dynamic>> batch = [];
      List<({int offset, int length, String content})> wordOffsets = [];
      int headwordCount = 0;
      int defWordCount = 0;

      await for (final entry in stream) {
        final String word = entry['word'];
        final offset = entry['offset'] as int;
        final length = entry['length'] as int;
        final content = indexDefinitions
            ? await dictReader.readAtIndex(offset, length)
            : '';

        batch.add({
          'word': word,
          'content': content,
          'dict_id': dictId,
          'offset': offset,
          'length': length,
        });

        headwordCount++;
        if (content.isNotEmpty) {
          // Approximate word count by splitting on whitespace
          defWordCount += content
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty)
              .length;
        }

        wordOffsets.add((offset: offset, length: length, content: content));
        if (batch.length >= 2000) {
          await _dbHelper.batchInsertWords(dictId, batch);
          batch.clear();
          yield ImportProgress(
            message: 'Indexing $headwordCount headwords...',
            value:
                0.85 +
                (headwordCount /
                    (ifoParser.wordCount == 0 ? 100000 : ifoParser.wordCount) *
                    0.05),
            headwordCount: headwordCount,
            definitionWordCount: defWordCount,
          );
        }
      }
      if (batch.isNotEmpty) await _dbHelper.batchInsertWords(dictId, batch);

      // 6. Index Synonyms
      if (permanentSynPath != null) {
        yield ImportProgress(
          message: 'Indexing synonyms...',
          value: 0.9,
          headwordCount: headwordCount,
          definitionWordCount: defWordCount,
        );
        final synParser = SynParser();
        final synStream = synParser.parse(permanentSynPath);
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
          if (synBatch.length >= 2000) {
            await _dbHelper.batchInsertWords(dictId, synBatch);
            synBatch.clear();
            yield ImportProgress(
              message: 'Indexing synonyms... ($headwordCount total headwords)',
              value: 0.9 + (headwordCount / wordOffsets.length * 0.05),
              headwordCount: headwordCount,
              definitionWordCount: defWordCount,
            );
          }
        }
        if (synBatch.isNotEmpty) {
          await _dbHelper.batchInsertWords(dictId, synBatch);
        }
      }

      await dictReader.close();

      await _dbHelper.updateDictionaryWordCount(dictId, headwordCount);
      final sampleWords = await _dbHelper.getSampleWords(dictId);

      yield ImportProgress(
        message: 'Import complete!',
        value: 1.0,
        isCompleted: true,
        dictId: dictId,
        ifoPath: ifoPath,
        sampleWords: sampleWords.map((w) => w['word'] as String).toList(),
        headwordCount: headwordCount,
        definitionWordCount: defWordCount,
      );
    } catch (e, s) {
      debugPrint('Error in _processDictionaryFiles: $e\n$s');
      yield ImportProgress(
        message: 'Error: $e',
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

  Future<void> deleteDictionary(int id) async {
    final dicts = await _dbHelper.getDictionaries();
    final dict = dicts.firstWhere((d) => d['id'] == id, orElse: () => {});
    if (dict.isNotEmpty) {
      final parentDir = File(dict['path'] as String).parent;
      if (await parentDir.exists()) await parentDir.delete(recursive: true);
    }
    await _dbHelper.deleteDictionary(id);
  }

  Future<void> reorderDictionaries(List<int> sortedIds) async {
    await _dbHelper.reorderDictionaries(sortedIds);
  }

  /// Re-indexes all currently imported dictionaries to populate the 'content' column.
  /// This is useful after a schema update that adds the definition content to the search index.
  Stream<ImportProgress> reIndexDictionariesStream() async* {
    final dicts = await _dbHelper.getDictionaries();
    int total = dicts.length;
    int current = 0;

    for (final dict in dicts) {
      current++;
      final dictId = dict['id'] as int;
      final dictName = dict['name'] as String;
      final dictPath = dict['path'] as String;
      final indexDefinitions = (dict['index_definitions'] ?? 0) == 1;
      final parentDir = File(dictPath).parent.path;

      yield ImportProgress(
        message: 'Re-indexing $dictName ($current/$total)...',
        value: (current - 1) / total,
      );

      // Find .ifo and .idx files in the same directory
      String? ifoPath;
      String? idxPath;
      String? synPath;

      final dir = Directory(parentDir);
      await for (final entity in dir.list()) {
        if (entity is File) {
          if (entity.path.endsWith('.ifo')) ifoPath = entity.path;
          if (entity.path.endsWith('.idx')) idxPath = entity.path;
          if (entity.path.endsWith('.syn')) synPath = entity.path;
        }
      }

      if (ifoPath == null || idxPath == null) {
        debugPrint('Missing required files for re-indexing $dictName');
        continue;
      }

      // Clear existing index for this dictionary
      final db = await _dbHelper.database;
      await db.delete('word_index', where: 'dict_id = ?', whereArgs: [dictId]);

      // Parse metadata
      final ifoParser = IfoParser();
      await ifoParser.parse(ifoPath);

      // Re-index
      yield* _processReindexing(
        dictId,
        dictPath,
        idxPath,
        synPath,
        ifoParser,
        (current - 1) / total,
        1 / total,
        indexDefinitions: indexDefinitions,
      );
    }

    yield ImportProgress(
      message: 'Re-indexing complete!',
      value: 1.0,
      isCompleted: true,
    );
  }

  Stream<ImportProgress> _processReindexing(
    int dictId,
    String dictPath,
    String idxPath,
    String? synPath,
    IfoParser ifoParser,
    double baseProgress,
    double progressScale, {
    bool indexDefinitions = false,
  }) async* {
    final idxParser = IdxParser(ifoParser);
    final idxStream = idxParser.parse(idxPath);
    final dictReader = DictReader(dictPath);
    await dictReader.open();

    List<Map<String, dynamic>> batch = [];
    List<({int offset, int length, String content})> wordOffsets = [];
    int headwordCount = 0;
    int defWordCount = 0;

    await for (final entry in idxStream) {
      final offset = entry['offset'] as int;
      final length = entry['length'] as int;
      final content = indexDefinitions
          ? await dictReader.readAtIndex(offset, length)
          : '';

      batch.add({
        'word': entry['word'],
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
      if (batch.length >= 2000) {
        await _dbHelper.batchInsertWords(dictId, batch);
        batch.clear();
        yield ImportProgress(
          message: 'Indexing $headwordCount headwords...',
          value:
              baseProgress +
              (headwordCount /
                      (ifoParser.wordCount == 0
                          ? 100000
                          : ifoParser.wordCount) *
                      0.8) *
                  progressScale,
          headwordCount: headwordCount,
          definitionWordCount: defWordCount,
        );
      }
    }
    if (batch.isNotEmpty) await _dbHelper.batchInsertWords(dictId, batch);

    if (synPath != null) {
      final synParser = SynParser();
      final synStream = synParser.parse(synPath);
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
        if (synBatch.length >= 2000) {
          await _dbHelper.batchInsertWords(dictId, synBatch);
          synBatch.clear();
          yield ImportProgress(
            message: 'Indexing synonyms... ($headwordCount total headwords)',
            value:
                baseProgress +
                (0.8 + (headwordCount / wordOffsets.length) * 0.2) *
                    progressScale,
            headwordCount: headwordCount,
            definitionWordCount: defWordCount,
          );
        }
      }
      if (synBatch.isNotEmpty) {
        await _dbHelper.batchInsertWords(dictId, synBatch);
      }
    }

    await _dbHelper.updateDictionaryWordCount(dictId, headwordCount);

    await dictReader.close();
  }

  /// Resolves the correct filename for a downloaded file.
  /// Checks Content-Disposition header, URL path, and Content-Type in order.
  String _resolveDownloadFilename(String url, Map<String, String> headers) {
    // 1. Try Content-Disposition header (most reliable)
    final contentDisposition = headers['content-disposition'];
    if (contentDisposition != null) {
      final filenameMatch = RegExp(
        r'filename[*]?=["\s]*([^";\s]+)',
      ).firstMatch(contentDisposition);
      if (filenameMatch != null) {
        final name = filenameMatch.group(1)!;
        if (_hasKnownArchiveExtension(name)) return name;
      }
    }

    // 2. Try URL path segments
    final uri = Uri.parse(url);
    if (uri.pathSegments.isNotEmpty) {
      final urlName = uri.pathSegments.last;
      if (_hasKnownArchiveExtension(urlName)) return urlName;
    }

    // 3. Try Content-Type header
    final contentType = headers['content-type'] ?? '';
    if (contentType.contains('gzip') || contentType.contains('x-gzip')) {
      // Could be .tar.gz — check URL for hints
      final urlLower = url.toLowerCase();
      if (urlLower.contains('.tar.gz') || urlLower.contains('.tgz')) {
        return 'downloaded_dict.tar.gz';
      }
      return 'downloaded_dict.gz';
    } else if (contentType.contains('bzip2') ||
        contentType.contains('x-bzip2')) {
      return 'downloaded_dict.tar.bz2';
    } else if (contentType.contains('x-tar')) {
      return 'downloaded_dict.tar';
    } else if (contentType.contains('zip')) {
      return 'downloaded_dict.zip';
    }

    // 4. Fallback: try to guess from URL string
    final urlLower = url.toLowerCase();
    if (urlLower.contains('.tar.gz')) return 'downloaded_dict.tar.gz';
    if (urlLower.contains('.tgz')) return 'downloaded_dict.tgz';
    if (urlLower.contains('.tar.bz2')) return 'downloaded_dict.tar.bz2';
    if (urlLower.contains('.tbz2')) return 'downloaded_dict.tbz2';
    if (urlLower.contains('.tar')) return 'downloaded_dict.tar';
    if (urlLower.contains('.zip')) return 'downloaded_dict.zip';

    return 'downloaded_dict.zip';
  }

  /// Checks if a filename has a known archive extension.
  bool _hasKnownArchiveExtension(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.zip') ||
        lower.endsWith('.tar.gz') ||
        lower.endsWith('.tgz') ||
        lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tbz2') ||
        lower.endsWith('.tar');
  }

  /// Downloads a dictionary from the given URL and then imports it.
  /// Downloads a dictionary from [url] and imports it in one step.
  ///
  /// Downloads to a temporary file, then delegates to [importDictionaryStream].
  Stream<ImportProgress> downloadAndImportDictionaryStream(
    String url, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Connecting...', value: 0.0);

    final appDocDir = await getApplicationDocumentsDirectory();
    final tempDir = await appDocDir.createTemp('download_');

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await _client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download dictionary: HTTP ${response.statusCode}',
        );
      }

      // Determine the correct filename/extension from multiple sources
      String fileName = _resolveDownloadFilename(url, response.headers);
      final tempFile = File(p.join(tempDir.path, fileName));

      final contentLength = response.contentLength ?? -1;
      int bytesReceived = 0;

      final fileSink = tempFile.openWrite();
      await for (final chunk in response.stream) {
        fileSink.add(chunk);
        bytesReceived += (chunk.length as num).toInt();
        if (contentLength > 0) {
          final progress = bytesReceived / contentLength;
          yield ImportProgress(
            message: 'Downloading... ${(progress * 100).round()}%',
            value: progress * 0.5, // Map download to 0% - 50%
          );
        } else {
          yield ImportProgress(
            message:
                'Downloading... ${(bytesReceived / 1024 / 1024).toStringAsFixed(1)} MB',
            value: 0.1, // Indeterminate
          );
        }
      }
      await fileSink.close();

      yield ImportProgress(
        message: 'Download complete. Starting import...',
        value: 0.5,
      );

      // Now import the file
      final importStream = importDictionaryStream(
        tempFile.path,
        indexDefinitions: indexDefinitions,
      );
      await for (final importEvent in importStream) {
        if (importEvent.isCompleted) {
          yield ImportProgress(
            message: importEvent.message,
            value: 1.0,
            isCompleted: true,
            dictId: importEvent.dictId,
            error: importEvent.error,
          );
        } else {
          yield ImportProgress(
            message: importEvent.message,
            value: 0.5 + (importEvent.value * 0.5),
            error: importEvent.error,
          );
        }
      }
    } catch (e) {
      yield ImportProgress(
        message: 'Download error: $e',
        value: 0.0,
        error: e.toString(),
        isCompleted: true,
      );
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  /// Re-indexes a single dictionary.
  Stream<ImportProgress> reIndexDictionaryStream(int dictId) async* {
    final dict = await _dbHelper.getDictionaryById(dictId);
    if (dict == null) {
      yield ImportProgress(
        message: 'Dictionary not found.',
        value: 0.0,
        isCompleted: true,
        error: 'Dictionary not found',
      );
      return;
    }

    final dictName = dict['name'] as String;
    final dictPath = dict['path'] as String;
    final indexDefinitions = (dict['index_definitions'] ?? 0) == 1;
    final parentDir = p.dirname(dictPath);

    yield ImportProgress(message: 'Re-indexing $dictName...', value: 0.0);

    // Find .ifo and .idx files in the same directory
    String? ifoPath;
    String? idxPath;
    String? synPath;

    final dir = Directory(parentDir);
    await for (final entity in dir.list()) {
      if (entity is File) {
        if (entity.path.endsWith('.ifo')) ifoPath = entity.path;
        if (entity.path.endsWith('.idx')) idxPath = entity.path;
        if (entity.path.endsWith('.syn')) synPath = entity.path;
      }
    }

    if (ifoPath == null || idxPath == null) {
      yield ImportProgress(
        message: 'Missing required files for re-indexing $dictName',
        value: 0.0,
        isCompleted: true,
        error: 'Missing required files',
      );
      return;
    }

    // Clear existing index for this dictionary
    final db = await _dbHelper.database;
    await db.delete('word_index', where: 'dict_id = ?', whereArgs: [dictId]);

    // Parse metadata
    final ifoParser = IfoParser();
    await ifoParser.parse(ifoPath);

    // Re-index
    yield* _processReindexing(
      dictId,
      dictPath,
      idxPath,
      synPath,
      ifoParser,
      0.0,
      1.0,
      indexDefinitions: indexDefinitions,
    );

    yield ImportProgress(
      message: 'Re-indexing complete!',
      value: 1.0,
      isCompleted: true,
    );
  }
}
