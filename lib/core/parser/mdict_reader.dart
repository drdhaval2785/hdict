import 'package:dict_reader/dict_reader.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

/// Wrapper around the `dict_reader` package.
///
/// Provides a unified interface for reading MDict (.mdx/.mdd) dictionaries.
/// Only supported on native platforms.
class MdictReader {
  final String mdxPath;
  late DictReader _reader;
  bool _isInitialized = false;

  MdictReader(this.mdxPath) {
    _reader = DictReader(mdxPath);
  }

  /// Opens the MDX file.
  Future<void> open() async {
    if (kIsWeb) throw UnsupportedError('MDict is not supported on Web.');
    if (_isInitialized) return;
    try {
      await _reader.initDict();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing MDict: $e');
      rethrow;
    }
  }

  /// Returns the dictionary book name from MDX metadata, or null if unavailable.
  Future<String?> bookName() async {
    // dict_reader doesn't directly expose book name easily in a single call
    // often it's in the header, but for now we fallback to filename in manager.
    return null;
  }

  /// Looks up the HTML definition for a word.
  /// Returns null if the word is not found.
  Future<String?> lookup(String word) async {
    if (kIsWeb) throw UnsupportedError('MDict is not supported on Web.');
    if (!_isInitialized) await open();
    try {
      final info = await _reader.locate(word);
      if (info == null) return null;
      
      final data = await _reader.readOneMdx(info);
      return data;
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
      return _reader.search(prefix, limit: limit);
    } catch (_) {
      return [];
    }
  }

  /// Closes the MDX file.
  Future<void> close() async {
    if (kIsWeb) return;
    try {
      await _reader.close();
      _isInitialized = false;
    } catch (_) {}
  }
}
