import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:dictd_reader/dictd_reader.dart' as lib;

// Export DictdParser so callers can still parse DICTD indexes
export 'package:dictd_reader/dictd_reader.dart' show DictdParser;

import 'package:hdict/core/parser/random_access_source.dart';
import 'package:hdict/core/parser/saf_random_access_source.dart';
import 'package:hdict/core/parser/bookmark_random_access_source.dart';

/// Wrapper around the `dictd_reader` package for hdict.
/// Seamlessly integrates platform-specific `RandomAccessSource`.
class DictdReader {
  final String dictPath;
  lib.DictdReader? _reader;

  DictdReader(this.dictPath);

  static Future<DictdReader> fromPath(String path) async {
    final reader = DictdReader(path);
    await reader.openSource(FileRandomAccessSource(path));
    return reader;
  }

  static Future<DictdReader> fromUri(String uri) async {
    final reader = DictdReader(uri);
    await reader.openSource(SafRandomAccessSource(uri));
    return reader;
  }

  static Future<DictdReader> fromLinkedSource(String source, {String? targetPath, String? actualPath}) async {
    if (!kIsWeb && Platform.isAndroid) {
      if (source.startsWith('content://')) {
        // Use 'source' (the SAF content:// URI of the .dict.dz file) as the path
        // so that lib.DictdReader's _isCompressed correctly detects the .dz extension.
        final reader = DictdReader(source);
        await reader.openSource(SafRandomAccessSource(source));
        return reader;
      } else {
        // Fallback or folder-based resolve logic if needed
        final String fullPath = targetPath != null ? join(source, targetPath) : source;
        final reader = DictdReader(fullPath);
        await reader.openSource(SafRandomAccessSource(fullPath));
        return reader;
      }
    } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      final String path = actualPath ?? targetPath ?? source;
      final reader = DictdReader(path);
      await reader.openSource(BookmarkRandomAccessSource(source, targetPath: targetPath));
      return reader;
    } else {
      final String path = actualPath ?? targetPath ?? source;
      final reader = DictdReader(path);
      final String fullPath = targetPath != null ? join(source, targetPath) : source;
      await reader.openSource(FileRandomAccessSource(fullPath));
      return reader;
    }
  }

  Future<void> openSource(RandomAccessSource source) async {
    _reader = lib.DictdReader(dictPath);
    await _reader!.openSource(source);
  }

  Future<void> open() async {
      // In fromPath/fromUri pattern, source is already opened.
  }

  Future<String?> readEntry(int offset, int length) async {
    if (_reader == null) throw Exception('Reader not opened');
    return await _reader!.readEntry(offset, length);
  }

  Future<List<String>> readEntries(List<({int offset, int length})> entries) async {
    if (_reader == null) throw Exception('Reader not opened');
    
    // Sort by offset to minimize seeker movement
    final entriesWithIndex = entries.asMap().entries.toList()
      ..sort((a, b) => a.value.offset.compareTo(b.value.offset));

    final List<String?> results = List.filled(entries.length, null);
    for (final item in entriesWithIndex) {
      results[item.key] = await _reader!.readEntry(item.value.offset, item.value.length);
    }
    return results.cast<String>();
  }

  Future<void> close() async {
    await _reader?.close();
  }
}
