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
import 'package:hdict/core/parser/mdict_reader.dart';
import 'package:hdict/core/parser/dictd_parser.dart';
import 'package:hdict/core/parser/slob_reader.dart';

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
      archive = TarDecoder().decodeBytes(XZDecoder().decodeBytes(bytes));
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
    debugPrint('Error extracting $filePath: $e');
  }
}

// Updated _importEntry to support extracting to a specific workspace
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
    String? primaryPath;
    String? format;

    await for (final entity in Directory(tempDirPath).list(recursive: true)) {
      if (entity is! File) continue;

      final lowerPath = entity.path.toLowerCase();
      if (lowerPath.endsWith('.ifo') ||
          lowerPath.endsWith('.ifo.gz') ||
          lowerPath.endsWith('.ifo.dz') ||
          lowerPath.endsWith('.ifo.bz2') ||
          lowerPath.endsWith('.ifo.xz')) {
        primaryPath = entity.path;
        format = 'stardict';
        break;
      } else if (lowerPath.endsWith('.mdx')) {
        primaryPath = entity.path;
        format = 'mdict';
        break;
      } else if (lowerPath.endsWith('.slob')) {
        primaryPath = entity.path;
        format = 'slob';
        break;
      } else if (lowerPath.endsWith('.index')) {
        // DICTD index
        final base = p.withoutExtension(entity.path);
        final dictPath = ['${base}.dict.dz', '${base}.dict']
            .firstWhere((dp) => File(dp).existsSync(), orElse: () => '');
        if (dictPath.isNotEmpty) {
          primaryPath = entity.path;
          format = 'dictd';
          break;
        }
      }
    }

    if (primaryPath == null) {
      throw Exception('No valid dictionary files found in archive.');
    }

    sendPort.send(
      ImportProgress(
        message: 'Extraction complete.',
        value: 0.5,
        isCompleted: true,
        ifoPath: primaryPath, // using ifoPath as general primary path
        error: format, // abusing error field to pass format back, or better, use a custom message
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

      String? primaryPathFromIsolate;
      String? formatFromIsolate;

      await for (final message in receivePort) {
        if (message is ImportProgress) {
          yield message;

          if (message.isCompleted) {
            if (message.error != null && message.ifoPath == null) {
              // This is a real error
              throw Exception(message.error);
            } else if (message.ifoPath != null) {
              primaryPathFromIsolate = message.ifoPath;
              formatFromIsolate = message.error; // We passed format in error field
              break;
            }
          }
        }
      }

      if (primaryPathFromIsolate == null) {
        throw Exception('Extraction completed but no dictionary path received.');
      }

      final format = formatFromIsolate ?? 'stardict';
      switch (format) {
        case 'mdict':
          final mddPath = p.join(p.dirname(primaryPathFromIsolate), '${p.basenameWithoutExtension(primaryPathFromIsolate)}.mdd');
          yield* importMdictStream(
            primaryPathFromIsolate,
            mddPath: File(mddPath).existsSync() ? mddPath : null,
            indexDefinitions: indexDefinitions,
          );
          break;
        case 'slob':
          yield* importSlobStream(primaryPathFromIsolate, indexDefinitions: indexDefinitions);
          break;
        case 'dictd':
          // For DICTD, we need the companion .dict path. 
          // Re-scanning briefly in the temp dir
          final base = p.withoutExtension(primaryPathFromIsolate);
          final dictPath = ['${base}.dict.dz', '${base}.dict']
              .firstWhere((dp) => File(dp).existsSync(), orElse: () => '');
          if (dictPath.isEmpty) throw Exception('DICTD .dict file missing after extraction');
          yield* importDictdStream(primaryPathFromIsolate, dictPath, indexDefinitions: indexDefinitions);
          break;
        case 'stardict':
        default:
          yield* _processDictionaryFiles(primaryPathFromIsolate, indexDefinitions: indexDefinitions);
          break;
      }
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
    yield ImportProgress(message: 'Preparing workspace...', value: 0.0);

    final tempBaseDir = await getTemporaryDirectory();
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
      yield ImportProgress(message: 'Scanning for dictionaries...', value: 0.45);

      final List<({String path, String format, String? companionPath})> discovered = [];

      await for (final entity in workspaceDir.list(recursive: true)) {
        if (entity is! File) continue;

        final lowerPath = entity.path.toLowerCase();
        if (lowerPath.endsWith('.ifo') ||
            lowerPath.endsWith('.ifo.gz') ||
            lowerPath.endsWith('.ifo.dz') ||
            lowerPath.endsWith('.ifo.bz2') ||
            lowerPath.endsWith('.ifo.xz')) {
          discovered.add((path: entity.path, format: 'stardict', companionPath: null));
        } else if (lowerPath.endsWith('.mdx')) {
          discovered.add((path: entity.path, format: 'mdict', companionPath: null));
        } else if (lowerPath.endsWith('.slob')) {
          discovered.add((path: entity.path, format: 'slob', companionPath: null));
        } else if (lowerPath.endsWith('.index')) {
          // Find companion .dict or .dict.dz
          final base = p.withoutExtension(entity.path);
          final dictPath = ['${base}.dict.dz', '${base}.dict']
              .firstWhere((dp) => File(dp).existsSync(), orElse: () => '');
          if (dictPath.isNotEmpty) {
            discovered.add((path: entity.path, format: 'dictd', companionPath: dictPath));
          }
        }
      }

      if (discovered.isEmpty) {
        throw Exception(
            'No valid dictionary files found. Supported formats: StarDict (.ifo), MDict (.mdx), Slob (.slob), DICTD (.index+.dict)');
      }

      int totalDicts = discovered.length;
      int currentDict = 0;

      for (final item in discovered) {
        currentDict++;
        final name = p.basenameWithoutExtension(item.path);
        yield ImportProgress(
          message: 'Importing dictionary $currentDict of $totalDicts: $name',
          value: 0.45 + (currentDict - 1) / totalDicts * 0.55,
        );

        Stream<ImportProgress> subStream;
        switch (item.format) {
          case 'mdict':
            // Look for companion .mdd in the same folder as .mdx
            final mddPath = p.join(p.dirname(item.path), '${p.basenameWithoutExtension(item.path)}.mdd');
            subStream = importMdictStream(
              item.path,
              mddPath: File(mddPath).existsSync() ? mddPath : null,
              indexDefinitions: indexDefinitions,
            );
            break;
          case 'slob':
            subStream = importSlobStream(item.path, indexDefinitions: indexDefinitions);
            break;
          case 'dictd':
            subStream = importDictdStream(item.path, item.companionPath!, indexDefinitions: indexDefinitions);
            break;
          case 'stardict':
          default:
            subStream = _processDictionaryFiles(item.path, indexDefinitions: indexDefinitions);
            break;
        }

        await for (final progress in subStream) {
          yield ImportProgress(
            message: '[$currentDict/$totalDicts] ${progress.message}',
            value: 0.45 + ((currentDict - 1) + progress.value) / totalDicts * 0.55,
            headwordCount: progress.headwordCount,
            isCompleted: progress.isCompleted && currentDict == totalDicts,
            dictId: progress.dictId,
            sampleWords: progress.sampleWords,
            error: progress.error,
          );
          if (progress.isCompleted) break;
        }
      }

      yield ImportProgress(message: 'All imports complete.', value: 1.0, isCompleted: true);
    } catch (e) {
      yield ImportProgress(message: 'Error: $e', value: 0.0, error: e.toString(), isCompleted: true);
    } finally {
      if (await workspaceDir.exists()) {
        await workspaceDir.delete(recursive: true);
      }
    }
  }

  /// Web-friendly multiple file import.
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
            if (f.isFile) allFiles[f.name] = Uint8List.fromList(f.content as List<int>);
          }
        } else if (lowerName.endsWith('.tar.gz') || lowerName.endsWith('.tgz')) {
          final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(file.bytes));
          for (final f in archive) {
            if (f.isFile) allFiles[f.name] = Uint8List.fromList(f.content as List<int>);
          }
        } else if (lowerName.endsWith('.tar.bz2') || lowerName.endsWith('.tbz2')) {
          final archive = TarDecoder().decodeBytes(BZip2Decoder().decodeBytes(file.bytes));
          for (final f in archive) {
            if (f.isFile) allFiles[f.name] = Uint8List.fromList(f.content as List<int>);
          }
        } else if (lowerName.endsWith('.tar.xz')) {
          final archive = TarDecoder().decodeBytes(XZDecoder().decodeBytes(file.bytes));
          for (final f in archive) {
            if (f.isFile) allFiles[f.name] = Uint8List.fromList(f.content as List<int>);
          }
        } else if (lowerName.endsWith('.tar')) {
          final archive = TarDecoder().decodeBytes(file.bytes);
          for (final f in archive) {
            if (f.isFile) allFiles[f.name] = Uint8List.fromList(f.content as List<int>);
          }
        } else {
          allFiles[file.name] = file.bytes;
        }
        processedFiles++;
      }

      final ifoNames = allFiles.keys.where((n) => n.endsWith('.ifo')).toList();
      if (ifoNames.isEmpty) throw Exception('No .ifo files found');

      int totalDicts = ifoNames.length;
      int currentDict = 0;

      for (final ifoName in ifoNames) {
        currentDict++;
        yield ImportProgress(
          message: 'Importing dictionary $currentDict of $totalDicts: ${p.basenameWithoutExtension(ifoName)}',
          value: 0.5 + (currentDict - 1) / totalDicts * 0.5,
        );

        try {
          final stream = _processDictionaryFilesWeb(ifoName, allFiles, indexDefinitions: indexDefinitions);
          await for (final progress in stream) {
            yield ImportProgress(
              message: '[$currentDict/$totalDicts] ${progress.message}',
              value: 0.5 + ((currentDict - 1) + (progress.value)) / totalDicts * 0.5,
            );
            if (progress.isCompleted) break;
          }
        } catch (e) {
          debugPrint('Web error importing $ifoName: $e');
        }
      }

      yield ImportProgress(message: 'All web imports complete.', value: 1.0, isCompleted: true);
    } catch (e) {
      yield ImportProgress(message: 'Web error: $e', value: 0.0, error: e.toString(), isCompleted: true);
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

      String? idxPath = findLocalFile(['.idx', '.idx.gz', '.idx.dz', '.idx.bz2', '.idx.xz']);
      if (idxPath == null) throw Exception('No .idx file found for ${p.basename(ifoPath)}');

      String? dictPath = findLocalFile(['.dict', '.dict.dz', '.dict.gz', '.dict.bz2', '.dict.xz']);
      if (dictPath == null) throw Exception('No .dict file found for ${p.basename(ifoPath)}');

      String? synPath = findLocalFile(['.syn', '.syn.gz', '.syn.dz', '.syn.bz2', '.syn.xz']);


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
      final ifoContent = utf8.decode(decompressedIfoBytes, allowMalformed: true);
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
      yield ImportProgress(message: 'Decompressing components...', value: 0.55);
      final decompressedIdxBytes = await _maybeDecompressWeb(idxName, files[idxName]!);
      final decompressedDictBytes = await _maybeDecompressWeb(dictName, files[dictName]!);
      final decompressedSynBytes = synName != null ? await _maybeDecompressWeb(synName, files[synName]!) : null;

      final finalIfoName = _getDecompressedName(p.basename(ifoName));
      final finalIdxName = _getDecompressedName(p.basename(idxName));
      final finalDictName = _getDecompressedName(p.basename(dictName));
      final finalSynName = synName != null ? _getDecompressedName(p.basename(synName)) : null;

      final dictId = await _dbHelper.insertDictionary(bookName, finalDictName, indexDefinitions: indexDefinitions);

      // Save files to virtual filesystem (SQLite 'files' table)
      yield ImportProgress(message: 'Saving files to database...', value: 0.6);
      await _dbHelper.saveFile(dictId, finalIfoName, decompressedIfoBytes);
      await _dbHelper.saveFile(dictId, finalIdxName, decompressedIdxBytes);
      await _dbHelper.saveFile(dictId, finalDictName, decompressedDictBytes);
      if (finalSynName != null && decompressedSynBytes != null) {
        await _dbHelper.saveFile(dictId, finalSynName, decompressedSynBytes);
      }

      // Indexing on Web (sequential for simplicity/stability)
      yield ImportProgress(message: 'Indexing words (Web)...', value: 0.7);
      
      final idxParser = IdxParser(ifoParser);
      final dictReader = DictReader(finalDictName, dictId: dictId);
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
            content = utf8.decode(decompressedDictBytes.sublist(offset, offset + length), allowMalformed: true);
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
          defWordCount += content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
        }

        wordOffsets.add((offset: offset, length: length, content: content));
        
        if (batch.length >= 1000) {
          await _dbHelper.batchInsertWords(dictId, batch);
          batch.clear();
          yield ImportProgress(
            message: 'Indexing $headwordCount words...',
            value: 0.7 + (headwordCount / (ifoParser.wordCount == 0 ? 100000 : ifoParser.wordCount) * 0.2),
            headwordCount: headwordCount,
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
        if (synBatch.isNotEmpty) await _dbHelper.batchInsertWords(dictId, synBatch);
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
      );
    } catch (e, s) {
      debugPrint('Web import error: $e\n$s');
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
        value: 0.0, error: 'Web unsupported', isCompleted: true,
      );
      return;
    }

    yield ImportProgress(message: 'Opening MDict file...', value: 0.05);

    try {
      final reader = MdictReader(mdxPath);
      await reader.open();

      // Use the filename (without extension) as a fallback book name
      final bookName = p.basenameWithoutExtension(mdxPath);

      yield ImportProgress(message: 'Copying to permanent storage...', value: 0.15);

      final appDocDir = await getApplicationDocumentsDirectory();
      final dictsDir = Directory(p.join(appDocDir.path, 'dictionaries'));
      if (!await dictsDir.exists()) await dictsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final permanentDir = Directory(p.join(dictsDir.path, 'mdict_$timestamp'));
      await permanentDir.create(recursive: true);

      final finalMdxPath = p.join(permanentDir.path, p.basename(mdxPath));
      await File(mdxPath).copy(finalMdxPath);

      // Also copy the companion .mdd file if it exists
      final mddSourcePath = mddPath ?? mdxPath.replaceAll(RegExp(r'\.mdx$', caseSensitive: false), '.mdd');
      if (await File(mddSourcePath).exists()) {
        final finalMddPath = p.join(permanentDir.path, p.basename(mddSourcePath));
        await File(mddSourcePath).copy(finalMddPath);
      }

      await reader.close();

      yield ImportProgress(message: 'Registering dictionary...', value: 0.3);
      final dictId = await _dbHelper.insertDictionary(
        bookName,
        finalMdxPath,
        indexDefinitions: indexDefinitions,
        format: 'mdict',
      );

      yield ImportProgress(message: 'Enumerating headwords...', value: 0.4);

      // Re-open the permanent copy for indexing
      final permanentReader = MdictReader(finalMdxPath);
      await permanentReader.open();

      // Fetch all keys via prefix search with empty prefix
      final allKeys = await permanentReader.prefixSearch('', limit: 500000);
      final totalKeys = allKeys.length;
      yield ImportProgress(message: 'Indexing $totalKeys headwords...', value: 0.5);

      List<Map<String, dynamic>> batch = [];
      int indexed = 0;

      for (final word in allKeys) {
        // For MDict, we store offset=0,length=0 (lookup uses the word key directly)
        String content = '';
        if (indexDefinitions) {
          content = await permanentReader.lookup(word) ?? '';
        }

        batch.add({
          'word': word,
          'content': content,
          'dict_id': dictId,
          'offset': 0,
          'length': 0,
        });
        indexed++;

        if (batch.length >= 2000) {
          await _dbHelper.batchInsertWords(dictId, batch);
          batch.clear();
          yield ImportProgress(
            message: 'Indexing $indexed / $totalKeys headwords...',
            value: 0.5 + (indexed / (totalKeys == 0 ? 1 : totalKeys)) * 0.4,
            headwordCount: indexed,
          );
        }
      }

      if (batch.isNotEmpty) await _dbHelper.batchInsertWords(dictId, batch);
      await permanentReader.close();
      await _dbHelper.updateDictionaryWordCount(dictId, indexed);

      final sampleWords = await _dbHelper.getSampleWords(dictId);

      yield ImportProgress(
        message: 'MDict import complete!',
        value: 1.0,
        isCompleted: true,
        dictId: dictId,
        sampleWords: sampleWords.map((w) => w['word'] as String).toList(),
        headwordCount: indexed,
      );
    } catch (e, s) {
      debugPrint('MDict import error: $e\n$s');
      yield ImportProgress(
        message: 'MDict import error: $e',
        value: 0.0, error: e.toString(), isCompleted: true,
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
        value: 0.0, error: 'Web unsupported', isCompleted: true,
      );
      return;
    }

    yield ImportProgress(message: 'Setting up DICTD import...', value: 0.05);

    try {
      final dictdParser = DictdParser();

      // Decompress .dict.dz if needed
      yield ImportProgress(message: 'Decompressing dictionary data...', value: 0.1);
      final decompressedDictPath = await dictdParser.maybeDecompressDictZ(dictPath);

      final bookName = p.basenameWithoutExtension(indexPath)
          .replaceAll(RegExp(r'\.dict$'), '');

      yield ImportProgress(message: 'Copying to permanent storage...', value: 0.2);

      final appDocDir = await getApplicationDocumentsDirectory();
      final dictsDir = Directory(p.join(appDocDir.path, 'dictionaries'));
      if (!await dictsDir.exists()) await dictsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final permanentDir = Directory(p.join(dictsDir.path, 'dictd_$timestamp'));
      await permanentDir.create(recursive: true);

      final finalDictPath = p.join(permanentDir.path, p.basename(decompressedDictPath));
      final finalIndexPath = p.join(permanentDir.path, p.basename(indexPath));
      await File(decompressedDictPath).copy(finalDictPath);
      await File(indexPath).copy(finalIndexPath);

      yield ImportProgress(message: 'Registering dictionary...', value: 0.35);
      final dictId = await _dbHelper.insertDictionary(
        bookName,
        finalDictPath,
        indexDefinitions: indexDefinitions,
        format: 'dictd',
      );

      yield ImportProgress(message: 'Indexing DICTD words...', value: 0.45);

      final dictdReader = DictdReader(finalDictPath);
      await dictdReader.open();
      final indexStream = dictdParser.parseIndex(finalIndexPath);

      List<Map<String, dynamic>> batch = [];
      int headwordCount = 0;
      int defWordCount = 0;

      await for (final entry in indexStream) {
        final word = entry['word'] as String;
        final offset = entry['offset'] as int;
        final length = entry['length'] as int;

        String content = '';
        if (indexDefinitions) {
          content = await dictdReader.readAtOffset(offset, length);
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
          defWordCount += content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
        }

        if (batch.length >= 2000) {
          await _dbHelper.batchInsertWords(dictId, batch);
          batch.clear();
          yield ImportProgress(
            message: 'Indexing $headwordCount words...',
            value: 0.45 + (headwordCount / 100000) * 0.45,
            headwordCount: headwordCount,
          );
        }
      }

      if (batch.isNotEmpty) await _dbHelper.batchInsertWords(dictId, batch);
      await dictdReader.close();
      await _dbHelper.updateDictionaryWordCount(dictId, headwordCount);

      final sampleWords = await _dbHelper.getSampleWords(dictId);

      yield ImportProgress(
        message: 'DICTD import complete!',
        value: 1.0,
        isCompleted: true,
        dictId: dictId,
        sampleWords: sampleWords.map((w) => w['word'] as String).toList(),
        headwordCount: headwordCount,
        definitionWordCount: defWordCount,
      );
    } catch (e, s) {
      debugPrint('DICTD import error: $e\n$s');
      yield ImportProgress(
        message: 'DICTD import error: $e',
        value: 0.0, error: e.toString(), isCompleted: true,
      );
    }
  }

  // ── Slob Import ─────────────────────────────────────────────────────────────

  /// Imports a Slob (.slob) dictionary file.
  Stream<ImportProgress> importSlobStream(
    String slobPath, {
    bool indexDefinitions = false,
  }) async* {
    if (kIsWeb) {
      yield ImportProgress(
        message: 'Error: Slob import is not supported on Web.',
        value: 0.0, error: 'Web unsupported', isCompleted: true,
      );
      return;
    }

    yield ImportProgress(message: 'Opening Slob file...', value: 0.05);

    try {
      final reader = SlobReader(slobPath);
      await reader.open();

      final bookName = p.basenameWithoutExtension(slobPath);

      yield ImportProgress(message: 'Copying to permanent storage...', value: 0.15);

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
      );

      yield ImportProgress(message: 'Indexing Slob entries...', value: 0.4);

      // Re-open permanent copy for indexing
      final permanentReader = SlobReader(finalSlobPath);
      await permanentReader.open();

      List<Map<String, dynamic>> batch = [];
      int headwordCount = 0;
      int defWordCount = 0;

      await for (final ref in permanentReader.getAllRefs()) {
        final word = ref['word'] as String;
        final binIndex = ref['bin_index'] as int;
        final itemIndex = ref['item_index'] as int;

        // Encode bin_index and item_index into offset and length fields
        // offset = binIndex, length = itemIndex (both are ints and fit fine)
        String content = '';
        if (indexDefinitions) {
          content = await permanentReader.readItem(binIndex, itemIndex) ?? '';
        }

        batch.add({
          'word': word,
          'content': content,
          'dict_id': dictId,
          'offset': binIndex,   // repurposed: bin index within slob
          'length': itemIndex,  // repurposed: item index within bin
        });
        headwordCount++;

        if (content.isNotEmpty) {
          defWordCount += content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
        }

        if (batch.length >= 2000) {
          await _dbHelper.batchInsertWords(dictId, batch);
          batch.clear();
          yield ImportProgress(
            message: 'Indexing $headwordCount entries...',
            value: 0.4 + (headwordCount / 100000).clamp(0.0, 0.5),
            headwordCount: headwordCount,
          );
        }
      }

      if (batch.isNotEmpty) await _dbHelper.batchInsertWords(dictId, batch);
      await permanentReader.close();
      await _dbHelper.updateDictionaryWordCount(dictId, headwordCount);

      final sampleWords = await _dbHelper.getSampleWords(dictId);

      yield ImportProgress(
        message: 'Slob import complete!',
        value: 1.0,
        isCompleted: true,
        dictId: dictId,
        sampleWords: sampleWords.map((w) => w['word'] as String).toList(),
        headwordCount: headwordCount,
        definitionWordCount: defWordCount,
      );
    } catch (e, s) {
      debugPrint('Slob import error: $e\n$s');
      yield ImportProgress(
        message: 'Slob import error: $e',
        value: 0.0, error: e.toString(), isCompleted: true,
      );
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
    final rawPath = dictRecord['path'] as String;
    final dictPath = await _dbHelper.resolvePath(rawPath);

    switch (format) {
      case 'mdict':
        final reader = MdictReader(dictPath);
        try {
          await reader.open();
          return await reader.lookup(word);
        } finally {
          await reader.close();
        }

      case 'dictd':
        final reader = DictdReader(dictPath);
        return await reader.readEntry(offset, length);

      case 'slob':
        final reader = SlobReader(dictPath);
        try {
          await reader.open();
          return await reader.readItem(offset, length); // offset=binIndex, length=itemIndex
        } finally {
          await reader.close();
        }

      case 'stardict':
      default:
        final reader = DictReader(dictPath);
        return await reader.readEntry(offset, length);
    }
  }

  Stream<ImportProgress> reIndexDictionariesStream() async* {
    yield ImportProgress(message: 'Re-indexing not fully implemented for Web yet.', value: 1.0, isCompleted: true);
  }

  Stream<ImportProgress> reindexDictionaryStream(int dictId) async* {
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
      final String ifoPath = dictPath.replaceAll('.dict', '.ifo');
      final String idxPath = dictPath.replaceAll('.dict', '.idx');
      final String synPathCandidate = dictPath.replaceAll('.dict', '.syn');
      final String? synPath =
          File(synPathCandidate).existsSync() ? synPathCandidate : null;

      final ifoParser = IfoParser();
      await ifoParser.parse(ifoPath);

      // Wipe existing index
      yield ImportProgress(message: 'Wiping existing index...', value: 0.2);
      await _dbHelper.deleteWordsByDictionaryId(dictId);
      await _dbHelper.updateDictionaryIndexDefinitions(dictId, true);

      yield ImportProgress(message: 'Starting re-indexing...', value: 0.3);

      final receivePort = ReceivePort();
      final rootIsolateToken = RootIsolateToken.instance!;

      await Isolate.spawn(
        _indexEntry,
        _IndexArgs(
          dictId,
          idxPath,
          dictPath,
          synPath,
          true, // indexDefinitions
          ifoParser,
          receivePort.sendPort,
          rootIsolateToken,
        ),
      );

      await for (final message in receivePort) {
        if (message is ImportProgress) {
          if (message.error != null) {
            receivePort.close();
            throw Exception(message.error);
          }
          if (message.isCompleted) {
            receivePort.close();
            break;
          }
          yield message;
        }
      }
      yield ImportProgress(
        message: 'Re-indexing complete!',
        value: 1.0,
        isCompleted: true,
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
    if (effectiveUrl.contains('github.com/')) {
      effectiveUrl = effectiveUrl
          .replaceFirst('github.com/', 'raw.githubusercontent.com/')
          .replaceFirst('/blob/', '/')
          .replaceFirst('/raw/', '/');
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
        String errorMsg = e.toString();
        if (errorMsg.contains('ClientException') && errorMsg.contains('Failed to fetch')) {
          errorMsg = 'Download failed due to a CORS error. This happens when the server hosting the file doesn\'t allow web browsers from other domains to download it directly. Try downloading the file manually and then use "Import File".';
        }
        yield ImportProgress(message: 'Download error: $errorMsg', value: 0.0, error: errorMsg, isCompleted: true);
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
