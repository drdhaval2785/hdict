import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
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

List<int> _decompressBZip2(List<int> bytes) {
  return BZip2Decoder().decodeBytes(bytes);
}

List<int> _decompressXZ(List<int> bytes) {
  return XZDecoder().decodeBytes(bytes);
}

Archive _decodeZip(List<int> bytes) {
  return ZipDecoder().decodeBytes(bytes);
}

Archive _decodeTarGz(List<int> bytes) {
  try {
    return TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
  } catch (e) {
    if (e.toString().contains('Filter error')) {
      throw Exception(
        'The file does not appear to be a valid GZip archive (Filter error). '
        'If this is a GitHub link, ensure you are using the "Raw" or "Download" URL.',
      );
    }
    rethrow;
  }
}

Archive _decodeTar(List<int> bytes) {
  return TarDecoder().decodeBytes(bytes);
}

Archive _decodeTarBz2(List<int> bytes) {
  return TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));
}

Archive _decodeTarXz(List<int> bytes) {
  return TarDecoder().decodeBytes(XZDecoder().decodeBytes(bytes));
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

// Data class for indexing isolate
class _IndexArgs {
  final int dictId;
  final String idxPath;
  final String dictPath;
  final String? synPath;
  final bool indexDefinitions;
  final IfoParser ifoParser;
  final SendPort sendPort;
  final RootIsolateToken rootIsolateToken;

  _IndexArgs(
    this.dictId,
    this.idxPath,
    this.dictPath,
    this.synPath,
    this.indexDefinitions,
    this.ifoParser,
    this.sendPort,
    this.rootIsolateToken,
  );
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
    final dictReader = DictReader(args.dictPath);
    await dictReader.open();

    List<Map<String, dynamic>> batch = [];
    List<({int offset, int length, String content})> wordOffsets = [];
    int headwordCount = 0;
    int defWordCount = 0;

    await for (final entry in stream) {
      final String word = entry['word'];
      final offset = entry['offset'] as int;
      final length = entry['length'] as int;
      final content =
          args.indexDefinitions ? await dictReader.readAtIndex(offset, length) : '';

      batch.add({
        'word': word,
        'content': content,
        'dict_id': args.dictId,
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
        await dbHelper.batchInsertWords(args.dictId, batch);
        batch.clear();
        sendPort.send(
          ImportProgress(
            message: 'Indexing $headwordCount headwords...',
            value: 0.85 +
                (headwordCount /
                        (args.ifoParser.wordCount == 0
                            ? 100000
                            : args.ifoParser.wordCount) *
                        0.05),
            headwordCount: headwordCount,
            definitionWordCount: defWordCount,
          ),
        );
      }
    }
    if (batch.isNotEmpty) await dbHelper.batchInsertWords(args.dictId, batch);

    if (args.synPath != null) {
      final synParser = SynParser();
      final synStream = synParser.parse(args.synPath!);
      List<Map<String, dynamic>> synBatch = [];
      await for (final syn in synStream) {
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
        if (synBatch.length >= 2000) {
          await dbHelper.batchInsertWords(args.dictId, synBatch);
          synBatch.clear();
        }
      }
      if (synBatch.isNotEmpty) {
        await dbHelper.batchInsertWords(args.dictId, synBatch);
      }
    }

    await dictReader.close();
    await dbHelper.updateDictionaryWordCount(args.dictId, headwordCount);

    sendPort.send(
      ImportProgress(
        message: 'Indexing complete.',
        value: 0.95,
        isCompleted: true,
        headwordCount: headwordCount,
        definitionWordCount: defWordCount,
      ),
    );
  } catch (e, s) {
    debugPrint('Error in _indexEntry: $e\n$s');
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
    } else if (archivePath.endsWith('.tar.xz')) {
      archive = await compute(_decodeTarXz, bytes);
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
      if (entity is File &&
          (entity.path.endsWith('.ifo') ||
              entity.path.endsWith('.ifo.gz') ||
              entity.path.endsWith('.ifo.dz') ||
              entity.path.endsWith('.ifo.bz2') ||
              entity.path.endsWith('.ifo.xz'))) {
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
class DictionaryManager {
  final DatabaseHelper _dbHelper;
  final http.Client _client;

  DictionaryManager({DatabaseHelper? dbHelper, http.Client? client})
    : _dbHelper = dbHelper ?? DatabaseHelper(),
      _client = client ?? http.Client();

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
      final bytes = await File(path).readAsBytes();
      final decompressed = await compute(_decompressXZ, bytes);
      await File(target).writeAsBytes(decompressed);
      return target;
    }
    return path;
  }

  /// Finds a file by checking multiple possible extensions and decompressing if necessary.
  Future<String?> _findAndPrepareFile(
    String basePath,
    List<String> extensions,
  ) async {
    for (final ext in extensions) {
      final path = '$basePath$ext';
      if (await File(path).exists()) {
        return await _maybeDecompress(path);
      }
    }
    return null;
  }

  /// Imports a dictionary with progress updates.
  Stream<ImportProgress> importDictionaryStream(
    String archivePath, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Preparing...', value: 0.0);

    if (kIsWeb) {
      yield ImportProgress(message: 'Error: Path-based import not supported on Web.', value: 0.0, error: 'Web requires byte-based import', isCompleted: true);
      return;
    }

    final tempBaseDir = await getTemporaryDirectory();
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

      String? ifoPathFromIsolate;

      await for (final message in receivePort) {
        if (message is ImportProgress) {
          yield message;

          if (message.isCompleted) {
            if (message.error != null) {
              throw Exception(message.error);
            } else if (message.ifoPath != null) {
              ifoPathFromIsolate = message.ifoPath;
              break;
            }
          }
        }
      }

      if (ifoPathFromIsolate == null) {
        throw Exception('Extraction completed but no .ifo file path received.');
      }

      yield* _processDictionaryFiles(ifoPathFromIsolate, indexDefinitions: indexDefinitions);
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
      Archive archive;
      if (fileName.endsWith('.zip')) {
        archive = ZipDecoder().decodeBytes(bytes);
      } else if (fileName.endsWith('.tar.gz') || fileName.endsWith('.tgz')) {
        archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
      } else if (fileName.endsWith('.tar.bz2') || fileName.endsWith('.tbz2')) {
        archive = TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(bytes));
      } else if (fileName.endsWith('.tar.xz')) {
        archive = TarDecoder().decodeBytes(XZDecoder().decodeBytes(bytes));
      } else if (fileName.endsWith('.tar')) {
        archive = TarDecoder().decodeBytes(bytes);
      } else {
        throw Exception('Unsupported archive format');
      }

      // On Web, we can't extract to a filesystem. We extract to a Map of bytes.
      Map<String, Uint8List> files = {};
      String? ifoName;

      for (final file in archive) {
        if (file.isFile) {
          final content = file.content as List<int>;
          files[file.name] = Uint8List.fromList(content);
          if (file.name.endsWith('.ifo')) ifoName = file.name;
        }
      }

      if (ifoName == null) throw Exception('No .ifo file found');

      yield* _processDictionaryFilesWeb(ifoName, files, indexDefinitions: indexDefinitions);
    } catch (e) {
      yield ImportProgress(message: 'Import error: $e', value: 0.0, error: e.toString(), isCompleted: true);
    }
  }

  /// Imports a dictionary from a set of individual files.
  Stream<ImportProgress> importMultipleFilesStream(
    List<String> filePaths, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Preparing files...', value: 0.0);

    String? ifoPath;
    for (final path in filePaths) {
      if (path.contains('.ifo')) {
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

    yield* _processDictionaryFiles(
      ifoPath,
      indexDefinitions: indexDefinitions,
      otherFilePaths: filePaths,
    );
  }

  /// Web-friendly multiple file import.
  Stream<ImportProgress> importMultipleFilesWebStream(
    List<({String name, Uint8List bytes})> files, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Preparing web files...', value: 0.0);

    Map<String, Uint8List> fileMap = {};
    String? ifoName;
    for (final file in files) {
      fileMap[file.name] = file.bytes;
      if (file.name.endsWith('.ifo')) ifoName = file.name;
    }

    if (ifoName == null) {
      yield ImportProgress(message: 'Error: No .ifo file selected', value: 0.0, error: 'No .ifo file selected', isCompleted: true);
      return;
    }

    yield* _processDictionaryFilesWeb(ifoName, fileMap, indexDefinitions: indexDefinitions);
  }

  /// Shared logic for processing dictionary files and saving them permanently on Native.
  Stream<ImportProgress> _processDictionaryFiles(
    String ifoPath, {
    bool indexDefinitions = false,
    List<String>? otherFilePaths,
  }) async* {
    try {
      yield ImportProgress(
        message: 'Processing dictionary files...',
        value: 0.55,
      );

      final actualIfoPath = await _maybeDecompress(ifoPath);
      final basePath = p.withoutExtension(actualIfoPath);

      // Robust file finding: checking provided paths first, then local directory
      String? findFile(List<String> extensions) {
        if (otherFilePaths != null) {
          for (final path in otherFilePaths) {
            final lowerPath = path.toLowerCase();
            if (extensions.any((ext) => lowerPath.endsWith(ext))) {
              return path;
            }
          }
        }
        return null; // Fallback to original logic if not found in list
      }

      String? idxPath = findFile(['.idx', '.idx.gz', '.idx.dz', '.idx.bz2', '.idx.xz']);
      idxPath ??= await _findAndPrepareFile(basePath, ['.idx', '.idx.gz', '.idx.dz', '.idx.bz2', '.idx.xz']);
      if (idxPath == null) throw Exception('No .idx file found');

      String? dictPath = findFile(['.dict', '.dict.dz', '.dict.gz', '.dict.bz2', '.dict.xz']);
      dictPath ??= await _findAndPrepareFile(basePath, ['.dict', '.dict.dz', '.dict.gz', '.dict.bz2', '.dict.xz']);
      if (dictPath == null) throw Exception('No .dict file found');

      String? synPath = findFile(['.syn', '.syn.gz', '.syn.dz', '.syn.bz2', '.syn.xz']);
      synPath ??= await _findAndPrepareFile(basePath, ['.syn', '.syn.gz', '.syn.dz', '.syn.bz2', '.syn.xz']);

      final ifoParser = IfoParser();
      await ifoParser.parse(actualIfoPath);
      final bookName = ifoParser.bookName ?? 'Unknown Dictionary';

      yield ImportProgress(message: 'Saving dictionary files...', value: 0.75);

      // Native: Move to permanent location
      final appDocDir = await getApplicationDocumentsDirectory();
      final dictsDir = Directory(p.join(appDocDir.path, 'dictionaries'));
      if (!await dictsDir.exists()) await dictsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final permanentDir = Directory(p.join(dictsDir.path, 'dict_$timestamp'));
      await permanentDir.create(recursive: true);

      // Ensure we use the decompressed versions if they were created by _maybeDecompress or _findAndPrepareFile
      final preparedIdxPath = await _maybeDecompress(idxPath);
      final preparedDictPath = await _maybeDecompress(dictPath);
      final preparedSynPath = synPath != null ? await _maybeDecompress(synPath) : null;

      final finalDictPath = p.join(permanentDir.path, p.basename(preparedDictPath));
      await File(preparedDictPath).copy(finalDictPath);
      await File(preparedIdxPath).copy(p.join(permanentDir.path, p.basename(preparedIdxPath)));
      await File(actualIfoPath).copy(p.join(permanentDir.path, p.basename(actualIfoPath)));
      if (preparedSynPath != null) {
        await File(preparedSynPath).copy(p.join(permanentDir.path, p.basename(preparedSynPath)));
      }

      final dictId = await _dbHelper.insertDictionary(
        bookName,
        finalDictPath,
        indexDefinitions: indexDefinitions,
      );

      yield ImportProgress(message: 'Indexing words...', value: 0.85);

      final receivePort = ReceivePort();
      final rootIsolateToken = RootIsolateToken.instance!;

      await Isolate.spawn(
        _indexEntry,
        _IndexArgs(
          dictId,
          p.join(permanentDir.path, p.basename(preparedIdxPath)),
          finalDictPath,
          preparedSynPath != null ? p.join(permanentDir.path, p.basename(preparedSynPath)) : null,
          indexDefinitions,
          ifoParser,
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

  /// Web-specific processing logic using bytes and SQLite virtual filesystem.
  Stream<ImportProgress> _processDictionaryFilesWeb(
    String ifoName,
    Map<String, Uint8List> files, {
    bool indexDefinitions = false,
  }) async* {
    try {
      yield ImportProgress(message: 'Processing web files...', value: 0.5);

      final ifoBytes = files[ifoName]!;
      final ifoContent = utf8.decode(ifoBytes);
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

      final dictId = await _dbHelper.insertDictionary(bookName, dictName, indexDefinitions: indexDefinitions);

      // Save files to virtual filesystem (SQLite 'files' table)
      yield ImportProgress(message: 'Saving files to database...', value: 0.6);
      await _dbHelper.saveFile(dictId, p.basename(ifoName), ifoBytes);
      await _dbHelper.saveFile(dictId, p.basename(idxName), files[idxName]!);
      await _dbHelper.saveFile(dictId, p.basename(dictName), files[dictName]!);

      // Note: SYN handling could be added here too.

      yield ImportProgress(message: 'Import complete (Web)!', value: 1.0, isCompleted: true, dictId: dictId);
    } catch (e) {
      yield ImportProgress(message: 'Web import error: $e', value: 0.0, error: e.toString(), isCompleted: true);
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
    await _dbHelper.deleteDictionary(id);
  }

  Future<void> reorderDictionaries(List<int> sortedIds) async {
    await _dbHelper.reorderDictionaries(sortedIds);
  }

  Stream<ImportProgress> reIndexDictionariesStream() async* {
    yield ImportProgress(message: 'Re-indexing not fully implemented for Web yet.', value: 1.0, isCompleted: true);
  }

  Stream<ImportProgress> reIndexDictionaryStream(int dictId) async* {
    yield ImportProgress(message: 'Re-indexing not fully implemented for Web yet.', value: 1.0, isCompleted: true);
  }

  String _resolveDownloadFilename(String url, Map<String, String> headers) {
    final contentDisposition = headers['content-disposition'];
    if (contentDisposition != null) {
      final filenameMatch = RegExp(r'filename[*]?=["\s]*([^";\s]+)').firstMatch(contentDisposition);
      if (filenameMatch != null) {
        final name = filenameMatch.group(1)!;
        if (_hasKnownArchiveExtension(name)) return name;
      }
    }
    final uri = Uri.parse(url);
    if (uri.pathSegments.isNotEmpty) {
      final urlName = uri.pathSegments.last;
      if (_hasKnownArchiveExtension(urlName)) return urlName;
    }
    return 'downloaded_dict.zip';
  }

  bool _hasKnownArchiveExtension(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.zip') || lower.endsWith('.tar.gz') || lower.endsWith('.tgz') ||
        lower.endsWith('.tar.bz2') || lower.endsWith('.tbz2') || lower.endsWith('.tar.xz') || lower.endsWith('.tar');
  }

  Stream<ImportProgress> downloadAndImportDictionaryStream(
    String url, {
    bool indexDefinitions = false,
  }) async* {
    yield ImportProgress(message: 'Connecting...', value: 0.0);

    String effectiveUrl = url.trim().replaceAll(' ', '');
    if (effectiveUrl.contains('github.com/') && effectiveUrl.contains('/blob/')) {
      effectiveUrl = effectiveUrl.replaceFirst('/blob/', '/raw/');
    }

    if (kIsWeb) {
      // On Web, we must use byte-based download and import
      try {
        final response = await http.get(Uri.parse(effectiveUrl));
        if (response.statusCode == 200) {
          String fileName = _resolveDownloadFilename(effectiveUrl, response.headers);
          yield* importDictionaryWebStream(fileName, response.bodyBytes, indexDefinitions: indexDefinitions);
        } else {
          throw Exception('Failed to download: HTTP ${response.statusCode}');
        }
      } catch (e) {
        yield ImportProgress(message: 'Download error: $e', value: 0.0, error: e.toString(), isCompleted: true);
      }
      return;
    }

    final tempBaseDir = await getTemporaryDirectory();
    final tempDir = await tempBaseDir.createTemp('download_');

    try {
      final request = http.Request('GET', Uri.parse(effectiveUrl));
      final response = await _client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      String fileName = _resolveDownloadFilename(effectiveUrl, response.headers);
      final tempFile = File(p.join(tempDir.path, fileName));

      final contentLength = response.contentLength ?? -1;
      int bytesReceived = 0;

      final fileSink = tempFile.openWrite();
      await for (final chunk in response.stream) {
        fileSink.add(chunk);
        bytesReceived += chunk.length;
        if (contentLength > 0) {
          yield ImportProgress(message: 'Downloading... ${(bytesReceived / contentLength * 100).round()}%', value: (bytesReceived / contentLength) * 0.5);
        }
      }
      await fileSink.close();

      yield ImportProgress(message: 'Download complete. Importing...', value: 0.5);
      yield* importDictionaryStream(tempFile.path, indexDefinitions: indexDefinitions);
    } catch (e) {
      yield ImportProgress(message: 'Download error: $e', value: 0.0, error: e.toString(), isCompleted: true);
    }
  }
}
