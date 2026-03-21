import 'dart:io';
import 'package:flutter/foundation.dart';
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

  static Future<DictdReader> fromLinkedSource(String source) async {
    final reader = DictdReader(source);
    if (!kIsWeb && Platform.isAndroid) {
      await reader.openSource(SafRandomAccessSource(source));
    } else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      await reader.openSource(BookmarkRandomAccessSource(source));
    } else {
      await reader.openSource(FileRandomAccessSource(source));
    }
    return reader;
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

  Future<void> close() async {
    await _reader?.close();
  }
}
