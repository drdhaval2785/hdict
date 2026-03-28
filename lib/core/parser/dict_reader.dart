import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:hdict/core/database/database_helper.dart';
import 'package:dictzip_reader/dictzip_reader.dart'
    hide RandomAccessSource, FileRandomAccessSource, MemoryRandomAccessSource;
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
  static Future<DictReader> fromPath(String path, {int? dictId, String? name}) async {
    return DictReader(
      path,
      source: FileRandomAccessSource(path),
      dictId: dictId,
    );
  }

  /// Factory to create an instance from a linked source (SAF or Bookmark).
  /// On Android [source] must be the content:// URI of the .dict/.dict.dz file
  /// so that [isDz] is correctly computed from the actual file extension.
  static Future<DictReader> fromLinkedSource(
    String source, {
    String? targetPath,
    String? actualPath,
    String? name,
  }) async {
    if (Platform.isAndroid) {
      // On Android 'source' is the SAF content:// URI of the .dict or .dict.dz file.
      // Use 'source' (not 'actualPath' which may be the .ifo URI) as 'path' so that
      // isDz correctly detects .dict.dz and opens the dictzip reader.
      return DictReader(source, source: SafRandomAccessSource(source, name: name));
    } else if (Platform.isIOS || Platform.isMacOS) {
      final String path = actualPath ?? targetPath ?? source;
      return DictReader(
        path,
        source: BookmarkRandomAccessSource(source, targetPath: targetPath),
      );
    } else {
      // For Linux/Windows, linked source is just a direct path for now
      final String fullPath = targetPath != null
          ? p.join(source, targetPath)
          : source;
      return DictReader(fullPath, source: FileRandomAccessSource(fullPath));
    }
  }

  /// Factory to create a DictReader from an Android SAF URI.
  static Future<DictReader> fromUri(String uri, {int? dictId}) async {
    return DictReader(uri, source: SafRandomAccessSource(uri), dictId: dictId);
  }

  /// Factory to create a DictReader from in-memory bytes.
  /// Useful for small .dict.dz files loaded entirely into memory for fast I/O.
  static Future<DictReader> fromBytes(
    Uint8List bytes, {
    String? fileName,
    int? dictId,
  }) async {
    final path = fileName ?? 'memory.dict';
    final memorySource = MemoryRandomAccessSource(bytes);
    return DictReader(path, source: memorySource, dictId: dictId);
  }

  DictzipReader? _dzReader;

  /// True for .dict.dz files; false for plain .dict.
  /// Exposed so callers can decide whether locking is needed.
  bool get isDz => path.toLowerCase().endsWith('.dz');

  /// Opens the file for reading.
  /// Calls [source.open()] first to prepare the underlying source:
  /// - For [SafRandomAccessSource]: pre-fills the 1MB read-ahead buffer so the
  ///   very first [readAtIndex] call is always a cache hit (~0ms instead of
  ///   100-140ms MethodChannel roundtrip per dictionary).
  /// - For [FileRandomAccessSource]: opens and holds the OS file handle.
  /// - For [MemoryRandomAccessSource]: no-op.
  ///
  /// For `.dict.dz` files this also initialises the [DictzipLocalReader].
  Future<void> open() async {
    if (kIsWeb) return;
    // Prepare the underlying source (fills SAF buffer / opens file handle).
    await source.open();
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
      final bytes = await DatabaseHelper().getFilePart(
        dictId!,
        p.basename(path),
        offset,
        length,
      );
      if (bytes == null)
        throw Exception('Failed to read from virtual FS: ${p.basename(path)}');
      return utf8.decode(bytes, allowMalformed: true);
    }

    if (isDz) {
      if (_dzReader == null)
        throw Exception('DictReader not opened. Call open() first.');
      return await _dzReader!.read(offset, length);
    }

    final bytes = await source.read(offset, length);
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Reads multiple definitions at the given offsets and lengths.
  Future<List<String>> readBulk(
    List<({int offset, int length})> entries,
  ) async {
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

    // For SAF, read entries in PARALLEL if not in memory, for much better performance.
    // However, if the data is already in memory, use a SERIAL loop to avoid Future overhead.
    final src = source;
    bool isFast = src is FileRandomAccessSource;
    if (src is SafRandomAccessSource && src.isFullFileInMemory) {
      isFast = true;
    }

    final List<String> results = List.filled(entries.length, '');

    if (isFast) {
      // SERIAL PATH: Minimize event loop churn for in-memory/local data
      for (int i = 0; i < entries.length; i++) {
        results[i] = await readAtIndex(entries[i].offset, entries[i].length);
      }
    } else {
      // PARALLEL PATH: Launch all reads in parallel using Future.wait()
      final entriesWithIndex = entries.asMap().entries.toList();
      final futures = entriesWithIndex.map((item) async {
        final result = await readAtIndex(item.value.offset, item.value.length);
        return (index: item.key, content: result);
      }).toList();

      final responses = await Future.wait(futures);
      for (final resp in responses) {
        results[resp.index] = resp.content;
      }
    }

    return results;
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
