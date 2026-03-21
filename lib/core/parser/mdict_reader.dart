import 'package:flutter/foundation.dart';
import 'mdict/mdict_parser.dart';
import 'package:hdict/core/parser/random_access_source.dart';
import 'package:hdict/core/parser/saf_random_access_source.dart';
import 'package:hdict/core/parser/bookmark_random_access_source.dart';
import 'package:path/path.dart';
import 'dart:io';

/// Wrapper around the vendored MdxParser.
///
/// Provides a unified interface for reading MDict (.mdx/.mdd) dictionaries.
/// Supported on native platforms via [RandomAccessSource].
class MdictReader {
  final String mdxPath;
  final RandomAccessSource source;
  late MdxParser _parser;
  bool _isInitialized = false;

  MdictReader(this.mdxPath, {required this.source}) {
    _parser = MdxParser(source, mdxPath);
  }

  /// Factory to create an MdictReader from a local file path.
  static Future<MdictReader> fromPath(String path) async {
    return MdictReader(path, source: FileRandomAccessSource(path));
  }

  /// Factory to create an instance from a linked source (SAF or Bookmark).
  static Future<MdictReader> fromLinkedSource(String source, {String? targetPath, String? actualPath}) async {
    final String path = actualPath ?? targetPath ?? source;
    if (Platform.isAndroid) {
      return MdictReader(path, source: SafRandomAccessSource(source));
    } else if (Platform.isIOS || Platform.isMacOS) {
      return MdictReader(path, source: BookmarkRandomAccessSource(source, targetPath: targetPath));
    } else {
      // For Linux/Windows, linked source is just a direct path for now
      final String fullPath = targetPath != null ? join(source, targetPath) : source;
      return MdictReader(fullPath, source: FileRandomAccessSource(fullPath));
    }
  }

  /// Factory to create an MdictReader from an Android SAF URI.
  static Future<MdictReader> fromUri(String uri) async {
    return MdictReader(uri, source: SafRandomAccessSource(uri));
  }

  /// Opens the MDX file.
  Future<void> open() async {
    if (kIsWeb) throw UnsupportedError('MDict is not supported on Web.');
    if (_isInitialized) return;
    try {
      await _parser.initDict();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing MDict: $e');
      rethrow;
    }
  }

  /// Looks up the HTML definition for a word.
  Future<String?> lookup(String word) async {
    if (kIsWeb) throw UnsupportedError('MDict is not supported on Web.');
    if (!_isInitialized) await open();
    try {
      final info = await _parser.locate(word);
      if (info == null) return null;
      
      return await _parser.readOneMdx(info);
    } catch (e) {
      debugPrint('Error looking up $word: $e');
      return null;
    }
  }

  /// Returns up to [limit] headwords that start with [prefix].
  Future<List<String>> prefixSearch(String prefix, {int limit = 50000}) async {
    if (kIsWeb) throw UnsupportedError('MDict is not supported on Web.');
    if (!_isInitialized) await open();
    try {
      return await _parser.search(prefix, limit: limit);
    } catch (_) {
      return [];
    }
  }

  /// Closes the MDX file.
  Future<void> close() async {
    if (kIsWeb) return;
    try {
      await _parser.close();
      _isInitialized = false;
    } catch (_) {}
  }
}
