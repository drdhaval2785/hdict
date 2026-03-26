import 'package:flutter/foundation.dart';
import 'package:hdict/core/utils/logger.dart';
import 'package:mdict_reader/mdict_reader.dart' as dr;
import 'package:hdict/core/parser/mdd_reader.dart';
import 'package:hdict/core/parser/random_access_source.dart';
import 'package:hdict/core/parser/saf_random_access_source.dart';
import 'package:hdict/core/parser/bookmark_random_access_source.dart';
import 'package:path/path.dart';
import 'dart:io';

enum MdictSourceType { local, saf, bookmark }

class MdictReader {
  final String mdxPath;
  final RandomAccessSource source;
  late dr.DictReader _parser;
  bool _isInitialized = false;

  final String? _mddPath;
  final MdictSourceType _mddSourceType;
  final String? _mddBookmark;
  MddReader? _mddReader;
  String? _cssContent;

  MdictReader(
    this.mdxPath, {
    required this.source,
    String? mddPath,
    MdictSourceType mddSourceType = MdictSourceType.local,
    String? mddBookmark,
  }) : _mddPath = mddPath,
       _mddSourceType = mddSourceType,
       _mddBookmark = mddBookmark {
    _parser = dr.DictReader(mdxPath);
  }

  static Future<MdictReader> fromPath(String path, {String? mddPath}) async {
    return MdictReader(
      path,
      source: FileRandomAccessSource(path),
      mddPath: mddPath,
    );
  }

  static Future<MdictReader> fromLinkedSource(
    String source, {
    String? targetPath,
    String? actualPath,
    String? mddPath,
  }) async {
    final String path = actualPath ?? targetPath ?? source;
    RandomAccessSource src;
    MdictSourceType mddSourceType;
    if (Platform.isAndroid) {
      src = SafRandomAccessSource(source);
      mddSourceType = MdictSourceType.saf;
    } else if (Platform.isIOS || Platform.isMacOS) {
      src = BookmarkRandomAccessSource(source, targetPath: targetPath);
      mddSourceType = MdictSourceType.bookmark;
    } else {
      final String fullPath = targetPath != null
          ? join(source, targetPath)
          : source;
      src = FileRandomAccessSource(fullPath);
      mddSourceType = MdictSourceType.local;
    }
    return MdictReader(
      path,
      source: src,
      mddPath: mddPath,
      mddSourceType: mddSourceType,
      mddBookmark: source,
    );
  }

  static Future<MdictReader> fromUri(String uri, {String? mddPath}) async {
    return MdictReader(
      uri,
      source: SafRandomAccessSource(uri),
      mddPath: mddPath,
      mddSourceType: MdictSourceType.saf,
    );
  }

  /// Factory to create an MdictReader from in-memory bytes.
  /// Useful for small .mdx files loaded entirely into memory for fast I/O.
  static Future<MdictReader> fromBytes(
    Uint8List bytes, {
    String? fileName,
    String? mddPath,
  }) async {
    final path = fileName ?? 'memory.mdx';
    final reader = dr.DictReader.fromBytes(bytes, fileName: path);
    return MdictReader._fromParser(reader, path, mddPath: mddPath);
  }

  /// Internal constructor for creating from parser
  MdictReader._fromParser(dr.DictReader parser, String path, {String? mddPath})
    : mdxPath = path,
      source = FileRandomAccessSource(path),
      _mddPath = mddPath,
      _mddSourceType = MdictSourceType.local,
      _mddBookmark = null,
      _parser = parser;

  Future<void> open() async {
    if (kIsWeb) throw UnsupportedError('MDict is not supported on Web.');
    if (_isInitialized) return;
    try {
      await _parser.initDict();
      _isInitialized = true;

      if (_mddPath != null) {
        await _openMdd();
      }
    } catch (e) {
      debugPrint('Error initializing MDict: $e');
      rethrow;
    }
  }

  Future<void> _openMdd() async {
    final mddPath = _mddPath;
    if (mddPath == null) return;
    try {
      RandomAccessSource mddSource;

      switch (_mddSourceType) {
        case MdictSourceType.saf:
          mddSource = SafRandomAccessSource(mddPath);
        case MdictSourceType.bookmark:
          final bookmark = _mddBookmark;
          mddSource = BookmarkRandomAccessSource(
            bookmark ?? mddPath,
            targetPath: mddPath,
          );
        case MdictSourceType.local:
          mddSource = FileRandomAccessSource(mddPath);
      }

      _mddReader = MddReader(mddPath, source: mddSource);
      await _mddReader!.open();
      _cssContent = await _mddReader!.getCssContent();
    } catch (e) {
      debugPrint('Error initializing MDD: $e');
    }
  }

  String? get cssContent => _cssContent;

  bool get hasMdd => _mddReader != null;

  Future<List<int>?> getMddResource(String key) async {
    if (_mddReader == null) return null;
    return _mddReader!.getResource(key);
  }

  Future<Uint8List?> getMddResourceBytes(String key) async {
    if (_mddReader == null) return null;
    return _mddReader!.getResourceAsBytes(key);
  }

  Future<String?> lookup(String word) async {
    if (kIsWeb) throw UnsupportedError('MDict is not supported on Web.');
    if (!_isInitialized) await open();
    try {
      hDebugPrint('MdictReader.lookup: Looking up word: "$word" in $mdxPath');
      final info = await _parser.locate(word);
      hDebugPrint('MdictReader.lookup: locate("$word") returned: $info');
      if (info == null) {
        hDebugPrint(
          'MdictReader.lookup: WARNING - locate returned null for "$word"',
        );
        return null;
      }
      final result = await _parser.readOneMdx(info);
      hDebugPrint(
        'MdictReader.lookup: readOneMdx for "$word" returned: ${result.length > 100 ? "${result.substring(0, 100)}..." : result}',
      );
      return result;
    } catch (e, stack) {
      hDebugPrint('MdictReader.lookup: EXCEPTION for "$word": $e');
      hDebugPrint('MdictReader.lookup: Stack trace: $stack');
      return null;
    }
  }

  Future<List<(String, int)>> prefixSearch(
    String prefix, {
    int limit = 50000,
  }) async {
    if (kIsWeb) throw UnsupportedError('MDict is not supported on Web.');
    if (!_isInitialized) await open();
    try {
      final results = _parser.search(prefix, limit: limit);
      return results.map((k) => (k, 0)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> close() async {
    if (kIsWeb) return;
    try {
      await _parser.close();
      if (_mddReader != null) {
        await _mddReader!.close();
        _mddReader = null;
      }
      _isInitialized = false;
    } catch (_) {}
  }
}
