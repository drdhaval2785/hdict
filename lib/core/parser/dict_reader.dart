import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:convert';
import 'package:hdict/core/database/database_helper.dart';
import 'package:dictzip_reader/dictzip_reader.dart' hide RandomAccessSource, FileRandomAccessSource;
import 'package:path/path.dart' as p;
import 'package:hdict/core/parser/random_access_source.dart';
import 'package:hdict/core/parser/saf_random_access_source.dart';
import 'package:hdict/core/parser/bookmark_random_access_source.dart';

/// Reads definitions from a StarDict .dict or .dict.dz file at specified offsets and lengths.
///
/// For plain `.dict` files, uses [File.openRead] for fully stateless random-access
/// reads — each call opens a fresh OS-level read stream, making concurrent calls safe
/// with no locking required on the caller side.
///
/// For `.dict.dz` files, delegates to [DictzipLocalReader] which performs
/// chunk-based random access; its internal chunk cache is mutable, so the caller
/// must still serialize concurrent accesses.
class DictReader {
  final RandomAccessSource source;
  final String path;
  final int? dictId;

  DictReader(this.path, {required this.source, this.dictId});

  /// Factory to create a DictReader from a local file path.
  static Future<DictReader> fromPath(String path, {int? dictId}) async {
    return DictReader(path, source: FileRandomAccessSource(path), dictId: dictId);
  }

  /// Factory to create an instance from a linked source (SAF or Bookmark).
  static Future<DictReader> fromLinkedSource(String source, {String? targetPath, String? actualPath}) async {
    final String path = actualPath ?? targetPath ?? source;
    if (Platform.isAndroid) {
      // For SAF on Android, 'source' is usually the URI of the specific file
      // but if we move to folder-based SAF, we might need targetPath too.
      return DictReader(path, source: SafRandomAccessSource(source));
    } else if (Platform.isIOS || Platform.isMacOS) {
      return DictReader(path, source: BookmarkRandomAccessSource(source, targetPath: targetPath));
    } else {
      // For Linux/Windows, linked source is just a direct path for now
      final String fullPath = targetPath != null ? p.join(source, targetPath) : source;
      return DictReader(fullPath, source: FileRandomAccessSource(fullPath));
    }
  }

  /// Factory to create a DictReader from an Android SAF URI.
  static Future<DictReader> fromUri(String uri, {int? dictId}) async {
    return DictReader(uri, source: SafRandomAccessSource(uri), dictId: dictId);
  }

  DictzipReader? _dzReader;

  /// True for .dict.dz files; false for plain .dict.
  /// Exposed so callers can decide whether locking is needed.
  bool get isDz => path.toLowerCase().endsWith('.dz');

  /// Opens the file for reading.
  /// For plain `.dict` files this is a no-op (reads use stateless [File.openRead]).
  /// For `.dict.dz` files this initialises the [DictzipLocalReader].
  Future<void> open() async {
    if (kIsWeb) return;
    if (isDz) {
      _dzReader = DictzipReader(null);
      await _dzReader!.openSource(source);
    }
  }

  /// Reads [length] bytes starting at [offset].
  ///
  /// **Plain `.dict`:** uses [File.openRead] — fully stateless, safe to call
  /// concurrently from multiple futures without any external lock.
  ///
  /// **`.dict.dz`:** delegates to [DictzipLocalReader] whose chunk cache is
  /// shared mutable state; the caller must serialise concurrent accesses.
  Future<String> readAtIndex(int offset, int length) async {
    if (kIsWeb) {
      if (dictId == null) throw Exception('dictId required for Web reading');
      final bytes = await DatabaseHelper().getFilePart(dictId!, p.basename(path), offset, length);
      if (bytes == null) throw Exception('Failed to read from virtual FS: ${p.basename(path)}');
      return utf8.decode(bytes, allowMalformed: true);
    }

    if (isDz) {
      if (_dzReader == null) throw Exception('DictReader not opened. Call open() first.');
      return await _dzReader!.read(offset, length);
    }

    final bytes = await source.read(offset, length);
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Reads multiple definitions at the given offsets and lengths.
  Future<List<String>> readBulk(List<({int offset, int length})> entries) async {
    if (kIsWeb) {
      // For Web, we can still do it sequentially or optimize DatabaseHelper if needed,
      // but for now, let's keep it simple for the wrapper.
      final List<String> results = [];
      for (final entry in entries) {
        results.add(await readAtIndex(entry.offset, entry.length));
      }
      return results;
    }

    if (isDz) {
      if (_dzReader == null) await open();
      final dzEntries = entries.map((e) => (e.offset, e.length)).toList();
      final results = await _dzReader!.readBulk(dzEntries);
      return results;
    }

    // For plain .dict, we sort by offset to minimize seeker movement and avoid parallel handle conflicts.
    // Our RandomAccessSource implementations use a single handle, so we MUST be sequential.
    // We keep track of original indices to return results in requested order
    final entriesWithIndex = entries.asMap().entries.toList()
      ..sort((a, b) => a.value.offset.compareTo(b.value.offset));

    final List<String?> results = List.filled(entries.length, null);
    for (final item in entriesWithIndex) {
      results[item.key] = await readAtIndex(item.value.offset, item.value.length);
    }
    return results.cast<String>();
  }

  /// Closes the file.
  /// For plain `.dict` files this is a no-op (no persistent handle was opened).
  Future<void> close() async {
    if (kIsWeb) return;
    if (isDz) {
      await _dzReader?.close();
      _dzReader = null;
    }
    await source.close();
  }

  /// Reads the definition at the given offset and length.
  /// For plain `.dict` files, [readAtIndex] is always safe to call directly.
  /// For `.dict.dz` files, opens+reads+closes if the reader isn't already open.
  Future<String> readEntry(int offset, int length) async {
    if (kIsWeb || !isDz || _dzReader != null) {
      return await readAtIndex(offset, length);
    }

    await open();
    try {
      return await readAtIndex(offset, length);
    } finally {
      await close();
    }
  }
}
