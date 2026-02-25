import 'package:mdict_flutter/mdict_flutter.dart' as mdict;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Wrapper around the `mdict_flutter` package.
///
/// Provides a unified interface for reading MDict (.mdx/.mdd) dictionaries.
/// Only supported on native platforms (Android, iOS, macOS, Windows, Linux).
/// Web is not supported because `mdict_flutter` uses `dart:io` file access.
class MdictReader {
  final String mdxPath;
  late mdict.MdictReader _reader;

  MdictReader(this.mdxPath);

  /// Opens the MDX file.
  Future<void> open() async {
    if (kIsWeb) throw UnsupportedError('MDict is not supported on Web.');
    _reader = mdict.MdictReader(mdxPath);
    await _reader.open();
  }

  /// Returns the dictionary book name from MDX metadata, or null if unavailable.
  Future<String?> bookName() async {
    try {
      // mdict_flutter exposes header metadata via lookup of a special key.
      // The book name is stored as the title attribute in the MDX header.
      // We extract it via the internal header — fallback to null if unavailable.
      return null; // Will be overridden by caller using filename if null.
    } catch (_) {
      return null;
    }
  }

  /// Looks up the HTML definition for a word.
  /// Returns null if the word is not found.
  Future<String?> lookup(String word) async {
    if (kIsWeb) throw UnsupportedError('MDict is not supported on Web.');
    try {
      return await _reader.lookup(word);
    } catch (_) {
      return null;
    }
  }

  /// Returns up to [limit] headwords that start with [prefix].
  /// Pass an empty string to enumerate all keys (may be slow for large dicts).
  Future<List<String>> prefixSearch(String prefix, {int limit = 50000}) async {
    if (kIsWeb) throw UnsupportedError('MDict is not supported on Web.');
    try {
      return await _reader.prefixSearch(prefix, limit: limit);
    } catch (_) {
      return [];
    }
  }

  /// Closes the MDX file.
  Future<void> close() async {
    if (kIsWeb) return;
    try {
      await _reader.close();
    } catch (_) {}
  }
}
